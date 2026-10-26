/* Prints the source line of every XML_Parse / XML_ParseBuffer call before it runs. */
#include <stdio.h>

static enum XML_Status trace_parse(XML_Parser p, const char *s, int len, int final, int line) {
	fprintf(stderr, "[line %d] XML_Parse len=%d final=%d\n", line, len, final);
	fflush(stderr);
	return XML_Parse(p, s, len, final);
}

static enum XML_Status trace_parse_buffer(XML_Parser p, int len, int final, int line) {
	fprintf(stderr, "[line %d] XML_ParseBuffer len=%d final=%d\n", line, len, final);
	fflush(stderr);
	return XML_ParseBuffer(p, len, final);
}

#define XML_Parse(p, s, l, f) trace_parse((p), (s), (l), (f), __LINE__)
#define XML_ParseBuffer(p, l, f) trace_parse_buffer((p), (l), (f), __LINE__)
