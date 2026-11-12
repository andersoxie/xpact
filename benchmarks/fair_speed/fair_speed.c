/* fair_speed.c: time one document through libexpat.dll or xpact.dll with the same code (andersoxie#275).

   Both libraries export the Expat C API, so the harness loads either one with LoadLibrary and calls it through
   the same function pointers. A checksum over the events (element names, attributes, text) shows that both did
   the same work; text is hashed byte by byte, so how it is split into callbacks does not change the checksum.

   Usage: fair_speed <dll> <file> <chunk bytes, 0 = whole> <callbacks 0|1> <namespaces 0|1> <iterations>
   Prints one line: status code ms_per_parse checksum (status 1 = accepted). The time covers creating the parser,
   every XML_Parse call and freeing the parser; reading the file is not timed.
   Build: cl /O2 fair_speed.c   (no import library: the DLL is loaded at run time) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

typedef void *XML_Parser;
typedef void (__cdecl *StartH)(void *, const char *, const char **);
typedef void (__cdecl *EndH)(void *, const char *);
typedef void (__cdecl *TextH)(void *, const char *, int);
typedef XML_Parser (__cdecl *CreateF)(const char *);
typedef XML_Parser (__cdecl *CreateNSF)(const char *, char);
typedef void (__cdecl *FreeF)(XML_Parser);
typedef int (__cdecl *ParseF)(XML_Parser, const char *, int, int);
typedef int (__cdecl *ErrF)(XML_Parser);
typedef void (__cdecl *SetUserF)(XML_Parser, void *);
typedef void (__cdecl *SetElemF)(XML_Parser, StartH, EndH);
typedef void (__cdecl *SetTextF)(XML_Parser, TextH);

static unsigned long long hash;
static void mix(const char *s, size_t n) { for (size_t i = 0; i < n; i++) { hash ^= (unsigned char)s[i]; hash *= 1099511628211ULL; } }
static void __cdecl on_start(void *u, const char *name, const char **atts) {
  (void)u; mix("<", 1); mix(name, strlen(name));
  for (int i = 0; atts[i]; i += 2) { mix(" ", 1); mix(atts[i], strlen(atts[i])); mix("=", 1); mix(atts[i + 1], strlen(atts[i + 1])); }
}
static void __cdecl on_end(void *u, const char *name) { (void)u; mix("/", 1); mix(name, strlen(name)); }
static void __cdecl on_text(void *u, const char *s, int n) { (void)u; mix(s, (size_t)n); }

int main(int argc, char **argv) {
  if (argc < 7) { fprintf(stderr, "usage: fair_speed <dll> <file> <chunk> <callbacks> <namespaces> <iterations>\n"); return 2; }
  HMODULE lib = LoadLibraryA(argv[1]);
  if (!lib) { fprintf(stderr, "cannot load %s\n", argv[1]); return 2; }
  CreateF create = (CreateF)GetProcAddress(lib, "XML_ParserCreate");
  CreateNSF create_ns = (CreateNSF)GetProcAddress(lib, "XML_ParserCreateNS");
  FreeF parser_free = (FreeF)GetProcAddress(lib, "XML_ParserFree");
  ParseF parse = (ParseF)GetProcAddress(lib, "XML_Parse");
  ErrF error = (ErrF)GetProcAddress(lib, "XML_GetErrorCode");
  SetUserF set_user = (SetUserF)GetProcAddress(lib, "XML_SetUserData");
  SetElemF set_elem = (SetElemF)GetProcAddress(lib, "XML_SetElementHandler");
  SetTextF set_text = (SetTextF)GetProcAddress(lib, "XML_SetCharacterDataHandler");
  if (!create || !create_ns || !parser_free || !parse || !error || !set_user || !set_elem || !set_text) { fprintf(stderr, "missing export\n"); return 2; }

  FILE *f = fopen(argv[2], "rb");
  if (!f) { fprintf(stderr, "cannot open %s\n", argv[2]); return 2; }
  fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
  char *data = malloc(size > 0 ? size : 1); fread(data, 1, size, f); fclose(f);
  long chunk = atol(argv[3]); int callbacks = atoi(argv[4]), ns = atoi(argv[5]), iterations = atoi(argv[6]);
  if (chunk <= 0 || chunk > size) chunk = size > 0 ? size : 1;

  LARGE_INTEGER fr, t0, t1; QueryPerformanceFrequency(&fr);
  int status = 1, code = 0; unsigned long long checksum = 0;
  QueryPerformanceCounter(&t0);
  for (int it = 0; it < iterations; it++) {
    hash = 14695981039346656037ULL;
    XML_Parser p = ns ? create_ns(NULL, '|') : create(NULL);
    if (callbacks) { set_user(p, NULL); set_elem(p, on_start, on_end); set_text(p, on_text); }
    status = 1;
    for (long i = 0; i < size || i == 0; i += chunk) {
      long n = size - i < chunk ? size - i : chunk;
      if (!parse(p, data + i, (int)n, i + n >= size)) { status = 0; break; }
    }
    code = status ? 0 : error(p);
    parser_free(p);
    checksum = hash;
  }
  QueryPerformanceCounter(&t1);
  printf("%d %d %.6f %016llx\n", status, code, (t1.QuadPart - t0.QuadPart) * 1000.0 / fr.QuadPart / iterations, callbacks ? checksum : 0ULL);
  free(data);
  return 0;
}
