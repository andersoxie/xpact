/* Feed one XML file to XML_Parse in pieces of N bytes and time it.
   Usage: chunk_time <file> <chunk-size> [repeat]
   Prints: chunk status error starts ends text_bytes checksum ms */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include "xpact.h"

static long g_starts, g_ends, g_text;
static unsigned long g_sum;

static void mix(const char *s, int n) {
	int i;
	for (i = 0; i < n; i++) g_sum = g_sum * 31u + (unsigned char)s[i];
}

static void XMLCALL on_start(void *u, const XML_Char *name, const XML_Char **atts) {
	(void)u;
	g_starts++;
	mix(name, (int)strlen(name));
	for (; atts && *atts; atts++) mix(*atts, (int)strlen(*atts));
}

static void XMLCALL on_end(void *u, const XML_Char *name) {
	(void)u;
	g_ends++;
	mix(name, (int)strlen(name));
}

static void XMLCALL on_text(void *u, const XML_Char *s, int len) {
	(void)u;
	g_text += len;
	mix(s, len);
}

int main(int argc, char **argv) {
	FILE *f;
	char *data;
	long size, pos;
	int chunk, repeat, r, status = XML_STATUS_OK;
	LARGE_INTEGER t0, t1, freq;
	XML_Parser p;
	if (argc < 3) { fprintf(stderr, "usage: chunk_time <file> <chunk> [repeat]\n"); return 2; }
	f = fopen(argv[1], "rb");
	if (!f) { perror("open"); return 2; }
	fseek(f, 0, SEEK_END); size = ftell(f); fseek(f, 0, SEEK_SET);
	data = (char *)malloc(size > 0 ? size : 1);
	if (fread(data, 1, size, f) != (size_t)size) { fprintf(stderr, "read failed\n"); return 2; }
	fclose(f);
	chunk = atoi(argv[2]);
	if (chunk <= 0) chunk = (int)size;
	repeat = argc > 3 ? atoi(argv[3]) : 1;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&t0);
	for (r = 0; r < repeat; r++) {
		g_starts = g_ends = g_text = 0; g_sum = 0;
		p = XML_ParserCreate(NULL);
		XML_SetElementHandler(p, on_start, on_end);
		XML_SetCharacterDataHandler(p, on_text);
		for (pos = 0; pos < size && status != XML_STATUS_ERROR; pos += chunk) {
			int n = (int)((size - pos) < chunk ? (size - pos) : chunk);
			status = XML_Parse(p, data + pos, n, XML_FALSE);
		}
		if (status != XML_STATUS_ERROR) status = XML_Parse(p, "", 0, XML_TRUE);
		if (r + 1 == repeat) {
			QueryPerformanceCounter(&t1);
			printf("%d\t%s\t%d\t%ld\t%ld\t%ld\t%lu\t%.1f\n", chunk, status == XML_STATUS_OK ? "OK" : "ERROR",
				(int)XML_GetErrorCode(p), g_starts, g_ends, g_text, g_sum,
				(double)(t1.QuadPart - t0.QuadPart) * 1000.0 / (double)freq.QuadPart / repeat);
		}
		XML_ParserFree(p);
	}
	return 0;
}
