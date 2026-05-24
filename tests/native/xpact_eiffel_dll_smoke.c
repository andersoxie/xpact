#include "xpact.h"

#include <stdio.h>
#include <string.h>

static XML_Parser g_parser;
static int g_callback_failed;
static char g_default_text[256];
static int g_default_len;
static int g_doctype_start_count;
static int g_doctype_end_count;
static int g_doctype_failed;
static int g_attlist_count;
static int g_attlist_failed;
static int g_default_attr_start_count;
static int g_default_attr_failed;
static int g_element_decl_count;
static int g_element_decl_failed;
static int g_notation_decl_count;
static int g_notation_decl_failed;

static int
check(int condition, const char *label) {
	if (!condition) {
		fprintf(stderr, "FAIL: %s\n", label);
		return 0;
	}
	return 1;
}

static void XMLCALL
text_handler(void *userData, const XML_Char *s, int len) {
	int offset = -1;
	int size = -1;
	const char *context;
	(void)userData;
	if (len != 5 || strncmp(s, "Hello", 5) != 0) {
		g_callback_failed = 1;
		return;
	}
	context = XML_GetInputContext(g_parser, &offset, &size);
	if (context == NULL || offset != 3 || size != 12 || XML_GetCurrentByteIndex(g_parser) != 3 || XML_GetCurrentByteCount(g_parser) != 5) {
		g_callback_failed = 1;
	}
}

static void XMLCALL
default_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (len < 0 || g_default_len + len >= (int)sizeof(g_default_text)) {
		g_callback_failed = 1;
		return;
	}
	memcpy(g_default_text + g_default_len, s, (size_t)len);
	g_default_len += len;
	g_default_text[g_default_len] = '\0';
}

static void XMLCALL
start_doctype_handler(void *userData, const XML_Char *doctypeName, const XML_Char *sysid, const XML_Char *pubid, int has_internal_subset) {
	(void)userData;
	g_doctype_start_count++;
	if (strcmp(doctypeName, "doc") != 0 || sysid == NULL || strcmp(sysid, "test.dtd") != 0 || pubid == NULL || strcmp(pubid, "pubname") != 0 || !has_internal_subset) {
		g_doctype_failed = 1;
	}
}

static void XMLCALL
end_doctype_handler(void *userData) {
	(void)userData;
	g_doctype_end_count++;
}

static void XMLCALL
attlist_handler(void *userData, const XML_Char *elname, const XML_Char *attname, const XML_Char *att_type, const XML_Char *dflt, int isrequired) {
	(void)userData;
	g_attlist_count++;
	if (g_attlist_count == 1) {
		if (strcmp(elname, "doc") != 0 || strcmp(attname, "a") != 0 || strcmp(att_type, "(one|two|three)") != 0 || dflt != NULL || !isrequired) {
			g_attlist_failed = 1;
		}
	} else if (g_attlist_count == 2) {
		if (strcmp(elname, "doc") != 0 || strcmp(attname, "b") != 0 || strcmp(att_type, "NOTATION(foo)") != 0 || dflt == NULL || strcmp(dflt, "bar") != 0 || isrequired) {
			g_attlist_failed = 1;
		}
	} else {
		g_attlist_failed = 1;
	}
}

static void XMLCALL
default_attr_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	g_default_attr_start_count++;
	if (strcmp(name, "doc") == 0) {
		if (XML_GetSpecifiedAttributeCount(g_parser) != 2 || XML_GetIdAttributeIndex(g_parser) != 0) {
			g_default_attr_failed = 1;
			return;
		}
		if (atts == NULL || atts[0] == NULL || strcmp(atts[0], "id") != 0 || strcmp(atts[1], "doc_identity") != 0) {
			g_default_attr_failed = 1;
			return;
		}
		if (atts[2] == NULL || strcmp(atts[2], "a") != 0 || strcmp(atts[3], "expected_doc") != 0 || atts[4] == NULL || strcmp(atts[4], "b") != 0 || strcmp(atts[5], "second_expected_doc") != 0 || atts[6] != NULL) {
			g_default_attr_failed = 1;
		}
	} else if (strcmp(name, "tag") == 0) {
		if (XML_GetSpecifiedAttributeCount(g_parser) != 0 || XML_GetIdAttributeIndex(g_parser) != -1) {
			g_default_attr_failed = 1;
			return;
		}
		if (atts == NULL || atts[0] == NULL || strcmp(atts[0], "a") != 0 || strcmp(atts[1], "expected_tag") != 0 || atts[2] != NULL) {
			g_default_attr_failed = 1;
		}
	} else {
		g_default_attr_failed = 1;
	}
}

static void XMLCALL
element_decl_handler(void *userData, const XML_Char *name, XML_Content *model) {
	(void)userData;
	g_element_decl_count++;
	if (strcmp(name, "junk") != 0 || model == NULL) {
		g_element_decl_failed = 1;
		if (model != NULL) {
			XML_FreeContentModel(g_parser, model);
		}
		return;
	}
	if (
		model[0].type != XML_CTYPE_SEQ
		|| model[0].quant != XML_CQUANT_NONE
		|| model[0].numchildren != 2
		|| model[0].children != &model[1]
		|| model[0].name != NULL
		|| model[1].type != XML_CTYPE_CHOICE
		|| model[1].quant != XML_CQUANT_NONE
		|| model[1].numchildren != 3
		|| model[1].children != &model[3]
		|| model[1].name != NULL
		|| model[2].type != XML_CTYPE_NAME
		|| model[2].quant != XML_CQUANT_REP
		|| model[2].numchildren != 0
		|| model[2].children != NULL
		|| model[2].name == NULL
		|| strcmp(model[2].name, "zebra") != 0
		|| model[3].type != XML_CTYPE_NAME
		|| model[3].quant != XML_CQUANT_NONE
		|| model[3].name == NULL
		|| strcmp(model[3].name, "bar") != 0
		|| model[4].type != XML_CTYPE_NAME
		|| model[4].quant != XML_CQUANT_NONE
		|| model[4].name == NULL
		|| strcmp(model[4].name, "foo") != 0
		|| model[5].type != XML_CTYPE_NAME
		|| model[5].quant != XML_CQUANT_PLUS
		|| model[5].name == NULL
		|| strcmp(model[5].name, "xyz") != 0
	) {
		g_element_decl_failed = 1;
	}
	XML_FreeContentModel(g_parser, model);
}

static void XMLCALL
notation_decl_handler(void *userData, const XML_Char *notationName, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	(void)userData;
	g_notation_decl_count++;
	if (g_notation_decl_count == 1) {
		if (strcmp(notationName, "note") != 0 || base != NULL || systemId != NULL || publicId == NULL || strcmp(publicId, "pub") != 0) {
			g_notation_decl_failed = 1;
		}
	} else if (g_notation_decl_count == 2) {
		if (strcmp(notationName, "img") != 0 || base != NULL || systemId == NULL || strcmp(systemId, "image/gif") != 0 || publicId != NULL) {
			g_notation_decl_failed = 1;
		}
	} else {
		g_notation_decl_failed = 1;
	}
}

int
main(void) {
	enum XML_Status status;
	XML_Parser parser = XML_ParserCreate("UTF-8");
	const char *default_input = "<?test processing instruction?>\n<doc/>";
	const char *doctype_input = "<!DOCTYPE doc PUBLIC 'pubname' 'test.dtd' [<!ENTITY foo 'bar'>]><doc>&foo;</doc>";
	const char *dtd_default_input =
		"<!DOCTYPE doc [\n"
		"<!ENTITY e SYSTEM 'http://example.org/e'>\n"
		"<!NOTATION n SYSTEM 'http://example.org/n'>\n"
		"<!ELEMENT doc EMPTY>\n"
		"<!ATTLIST doc a CDATA #IMPLIED>\n"
		"<?pi in dtd?>\n"
		"<!--comment in dtd-->\n"
		"]><doc/>";
	const char *attlist_input =
		"<!DOCTYPE doc [\n"
		"<!ELEMENT doc EMPTY>\n"
		"<!NOTATION foo SYSTEM 'http://example.org/foo'>\n"
		"<!ATTLIST doc a ( one | two | three ) #REQUIRED>\n"
		"<!ATTLIST doc b NOTATION (foo) 'bar'>\n"
		"]><doc a='two'/>";
	const char *default_attr_input =
		"<!DOCTYPE doc [\n"
		"<!ATTLIST doc a CDATA 'expected_doc'>\n"
		"<!ATTLIST tag a CDATA 'expected_tag'>\n"
		"<!ATTLIST doc b CDATA 'second_expected_doc' a CDATA 'ignored_doc'>\n"
		"<!ATTLIST doc id ID #REQUIRED>\n"
		"]><doc id='doc_identity'><tag></tag></doc>";
	const char *element_decl_input =
		"<!DOCTYPE foo [\n"
		"<!ELEMENT junk ((bar|foo|xyz+), zebra*)>\n"
		"]><foo/>";
	const char *notation_decl_input =
		"<!DOCTYPE doc [\n"
		"<!NOTATION note PUBLIC 'pub'>\n"
		"<!NOTATION img SYSTEM 'image/gif'>\n"
		"<!ELEMENT doc EMPTY>\n"
		"]><doc/>";
	const char *bad_public_doctype_input =
		"<?xml version='1.0' encoding='utf-8'?>\n"
		"<!DOCTYPE doc PUBLIC '{BadName}' 'test'>\n"
		"<doc></doc>";
	if (!check(parser != NULL, "parser created")) return 1;
	status = XML_Parse(parser, "<root><child>text</child></root>", 32, XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_NONE, "error code delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for context check")) return 1;
	g_parser = parser;
	XML_SetCharacterDataHandler(parser, text_handler);
	status = XML_Parse(parser, "<e>Hello</e>", 12, XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for context check")) return 1;
	if (!check(!g_callback_failed, "input context delegated inside callback")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default check")) return 1;
	g_default_len = 0;
	g_default_text[0] = '\0';
	XML_SetDefaultHandler(parser, default_handler);
	status = XML_Parse(parser, default_input, (int)strlen(default_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for default check")) return 1;
	if (!check(strcmp(g_default_text, default_input) == 0, "default handler receives raw tokens")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for doctype check")) return 1;
	g_default_len = 0;
	g_default_text[0] = '\0';
	g_doctype_start_count = 0;
	g_doctype_end_count = 0;
	g_doctype_failed = 0;
	XML_SetDefaultHandler(parser, default_handler);
	XML_SetDoctypeDeclHandler(parser, start_doctype_handler, end_doctype_handler);
	status = XML_Parse(parser, doctype_input, (int)strlen(doctype_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for doctype check")) return 1;
	if (!check(g_doctype_start_count == 1 && g_doctype_end_count == 1 && !g_doctype_failed, "doctype callbacks delegated")) return 1;
	if (!check(strstr(g_default_text, "'pubname'") != NULL && strstr(g_default_text, "'test.dtd'") != NULL, "default handler receives doctype identifiers")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for DTD default check")) return 1;
	g_default_len = 0;
	g_default_text[0] = '\0';
	XML_SetDefaultHandler(parser, default_handler);
	status = XML_Parse(parser, dtd_default_input, (int)strlen(dtd_default_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for DTD default check")) return 1;
	if (!check(strcmp(g_default_text, "\n\n\n\n\n\n\n<doc/>") == 0, "default handler receives DTD whitespace")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for attlist check")) return 1;
	g_attlist_count = 0;
	g_attlist_failed = 0;
	XML_SetAttlistDeclHandler(parser, attlist_handler);
	status = XML_Parse(parser, attlist_input, (int)strlen(attlist_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for attlist check")) return 1;
	if (!check(g_attlist_count == 2 && !g_attlist_failed, "attlist declaration callbacks delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default attribute check")) return 1;
	g_parser = parser;
	g_default_attr_start_count = 0;
	g_default_attr_failed = 0;
	XML_SetStartElementHandler(parser, default_attr_start_handler);
	status = XML_Parse(parser, default_attr_input, (int)strlen(default_attr_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for default attribute check")) return 1;
	if (!check(g_default_attr_start_count == 2 && !g_default_attr_failed, "default attributes delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for element declaration check")) return 1;
	g_parser = parser;
	g_element_decl_count = 0;
	g_element_decl_failed = 0;
	XML_SetElementDeclHandler(parser, element_decl_handler);
	status = XML_Parse(parser, element_decl_input, (int)strlen(element_decl_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for element declaration check")) return 1;
	if (!check(g_element_decl_count == 1 && !g_element_decl_failed, "element declaration content model delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for notation declaration check")) return 1;
	g_notation_decl_count = 0;
	g_notation_decl_failed = 0;
	XML_SetNotationDeclHandler(parser, notation_decl_handler);
	status = XML_Parse(parser, notation_decl_input, (int)strlen(notation_decl_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse reached Eiffel parser for notation declaration check")) return 1;
	if (!check(g_notation_decl_count == 2 && !g_notation_decl_failed, "notation declaration callbacks delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for bad public doctype check")) return 1;
	XML_SetDoctypeDeclHandler(parser, start_doctype_handler, end_doctype_handler);
	status = XML_Parse(parser, bad_public_doctype_input, (int)strlen(bad_public_doctype_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "bad public doctype rejected")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_PUBLICID, "bad public doctype maps to XML_ERROR_PUBLICID")) return 1;
	XML_ParserFree(parser);

	puts("xpact Eiffel DLL smoke: ok");
	return 0;
}
