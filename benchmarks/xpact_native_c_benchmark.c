#include "xpact.h"

#include <limits.h>
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

static char *
read_file(const char *path, size_t *length_out) {
	FILE *file;
	long size;
	char *buffer;
	size_t read_count;

	file = fopen(path, "rb");
	if (file == NULL) {
		fprintf(stderr, "cannot open XML file: %s\n", path);
		return NULL;
	}
	if (fseek(file, 0, SEEK_END) != 0) {
		fprintf(stderr, "cannot seek XML file: %s\n", path);
		fclose(file);
		return NULL;
	}
	size = ftell(file);
	if (size < 0) {
		fprintf(stderr, "cannot determine XML file size: %s\n", path);
		fclose(file);
		return NULL;
	}
	if (size > INT_MAX) {
		fprintf(stderr, "XML file is too large for this whole-buffer benchmark: %s\n", path);
		fclose(file);
		return NULL;
	}
	if (fseek(file, 0, SEEK_SET) != 0) {
		fprintf(stderr, "cannot rewind XML file: %s\n", path);
		fclose(file);
		return NULL;
	}
	buffer = (char *)malloc((size_t)size + 1);
	if (buffer == NULL) {
		fprintf(stderr, "cannot allocate XML file buffer: %s\n", path);
		fclose(file);
		return NULL;
	}
	read_count = fread(buffer, 1, (size_t)size, file);
	fclose(file);
	if (read_count != (size_t)size) {
		fprintf(stderr, "cannot read complete XML file: %s\n", path);
		free(buffer);
		return NULL;
	}
	buffer[size] = '\0';
	*length_out = (size_t)size;
	return buffer;
}

static int
configure_parser(XML_Parser parser, int use_callbacks) {
	if (parser == NULL) {
		fputs("parser allocation failed\n", stderr);
		return 1;
	}

	if (use_callbacks) {
		XML_SetElementHandler(parser, start_element, end_element);
		XML_SetCharacterDataHandler(parser, character_data);
	}
	return 0;
}

static int
parse_document_with_parser(XML_Parser parser, const char *document, size_t document_length) {
	enum XML_Status status;
	enum XML_Error error;

	status = XML_Parse(parser, document, (int)document_length, XML_TRUE);
	if (status == XML_STATUS_ERROR) {
		error = XML_GetErrorCode(parser);
		fprintf(stderr, "parse failed: %s\n", XML_ErrorString(error));
		if (error == XML_ERROR_NOT_STARTED) {
			return XPACT_BENCHMARK_UNAVAILABLE;
		}
		return 1;
	}
	return 0;
}

static int
parse_document(const char *document, size_t document_length, int use_callbacks) {
	XML_Parser parser = XML_ParserCreate(NULL);
	int status;

	status = configure_parser(parser, use_callbacks);
	if (status != 0) {
		if (parser != NULL) {
			XML_ParserFree(parser);
		}
		return status;
	}

	status = parse_document_with_parser(parser, document, document_length);
	XML_ParserFree(parser);
	return status;
}

static int
parse_documents_with_reused_parser(const char *document, size_t document_length, int use_callbacks, int iterations) {
	XML_Parser parser = XML_ParserCreate(NULL);
	int i;
	int status;

	status = configure_parser(parser, use_callbacks);
	if (status != 0) {
		if (parser != NULL) {
			XML_ParserFree(parser);
		}
		return status;
	}

	for (i = 0; i < iterations; i++) {
		status = parse_document_with_parser(parser, document, document_length);
		if (status != 0) {
			XML_ParserFree(parser);
			return status;
		}
		if (i + 1 < iterations && XML_ParserReset(parser, NULL) != XML_TRUE) {
			fputs("parser reset failed\n", stderr);
			XML_ParserFree(parser);
			return 1;
		}
	}

	XML_ParserFree(parser);
	return 0;
}

int
main(int argc, char **argv) {
	int iterations = 1000;
	int use_callbacks = 1;
	int reuse_parser = 0;
	char document[4096];
	char *file_document = NULL;
	const char *parse_document_text;
	const char *file_path = NULL;
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
		} else if (strcmp(argv[i], "--reuse-parser") == 0) {
			reuse_parser = 1;
		} else if (strcmp(argv[i], "--file") == 0 && i + 1 < argc) {
			file_path = argv[++i];
		} else {
			fprintf(stderr, "usage: %s [--iterations N] [--mode callbacks|tokenizer] [--reuse-parser] [--file PATH] [--version]\n", argv[0]);
			return 2;
		}
	}

	if (iterations <= 0) {
		fputs("--iterations must be positive\n", stderr);
		return 2;
	}

	if (file_path != NULL) {
		file_document = read_file(file_path, &document_length);
		if (file_document == NULL) {
			return 1;
		}
		parse_document_text = file_document;
	} else {
		document_length = sample_document(document, sizeof(document));
		if (document_length == 0) {
			fputs("sample document buffer too small\n", stderr);
			return 1;
		}
		parse_document_text = document;
	}

	if (reuse_parser) {
		parse_status = parse_documents_with_reused_parser(parse_document_text, document_length, use_callbacks, iterations);
		if (parse_status != 0) {
			free(file_document);
			return parse_status;
		}
	} else {
		for (i = 0; i < iterations; i++) {
			parse_status = parse_document(parse_document_text, document_length, use_callbacks);
			if (parse_status != 0) {
				free(file_document);
				return parse_status;
			}
		}
	}

	printf(
		"xpact native C ABI %s parsed %d documents (%lu bytes each, %lu callback events, parser %s).\n",
		use_callbacks ? "callbacks" : "tokenizer",
		iterations,
		(unsigned long)document_length,
		g_events,
		reuse_parser ? "reused" : "created per document"
	);
	free(file_document);
	return 0;
}
