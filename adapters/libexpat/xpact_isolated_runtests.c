/* Upstream assertions use longjmp. Exiting an isolated child instead keeps
 * failed callbacks from bypassing Eiffel's GC stack cleanup in the next test. */
#include "expat_config.h"
#include <windows.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "expat.h"
#include "minicheck.h"
#include "common.h"
#include "basic_tests.h"
#include "ns_tests.h"
#include "misc_tests.h"
#include "alloc_tests.h"
#include "nsalloc_tests.h"
#include "acc_tests.h"

typedef struct {
    TCase *test_case;
    tcase_test_function test;
    const char *name;
    const char *source;
} XpactTest;

XML_Parser g_parser = NULL;
extern XML_Bool g_reparseDeferralEnabledDefault;
static XpactTest *tests;
static size_t test_count;
static size_t test_capacity;
static const XpactTest *active_test;
static const char *active_phase = "during setup";
static int active_deferral;

static void
print_failure(const XpactTest *test, const char *context,
              const char *phase, const char *file, int line) {
    fprintf(stdout, "FAIL [%s]: %s (%s at %s:%d)\n", context,
            test->name, phase, file, line);
    fflush(stdout);
}

/* All test/helper assertions resolve here; only minicheck.c renames _fail. */
void
_fail(const char *file, int line, const char *message) {
    char context[80];
    if (message != NULL)
        fprintf(stderr, "ERROR: %s\n", message);
    if (active_test == NULL) {
        fprintf(stderr, "***Exception: assertion outside an isolated test\n");
        fflush(stderr);
        _Exit(2);
    }
    snprintf(context, sizeof(context), "chunksize=%d deferral=%d",
             g_chunkSize, active_deferral);
    print_failure(active_test, context, active_phase,
                  file != NULL ? file : active_test->source, line);
    fflush(stderr);
    /* Do not call teardown or unwind the active Eiffel callback. */
    _Exit(EXIT_FAILURE);
}

void
xpact_adapter_add_test(TCase *test_case, tcase_test_function test,
                        const char *name, const char *source) {
    if (test_count == test_capacity) {
        size_t capacity = test_capacity == 0 ? 64 : test_capacity * 2;
        XpactTest *grown;
        if (capacity < test_capacity || capacity > SIZE_MAX / sizeof(*tests)) {
            fprintf(stderr, "***Exception: test registry is too large\n");
            exit(2);
        }
        grown = (XpactTest *)realloc(tests, capacity * sizeof(*tests));
        if (grown == NULL) {
            fprintf(stderr, "***Exception: cannot allocate test registry\n");
            exit(2);
        }
        tests = grown;
        test_capacity = capacity;
    }
    tests[test_count].test_case = test_case;
    tests[test_count].test = test;
    tests[test_count].name = name;
    tests[test_count].source = source;
    test_count++;
    tcase_add_test(test_case, test);
}

static Suite *
make_suite(void) {
    Suite *suite = suite_create("basic");
    if (suite == NULL) {
        fprintf(stderr, "***Exception: cannot allocate upstream suite\n");
        exit(2);
    }
    make_basic_test_case(suite);
    make_namespace_test_case(suite);
    make_miscellaneous_test_case(suite);
    make_alloc_test_case(suite);
    make_nsalloc_test_case(suite);
#if XML_GE == 1
    make_accounting_test_case(suite);
#endif
    return suite;
}

static void
run_test(size_t index) {
    active_test = &tests[index];
    for (g_chunkSize = 0; g_chunkSize <= 5; g_chunkSize++) {
        for (active_deferral = 0; active_deferral <= 1; active_deferral++) {
            g_reparseDeferralEnabledDefault = (XML_Bool)active_deferral;
            active_phase = "during setup";
            if (active_test->test_case->setup != NULL)
                active_test->test_case->setup();
            active_phase = "during actual test";
            active_test->test();
            active_phase = "during teardown";
            if (active_test->test_case->teardown != NULL)
                active_test->test_case->teardown();
        }
    }
    active_test = NULL;
}

static int
registry_matches_suite(const Suite *suite) {
    size_t registered = 0;
    for (const TCase *test_case = suite->tests; test_case != NULL;
         test_case = test_case->next_tcase) {
        for (int i = 0; i < test_case->ntests; i++) {
            size_t matches = 0;
            for (size_t j = 0; j < test_count; j++) {
                if (tests[j].test_case == test_case
                    && tests[j].test == test_case->tests[i])
                    matches++;
            }
            if (matches != 1) {
                fprintf(stderr, "***Exception: upstream registration lacks unique test metadata\n");
                return 0;
            }
            registered++;
        }
    }
    if (registered != test_count) {
        fprintf(stderr, "***Exception: test metadata does not cover the upstream suite\n");
        return 0;
    }
    return 1;
}

static void
windows_error(const XpactTest *test, const char *operation, DWORD error) {
    fprintf(stderr, "***Exception: %s: %s failed (Windows error %lu)\n",
            test->name, operation, (unsigned long)error);
    fflush(stderr);
}

static int
close_handle(HANDLE *handle, const XpactTest *test, const char *kind) {
    int success = 1;
    if (*handle != NULL) {
        if (!CloseHandle(*handle)) {
            windows_error(test, kind, GetLastError());
            success = 0;
        }
        *handle = NULL;
    }
    return success;
}

static int
terminate_child(HANDLE process, HANDLE job, int assigned,
                  const XpactTest *test) {
    BOOL stopped = assigned ? TerminateJobObject(job, ERROR_TIMEOUT)
                            : TerminateProcess(process, ERROR_TIMEOUT);
    if (!stopped) {
        windows_error(test, assigned ? "TerminateJobObject" : "TerminateProcess",
                      GetLastError());
        if (assigned && !TerminateProcess(process, ERROR_TIMEOUT))
            windows_error(test, "TerminateProcess", GetLastError());
    }
    switch (WaitForSingleObject(process, 10000)) {
    case WAIT_OBJECT_0:
        return 1;
    case WAIT_FAILED:
        windows_error(test, "wait for terminated child", GetLastError());
        break;
    default:
        fprintf(stderr, "***Exception: %s: child termination did not complete\n",
                test->name);
        fflush(stderr);
    }
    return 0;
}

static int
run_child(const wchar_t *executable, size_t index, DWORD timeout_seconds) {
    const XpactTest *test = &tests[index];
    wchar_t command[32768];
    STARTUPINFOEXW startup;
    PROCESS_INFORMATION process;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits;
    HANDLE job = NULL;
    DWORD exit_code = 0;
    DWORD wait_result;
    SIZE_T attribute_size = 0;
    int attributes_initialized = 0;
    int assigned = 0, running = 0, failed = 0, infrastructure_failure = 0;
    int fatal_cleanup = 0;

    ZeroMemory(&startup, sizeof(startup));
    ZeroMemory(&process, sizeof(process));
    ZeroMemory(&limits, sizeof(limits));
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    startup.StartupInfo.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    startup.StartupInfo.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    if (_snwprintf_s(command, sizeof(command) / sizeof(command[0]), _TRUNCATE,
                     L"\"%ls\" --xpact-child %zu", executable, index) < 0) {
        fprintf(stderr, "***Exception: %s: executable path is too long\n", test->name);
        infrastructure_failure = 1;
        goto cleanup;
    }
    /* NULL security attributes keep the job handle out of the child. */
    job = CreateJobObjectW(NULL, NULL);
    if (job == NULL) {
        windows_error(test, "CreateJobObjectW", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                                 &limits, sizeof(limits))) {
        windows_error(test, "SetInformationJobObject", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    InitializeProcThreadAttributeList(NULL, 1, 0, &attribute_size);
    if (attribute_size == 0) {
        windows_error(test, "size process attributes", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    startup.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)malloc(attribute_size);
    if (startup.lpAttributeList == NULL) {
        windows_error(test, "allocate process attributes", ERROR_NOT_ENOUGH_MEMORY);
        infrastructure_failure = 1;
        goto cleanup;
    }
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &attribute_size)) {
        windows_error(test, "initialize process attributes", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    attributes_initialized = 1;
    /* Join the job atomically at creation, including if the parent is cancelled
     * before CreateProcessW returns. The job handle itself is not inherited. */
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0,
                                   PROC_THREAD_ATTRIBUTE_JOB_LIST,
                                   &job, sizeof(job), NULL, NULL)) {
        windows_error(test, "set child job attribute", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    if (!CreateProcessW(executable, command, NULL, NULL, TRUE,
                         CREATE_SUSPENDED | CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT,
                         NULL, NULL, &startup.StartupInfo, &process)) {
        windows_error(test, "CreateProcessW", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    running = 1;
    assigned = 1;
    if (ResumeThread(process.hThread) == (DWORD)-1) {
        windows_error(test, "ResumeThread", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    if (!close_handle(&process.hThread, test, "close child thread")) {
        infrastructure_failure = 1;
        fatal_cleanup = 1;
        goto cleanup;
    }
    wait_result = WaitForSingleObject(process.hProcess, timeout_seconds * 1000);
    if (wait_result == WAIT_TIMEOUT) {
        fprintf(stderr, "***Timeout: %s exceeded %lu seconds\n", test->name,
                (unsigned long)timeout_seconds);
        infrastructure_failure = 1;
        goto cleanup;
    }
    if (wait_result != WAIT_OBJECT_0) {
        windows_error(test, "wait for child", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    running = 0;
    if (!GetExitCodeProcess(process.hProcess, &exit_code)) {
        windows_error(test, "GetExitCodeProcess", GetLastError());
        infrastructure_failure = 1;
        goto cleanup;
    }
    failed = exit_code != EXIT_SUCCESS;
    if (exit_code != EXIT_SUCCESS && exit_code != EXIT_FAILURE) {
        fprintf(stderr, "***Exception: %s exited with code 0x%08lX\n",
                test->name, (unsigned long)exit_code);
        infrastructure_failure = 1;
    }

cleanup:
    if (running && !terminate_child(process.hProcess, job, assigned, test))
        fatal_cleanup = 1;
    if (attributes_initialized)
        DeleteProcThreadAttributeList(startup.lpAttributeList);
    free(startup.lpAttributeList);
    /* Kill any descendants a completed test might have left behind. */
    if (!close_handle(&job, test, "close child job"))
        fatal_cleanup = 1;
    if (!close_handle(&process.hThread, test, "close child thread"))
        fatal_cleanup = 1;
    if (!close_handle(&process.hProcess, test, "close child process"))
        fatal_cleanup = 1;
    if (fatal_cleanup)
        return 2;
    if (infrastructure_failure) {
        print_failure(test, "isolated child", "during child process", test->source, 0);
        return 1;
    }
    return failed;
}

static int
parse_unsigned(const char *text, unsigned long long maximum,
                 unsigned long long *value) {
    char *end;
    unsigned long long parsed;
    if (text[0] < '0' || text[0] > '9')
        return 0;
    errno = 0;
    parsed = strtoull(text, &end, 10);
    if (errno == ERANGE || *end != '\0' || parsed > maximum)
        return 0;
    *value = parsed;
    return 1;
}

static const char *
source_name(const char *source) {
    const char *slash = strrchr(source, '/');
    const char *backslash = strrchr(source, '\\');
    if (backslash != NULL && (slash == NULL || backslash > slash))
        slash = backslash;
    return slash == NULL ? source : slash + 1;
}

static int
selected(const char *name, int argc, char **argv) {
    int has_filter = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--test") == 0) {
            has_filter = 1;
            if (strcmp(argv[++i], name) == 0)
                return 1;
        }
    }
    return !has_filter;
}

int
main(int argc, char **argv) {
    wchar_t executable[32768];
    DWORD path_length;
    DWORD timeout_seconds = 120;
    unsigned long long child_index = 0;
    int child_mode = 0, has_filter = 0, list_tests = 0;
    int verbosity = CK_NORMAL, failures = 0;
    size_t checks = 0;
    Suite *suite;
    SRunner *runner;

    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#ifdef _MSC_VER
    _set_error_mode(_OUT_TO_STDERR);
    _set_abort_behavior(0, _CALL_REPORTFAULT);
#endif
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0)
            verbosity = CK_VERBOSE;
        else if (strcmp(argv[i], "-q") == 0 || strcmp(argv[i], "--quiet") == 0)
            verbosity = CK_SILENT;
        else if (strcmp(argv[i], "--list-tests") == 0)
            list_tests = 1;
        else if (strcmp(argv[i], "--test") == 0 && i + 1 < argc) {
            has_filter = 1;
            i++;
        } else if (strcmp(argv[i], "--timeout") == 0 && i + 1 < argc) {
            unsigned long long value;
            if (!parse_unsigned(argv[++i], 3600, &value) || value == 0) {
                fprintf(stderr, "runtests: --timeout must be an integer from 1 to 3600\n");
                return 2;
            }
            timeout_seconds = (DWORD)value;
        } else if (strcmp(argv[i], "--xpact-child") == 0 && i + 1 < argc) {
            if (child_mode || !parse_unsigned(argv[++i], SIZE_MAX, &child_index)) {
                fprintf(stderr, "runtests: invalid child index\n");
                return 2;
            }
            child_mode = 1;
        } else {
            fprintf(stderr, "runtests: unknown or incomplete option '%s'\n", argv[i]);
            return 2;
        }
    }
    if (child_mode && (has_filter || list_tests)) {
        fprintf(stderr, "runtests: child mode cannot select or list tests\n");
        return 2;
    }
    suite = make_suite();
    runner = srunner_create(suite);
    if (runner == NULL || test_count == 0 || test_count > INT_MAX
        || !registry_matches_suite(suite)) {
        fprintf(stderr, "***Exception: upstream test registry is empty or unavailable\n");
        free(tests);
        if (runner != NULL)
            srunner_free(runner);
        return 2;
    }
    if (child_mode) {
        if (child_index >= test_count) {
            fprintf(stderr, "runtests: child index is out of range\n");
            srunner_free(runner);
            free(tests);
            return 2;
        }
        run_test((size_t)child_index);
        srunner_free(runner);
        free(tests);
        return EXIT_SUCCESS;
    }
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--test") == 0) {
            size_t matches = 0;
            const char *name = argv[++i];
            for (size_t j = 0; j < test_count; j++)
                if (strcmp(tests[j].name, name) == 0)
                    matches++;
            if (matches != 1) {
                fprintf(stderr, "runtests: test name '%s' is unknown or ambiguous\n", name);
                srunner_free(runner);
                free(tests);
                return 2;
            }
        }
    }
    if (list_tests) {
        printf("source\tname\n");
        for (size_t i = 0; i < test_count; i++)
            if (selected(tests[i].name, argc, argv))
                printf("%s\t%s\n", source_name(tests[i].source), tests[i].name);
        srunner_free(runner);
        free(tests);
        return EXIT_SUCCESS;
    }
    path_length = GetModuleFileNameW(NULL, executable,
                                   sizeof(executable) / sizeof(executable[0]));
    if (path_length == 0 || path_length >= sizeof(executable) / sizeof(executable[0])) {
        fprintf(stderr, "***Exception: cannot resolve isolated test executable path\n");
        srunner_free(runner);
        free(tests);
        return 2;
    }
    if (verbosity != CK_SILENT)
        printf("Expat version: %" XML_FMT_STR "\n", XML_ExpatVersion());
    fflush(stdout);
    fflush(stderr);
    for (size_t i = 0; i < test_count; i++) {
        int failed;
        if (!selected(tests[i].name, argc, argv))
            continue;
        checks++;
        failed = run_child(executable, i, timeout_seconds);
        if (failed == 2) {
            fprintf(stderr, "***Exception: aborting after unconfirmed child cleanup: %s\n",
                    tests[i].name);
            fflush(stderr);
            srunner_free(runner);
            free(tests);
            return 2;
        }
        failures += failed;
        if (!failed && verbosity == CK_VERBOSE) {
            printf("PASS: %s\n", tests[i].name);
            fflush(stdout);
        }
    }
    printf("%d%%: Checks: %zu, Failed: %d\n",
           (int)(((checks - failures) * 100) / checks), checks, failures);
    fflush(stdout);
    srunner_free(runner);
    free(tests);
    return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
