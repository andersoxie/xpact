/* Sample only the fair_speed benchmark running on the main thread of this
   executable. No kernel drivers, system tracing, or access to other processes.
   The benchmark's first and second counter reads delimit the sampled region. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <mmsystem.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_M_X64)
#error Build with the x64 MSVC toolchain.
#endif

enum { MAX_MODULES = 256, MAX_FRAMES = 96 };
typedef struct {
    DWORD64 base;
    DWORD size;
    const RUNTIME_FUNCTION *table;
    size_t nfunctions;
    char name[MAX_PATH];
} SampleModule;
typedef struct {
    unsigned module_no;
    DWORD64 rva;
} SampleFrame;

static SampleModule modules[MAX_MODULES];
static unsigned nmodules, samples, capture_errors, unknown_leaf;
static FILE *out;
static HANDLE start_event, end_event, benchmark_thread;
static ULONG_PTR stack_low, stack_high;
static unsigned counter_calls;

static BOOL WINAPI benchmark_counter(LARGE_INTEGER *value) {
    ++counter_calls;
    SetEvent(counter_calls == 1 ? start_event : end_event);
    return QueryPerformanceCounter(value);
}

#define main stock_benchmark_main
#define QueryPerformanceCounter benchmark_counter
#include "../../../benchmarks/fair_speed/fair_speed.c"
#undef QueryPerformanceCounter
#undef main

static int snapshot_modules(void) {
    HMODULE handles[MAX_MODULES];
    DWORD bytes;
    if (!EnumProcessModules(GetCurrentProcess(), handles, sizeof(handles), &bytes) ||
        bytes > sizeof(handles)) return 0;
    nmodules = bytes / sizeof(*handles);
    for (unsigned i = 0; i < nmodules; ++i) {
        const BYTE *base = (const BYTE *)handles[i];
        const IMAGE_DOS_HEADER *dos = (const IMAGE_DOS_HEADER *)base;
        const IMAGE_NT_HEADERS64 *pe = (const IMAGE_NT_HEADERS64 *)(base + dos->e_lfanew);
        const IMAGE_DATA_DIRECTORY dir = pe->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXCEPTION];
        SampleModule *m = &modules[i];
        if (pe->Signature != IMAGE_NT_SIGNATURE || pe->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)
            return 0;
        if (!GetModuleBaseNameA(GetCurrentProcess(), handles[i], m->name, sizeof(m->name))) return 0;
        m->base = (DWORD64)base;
        m->size = pe->OptionalHeader.SizeOfImage;
        if (dir.Size && dir.VirtualAddress < m->size && dir.Size <= m->size - dir.VirtualAddress) {
            m->table = (const RUNTIME_FUNCTION *)(base + dir.VirtualAddress);
            m->nfunctions = dir.Size / sizeof(*m->table);
        }
    }
    return 1;
}

static unsigned identify(DWORD64 pc) {
    for (unsigned i = 0; i < nmodules; ++i) {
        if (pc >= modules[i].base && pc - modules[i].base < modules[i].size) return i;
    }
    return nmodules;
}

/* Use the saved image's PE exception directory, avoiding symbol/loader lookup
   while the benchmark thread is suspended. These workloads use native images. */
static const RUNTIME_FUNCTION *find_function(const SampleModule *m, DWORD64 pc) {
    DWORD rva = (DWORD)(pc - m->base);
    size_t low = 0, high = m->nfunctions;
    while (low < high) {
        size_t mid = low + (high - low) / 2;
        const RUNTIME_FUNCTION *fn = &m->table[mid];
        if (rva < fn->BeginAddress) high = mid;
        else if (rva >= fn->EndAddress) low = mid + 1;
        else return fn;
    }
    return NULL;
}

static unsigned unwind(CONTEXT *ct, SampleFrame *frames) {
    unsigned n = 0;
    __try {
        while (ct->Rip && n < MAX_FRAMES && ct->Rsp >= stack_low && ct->Rsp <= stack_high - sizeof(DWORD64)) {
            DWORD64 pc = ct->Rip;
            unsigned id = identify(pc);
            frames[n].module_no = id;
            /* Return addresses point just after the calling instruction. */
            frames[n].rva = id < nmodules ? pc - modules[id].base - (n != 0) : 0;
            ++n;
            if (id == nmodules) break;
            const SampleModule *mod = &modules[id];
            const RUNTIME_FUNCTION *fn = find_function(mod, pc);
            DWORD64 old_sp = ct->Rsp;
            if (fn) {
                PVOID handler_data;
                DWORD64 establisher;
                RtlVirtualUnwind(UNW_FLAG_NHANDLER, mod->base, pc, (PRUNTIME_FUNCTION)fn,
                                 ct, &handler_data, &establisher, NULL);
            } else {
                ct->Rip = *(const DWORD64 *)ct->Rsp;
                ct->Rsp += sizeof(DWORD64);
            }
            if (ct->Rsp < old_sp || (ct->Rsp == old_sp && ct->Rip == pc)) break;
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        ++capture_errors;
    }
    return n;
}

static DWORD WINAPI sample_thread(void *unused) {
    (void)unused;
    HANDLE waits[2] = {end_event, start_event};
    if (WaitForMultipleObjects(2, waits, FALSE, INFINITE) != WAIT_OBJECT_0 + 1) return 0;
    while (WaitForSingleObject(end_event, 1) == WAIT_TIMEOUT) {
        SampleFrame frames[MAX_FRAMES];
        CONTEXT context = {0};
        context.ContextFlags = CONTEXT_FULL;
        unsigned n = 0;
        if (SuspendThread(benchmark_thread) == (DWORD)-1) { ++capture_errors; break; }
        if (GetThreadContext(benchmark_thread, &context)) n = unwind(&context, frames);
        else ++capture_errors;
        if (ResumeThread(benchmark_thread) == (DWORD)-1) { ++capture_errors; break; }
        if (n) {
            ++samples;
            if (frames[0].module_no == nmodules) ++unknown_leaf;
            for (unsigned j = 0; j < n; ++j) {
                const SampleFrame fr = frames[j];
                fprintf(out, "%u\t%u\t%s\t0x%llx\n", samples, j,
                        fr.module_no < nmodules ? modules[fr.module_no].name : "[unknown]",
                        (unsigned long long)fr.rva);
            }
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 8) {
        fprintf(stderr, "usage: sample <dll> <file> <chunk> <callbacks 0|1> <namespaces 0|1> <iterations> <output.tsv>\n");
        return 2;
    }
    /* Preload exactly the same image the stock harness will request. */
    if (!LoadLibraryA(argv[1]) || !snapshot_modules()) {
        fprintf(stderr, "Could not load DLL or enumerate loaded PE images (%lu)\n", GetLastError());
        return 2;
    }
    GetCurrentThreadStackLimits(&stack_low, &stack_high);
    if (!DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(),
                         &benchmark_thread, 0, FALSE, DUPLICATE_SAME_ACCESS)) return 2;
    out = fopen(argv[7], "w");
    if (!out) return 2;
    fputs("sample_id\tframe_index\tmodule\trva\n", out);
    start_event = CreateEventW(NULL, TRUE, FALSE, NULL);
    end_event = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!start_event || !end_event) return 2;
    timeBeginPeriod(1);
    HANDLE sampler = CreateThread(NULL, 0, sample_thread, NULL, 0, NULL);
    if (!sampler) return 2;
    int result = stock_benchmark_main(7, argv);
    SetEvent(end_event);
    WaitForSingleObject(sampler, INFINITE);
    timeEndPeriod(1);
    fclose(out);
    CloseHandle(sampler);
    CloseHandle(start_event);
    CloseHandle(end_event);
    CloseHandle(benchmark_thread);
    fprintf(stderr, "%u main-thread stack samples; %u capture errors; %u unmapped leaves\n",
            samples, capture_errors, unknown_leaf);
    return result ? result : (samples && !capture_errors ? 0 : 3);
}
