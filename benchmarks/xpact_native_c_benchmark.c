#include "xpact.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define XPACT_BENCHMARK_UNAVAILABLE 77

static unsigned long g_events = 0;

static void XMLCALL
start_element(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)name;
	(void)atts;
	g_events++;
}

static void XMLCALL
end_element(void *userData, const XML_Char *name) {
	(void)userData;
	(void)name;
	g_events++;
}

static void XMLCALL
character_data(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	if (len > 0) {
		g_events++;
	}
}

static size_t
sample_document(char *buffer, size_t capacity) {
	size_t used = 0;
	int index;
	int written;

	written = snprintf(buffer + used, capacity - used, "<catalog>");
	if (written < 0 || (size_t)written >= capacity - used) {
		return 0;
	}
	used += (size_t)written;

	for (index = 1; index <= 100; index++) {
		written = snprintf(buffer + used, capacity - used, "<item id=\"%d\">value</item>", index);
		if (written < 0 || (size_t)written >= capacity - used) {
			return 0;
		}
		used += (size_t)written;
	}

	written = snprintf(buffer + used, capacity - used, "</catalog>");
	if (written < 0 || (size_t)written >= capacity - used) {
		return 0;
	}
	used += (size_t)written;

	return used;
}

static int
parse_document(const char *document, size_t document_length, int use_callbacks) {
	XML_Parser parser = XML_ParserCreate(NULL);
	enum XML_Status status;
	enum XML_Error error;

	if (parser == NULL) {
		fputs("parser allocation failed\n", stderr);
		return 1;
	}

	if (use_callbacks) {
		XML_SetElementHandler(parser, start_element, end_element);
		XML_SetCharacterDataHandler(parser, character_data);
	}

	status = XML_Parse(parser, document, (int)document_length, XML_TRUE);
	if (status == XML_STATUS_ERROR) {
		error = XML_GetErrorCode(parser);
		fprintf(stderr, "parse failed: %s\n", XML_ErrorString(error));
		XML_ParserFree(parser);
		if (error == XML_ERROR_NOT_STARTED) {
			return XPACT_BENCHMARK_UNAVAILABLE;
		}
		return 1;
	}

	XML_ParserFree(parser);
	return 0;
}

int
main(int argc, char **argv) {
	int iterations = 1000;
	int use_callbacks = 1;
	char document[4096];
	size_t document_length;
	int i;
	int parse_status;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--version") == 0) {
			puts(XML_ExpatVersion());
			return 0;
		} else if (strcmp(argv[i], "--iterations") == 0 && i + 1 < argc) {
			iterations = atoi(argv[++i]);
		} else if (strcmp(argv[i], "--mode") == 0 && i + 1 < argc) {
			const char *mode = argv[++i];
			if (strcmp(mode, "callbacks") == 0) {
				use_callbacks = 1;
			} else if (strcmp(mode, "tokenizer") == 0) {
				use_callbacks = 0;
			} else {
				fprintf(stderr, "unknown mode: %s\n", mode);
				return 2;
			}
		} else {
			fprintf(stderr, "usage: %s [--iterations N] [--mode callbacks|tokenizer] [--version]\n", argv[0]);
			return 2;
		}
	}

	if (iterations <= 0) {
		fputs("--iterations must be positive\n", stderr);
		return 2;
	}

	document_length = sample_document(document, sizeof(document));
	if (document_length == 0) {
		fputs("sample document buffer too small\n", stderr);
		return 1;
	}

	for (i = 0; i < iterations; i++) {
		parse_status = parse_document(document, document_length, use_callbacks);
		if (parse_status != 0) {
			return parse_status;
		}
	}

	printf(
		"xpact native C ABI %s parsed %d documents (%lu bytes each, %lu callback events).\n",
		use_callbacks ? "callbacks" : "tokenizer",
		iterations,
		(unsigned long)document_length,
		g_events
	);
	return 0;
}
