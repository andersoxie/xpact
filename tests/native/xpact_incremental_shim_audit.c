#if defined(_MSC_VER)
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "xpact.h"

#include <stdio.h>
#include <string.h>

struct audit_state {
	XML_Parser parser;
	int start_count;
	int end_count;
	int text_count;
	int text_bytes;
	int stop_after_first_text;
	int max_context_size;
	int max_context_offset;
	int callback_failed;
};

static int g_failed = 0;

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

static const char *
parsing_name(enum XML_Parsing parsing) {
	if (parsing == XML_PARSING) {
		return "PARSING";
	}
	if (parsing == XML_FINISHED) {
		return "FINISHED";
	}
	if (parsing == XML_SUSPENDED) {
		return "SUSPENDED";
	}
	return "INITIALIZED";
}

static void
report_case(const char *name, const char *classification, int observed, const char *detail) {
	printf("%s\t%s\t%s\t%s\n", name, classification, observed ? "observed" : "unexpected", detail);
	if (!observed) {
		g_failed = 1;
	}
}

static void XMLCALL
start_element(void *userData, const XML_Char *name, const XML_Char **atts) {
	struct audit_state *state = (struct audit_state *)userData;
	(void)name;
	(void)atts;
	state->start_count++;
}

static void XMLCALL
end_element(void *userData, const XML_Char *name) {
	struct audit_state *state = (struct audit_state *)userData;
	(void)name;
	state->end_count++;
}

static void XMLCALL
character_data(void *userData, const XML_Char *s, int len) {
	struct audit_state *state = (struct audit_state *)userData;
	const char *context;
	int offset = 0;
	int size = 0;
	(void)s;

	if (len <= 0) {
		return;
	}
	state->text_count++;
	state->text_bytes += len;
	if (state->parser != NULL) {
		context = XML_GetInputContext(state->parser, &offset, &size);
		if (context == NULL) {
			state->callback_failed = 1;
		} else if (size > state->max_context_size) {
			state->max_context_size = size;
			state->max_context_offset = offset;
		}
	}
	if (state->stop_after_first_text && state->text_count == 1) {
		if (XML_StopParser(state->parser, XML_TRUE) != XML_STATUS_OK) {
			state->callback_failed = 1;
		}
	}
}

static int
test_parse_buffer_plain_start(void) {
	XML_Parser parser;
	XML_ParsingStatus parsing_status;
	struct audit_state state;
	void *buffer;
	enum XML_Status status;
	char detail[256];
	int observed;

	memset(&state, 0, sizeof(state));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("parse_buffer_plain_start_nonfinal", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	XML_SetUserData(parser, &state);
	XML_SetElementHandler(parser, start_element, end_element);
	buffer = XML_GetBuffer(parser, 5);
	if (buffer != NULL) {
		memcpy(buffer, "<doc>", 5u);
		status = XML_ParseBuffer(parser, 5, XML_FALSE);
	} else {
		status = XML_STATUS_ERROR;
	}
	XML_GetParsingStatus(parser, &parsing_status);
	observed = buffer != NULL && status == XML_STATUS_OK && state.start_count == 1 && parsing_status.parsing == XML_PARSING && !parsing_status.finalBuffer;
	(void)snprintf(
		detail,
		sizeof(detail),
		"status=%s start_after_first=%d parsing=%s final=%d",
		status_name(status),
		state.start_count,
		parsing_name(parsing_status.parsing),
		(int)parsing_status.finalBuffer
	);
	report_case("parse_buffer_plain_start_nonfinal", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

static int
test_plain_start_nonfinal(void) {
	XML_Parser parser;
	XML_ParsingStatus parsing_status;
	struct audit_state state;
	enum XML_Status status;
	char detail[256];
	int observed;

	memset(&state, 0, sizeof(state));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("plain_start_nonfinal", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	XML_SetUserData(parser, &state);
	XML_SetElementHandler(parser, start_element, end_element);
	status = XML_Parse(parser, "<doc>", 5, XML_FALSE);
	XML_GetParsingStatus(parser, &parsing_status);
	observed = status == XML_STATUS_OK && state.start_count == 1 && parsing_status.parsing == XML_PARSING && !parsing_status.finalBuffer;
	(void)snprintf(
		detail,
		sizeof(detail),
		"status=%s start_after_first=%d parsing=%s final=%d",
		status_name(status),
		state.start_count,
		parsing_name(parsing_status.parsing),
		(int)parsing_status.finalBuffer
	);
	report_case("plain_start_nonfinal", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

static int
test_attributed_start_nonfinal(void) {
	XML_Parser parser;
	struct audit_state state;
	enum XML_Status first_status;
	enum XML_Status final_status;
	int first_start_count;
	char detail[256];
	int observed;

	memset(&state, 0, sizeof(state));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("attributed_start_nonfinal", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	XML_SetUserData(parser, &state);
	XML_SetElementHandler(parser, start_element, end_element);
	first_status = XML_Parse(parser, "<doc id='1'>", 12, XML_FALSE);
	first_start_count = state.start_count;
	final_status = XML_Parse(parser, "x</doc>", 7, XML_TRUE);
	observed = first_status == XML_STATUS_OK && first_start_count == 1 && final_status == XML_STATUS_OK && state.start_count == 1 && state.end_count == 1;
	(void)snprintf(
		detail,
		sizeof(detail),
		"first_status=%s start_after_first=%d final_status=%s start_total=%d end_total=%d",
		status_name(first_status),
		first_start_count,
		status_name(final_status),
		state.start_count,
		state.end_count
	);
	report_case("attributed_start_nonfinal", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

static int
test_attributed_start_without_deferral(void) {
	XML_Parser parser;
	struct audit_state state;
	enum XML_Status status;
	XML_Bool configured;
	char detail[256];
	int observed;

	memset(&state, 0, sizeof(state));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("attributed_start_nonfinal_without_reparse_deferral", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	XML_SetUserData(parser, &state);
	XML_SetElementHandler(parser, start_element, end_element);
	configured = XML_SetReparseDeferralEnabled(parser, XML_FALSE);
	status = XML_Parse(parser, "<doc id='1'>", 12, XML_FALSE);
	observed = configured && status == XML_STATUS_OK && state.start_count == 1;
	(void)snprintf(
		detail,
		sizeof(detail),
		"configured=%d status=%s start_after_first=%d",
		(int)configured,
		status_name(status),
		state.start_count
	);
	report_case("attributed_start_nonfinal_without_reparse_deferral", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

static int
test_bounded_context_window(void) {
	XML_Parser parser;
	struct audit_state state;
	enum XML_Status first_status;
	enum XML_Status text_status;
	enum XML_Status final_status;
	char text[4096];
	char detail[256];
	int observed;

	memset(&state, 0, sizeof(state));
	memset(text, 'a', sizeof(text));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("input_context_uses_bounded_window", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	XML_SetUserData(parser, &state);
	XML_SetCharacterDataHandler(parser, character_data);
	first_status = XML_Parse(parser, "<doc>", 5, XML_FALSE);
	text_status = XML_Parse(parser, text, (int)sizeof(text), XML_FALSE);
	final_status = XML_Parse(parser, "</doc>", 6, XML_TRUE);
	observed =
		first_status == XML_STATUS_OK
		&& text_status == XML_STATUS_OK
		&& final_status == XML_STATUS_OK
		&& !state.callback_failed
		&& state.text_bytes == (int)sizeof(text)
		&& state.max_context_size > 0
		&& state.max_context_size <= 1024
		&& state.max_context_offset >= 0
		&& state.max_context_offset <= state.max_context_size;
	(void)snprintf(
		detail,
		sizeof(detail),
		"statuses=%s/%s/%s text_bytes=%d max_context_size=%d max_context_offset=%d",
		status_name(first_status),
		status_name(text_status),
		status_name(final_status),
		state.text_bytes,
		state.max_context_size,
		state.max_context_offset
	);
	report_case("input_context_uses_bounded_window", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

static int
test_suspend_resume_replay(void) {
	XML_Parser parser;
	XML_ParsingStatus parsing_status;
	struct audit_state state;
	enum XML_Status parse_status;
	enum XML_Status resume_status;
	char detail[256];
	int observed;
	const char *document = "<doc>one<child/>two</doc>";

	memset(&state, 0, sizeof(state));
	parser = XML_ParserCreate(NULL);
	if (parser == NULL) {
		report_case("suspend_resume_replay", "passes", 0, "parser allocation failed");
		return 0;
	}
	state.parser = parser;
	state.stop_after_first_text = 1;
	XML_SetUserData(parser, &state);
	XML_SetCharacterDataHandler(parser, character_data);
	parse_status = XML_Parse(parser, document, (int)strlen(document), XML_TRUE);
	XML_GetParsingStatus(parser, &parsing_status);
	state.stop_after_first_text = 0;
	resume_status = XML_ResumeParser(parser);
	observed =
		parse_status == XML_STATUS_SUSPENDED
		&& parsing_status.parsing == XML_SUSPENDED
		&& resume_status == XML_STATUS_OK
		&& !state.callback_failed
		&& state.text_bytes == 6;
	(void)snprintf(
		detail,
		sizeof(detail),
		"parse=%s suspended_parsing=%s resume=%s text_bytes=%d text_callbacks=%d",
		status_name(parse_status),
		parsing_name(parsing_status.parsing),
		status_name(resume_status),
		state.text_bytes,
		state.text_count
	);
	report_case("suspend_resume_replay", "passes", observed, detail);
	XML_ParserFree(parser);
	return observed;
}

struct latin1_state {
	XML_Parser parser;
	int body_index;
	int body_line;
	int starts;
	int ends;
	size_t text_length;
	int suspended;
	int failed;
};

static void
check_latin1_position(struct latin1_state *state, const char *token, int index, int count, int line, int column) {
	XML_Index actual_index = XML_GetCurrentByteIndex(state->parser);
	int actual_count = XML_GetCurrentByteCount(state->parser);
	XML_Size actual_line = XML_GetCurrentLineNumber(state->parser);
	XML_Size actual_column = XML_GetCurrentColumnNumber(state->parser);
	index += state->body_index;
	line += state->body_line;
	if (actual_index != index || actual_count != count || actual_line != (XML_Size)line || actual_column != (XML_Size)column) {
		fprintf(stderr, "Latin-1 %s: byte %lld+%d at %llu:%llu, expected %d+%d at %d:%d\n",
			token, (long long)actual_index, actual_count, (unsigned long long)actual_line,
			(unsigned long long)actual_column, index, count, line, column);
		state->failed = 1;
	}
}

static void XMLCALL
latin1_start(void *user_data, const XML_Char *name, const XML_Char **atts) {
	struct latin1_state *state = (struct latin1_state *)user_data;
	state->starts++;
	if (state->starts == 1 && strcmp(name, "r") == 0) {
		check_latin1_position(state, "<r>", 0, 3, 0, 0);
	} else if (state->starts == 2 && strcmp(name, "n") == 0 && atts != NULL &&
		atts[0] != NULL && strcmp(atts[0], "q") == 0 && atts[1] != NULL &&
		strcmp(atts[1], "\xc3\xa4") == 0 && atts[2] == NULL) {
		check_latin1_position(state, "<n q=...>", 6, 9, 1, 0);
		if (XML_StopParser(state->parser, XML_TRUE) != XML_STATUS_OK) {
			state->failed = 1;
		}
	} else {
		state->failed = 1;
	}
}

static void XMLCALL
latin1_end(void *user_data, const XML_Char *name) {
	struct latin1_state *state = (struct latin1_state *)user_data;
	state->ends++;
	if (state->ends == 1 && strcmp(name, "n") == 0) {
		check_latin1_position(state, "</n>", 16, 4, 1, 10);
	} else if (state->ends == 2 && strcmp(name, "r") == 0) {
		check_latin1_position(state, "</r>", 20, 4, 1, 14);
	} else {
		state->failed = 1;
	}
}

static void XMLCALL
latin1_text(void *user_data, const XML_Char *s, int length) {
	static const char expected[] = "\xc3\xa9\n\xc3\xb6";
	struct latin1_state *state = (struct latin1_state *)user_data;
	if ((size_t)length > sizeof(expected) - 1 - state->text_length ||
		memcmp(s, expected + state->text_length, (size_t)length) != 0) {
		state->failed = 1;
		return;
	}
	state->text_length += (size_t)length;
	if (state->starts == 2 && state->ends == 0 && length > 0) {
		int offset = 0;
		int size = 0;
		const char *context = XML_GetInputContext(state->parser, &offset, &size);
		check_latin1_position(state, "child text", 15, 1, 1, 9);
		if (context == NULL || offset < 0 || offset >= size || (unsigned char)context[offset] != 0xf6) {
			fprintf(stderr, "Latin-1 child text: input context does not point to raw 0xf6\n");
			state->failed = 1;
		}
	}
}

static enum XML_Status
feed_latin1(XML_Parser parser, const char *chunk, int final, int buffered) {
	int length = (int)strlen(chunk);
	if (buffered) {
		void *buffer = XML_GetBuffer(parser, length == 0 ? 1 : length);
		if (buffer == NULL) return XML_STATUS_ERROR;
		memcpy(buffer, chunk, (size_t)length);
		return XML_ParseBuffer(parser, length, final);
	}
	return XML_Parse(parser, chunk, length, final);
}

static int
parse_latin1_document(XML_Parser parser, int declared, int buffered) {
	static const char *const chunks[] = {"<r>", "\xe9", "\r", "\n", "<n q='\xe4'>", "\xf6", "</n>", "</r>", ""};
	static const char declaration_start[] = "<?xml version='1.0' enco";
	static const char declaration_end[] = "ding='ISO-8859-1'?>\n";
	struct latin1_state state = {0};
	size_t i;
	state.parser = parser;
	state.body_line = declared ? 2 : 1;
	XML_SetUserData(parser, &state);
	XML_SetElementHandler(parser, latin1_start, latin1_end);
	XML_SetCharacterDataHandler(parser, latin1_text);
	if (!XML_SetReparseDeferralEnabled(parser, declared ? XML_TRUE : XML_FALSE)) return 0;
	if (declared) {
		state.body_index = (int)(sizeof(declaration_start) + sizeof(declaration_end) - 2);
		if (feed_latin1(parser, declaration_start, XML_FALSE, buffered) != XML_STATUS_OK ||
			feed_latin1(parser, declaration_end, XML_FALSE, buffered) != XML_STATUS_OK) return 0;
	}
	for (i = 0; i < sizeof(chunks) / sizeof(chunks[0]); i++) {
		enum XML_Status status = feed_latin1(parser, chunks[i], chunks[i][0] == '\0', buffered);
		if (status == XML_STATUS_SUSPENDED) {
			state.suspended++;
			status = XML_ResumeParser(parser);
		}
		if (status != XML_STATUS_OK) return 0;
	}
	return !state.failed && state.starts == 2 && state.ends == 2 && state.suspended == 1 && state.text_length == 5;
}

static void
test_latin1_lifecycle(void) {
	XML_Parser parser = XML_ParserCreate("ISO-8859-1");
	struct latin1_state error_state = {0};
	int observed = parser != NULL && parse_latin1_document(parser, 0, 0);
	report_case("latin1_explicit_chunked", "passes", observed, "raw token positions, split CRLF, suspend/resume and empty final");
	if (parser == NULL) return;

	error_state.parser = parser;
	error_state.body_line = 1;
	observed = XML_ParserReset(parser, NULL) &&
		XML_SetEncoding(parser, "ISO-8859-1") == XML_STATUS_OK &&
		feed_latin1(parser, "<r>\xe9", XML_FALSE, 0) == XML_STATUS_OK &&
		feed_latin1(parser, "</x>", XML_TRUE, 0) == XML_STATUS_ERROR &&
		XML_GetErrorCode(parser) == XML_ERROR_TAG_MISMATCH;
	if (observed) check_latin1_position(&error_state, "mismatched name", 6, 0, 0, 6);
	report_case("latin1_mismatch_after_reset", "passes", observed && !error_state.failed, "error byte index and column after high byte");

	/* A reset without an encoding must discard the previous Latin-1 decoder. */
	observed = XML_ParserReset(parser, NULL) &&
		feed_latin1(parser, "<r>\xe9</r>", XML_TRUE, 1) == XML_STATUS_ERROR &&
		XML_GetErrorCode(parser) == XML_ERROR_INVALID_TOKEN &&
		XML_ParserReset(parser, NULL) && parse_latin1_document(parser, 1, 1);
	report_case("latin1_declared_parse_buffer_after_failure", "passes", observed, "split declaration and fresh positions after reset");
	XML_ParserFree(parser);
}

struct latin1_markup_state {
	struct latin1_state position;
	size_t next_text;
	int cdata_boundaries;
};

static void XMLCALL
latin1_markup_text(void *user_data, const char *s, int length) {
	/* Allow adjacent characters to share a callback. References occupy their
	   entire original spelling even though the callback gets one character. */
	static const struct {
		const char *utf8;
		int raw_index;
		int raw_count;
	} pieces[] = {
		{"\xc3\xa9", 3, 1}, {"\xc3\xa4", 4, 1}, {"&", 5, 5}, {"\xc3\xb6", 10, 6},
		{"\xc3\xa9", 25, 1}, {"\xc3\xa4", 26, 1}, {"\n", 30, 2}
	};
	struct latin1_markup_state *state = (struct latin1_markup_state *)user_data;
	size_t first = state->next_text;
	int used = 0;
	if (length == 0) return;
	while (used < length && state->next_text < sizeof(pieces) / sizeof(pieces[0])) {
		const char *expected = pieces[state->next_text].utf8;
		int size = (int)strlen(expected);
		if (size > length - used || memcmp(s + used, expected, (size_t)size) != 0) break;
		used += size;
		state->next_text++;
	}
	if (used == length && state->next_text > first) {
		size_t last = state->next_text - 1;
		int index = pieces[first].raw_index;
		check_latin1_position(&state->position, "text span", index,
			pieces[last].raw_index + pieces[last].raw_count - index, 0, index);
	} else {
		state->position.failed = 1;
	}
}

static void XMLCALL
latin1_cdata_start(void *user_data) {
	struct latin1_markup_state *state = (struct latin1_markup_state *)user_data;
	if (state->next_text != 4 || state->cdata_boundaries != 0) state->position.failed = 1;
	state->cdata_boundaries++;
	check_latin1_position(&state->position, "<![CDATA[", 16, 9, 0, 16);
}

static void XMLCALL
latin1_cdata_end(void *user_data) {
	struct latin1_markup_state *state = (struct latin1_markup_state *)user_data;
	if (state->next_text != 6 || state->cdata_boundaries != 1) state->position.failed = 1;
	state->cdata_boundaries++;
	check_latin1_position(&state->position, "]]>", 27, 3, 0, 27);
}

static void
test_latin1_reference_and_cdata_spans(void) {
	static const char *const chunks[] = {
		"<r>\xe9", "\xe4", "&amp;", "&#xF6;", "<![CDATA[", "\xe9", "\xe4]]>", "\r", "", "\n", "</r>"
	};
	struct latin1_markup_state state = {0};
	XML_Parser parser = XML_ParserCreate("ISO-8859-1");
	int observed = 0;
	if (parser != NULL) {
		size_t i;
		state.position.parser = parser;
		state.position.body_line = 1;
		XML_SetUserData(parser, &state);
		XML_SetCharacterDataHandler(parser, latin1_markup_text);
		XML_SetCdataSectionHandler(parser, latin1_cdata_start, latin1_cdata_end);
		observed = XML_SetReparseDeferralEnabled(parser, XML_FALSE);
		for (i = 0; observed && i < sizeof(chunks) / sizeof(chunks[0]); i++) {
			observed = feed_latin1(parser, chunks[i], i == sizeof(chunks) / sizeof(chunks[0]) - 1, 0) == XML_STATUS_OK;
		}
		observed = observed && !state.position.failed && state.next_text == 7 && state.cdata_boundaries == 2;
		XML_ParserFree(parser);
	}
	report_case("latin1_reference_and_cdata_spans", "passes", observed, "raw reference spelling, CDATA delimiters and split text");
}

static const char latin1_default_document[] = "<r q='\xe9'>\xe4\xf6<z/></r>";

struct latin1_default_state {
	struct latin1_state position;
	int raw_index;
};

static void XMLCALL
latin1_default(void *user_data, const XML_Char *s, int length) {
	static const char utf8[] = "<r q='\xc3\xa9'>\xc3\xa4\xc3\xb6<z/></r>";
	struct latin1_default_state *state = (struct latin1_default_state *)user_data;
	int offset = 0, size = 0, count = 0, i;
	const char *context = XML_GetInputContext(state->position.parser, &offset, &size);
	if ((size_t)length > sizeof(utf8) - 1 - state->position.text_length ||
		memcmp(s, utf8 + state->position.text_length, (size_t)length) != 0) {
		state->position.failed = 1;
		return;
	}
	state->position.text_length += (size_t)length;
	/* Each code point in this UTF-8 payload came from one source byte. */
	for (i = 0; i < length; i++) {
		if (((unsigned char)s[i] & 0xc0) != 0x80) count++;
	}
	check_latin1_position(&state->position, "default handler", state->raw_index, count, 0, state->raw_index);
	if (context == NULL || offset < 0 || offset > size || count > size - offset ||
		memcmp(context + offset, latin1_default_document + state->raw_index, (size_t)count) != 0) {
		fprintf(stderr, "Latin-1 default handler: raw context differs at byte %d\n", state->raw_index);
		state->position.failed = 1;
	}
	state->raw_index += count;
}

static void
test_latin1_default_spans(void) {
	struct latin1_default_state state = {0};
	XML_Parser parser = XML_ParserCreate("ISO-8859-1");
	int observed = 0;
	if (parser != NULL) {
		size_t i;
		state.position.parser = parser;
		state.position.body_line = 1;
		XML_SetUserData(parser, &state);
		XML_SetDefaultHandler(parser, latin1_default);
		observed = XML_SetReparseDeferralEnabled(parser, XML_FALSE);
		for (i = 0; observed && i < sizeof(latin1_default_document) - 1; i++) {
			observed = XML_Parse(parser, latin1_default_document + i, 1, XML_FALSE) == XML_STATUS_OK;
		}
		observed = observed && XML_Parse(parser, "", 0, XML_TRUE) == XML_STATUS_OK &&
			!state.position.failed && state.raw_index == (int)sizeof(latin1_default_document) - 1;
		XML_ParserFree(parser);
	}
	report_case("latin1_default_spans", "passes", observed, "default callbacks and input context over one-byte chunks");
}

int
main(void) {
	printf("case\tclassification\tresult\tdetail\n");
	(void)test_plain_start_nonfinal();
	(void)test_parse_buffer_plain_start();
	(void)test_attributed_start_nonfinal();
	(void)test_attributed_start_without_deferral();
	(void)test_bounded_context_window();
	(void)test_suspend_resume_replay();
	test_latin1_lifecycle();
	test_latin1_reference_and_cdata_spans();
	test_latin1_default_spans();
	return g_failed ? 1 : 0;
}
