#if defined(_MSC_VER)
#define _CRT_SECURE_NO_WARNINGS
#endif

#ifdef XPACT_USE_SYSTEM_EXPAT
#include <expat.h>
#else
#include "xpact.h"
#endif

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum parse_mode {
	MODE_DIRECT = 1,
	MODE_BUFFER = 2
};

struct crc32_state {
	unsigned long value;
};

struct text_buffer {
	char *data;
	size_t count;
	size_t capacity;
};

struct parse_digest {
	struct crc32_state semantic;
	struct crc32_state trace;
	struct text_buffer text;
	unsigned long events;
	unsigned long text_bytes;
	int failed;
};

struct parse_result {
	enum XML_Status status;
	enum XML_Error error;
	XML_Index byte_index;
	XML_Size line;
	XML_Size column;
	unsigned long semantic_crc;
	unsigned long trace_crc;
	unsigned long events;
	unsigned long text_bytes;
	int digest_failed;
};

struct chunk_sizes {
	size_t *items;
	size_t count;
	size_t capacity;
};

static unsigned long g_crc32_table[256];
static int g_crc32_ready = 0;

static void
crc32_prepare(void) {
	unsigned long value;
	unsigned int index;
	unsigned int bit;

	if (g_crc32_ready) {
		return;
	}
	for (index = 0; index < 256; index++) {
		value = index;
		for (bit = 0; bit < 8; bit++) {
			if ((value & 1u) != 0u) {
				value = 0xedb88320UL ^ (value >> 1);
			} else {
				value >>= 1;
			}
		}
		g_crc32_table[index] = value;
	}
	g_crc32_ready = 1;
}

static void
crc32_reset(struct crc32_state *state) {
	crc32_prepare();
	state->value = 0xffffffffUL;
}

static void
crc32_update(struct crc32_state *state, const void *bytes, size_t count) {
	const unsigned char *cursor = (const unsigned char *)bytes;
	size_t index;

	for (index = 0; index < count; index++) {
		state->value = g_crc32_table[(state->value ^ cursor[index]) & 0xffu] ^ (state->value >> 8);
	}
}

static void
crc32_update_byte(struct crc32_state *state, unsigned char value) {
	crc32_update(state, &value, 1);
}

static unsigned long
crc32_finish(const struct crc32_state *state) {
	return state->value ^ 0xffffffffUL;
}

static void
digest_u32(struct crc32_state *state, unsigned long value) {
	unsigned char bytes[4];

	bytes[0] = (unsigned char)(value & 0xffu);
	bytes[1] = (unsigned char)((value >> 8) & 0xffu);
	bytes[2] = (unsigned char)((value >> 16) & 0xffu);
	bytes[3] = (unsigned char)((value >> 24) & 0xffu);
	crc32_update(state, bytes, sizeof(bytes));
}

static void
digest_string(struct crc32_state *state, const char *value) {
	size_t count = value != NULL ? strlen(value) : 0u;

	digest_u32(state, (unsigned long)count);
	if (count > 0u) {
		crc32_update(state, value, count);
	}
}

static int
text_buffer_append(struct text_buffer *buffer, const char *text, size_t count) {
	char *resized;
	size_t new_capacity;

	if (count == 0u) {
		return 1;
	}
	if (buffer->count + count > buffer->capacity) {
		new_capacity = buffer->capacity == 0u ? 256u : buffer->capacity;
		while (new_capacity < buffer->count + count) {
			if (new_capacity > ((size_t)-1) / 2u) {
				return 0;
			}
			new_capacity *= 2u;
		}
		resized = (char *)realloc(buffer->data, new_capacity);
		if (resized == NULL) {
			return 0;
		}
		buffer->data = resized;
		buffer->capacity = new_capacity;
	}
	memcpy(buffer->data + buffer->count, text, count);
	buffer->count += count;
	return 1;
}

static void
text_buffer_dispose(struct text_buffer *buffer) {
	free(buffer->data);
	buffer->data = NULL;
	buffer->count = 0u;
	buffer->capacity = 0u;
}

static void
parse_digest_init(struct parse_digest *digest) {
	crc32_reset(&digest->semantic);
	crc32_reset(&digest->trace);
	digest->text.data = NULL;
	digest->text.count = 0u;
	digest->text.capacity = 0u;
	digest->events = 0u;
	digest->text_bytes = 0u;
	digest->failed = 0;
}

static void
parse_digest_dispose(struct parse_digest *digest) {
	text_buffer_dispose(&digest->text);
}

static int
flush_semantic_text(struct parse_digest *digest) {
	if (digest->text.count == 0u) {
		return 1;
	}
	crc32_update_byte(&digest->semantic, (unsigned char)'T');
	digest_u32(&digest->semantic, (unsigned long)digest->text.count);
	crc32_update(&digest->semantic, digest->text.data, digest->text.count);
	digest->text.count = 0u;
	return 1;
}

static unsigned long
attribute_pair_count(const XML_Char **atts) {
	unsigned long count = 0u;

	if (atts != NULL) {
		while (atts[count * 2u] != NULL) {
			count++;
		}
	}
	return count;
}

static void XMLCALL
start_element(void *userData, const XML_Char *name, const XML_Char **atts) {
	struct parse_digest *digest = (struct parse_digest *)userData;
	unsigned long attribute_count;
	unsigned long index;

	if (digest == NULL || digest->failed) {
		return;
	}
	if (!flush_semantic_text(digest)) {
		digest->failed = 1;
		return;
	}
	attribute_count = attribute_pair_count(atts);

	crc32_update_byte(&digest->semantic, (unsigned char)'S');
	digest_string(&digest->semantic, name);
	digest_u32(&digest->semantic, attribute_count);

	crc32_update_byte(&digest->trace, (unsigned char)'S');
	digest_string(&digest->trace, name);
	digest_u32(&digest->trace, attribute_count);

	for (index = 0u; index < attribute_count; index++) {
		digest_string(&digest->semantic, atts[index * 2u]);
		digest_string(&digest->semantic, atts[index * 2u + 1u]);
		digest_string(&digest->trace, atts[index * 2u]);
		digest_string(&digest->trace, atts[index * 2u + 1u]);
	}
	digest->events++;
}

static void XMLCALL
end_element(void *userData, const XML_Char *name) {
	struct parse_digest *digest = (struct parse_digest *)userData;

	if (digest == NULL || digest->failed) {
		return;
	}
	if (!flush_semantic_text(digest)) {
		digest->failed = 1;
		return;
	}
	crc32_update_byte(&digest->semantic, (unsigned char)'E');
	digest_string(&digest->semantic, name);
	crc32_update_byte(&digest->trace, (unsigned char)'E');
	digest_string(&digest->trace, name);
	digest->events++;
}

static void XMLCALL
character_data(void *userData, const XML_Char *s, int len) {
	struct parse_digest *digest = (struct parse_digest *)userData;

	if (digest == NULL || digest->failed || len <= 0) {
		return;
	}
	if (!text_buffer_append(&digest->text, s, (size_t)len)) {
		digest->failed = 1;
		return;
	}
	crc32_update_byte(&digest->trace, (unsigned char)'T');
	digest_u32(&digest->trace, (unsigned long)len);
	crc32_update(&digest->trace, s, (size_t)len);
	digest->events++;
	digest->text_bytes += (unsigned long)len;
}

static const char *
mode_name(enum parse_mode mode) {
	return mode == MODE_BUFFER ? "buffer" : "direct";
}

static const char *
status_name(enum XML_Status status) {
	if (status == XML_STATUS_OK) {
		return "OK";
	}
	if (status == XML_STATUS_SUSPENDED) {
		return "SUSPENDED";
	}
	return "ERROR";
}

static enum XML_Status
parse_chunk(XML_Parser parser, const char *chunk, size_t count, int is_final, enum parse_mode mode) {
	void *buffer;

	if (count > (size_t)INT_MAX) {
		return XML_STATUS_ERROR;
	}
	if (mode == MODE_BUFFER) {
		buffer = XML_GetBuffer(parser, (int)count);
		if (buffer == NULL) {
			return XML_STATUS_ERROR;
		}
		if (count > 0u) {
			memcpy(buffer, chunk, count);
		}
		return XML_ParseBuffer(parser, (int)count, is_final);
	}
	return XML_Parse(parser, chunk, (int)count, is_final);
}

static int
parse_document(const char *document, size_t document_length, size_t chunk_size, enum parse_mode mode, struct parse_result *result) {
	XML_Parser parser;
	struct parse_digest digest;
	size_t offset = 0u;
	size_t count;
	int is_final;

	memset(result, 0, sizeof(*result));
	result->status = XML_STATUS_ERROR;
	result->error = XML_ERROR_NONE;
	result->byte_index = -1;
	result->line = 1;
	result->column = 0;

	if (chunk_size == 0u || chunk_size > (size_t)INT_MAX) {
		result->error = XML_ERROR_NONE;
		return 0;
	}

	parse_digest_init(&digest);
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		result->error = XML_ERROR_NO_MEMORY;
		parse_digest_dispose(&digest);
		return 0;
	}

	XML_SetUserData(parser, &digest);
	XML_SetElementHandler(parser, start_element, end_element);
	XML_SetCharacterDataHandler(parser, character_data);

	if (document_length == 0u) {
		result->status = parse_chunk(parser, "", 0u, XML_TRUE, mode);
	} else {
		while (offset < document_length) {
			count = document_length - offset;
			if (count > chunk_size) {
				count = chunk_size;
			}
			is_final = (offset + count == document_length) ? XML_TRUE : XML_FALSE;
			result->status = parse_chunk(parser, document + offset, count, is_final, mode);
			offset += count;
			if (result->status != XML_STATUS_OK) {
				break;
			}
		}
	}

	if (!flush_semantic_text(&digest)) {
		digest.failed = 1;
	}
	result->error = XML_GetErrorCode(parser);
	result->byte_index = XML_GetCurrentByteIndex(parser);
	result->line = XML_GetCurrentLineNumber(parser);
	result->column = XML_GetCurrentColumnNumber(parser);
	result->semantic_crc = crc32_finish(&digest.semantic);
	result->trace_crc = crc32_finish(&digest.trace);
	result->events = digest.events;
	result->text_bytes = digest.text_bytes;
	result->digest_failed = digest.failed;

	XML_ParserFree(parser);
	parse_digest_dispose(&digest);
	return !digest.failed;
}

static int
append_bytes(char **buffer, size_t *used, size_t *capacity, const char *text, size_t count) {
	char *resized;
	size_t new_capacity;

	if (*used + count + 1u > *capacity) {
		new_capacity = *capacity == 0u ? 1024u : *capacity;
		while (new_capacity < *used + count + 1u) {
			if (new_capacity > ((size_t)-1) / 2u) {
				return 0;
			}
			new_capacity *= 2u;
		}
		resized = (char *)realloc(*buffer, new_capacity);
		if (resized == NULL) {
			return 0;
		}
		*buffer = resized;
		*capacity = new_capacity;
	}
	memcpy(*buffer + *used, text, count);
	*used += count;
	(*buffer)[*used] = '\0';
	return 1;
}

static int
append_text(char **buffer, size_t *used, size_t *capacity, const char *text) {
	return append_bytes(buffer, used, capacity, text, strlen(text));
}

static char *
make_sample_document(int repeat, size_t *length_out) {
	char *buffer = NULL;
	size_t used = 0u;
	size_t capacity = 0u;
	int index;
	char item[256];
	int written;

	if (repeat <= 0) {
		repeat = 1;
	}
	if (!append_text(&buffer, &used, &capacity, "<?xml version='1.0'?>\n")) goto fail;
	if (!append_text(&buffer, &used, &capacity, "<!DOCTYPE catalog [<!ENTITY company 'AT&amp;T'>]>\n")) goto fail;
	if (!append_text(&buffer, &used, &capacity, "<catalog>")) goto fail;
	for (index = 1; index <= repeat; index++) {
		written = snprintf(
			item,
			sizeof(item),
			"<item id=\"%d\" code=\"c%d\">value %d &company;</item>",
			index,
			index % 17,
			index
		);
		if (written < 0 || (size_t)written >= sizeof(item)) {
			goto fail;
		}
		if (!append_text(&buffer, &used, &capacity, item)) goto fail;
	}
	if (!append_text(&buffer, &used, &capacity, "</catalog>")) goto fail;
	*length_out = used;
	return buffer;

fail:
	free(buffer);
	return NULL;
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
		fprintf(stderr, "XML file is too large for the chunked CRC harness: %s\n", path);
		fclose(file);
		return NULL;
	}
	if (fseek(file, 0, SEEK_SET) != 0) {
		fprintf(stderr, "cannot rewind XML file: %s\n", path);
		fclose(file);
		return NULL;
	}
	buffer = (char *)malloc((size_t)size + 1u);
	if (buffer == NULL) {
		fprintf(stderr, "cannot allocate XML file buffer: %s\n", path);
		fclose(file);
		return NULL;
	}
	read_count = fread(buffer, 1u, (size_t)size, file);
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

static void
chunk_sizes_dispose(struct chunk_sizes *sizes) {
	free(sizes->items);
	sizes->items = NULL;
	sizes->count = 0u;
	sizes->capacity = 0u;
}

static int
chunk_sizes_add(struct chunk_sizes *sizes, size_t value) {
	size_t new_capacity;
	size_t *resized;

	if (value == 0u || value > (size_t)INT_MAX) {
		return 0;
	}
	if (sizes->count == sizes->capacity) {
		new_capacity = sizes->capacity == 0u ? 16u : sizes->capacity * 2u;
		resized = (size_t *)realloc(sizes->items, new_capacity * sizeof(size_t));
		if (resized == NULL) {
			return 0;
		}
		sizes->items = resized;
		sizes->capacity = new_capacity;
	}
	sizes->items[sizes->count++] = value;
	return 1;
}

static int
parse_chunk_sizes(const char *text, size_t document_length, struct chunk_sizes *sizes) {
	const char *cursor = text;
	char *end = NULL;
	unsigned long value;

	sizes->items = NULL;
	sizes->count = 0u;
	sizes->capacity = 0u;

	while (*cursor != '\0') {
		while (*cursor == ',' || *cursor == ' ' || *cursor == '\t') {
			cursor++;
		}
		if (*cursor == '\0') {
			break;
		}
		if (strncmp(cursor, "whole", 5u) == 0 && (cursor[5] == '\0' || cursor[5] == ',' || cursor[5] == ' ' || cursor[5] == '\t')) {
			if (!chunk_sizes_add(sizes, document_length == 0u ? 1u : document_length)) {
				goto fail;
			}
			cursor += 5;
		} else {
			errno = 0;
			value = strtoul(cursor, &end, 10);
			if (errno != 0 || end == cursor || value == 0u || value > (unsigned long)INT_MAX) {
				goto fail;
			}
			if (!chunk_sizes_add(sizes, (size_t)value)) {
				goto fail;
			}
			cursor = end;
		}
		while (*cursor == ' ' || *cursor == '\t') {
			cursor++;
		}
		if (*cursor != '\0' && *cursor != ',') {
			goto fail;
		}
	}
	if (sizes->count == 0u) {
		goto fail;
	}
	return 1;

fail:
	chunk_sizes_dispose(sizes);
	return 0;
}

static const char *
base_name(const char *path) {
	const char *result = path;
	const char *cursor;

	for (cursor = path; *cursor != '\0'; cursor++) {
		if (*cursor == '/' || *cursor == '\\') {
			result = cursor + 1;
		}
	}
	return result;
}

static enum parse_mode
parse_mode_name(const char *text) {
	if (strcmp(text, "buffer") == 0) {
		return MODE_BUFFER;
	}
	if (strcmp(text, "direct") == 0) {
		return MODE_DIRECT;
	}
	return 0;
}

static void
usage(const char *program) {
	fprintf(
		stderr,
		"usage: %s [--file PATH] [--repeat N] [--chunk-sizes LIST] [--mode direct|buffer] [--engine LABEL] [--document-id LABEL] [--version]\n",
		program
	);
}

int
main(int argc, char **argv) {
	const char *file_path = NULL;
	const char *chunk_size_text = "1,2,3,4,5,7,8,16,31,64,127,1024,4096,whole";
	const char *engine = "expat-compatible";
	const char *document_id = NULL;
	char *document = NULL;
	size_t document_length = 0u;
	int repeat = 100;
	enum parse_mode mode = MODE_DIRECT;
	struct chunk_sizes sizes;
	struct parse_result result;
	unsigned long expected_semantic_crc = 0u;
	int have_expected = 0;
	int failed = 0;
	size_t index;
	const XML_LChar *version;
	const XML_LChar *error_text;

	for (index = 1u; index < (size_t)argc; index++) {
		if (strcmp(argv[index], "--version") == 0) {
			puts(XML_ExpatVersion());
			return 0;
		} else if (strcmp(argv[index], "--file") == 0 && index + 1u < (size_t)argc) {
			file_path = argv[++index];
		} else if (strcmp(argv[index], "--repeat") == 0 && index + 1u < (size_t)argc) {
			repeat = atoi(argv[++index]);
			if (repeat <= 0) {
				usage(argv[0]);
				return 2;
			}
		} else if (strcmp(argv[index], "--chunk-sizes") == 0 && index + 1u < (size_t)argc) {
			chunk_size_text = argv[++index];
		} else if (strcmp(argv[index], "--mode") == 0 && index + 1u < (size_t)argc) {
			mode = parse_mode_name(argv[++index]);
			if (mode == 0) {
				usage(argv[0]);
				return 2;
			}
		} else if (strcmp(argv[index], "--engine") == 0 && index + 1u < (size_t)argc) {
			engine = argv[++index];
		} else if (strcmp(argv[index], "--document-id") == 0 && index + 1u < (size_t)argc) {
			document_id = argv[++index];
		} else {
			usage(argv[0]);
			return 2;
		}
	}

	if (file_path != NULL) {
		document = read_file(file_path, &document_length);
		if (document == NULL) {
			return 1;
		}
		if (document_id == NULL) {
			document_id = base_name(file_path);
		}
	} else {
		document = make_sample_document(repeat, &document_length);
		if (document == NULL) {
			fputs("cannot allocate generated XML document\n", stderr);
			return 1;
		}
		if (document_id == NULL) {
			document_id = "generated-catalog";
		}
	}

	if (!parse_chunk_sizes(chunk_size_text, document_length, &sizes)) {
		fprintf(stderr, "invalid chunk-size list: %s\n", chunk_size_text);
		free(document);
		return 2;
	}

	version = XML_ExpatVersion();
	printf("engine\tversion\tmode\tdocument\tbytes\tchunk_size\tstatus\terror_code\terror_text\tbyte_index\tline\tcolumn\tsemantic_crc\ttrace_crc\tevents\ttext_bytes\n");

	for (index = 0u; index < sizes.count; index++) {
		if (!parse_document(document, document_length, sizes.items[index], mode, &result)) {
			failed = 1;
		}
		error_text = XML_ErrorString(result.error);
		printf(
			"%s\t%s\t%s\t%s\t%llu\t%llu\t%s\t%d\t%s\t%lld\t%llu\t%llu\t%08lx\t%08lx\t%lu\t%lu\n",
			engine,
			version != NULL ? version : "",
			mode_name(mode),
			document_id,
			(unsigned long long)document_length,
			(unsigned long long)sizes.items[index],
			status_name(result.status),
			(int)result.error,
			error_text != NULL ? error_text : "",
			(long long)result.byte_index,
			(unsigned long long)result.line,
			(unsigned long long)result.column,
			result.semantic_crc,
			result.trace_crc,
			result.events,
			result.text_bytes
		);
		if (result.status != XML_STATUS_OK || result.digest_failed) {
			failed = 1;
		} else if (!have_expected) {
			expected_semantic_crc = result.semantic_crc;
			have_expected = 1;
		} else if (result.semantic_crc != expected_semantic_crc) {
			fprintf(
				stderr,
				"semantic CRC mismatch for chunk size %llu: got %08lx expected %08lx\n",
				(unsigned long long)sizes.items[index],
				result.semantic_crc,
				expected_semantic_crc
			);
			failed = 1;
		}
	}

	chunk_sizes_dispose(&sizes);
	free(document);
	if (failed) {
		return 1;
	}
	fprintf(stderr, "chunked CRC harness ok: %s, %s, semantic %08lx\n", engine, mode_name(mode), expected_semantic_crc);
	return 0;
}
