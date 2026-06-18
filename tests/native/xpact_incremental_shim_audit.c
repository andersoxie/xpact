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

int
main(void) {
	printf("case\tclassification\tresult\tdetail\n");
	(void)test_plain_start_nonfinal();
	(void)test_parse_buffer_plain_start();
	(void)test_attributed_start_nonfinal();
	(void)test_attributed_start_without_deferral();
	(void)test_bounded_context_window();
	(void)test_suspend_resume_replay();
	return g_failed ? 1 : 0;
}
