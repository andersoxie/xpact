/* Differential trace: parse each file listed on stdin in pieces and print every callback
   with its position, then the final status, error and position.
   Usage: trace <mode> <chunk> < file-list
   mode: events | default | suspend | abort (non-resumable stop at callback N, default 3) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xpact.h"

static XML_Parser g_p;
static FILE *g_out;
static int g_mode, g_count, g_stop_every;

static void pos(const char *kind) {
	fprintf(g_out, "%s@%lu:%lu:%ld", kind, (unsigned long)XML_GetCurrentLineNumber(g_p),
		(unsigned long)XML_GetCurrentColumnNumber(g_p), (long)XML_GetCurrentByteIndex(g_p));
}

static void text(const char *s, int n) {
	int i;
	fputc('[', g_out);
	for (i = 0; i < n; i++) {
		unsigned char c = (unsigned char)s[i];
		if (c < 32 || c == '[' || c == ']' || c >= 127) fprintf(g_out, "\\x%02x", c); else fputc(c, g_out);
	}
	fputs("]\n", g_out);
}

static void maybe_stop(void) {
	g_count++;
	if (g_mode == 2 && g_stop_every > 0 && g_count % g_stop_every == 0) XML_StopParser(g_p, XML_TRUE);
	if (g_mode == 3 && g_count == g_stop_every) XML_StopParser(g_p, XML_FALSE);
}

static void XMLCALL on_start(void *u, const XML_Char *n, const XML_Char **a) {
	(void)u; pos("S"); text(n, (int)strlen(n));
	for (; a && *a; a++) { fputs("  a", g_out); text(*a, (int)strlen(*a)); }
	maybe_stop();
}
static void XMLCALL on_end(void *u, const XML_Char *n) { (void)u; pos("E"); text(n, (int)strlen(n)); maybe_stop(); }
static void XMLCALL on_text(void *u, const XML_Char *s, int n) { (void)u; pos("T"); text(s, n); maybe_stop(); }
static void XMLCALL on_pi(void *u, const XML_Char *t, const XML_Char *d) { (void)u; pos("P"); text(t, (int)strlen(t)); text(d, (int)strlen(d)); maybe_stop(); }
static void XMLCALL on_comment(void *u, const XML_Char *d) { (void)u; pos("C"); text(d, (int)strlen(d)); maybe_stop(); }
static void XMLCALL on_cdata_start(void *u) { (void)u; pos("<CD"); fputc('\n', g_out); maybe_stop(); }
static void XMLCALL on_cdata_end(void *u) { (void)u; pos("CD>"); fputc('\n', g_out); maybe_stop(); }
static void XMLCALL on_default(void *u, const XML_Char *s, int n) { (void)u; pos("D"); text(s, n); maybe_stop(); }
static void XMLCALL on_doctype(void *u, const XML_Char *n, const XML_Char *s, const XML_Char *p, int i) {
	(void)u; (void)s; (void)p; pos("DT"); text(n, (int)strlen(n)); fprintf(g_out, "  internal=%d\n", i); maybe_stop();
}
static void XMLCALL on_doctype_end(void *u) { (void)u; pos("DT>"); fputc('\n', g_out); maybe_stop(); }
static void XMLCALL on_entity(void *u, const XML_Char *n, int pe, const XML_Char *v, int vl, const XML_Char *b,
	const XML_Char *s, const XML_Char *p, const XML_Char *no) {
	(void)u; (void)b; (void)s; (void)p; (void)no; pos("EN"); fprintf(g_out, "%d", pe); text(n, (int)strlen(n));
	if (v) text(v, vl); maybe_stop();
}

static void run_file(const char *path, int chunk) {
	FILE *f = fopen(path, "rb");
	char *data;
	long size, at = 0;
	enum XML_Status st = XML_STATUS_OK;
	if (!f) return;
	fseek(f, 0, SEEK_END); size = ftell(f); fseek(f, 0, SEEK_SET);
	data = (char *)malloc(size > 0 ? size : 1);
	size = (long)fread(data, 1, size, f);
	fclose(f);
	fprintf(g_out, "== %s\n", path);
	g_p = XML_ParserCreate(NULL);
	g_count = 0;
	if (g_mode == 1) {
		XML_SetDefaultHandler(g_p, on_default);
	} else {
		XML_SetElementHandler(g_p, on_start, on_end);
		XML_SetCharacterDataHandler(g_p, on_text);
		XML_SetProcessingInstructionHandler(g_p, on_pi);
		XML_SetCommentHandler(g_p, on_comment);
		XML_SetCdataSectionHandler(g_p, on_cdata_start, on_cdata_end);
		XML_SetDoctypeDeclHandler(g_p, on_doctype, on_doctype_end);
		XML_SetEntityDeclHandler(g_p, on_entity);
	}
	for (;;) {
		int n = (int)((size - at) < chunk ? (size - at) : chunk);
		int final = at + n >= size;
		if (getenv("TRACE_CALLS")) fprintf(g_out, "#call %ld+%d\n", at, n);
		st = XML_Parse(g_p, data + at, n, final ? XML_TRUE : XML_FALSE);
		while (st == XML_STATUS_SUSPENDED) {
			fputs("~suspended\n", g_out);
			st = XML_ResumeParser(g_p);
		}
		at += n;
		if (st == XML_STATUS_ERROR || final) break;
	}
	pos("END");
	fprintf(g_out, " status=%d error=%d\n", (int)st, (int)XML_GetErrorCode(g_p));
	XML_ParserFree(g_p);
	free(data);
}

int main(int argc, char **argv) {
	char line[4096];
	int chunk;
	if (argc < 3) return 2;
	g_mode = strcmp(argv[1], "default") == 0 ? 1 : strcmp(argv[1], "suspend") == 0 ? 2 : strcmp(argv[1], "abort") == 0 ? 3 : 0;
	chunk = atoi(argv[2]);
	g_stop_every = argc > 3 ? atoi(argv[3]) : 3;
	g_out = stdout;
	while (fgets(line, sizeof line, stdin)) {
		line[strcspn(line, "\r\n")] = 0;
		if (line[0]) run_file(line, chunk);
	}
	return 0;
}
