#include "xpact.h"

#include <stdio.h>
#include <stdlib.h>
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
static int g_ns_default_attr_start_count;
static int g_ns_default_attr_failed;
static int g_entity_decl_count;
static int g_entity_decl_failed;
static int g_external_entity_ref_count;
static int g_general_entity_start_count;
static int g_general_entity_failed;
static char g_general_entity_text[256];
static int g_general_entity_len;
static int g_loaded_external_ref_count;
static int g_loaded_external_failed;
static int g_loaded_external_start_count;
static int g_loaded_external_end_count;
static int g_loaded_external_start_cdata_count;
static int g_loaded_external_end_cdata_count;
static char g_loaded_external_text[256];
static int g_loaded_external_len;
static const void *g_expected_external_arg;
static int g_external_arg_ref_count;
static int g_external_arg_failed;
static const void *g_expected_user_parameter_data;
static int g_user_parameter_comment_count;
static int g_user_parameter_skip_count;
static int g_user_parameter_xdecl_count;
static int g_user_parameter_failed;
static int g_skipped_entity_count;
static int g_skipped_entity_failed;
static int g_empty_text_failed;
static int g_sync_entity_start_count;
static int g_sync_entity_failed;
static char g_sync_entity_text[256];
static int g_sync_entity_len;
static int g_entity_context_failed;
static int g_default_current_failed;
static int g_default_current_record_count;
static int g_not_standalone_count;
static int g_foreign_dtd_ref_count;
static int g_foreign_dtd_failed;
static enum XML_Error g_expected_foreign_dtd_child_error;
static const char *g_foreign_dtd_text;
static char g_foreign_text[256];
static int g_foreign_text_len;
static int g_parameter_entity_ref_count;
static int g_parameter_entity_failed;
static int g_parameter_skip_count;
static int g_parameter_skip_failed;
static const char *g_bom_external_text;
static int g_bom_split;
static int g_bom_nested_callback_happened;
static int g_bom_failed;
static int g_external_value_ref_count;
static int g_external_value_failed;
static const char *g_external_value_text;
static enum XML_Error g_external_value_expected_error;
static int g_external_trailing_ref_count;
static int g_external_trailing_failed;
static int g_external_trailing_found;
static const char *g_external_trailing_text;
static char g_external_trailing_expected_char;
static enum XML_Error g_external_trailing_expected_error;
static int g_external_invalid_ref_count;
static int g_external_invalid_failed;
static const char *g_external_invalid_text;
static enum XML_Error g_external_invalid_expected_error;
static enum XML_Error g_external_invalid_actual_error;
static int g_external_encoding_ref_count;
static int g_external_encoding_failed;
static const char *g_external_encoding_text;
static const char *g_external_encoding_name;
static enum XML_Error g_external_encoding_expected_error;
static enum XML_Error g_external_encoding_actual_error;
static int g_failing_alloc_count;

struct malformed_doctype_case {
	const char *label;
	const char *input;
	enum XML_Error expected;
	int use_unknown_encoding_handler;
};

struct async_entity_case {
	const char *label;
	const char *input;
	XML_Size expected_line;
	XML_Size expected_column;
};

struct default_current_record {
	int kind;
	int arg;
};

struct external_value_case {
	const char *text;
	enum XML_Error expected_error;
};

struct external_trailing_case {
	const char *label;
	const char *text;
	char expected_char;
	enum XML_Error expected_error;
};

struct external_invalid_case {
	const char *label;
	const char *text;
	enum XML_Error expected_error;
};

struct external_encoding_case {
	const char *label;
	const char *parent_text;
	const char *text;
	const char *encoding;
	const char *expected_text;
	enum XML_Error expected_error;
};

struct utf16_case {
	const char *label;
	const char *text;
	int length;
	const char *expected_text;
	enum XML_Error expected_error;
};

#define DEFAULT_CURRENT_DEFAULT 1
#define DEFAULT_CURRENT_CDATA 2
#define DEFAULT_CURRENT_CDATA_NODEFAULT 3
#define DEFAULT_CURRENT_SKIP 4

static struct default_current_record g_default_current_records[64];

static int XMLCALL
smoke_prefix_converter(void *data, const char *s) {
	(void)data;
	if (s[0] == (char)-1) {
		return -1;
	}
	return (s[1] + (s[0] & 0x7f)) & 0x01ff;
}

static int XMLCALL
smoke_unknown_encoding_handler(void *encodingHandlerData, const XML_Char *name, XML_Encoding *info) {
	int i;
	(void)encodingHandlerData;
	if (name == NULL || strcmp(name, "prefix-conv") != 0 || info == NULL) {
		return XML_STATUS_ERROR;
	}
	for (i = 0; i < 128; i++) {
		info->map[i] = i;
	}
	for (; i < 256; i++) {
		info->map[i] = -2;
	}
	info->data = NULL;
	info->convert = smoke_prefix_converter;
	info->release = NULL;
	return XML_STATUS_OK;
}

static const struct malformed_doctype_case g_malformed_doctype_cases[] = {
	{
		"bad doctype prefix encoding",
		"<?xml version='1.0' encoding='prefix-conv'?>\n"
		"<!DOCTYPE doc [ \x80" "\x44 ]><doc/>",
		XML_ERROR_SYNTAX,
		1
	},
	{
		"bad doctype plus",
		"<!DOCTYPE 1+ [ <!ENTITY foo 'bar'> ]>\n<1+>&foo;</1+>",
		XML_ERROR_INVALID_TOKEN,
		0
	},
	{
		"bad doctype star",
		"<!DOCTYPE 1* [ <!ENTITY foo 'bar'> ]>\n<1*>&foo;</1*>",
		XML_ERROR_INVALID_TOKEN,
		0
	},
	{
		"bad doctype query",
		"<!DOCTYPE 1? [ <!ENTITY foo 'bar'> ]>\n<1?>&foo;</1?>",
		XML_ERROR_INVALID_TOKEN,
		0
	},
	{
		"bad doctype utf8",
		"<!DOCTYPE \xDB\x25" "doc><doc/>",
		XML_ERROR_INVALID_TOKEN,
		0
	},
	{
		"short doctype",
		"<!DOCTYPE doc></doc>",
		XML_ERROR_INVALID_TOKEN,
		0
	},
	{
		"short doctype missing public id",
		"<!DOCTYPE doc PUBLIC></doc>",
		XML_ERROR_SYNTAX,
		0
	},
	{
		"short doctype missing system id",
		"<!DOCTYPE doc SYSTEM></doc>",
		XML_ERROR_SYNTAX,
		0
	},
	{
		"long doctype",
		"<!DOCTYPE doc PUBLIC 'foo' 'bar' 'baz'></doc>",
		XML_ERROR_SYNTAX,
		0
	}
};

static const struct async_entity_case g_async_entity_cases[] = {
	{
		"opened by one entity and closed by another",
		"<!DOCTYPE t0 [\n"
		"   <!ENTITY open '<t1>'>\n"
		"   <!ENTITY close '</t1>'>\n"
		"]>\n"
		"<t0>&open;&close;</t0>\n",
		5,
		4
	},
	{
		"opened by tag and closed by entity",
		"<!DOCTYPE t0 [\n"
		"  <!ENTITY g0 ''>\n"
		"  <!ENTITY g1 '&g0;</t1>'>\n"
		"]>\n"
		"<t0><t1>&g1;</t0>\n",
		5,
		8
	},
	{
		"root opened by tag and closed by entity",
		"<!DOCTYPE t0 [\n"
		"  <!ENTITY g0 ''>\n"
		"  <!ENTITY g1 '&g0;</t0>'>\n"
		"]>\n"
		"<t0>&g1;\n",
		5,
		4
	},
	{
		"opened by entity and closed by tag",
		"<!DOCTYPE t0 [\n"
		"  <!ENTITY g0 ''>\n"
		"  <!ENTITY g1 '<t1>&g0;'>\n"
		"]>\n"
		"<t0>&g1;</t1></t0>\n",
		5,
		4
	},
	{
		"closed by entity then opened by entity",
		"<!DOCTYPE t0 [\n"
		"  <!ENTITY open '<t1>'>\n"
		"  <!ENTITY close '</t1>'>\n"
		"]>\n"
		"<t0><t1>&close;&open;</t1></t0>\n",
		5,
		8
	}
};

static int
check(int condition, const char *label) {
	if (!condition) {
		fprintf(stderr, "FAIL: %s\n", label);
		return 0;
	}
	return 1;
}

static void *
smoke_duff_malloc(size_t size) {
	if (g_failing_alloc_count <= 0) {
		return NULL;
	}
	g_failing_alloc_count--;
	return malloc(size);
}

static void *
smoke_duff_realloc(void *ptr, size_t size) {
	return realloc(ptr, size);
}

static void
smoke_duff_free(void *ptr) {
	free(ptr);
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

static void
record_default_current(int kind, int arg) {
	if (g_default_current_record_count >= (int)(sizeof(g_default_current_records) / sizeof(g_default_current_records[0]))) {
		g_default_current_failed = 1;
		return;
	}
	g_default_current_records[g_default_current_record_count].kind = kind;
	g_default_current_records[g_default_current_record_count].arg = arg;
	g_default_current_record_count++;
}

static int
check_default_current_record(int index, int kind, int arg) {
	return index >= 0
		&& index < g_default_current_record_count
		&& g_default_current_records[index].kind == kind
		&& g_default_current_records[index].arg == arg;
}

static void XMLCALL
default_current_default_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	record_default_current(DEFAULT_CURRENT_DEFAULT, len);
}

static void XMLCALL
default_current_cdata_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	record_default_current(DEFAULT_CURRENT_CDATA, len);
	XML_DefaultCurrent(g_parser);
}

static void XMLCALL
default_current_cdata_nodefault_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	record_default_current(DEFAULT_CURRENT_CDATA_NODEFAULT, len);
}

static void XMLCALL
default_current_skip_handler(void *userData, const XML_Char *entityName, int is_parameter_entity) {
	(void)userData;
	(void)entityName;
	record_default_current(DEFAULT_CURRENT_SKIP, is_parameter_entity);
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
ns_default_attr_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	g_ns_default_attr_start_count++;
	if (strcmp(name, "e:element") != 0) {
		g_ns_default_attr_failed = 1;
		return;
	}
	if (XML_GetSpecifiedAttributeCount(g_parser) != 0 || XML_GetIdAttributeIndex(g_parser) != -1) {
		g_ns_default_attr_failed = 1;
		return;
	}
	if (atts == NULL || atts[0] == NULL || strcmp(atts[0], "xmlns:e") != 0 || atts[1] == NULL || strcmp(atts[1], "http://example.org/") != 0 || atts[2] != NULL) {
		g_ns_default_attr_failed = 1;
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

static void XMLCALL
general_entity_decl_handler(void *userData, const XML_Char *entityName, int is_parameter_entity, const XML_Char *value, int value_length, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId, const XML_Char *notationName) {
	(void)userData;
	(void)base;
	(void)publicId;
	(void)notationName;
	g_entity_decl_count++;
	if (g_entity_decl_count == 1) {
		if (strcmp(entityName, "e1") != 0 || is_parameter_entity || value == NULL || value_length != 2 || strncmp(value, "v1", 2) != 0 || systemId != NULL) {
			g_entity_decl_failed = 1;
		}
	} else if (g_entity_decl_count == 2) {
		if (strcmp(entityName, "e2") != 0 || is_parameter_entity || value != NULL || value_length != 0 || systemId == NULL || strcmp(systemId, "v2") != 0) {
			g_entity_decl_failed = 1;
		}
	} else {
		g_entity_decl_failed = 1;
	}
}

static int XMLCALL
general_external_entity_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	(void)parser;
	(void)context;
	(void)base;
	(void)publicId;
	g_external_entity_ref_count++;
	if (systemId == NULL || strcmp(systemId, "v2") != 0) {
		g_general_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	return XML_STATUS_OK;
}

static void XMLCALL
general_entity_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	g_general_entity_start_count++;
	if (strcmp(name, "r") != 0 || atts == NULL || atts[0] == NULL || strcmp(atts[0], "a1") != 0 || atts[1] == NULL || strcmp(atts[1], "[v1]") != 0 || atts[2] != NULL) {
		g_general_entity_failed = 1;
	}
}

static void XMLCALL
general_entity_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (len < 0 || g_general_entity_len + len >= (int)sizeof(g_general_entity_text)) {
		g_general_entity_failed = 1;
		return;
	}
	memcpy(g_general_entity_text + g_general_entity_len, s, (size_t)len);
	g_general_entity_len += len;
	g_general_entity_text[g_general_entity_len] = '\0';
}

static void XMLCALL
loaded_external_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)atts;
	g_loaded_external_start_count++;
	if (g_loaded_external_start_count == 1) {
		if (strcmp(name, "doc") != 0) {
			g_loaded_external_failed = 1;
		}
	} else if (g_loaded_external_start_count == 2) {
		if (strcmp(name, "leaf") != 0) {
			g_loaded_external_failed = 1;
		}
	} else {
		g_loaded_external_failed = 1;
	}
}

static void XMLCALL
loaded_external_end_handler(void *userData, const XML_Char *name) {
	(void)userData;
	g_loaded_external_end_count++;
	if (g_loaded_external_end_count == 1) {
		if (strcmp(name, "leaf") != 0) {
			g_loaded_external_failed = 1;
		}
	} else if (g_loaded_external_end_count == 2) {
		if (strcmp(name, "doc") != 0) {
			g_loaded_external_failed = 1;
		}
	} else {
		g_loaded_external_failed = 1;
	}
}

static void XMLCALL
loaded_external_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (len < 0 || g_loaded_external_len + len >= (int)sizeof(g_loaded_external_text)) {
		g_loaded_external_failed = 1;
		return;
	}
	memcpy(g_loaded_external_text + g_loaded_external_len, s, (size_t)len);
	g_loaded_external_len += len;
	g_loaded_external_text[g_loaded_external_len] = '\0';
}

static void XMLCALL
utf16_attribute_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)name;
	if (atts == NULL || atts[0] == NULL || atts[1] == NULL) {
		g_loaded_external_failed = 1;
		return;
	}
	if ((int)strlen(atts[1]) >= (int)sizeof(g_loaded_external_text)) {
		g_loaded_external_failed = 1;
		return;
	}
	strcpy(g_loaded_external_text, atts[1]);
	g_loaded_external_len = (int)strlen(g_loaded_external_text);
}

static void XMLCALL
loaded_external_start_cdata_handler(void *userData) {
	(void)userData;
	g_loaded_external_start_cdata_count++;
}

static void XMLCALL
loaded_external_end_cdata_handler(void *userData) {
	(void)userData;
	g_loaded_external_end_cdata_count++;
}

static int XMLCALL
loading_external_entity_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *text = "<?xml version='1.0' encoding='utf-8'?>external <![CDATA[cdata]]><leaf/> tail";
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)publicId;
	g_loaded_external_ref_count++;
	if (parser != g_parser || context == NULL || systemId == NULL || strcmp(systemId, "mem://entity") != 0) {
		g_loaded_external_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, "utf-8");
	if (ext_parser == NULL) {
		g_loaded_external_failed = 1;
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	if (status != XML_STATUS_OK) {
		g_loaded_external_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_OK;
}

static int XMLCALL
external_arg_checker(XML_Parser parameter, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)systemId;
	(void)publicId;
	g_external_arg_ref_count++;
	if ((const void *)parameter != g_expected_external_arg) {
		g_external_arg_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(g_parser, context, NULL);
	if (ext_parser == NULL) {
		g_external_arg_failed = 1;
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, "<!ELEMENT doc (#PCDATA)*>", 25, XML_TRUE);
	if (status != XML_STATUS_OK) {
		g_external_arg_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_OK;
}

static int XMLCALL
reject_not_standalone_handler(void *userData) {
	(void)userData;
	g_not_standalone_count++;
	return XML_STATUS_ERROR;
}

static int XMLCALL
accept_not_standalone_handler(void *userData) {
	(void)userData;
	g_not_standalone_count++;
	return XML_STATUS_OK;
}

static void XMLCALL
foreign_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (len < 0 || g_foreign_text_len + len >= (int)sizeof(g_foreign_text)) {
		g_foreign_dtd_failed = 1;
		return;
	}
	memcpy(g_foreign_text + g_foreign_text_len, s, (size_t)len);
	g_foreign_text_len += len;
	g_foreign_text[g_foreign_text_len] = '\0';
}

static int XMLCALL
foreign_dtd_external_entity_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)publicId;
	g_foreign_dtd_ref_count++;
	if (context == NULL || systemId == NULL) {
		g_foreign_dtd_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (g_foreign_dtd_text == NULL) {
		return XML_STATUS_OK;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_foreign_dtd_failed = 1;
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, g_foreign_dtd_text, (int)strlen(g_foreign_dtd_text), XML_TRUE);
	if (status != XML_STATUS_OK) {
		enum XML_Error child_error = XML_GetErrorCode(ext_parser);
		XML_ParserFree(ext_parser);
		if (g_expected_foreign_dtd_child_error != XML_ERROR_NONE && child_error == g_expected_foreign_dtd_child_error) {
			return XML_STATUS_ERROR;
		}
		g_foreign_dtd_failed = 1;
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	if (g_expected_foreign_dtd_child_error != XML_ERROR_NONE) {
		g_foreign_dtd_failed = 1;
		return XML_STATUS_ERROR;
	}
	return XML_STATUS_OK;
}

static int XMLCALL
external_entity_not_standalone_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *text =
		"<!ELEMENT doc EMPTY>\n"
		"<!ENTITY % e1 SYSTEM 'bar'>\n"
		"%e1;\n";
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)publicId;
	g_parameter_entity_ref_count++;
	if (context == NULL || systemId == NULL || strcmp(systemId, "foo") != 0) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	XML_SetNotStandaloneHandler(ext_parser, reject_not_standalone_handler);
	status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	if (status != XML_STATUS_ERROR || XML_GetErrorCode(ext_parser) != XML_ERROR_NOT_STANDALONE) {
		g_parameter_entity_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_ERROR;
}

static int XMLCALL
invalid_tag_in_dtd_external_entity_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *outer_text =
		"<!ELEMENT doc EMPTY>\n"
		"<!ENTITY % e1 SYSTEM '004-2.ent'>\n"
		"<!ENTITY % e2 '%e1;'>\n"
		"%e1;\n";
	const char *inner_text =
		"<!ELEMENT el EMPTY>\n"
		"<el/>\n";
	const char *text;
	enum XML_Error expected_error;
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)publicId;
	g_parameter_entity_ref_count++;
	if (context == NULL || systemId == NULL) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (strcmp(systemId, "004-1.ent") == 0) {
		text = outer_text;
		expected_error = XML_ERROR_EXTERNAL_ENTITY_HANDLING;
	} else if (strcmp(systemId, "004-2.ent") == 0) {
		text = inner_text;
		expected_error = XML_ERROR_SYNTAX;
	} else {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	if (status != XML_STATUS_ERROR || XML_GetErrorCode(ext_parser) != expected_error) {
		g_parameter_entity_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_ERROR;
}

static int XMLCALL
external_entity_devaluer_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *text =
		"<!ELEMENT doc EMPTY>\n"
		"<!ENTITY % e1 SYSTEM 'bar'>\n"
		"%e1;\n";
	XML_Parser ext_parser;
	enum XML_Status status;
	int clear_handler = XML_GetUserData(parser) != NULL;
	(void)base;
	(void)publicId;
	g_parameter_entity_ref_count++;
	if (systemId == NULL || strcmp(systemId, "bar") == 0) {
		return XML_STATUS_OK;
	}
	if (strcmp(systemId, "foo") != 0) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_parameter_entity_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (clear_handler) {
		XML_SetExternalEntityRefHandler(ext_parser, NULL);
	}
	status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	if (status != XML_STATUS_OK) {
		g_parameter_entity_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_OK;
}

static int XMLCALL
external_bom_checker_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *outer_text =
		"<!ELEMENT doc EMPTY>\n"
		"<!ENTITY % e1 SYSTEM '004-2.ent'>\n"
		"<!ENTITY % e2 '%e1;'>\n";
	const char *text;
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)publicId;
	g_parameter_entity_ref_count++;
	if (context == NULL || systemId == NULL) {
		g_bom_failed = 1;
		return XML_STATUS_ERROR;
	}
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_bom_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (strcmp(systemId, "004-1.ent") == 0) {
		text = outer_text;
		status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	} else if (strcmp(systemId, "004-2.ent") == 0) {
		g_bom_nested_callback_happened = 1;
		status = XML_Parse(ext_parser, g_bom_external_text, g_bom_split, XML_FALSE);
		if (status == XML_STATUS_OK) {
			text = g_bom_external_text + g_bom_split;
			status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
		}
	} else {
		g_bom_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	if (status != XML_STATUS_OK) {
		g_bom_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_OK;
}

static int XMLCALL
external_entity_value_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *outer_text =
		"<!ELEMENT doc EMPTY>\n"
		"<!ENTITY % e1 SYSTEM '004-2.ent'>\n"
		"<!ENTITY % e2 '%e1;'>\n"
		"%e1;\n";
	XML_Parser ext_parser;
	enum XML_Status status;
	enum XML_Error actual_error;
	(void)base;
	(void)publicId;
	if (systemId == NULL) {
		return XML_STATUS_OK;
	}
	g_external_value_ref_count++;
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_external_value_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (strcmp(systemId, "004-1.ent") == 0) {
		status = XML_Parse(ext_parser, outer_text, (int)strlen(outer_text), XML_TRUE);
		if (status != XML_STATUS_OK) {
			g_external_value_failed = 1;
			XML_ParserFree(ext_parser);
			return XML_STATUS_ERROR;
		}
	} else if (strcmp(systemId, "004-2.ent") == 0) {
		status = XML_Parse(ext_parser, g_external_value_text, (int)strlen(g_external_value_text), XML_TRUE);
		if (g_external_value_expected_error == XML_ERROR_NONE) {
			if (status != XML_STATUS_OK) {
				g_external_value_failed = 1;
				XML_ParserFree(ext_parser);
				return XML_STATUS_ERROR;
			}
		} else {
			if (status != XML_STATUS_ERROR) {
				g_external_value_failed = 1;
				XML_ParserFree(ext_parser);
				return XML_STATUS_ERROR;
			}
			actual_error = XML_GetErrorCode(ext_parser);
			if (actual_error != g_external_value_expected_error) {
				g_external_value_failed = 1;
				XML_ParserFree(ext_parser);
				return XML_STATUS_ERROR;
			}
		}
	} else {
		g_external_value_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_OK;
}

static void XMLCALL
external_trailing_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (
		len == 1
		&& (
			s[0] == g_external_trailing_expected_char
			|| (g_external_trailing_expected_char == '\r' && s[0] == '\n')
		)
	) {
		g_external_trailing_found = 1;
	}
}

static int XMLCALL
external_entity_trailing_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	XML_Parser ext_parser;
	enum XML_Status status;
	enum XML_Error actual_error;
	(void)base;
	(void)systemId;
	(void)publicId;
	if (systemId == NULL) {
		return XML_STATUS_OK;
	}
	g_external_trailing_ref_count++;
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_external_trailing_failed = 1;
		return XML_STATUS_ERROR;
	}
	XML_SetCharacterDataHandler(ext_parser, external_trailing_text_handler);
	status = XML_Parse(ext_parser, g_external_trailing_text, (int)strlen(g_external_trailing_text), XML_TRUE);
	if (g_external_trailing_expected_error == XML_ERROR_NONE) {
		if (status != XML_STATUS_OK) {
			g_external_trailing_failed = 1;
		}
	} else {
		if (status != XML_STATUS_ERROR) {
			g_external_trailing_failed = 1;
		} else {
			actual_error = XML_GetErrorCode(ext_parser);
			if (actual_error != g_external_trailing_expected_error) {
				g_external_trailing_failed = 1;
			}
		}
	}
	XML_ParserFree(ext_parser);
	return g_external_trailing_failed ? XML_STATUS_ERROR : XML_STATUS_OK;
}

static int XMLCALL
external_entity_invalid_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	XML_Parser ext_parser;
	enum XML_Status status;
	enum XML_Error actual_error;
	(void)base;
	(void)publicId;
	if (systemId == NULL) {
		return XML_STATUS_OK;
	}
	g_external_invalid_ref_count++;
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_external_invalid_failed = 1;
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, g_external_invalid_text, (int)strlen(g_external_invalid_text), XML_TRUE);
	if (status != XML_STATUS_ERROR) {
		g_external_invalid_failed = 1;
	} else {
		actual_error = XML_GetErrorCode(ext_parser);
		g_external_invalid_actual_error = actual_error;
		if (actual_error != g_external_invalid_expected_error) {
			g_external_invalid_failed = 1;
		}
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_ERROR;
}

static int XMLCALL
external_entity_encoding_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	XML_Parser ext_parser;
	enum XML_Status status;
	enum XML_Error actual_error;
	(void)base;
	(void)systemId;
	(void)publicId;
	if (systemId == NULL) {
		return XML_STATUS_OK;
	}
	g_external_encoding_ref_count++;
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_external_encoding_failed = 1;
		return XML_STATUS_ERROR;
	}
	if (g_external_encoding_name != NULL && XML_SetEncoding(ext_parser, g_external_encoding_name) != XML_STATUS_OK) {
		g_external_encoding_failed = 1;
		XML_ParserFree(ext_parser);
		return XML_STATUS_ERROR;
	}
	status = XML_Parse(ext_parser, g_external_encoding_text, (int)strlen(g_external_encoding_text), XML_TRUE);
	if (g_external_encoding_expected_error == XML_ERROR_NONE) {
		if (status != XML_STATUS_OK) {
			g_external_encoding_failed = 1;
			g_external_encoding_actual_error = XML_GetErrorCode(ext_parser);
			XML_ParserFree(ext_parser);
			return XML_STATUS_ERROR;
		}
		XML_ParserFree(ext_parser);
		return XML_STATUS_OK;
	}
	if (status != XML_STATUS_ERROR) {
		g_external_encoding_failed = 1;
	} else {
		actual_error = XML_GetErrorCode(ext_parser);
		g_external_encoding_actual_error = actual_error;
		if (actual_error != g_external_encoding_expected_error) {
			g_external_encoding_failed = 1;
		}
	}
	XML_ParserFree(ext_parser);
	return XML_STATUS_ERROR;
}

static void XMLCALL
user_parameter_xml_decl_handler(void *userData, const XML_Char *version, const XML_Char *encoding, int standalone) {
	if (
		userData != g_expected_user_parameter_data
		|| version == NULL
		|| strcmp(version, "1.0") != 0
		|| encoding == NULL
		|| strcmp(encoding, "us-ascii") != 0
		|| standalone != -1
	) {
		g_user_parameter_failed = 1;
	}
	g_user_parameter_xdecl_count++;
}

static void XMLCALL
user_parameter_comment_handler(void *userData, const XML_Char *data) {
	(void)data;
	if (userData != g_expected_user_parameter_data || XML_GetUserData((XML_Parser)userData) != (void *)1) {
		g_user_parameter_failed = 1;
	}
	g_user_parameter_comment_count++;
}

static void XMLCALL
user_parameter_skip_handler(void *userData, const XML_Char *entityName, int is_parameter_entity) {
	if (
		userData != g_expected_user_parameter_data
		|| entityName == NULL
		|| strcmp(entityName, "entity") != 0
		|| is_parameter_entity
	) {
		g_user_parameter_failed = 1;
	}
	g_user_parameter_skip_count++;
}

static int XMLCALL
user_parameter_external_entity_handler(XML_Parser parser, const XML_Char *context, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId) {
	const char *text = "<!-- Subordinate parser -->\n<!ELEMENT doc (#PCDATA)*>";
	XML_Parser ext_parser;
	enum XML_Status status;
	(void)base;
	(void)systemId;
	(void)publicId;
	ext_parser = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (ext_parser == NULL) {
		g_user_parameter_failed = 1;
		return XML_STATUS_ERROR;
	}
	g_expected_user_parameter_data = ext_parser;
	status = XML_Parse(ext_parser, text, (int)strlen(text), XML_TRUE);
	g_expected_user_parameter_data = parser;
	XML_ParserFree(ext_parser);
	if (status != XML_STATUS_OK) {
		g_user_parameter_failed = 1;
		return XML_STATUS_ERROR;
	}
	return XML_STATUS_OK;
}

static void XMLCALL
skipped_entity_handler(void *userData, const XML_Char *entityName, int is_parameter_entity) {
	(void)userData;
	g_skipped_entity_count++;
	if (entityName == NULL || strcmp(entityName, "en") != 0 || is_parameter_entity) {
		g_skipped_entity_failed = 1;
	}
}

static void XMLCALL
parameter_skipped_entity_handler(void *userData, const XML_Char *entityName, int is_parameter_entity) {
	(void)userData;
	g_parameter_skip_count++;
	if (entityName == NULL || strcmp(entityName, "foo") != 0 || !is_parameter_entity) {
		g_parameter_skip_failed = 1;
	}
}

static void XMLCALL
empty_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	if (len != 0) {
		g_empty_text_failed = 1;
	}
}

static void XMLCALL
sync_entity_start_handler(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)atts;
	g_sync_entity_start_count++;
	if (name == NULL || name[0] == '\0') {
		g_sync_entity_failed = 1;
	}
}

static void XMLCALL
sync_entity_text_handler(void *userData, const XML_Char *s, int len) {
	(void)userData;
	if (len < 0 || g_sync_entity_len + len >= (int)sizeof(g_sync_entity_text)) {
		g_sync_entity_failed = 1;
		return;
	}
	memcpy(g_sync_entity_text + g_sync_entity_len, s, (size_t)len);
	g_sync_entity_len += len;
	g_sync_entity_text[g_sync_entity_len] = '\0';
}

static void XMLCALL
entity_context_text_handler(void *userData, const XML_Char *s, int len) {
	int offset = -1;
	int size = -1;
	int byte_count;
	const char *context;
	(void)userData;
	if (len != 2 || strncmp(s, "10", 2) != 0) {
		g_entity_context_failed = 1;
		return;
	}
	byte_count = XML_GetCurrentByteCount(g_parser);
	context = XML_GetInputContext(g_parser, &offset, &size);
	if (context == NULL || offset < 0 || size <= offset || byte_count != 11 || strncmp(context + offset, "&draft.day;", (size_t)byte_count) != 0) {
		g_entity_context_failed = 1;
	}
}

int
main(void) {
	enum XML_Status status;
	enum XML_Error actual_error;
	XML_Parser parser = XML_ParserCreate("UTF-8");
	const XML_Feature *feature;
	size_t malformed_index;
	size_t async_index;
	size_t external_value_index;
	size_t external_trailing_index;
	size_t external_invalid_index;
	size_t external_encoding_index;
	size_t utf16_index;
	size_t hash_index;
	size_t hash_collision_len;
	int saw_xml_char_feature = 0;
	int saw_xml_lchar_feature = 0;
	XML_Memory_Handling_Suite duff_allocator;
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
	const char *ns_default_attr_input =
		"<!DOCTYPE e:element [\n"
		"  <!ATTLIST e:element\n"
		"    xmlns:e CDATA 'http://example.org/'>\n"
		"      ]>\n"
		"<e:element/>";
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
	const char *general_entities_input =
		"<!DOCTYPE r [\n"
		"<!ENTITY e1 'v1'>\n"
		"<!ENTITY e2 SYSTEM 'v2'>\n"
		"]>\n"
		"<r a1='[&e1;]'>[&e1;][&e2;][&amp;&apos;&gt;&lt;&quot;]</r>";
	const char *loaded_external_input =
		"<!DOCTYPE doc [\n"
		"  <!ENTITY en SYSTEM 'mem://entity'>\n"
		"]>\n"
		"<doc>&en;</doc>";
	const char *external_arg_input =
		"<!DOCTYPE doc [\n"
		"  <!ENTITY en SYSTEM 'mem://arg'>\n"
		"]>\n"
		"<doc>&en;</doc>";
	const char *external_ref_parameter_input =
		"<?xml version='1.0' encoding='us-ascii'?>\n"
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc>&entity;</doc>";
	const char *unread_external_subset_input =
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc>&entity;</doc>";
	const char *no_external_subset_undefined_input = "<doc>&entity;</doc>";
	const char *standalone_external_subset_input =
		"<?xml version='1.0' standalone='yes'?>\n"
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc>&entity;</doc>";
	const char *not_standalone_external_subset_input =
		"<?xml version='1.0' encoding='us-ascii'?>\n"
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc>&entity;</doc>";
	const char *external_parameter_not_standalone_input =
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc></doc>";
	const char *invalid_tag_in_dtd_input =
		"<!DOCTYPE doc SYSTEM '004-1.ent'>\n"
		"<doc></doc>\n";
	const char *recursive_external_parameter_input =
		"<?xml version='1.0'?>\n"
		"<!DOCTYPE root SYSTEM 'http://example.org/dtd.ent' [\n"
		"<!ELEMENT root (#PCDATA|a)* >\n"
		"]>\n"
		"<root></root>";
	const char *undefined_external_parameter_input =
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc></doc>\n";
	const char *dtd_stop_processing_input =
		"<!DOCTYPE doc [\n"
		"%foo;\n"
		"<!ENTITY bar 'bas'>\n"
		"]><doc/>";
	const char *external_bom_input =
		"<!DOCTYPE doc SYSTEM '004-1.ent'>\n"
		"<doc></doc>\n";
	const char *external_bom_text = "\xEF\xBB\xBF<!ATTLIST doc a1 CDATA 'value'>";
	const struct external_value_case external_value_cases[] = {
		{"<!ATTLIST doc a1 CDATA 'value'>", XML_ERROR_NONE},
		{"<!ATTLIST $doc a1 CDATA 'value'>", XML_ERROR_INVALID_TOKEN},
		{"'wombat", XML_ERROR_UNCLOSED_TOKEN},
		{"\xE2\x82", XML_ERROR_PARTIAL_CHAR},
		{"<?xml version='1.0' encoding='utf-8'?>\n", XML_ERROR_NONE},
		{"<?xml?>", XML_ERROR_XML_DECL},
		{"\xEF\xBB\xBF<!ATTLIST doc a1 CDATA 'value'>", XML_ERROR_NONE},
		{"<?xml version='1.0' encoding='utf-8'?>\n$", XML_ERROR_INVALID_TOKEN},
		{"<?xml version='1.0' encoding='utf-8'?>\n'wombat", XML_ERROR_UNCLOSED_TOKEN},
		{"<?xml version='1.0' encoding='utf-8'?>\n\xE2\x82", XML_ERROR_PARTIAL_CHAR},
		{"%e1;", XML_ERROR_RECURSIVE_ENTITY_REF}
	};
	const struct external_trailing_case external_trailing_cases[] = {
		{"trailing CR fragment", "\r", '\r', XML_ERROR_NONE},
		{"open element with trailing CR", "<tag>\r", '\r', XML_ERROR_ASYNC_ENTITY},
		{"open element with trailing right square bracket", "<tag>]", ']', XML_ERROR_ASYNC_ENTITY}
	};
	const struct external_invalid_case external_invalid_cases[] = {
		{"bare external markup open", "<", XML_ERROR_UNCLOSED_TOKEN},
		{"partial UTF-8 start tag name", "<\xE2\x82", XML_ERROR_PARTIAL_CHAR},
		{"partial UTF-8 character data", "<tag>\xE2\x82", XML_ERROR_PARTIAL_CHAR}
	};
	const struct external_encoding_case external_encoding_cases[] = {
		{
			"explicit UTF-8 overrides external text declaration",
			loaded_external_input,
			"<?xml encoding='iso-8859-3'?>\xC3\xA9",
			"utf-8",
			"\xC3\xA9",
			XML_ERROR_NONE
		},
		{
			"explicit UTF-8 with BOM overrides external text declaration",
			loaded_external_input,
			"\xEF\xBB\xBF<?xml encoding='iso-8859-3'?>\xC3\xA9",
			"utf-8",
			"\xC3\xA9",
			XML_ERROR_NONE
		},
		{
			"unsupported explicit encoding on external general entity",
			loaded_external_input,
			"<?xml encoding='iso-8859-3'?>u",
			"unknown",
			NULL,
			XML_ERROR_UNKNOWN_ENCODING
		},
		{
			"unsupported explicit encoding on external DTD subset",
			not_standalone_external_subset_input,
			"<!ELEMENT doc (#PCDATA)*>",
			"unknown-encoding",
			NULL,
			XML_ERROR_UNKNOWN_ENCODING
		}
	};
	const char *foreign_dtd_decl_chunk = "<?xml version='1.0' encoding='us-ascii'?>\n";
	const char *foreign_dtd_body_chunk = "<doc>&entity;</doc>";
	const char *foreign_dtd_with_doctype_input =
		"<?xml version='1.0' encoding='us-ascii'?>\n"
		"<!DOCTYPE doc [<!ENTITY entity 'hello world'>]>\n"
		"<doc>&entity;</doc>";
	const char *foreign_dtd_without_external_subset_input =
		"<!DOCTYPE doc [<!ENTITY foo 'bar'>]>\n"
		"<doc>&foo;</doc>";
	const char *user_parameter_input =
		"<?xml version='1.0' encoding='us-ascii'?>\n"
		"<!-- Primary parse -->\n"
		"<!DOCTYPE doc SYSTEM 'foo'>\n"
		"<doc>&entity;";
	const char *user_parameter_epilog =
		"<!-- Back to primary parser -->\n"
		"</doc>";
	const char *skipped_external_input =
		"<!DOCTYPE doc [\n"
		"  <!ENTITY en SYSTEM 'http://example.org/dummy.ent'>\n"
		"]>\n"
		"<doc>&en;</doc>";
	const char *sync_entity_input =
		"<!DOCTYPE t0 [\n"
		"   <!ENTITY a '<t1></t1>'>\n"
		"   <!ENTITY b '<t2>two</t2>'>\n"
		"   <!ENTITY c '<t3>three<t4>four</t4>three</t3>'>\n"
		"   <!ENTITY d '<t5>&b;</t5>'>\n"
		"]>\n"
		"<t0>&a;&b;&c;&d;</t0>\n";
	const char utf16_be_bom_input[] =
		"\xFE\xFF"
		"\000<\000d\000o\000c\000>\000h\000i\000<\000/\000d\000o\000c\000>";
	const char utf16_le_bom_input[] =
		"\xFF\xFE"
		"<\000d\000o\000c\000>\000h\000i\000<\000/\000d\000o\000c\000>\000";
	const char utf16_le_nobom_input[] =
		"<\000d\000o\000c\000>\000h\000i\000<\000/\000d\000o\000c\000>\000";
	const char utf16_be_fullwidth_input[] =
		"\000<\000d\000o\000c\000>\xff\x21\000<\000/\000d\000o\000c\000>";
	const char utf16_be_surrogate_input[] =
		"\000<\000d\000o\000c\000>\xd8\x34\xdd\x5e\000<\000/\000d\000o\000c\000>";
	const char utf16_be_bad_surrogate_input[] =
		"\000<\000d\000o\000c\000>\xdc\x00\xd8\x00\000<\000/\000d\000o\000c\000>";
	const char utf16_cdata_input[] =
		"\000<\000d\000o\000c\000>\000<\000!\000[\000C\000D\000A\000T\000A\000[\000h\000e\000l\000l\000o\000]\000]\000>\000<\000/\000d\000o\000c\000>";
	const char utf16_declared_in_utf8_input[] =
		"<?xml version='1.0' encoding='utf-16'?><doc>hi</doc>";
	const char utf16_attribute_input[] =
		"<\000d\000 \000\x04\x0e\x08\x0e=\000'\000a\000'\000/\000>\000";
	const struct utf16_case utf16_cases[] = {
		{"UTF-16BE BOM document", utf16_be_bom_input, (int)sizeof(utf16_be_bom_input) - 1, "hi", XML_ERROR_NONE},
		{"UTF-16LE BOM document", utf16_le_bom_input, (int)sizeof(utf16_le_bom_input) - 1, "hi", XML_ERROR_NONE},
		{"UTF-16LE no-BOM document", utf16_le_nobom_input, (int)sizeof(utf16_le_nobom_input) - 1, "hi", XML_ERROR_NONE},
		{"UTF-16BE fullwidth character data", utf16_be_fullwidth_input, (int)sizeof(utf16_be_fullwidth_input) - 1, "\xEF\xBC\xA1", XML_ERROR_NONE},
		{"UTF-16BE surrogate character data", utf16_be_surrogate_input, (int)sizeof(utf16_be_surrogate_input) - 1, "\xF0\x9D\x85\x9E", XML_ERROR_NONE},
		{"UTF-16BE bad surrogate", utf16_be_bad_surrogate_input, (int)sizeof(utf16_be_bad_surrogate_input) - 1, NULL, XML_ERROR_INVALID_TOKEN},
		{"UTF-16BE CDATA", utf16_cdata_input, (int)sizeof(utf16_cdata_input) - 1, "hello", XML_ERROR_NONE},
		{"UTF-16 declared in UTF-8 bytes", utf16_declared_in_utf8_input, (int)sizeof(utf16_declared_in_utf8_input) - 1, NULL, XML_ERROR_INCORRECT_ENCODING}
	};
	const char *entity_context_input =
		"<!DOCTYPE day [\n"
		"  <!ENTITY draft.day '10'>\n"
		"]>\n"
		"<day>&draft.day;</day>\n";
	const char *hash_collision_input =
		"<doc>\n"
		"<a1/><a2/><a3/><a4/><a5/><a6/><a7/><a8/>\n"
		"<b1></b1><b2 attr='foo'>This is a foo</b2><b3></b3><b4></b4>\n"
		"<b5></b5><b6></b6><b7></b7><b8></b8>\n"
		"<c1/><c2/><c3/><c4/><c5/><c6/><c7/><c8/>\n"
		"<d1/><d2/><d3/><d4/><d5/><d6/><d7/>\n"
		"<d8>This triggers the table growth and collides with b2</d8>\n"
		"</doc>\n";
	const char *default_current_input = "<doc>hell]</doc>";
	const char *default_current_entity_input =
		"<!DOCTYPE doc [\n"
		"<!ENTITY entity '&#37;'>\n"
		"]>\n"
		"<doc>&entity;</doc>";
	const uint8_t hash_entropy[16] = {
		'0', '1', '2', '3', '4', '5', '6', '7',
		'8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
	};
	feature = XML_GetFeatureList();
	if (!check(feature != NULL, "feature list returned")) return 1;
	while (feature->feature != XML_FEATURE_END) {
		if (feature->feature == XML_FEATURE_SIZEOF_XML_CHAR) {
			if (!check(feature->value == sizeof(XML_Char), "sizeof XML_Char feature value")) return 1;
			saw_xml_char_feature = 1;
		} else if (feature->feature == XML_FEATURE_SIZEOF_XML_LCHAR) {
			if (!check(feature->value == sizeof(XML_LChar), "sizeof XML_LChar feature value")) return 1;
			saw_xml_lchar_feature = 1;
		}
		feature++;
	}
	if (!check(saw_xml_char_feature && saw_xml_lchar_feature, "feature list includes size entries")) return 1;

	duff_allocator.malloc_fcn = smoke_duff_malloc;
	duff_allocator.realloc_fcn = smoke_duff_realloc;
	duff_allocator.free_fcn = smoke_duff_free;
	g_failing_alloc_count = 0;
	if (!check(XML_ParserCreate_MM(NULL, &duff_allocator, NULL) == NULL, "custom allocator creation failure returns null")) return 1;
	g_failing_alloc_count = 1;
	{
		XML_Parser allocated_parser = XML_ParserCreate_MM(NULL, &duff_allocator, NULL);
		if (!check(allocated_parser != NULL, "custom allocator parser creation succeeds after one allocation")) return 1;
		XML_ParserFree(allocated_parser);
	}
	g_failing_alloc_count = 0;
	if (!check(XML_ParserCreate_MM("us-ascii", &duff_allocator, NULL) == NULL, "custom allocator encoded creation failure returns null")) return 1;
	g_failing_alloc_count = 1;
	{
		XML_Parser allocated_parser = XML_ParserCreate_MM("us-ascii", &duff_allocator, NULL);
		if (!check(allocated_parser != NULL, "custom allocator encoded parser creation succeeds after one allocation")) return 1;
		XML_ParserFree(allocated_parser);
	}

	if (!check(parser != NULL, "parser created")) return 1;
	if (!check(XML_SetEncoding(parser, NULL) == XML_STATUS_OK, "explicit encoding null accepted before parse")) return 1;
	if (!check(XML_SetEncoding(parser, "utf-8") == XML_STATUS_OK, "explicit UTF-8 encoding accepted before parse")) return 1;
	status = XML_Parse(parser, "<doc>Hello ", 11, XML_FALSE);
	if (!check(status == XML_STATUS_OK, "explicit encoding non-final parse accepted")) return 1;
	if (!check(XML_SetEncoding(parser, "us-ascii") == XML_STATUS_ERROR, "explicit encoding change rejected mid-parse")) return 1;
	status = XML_Parse(parser, " World</doc>", 12, XML_TRUE);
	if (!check(status == XML_STATUS_OK, "explicit encoding final parse accepted")) return 1;
	if (!check(XML_SetEncoding(parser, NULL) == XML_STATUS_OK, "explicit encoding unset accepted after parse")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for bad explicit encoding")) return 1;
	if (!check(XML_SetEncoding(parser, "unknown-encoding") == XML_STATUS_OK, "unknown explicit encoding accepted before parse")) return 1;
	status = XML_Parse(parser, "<doc>Hi</doc>", 13, XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "unknown explicit encoding rejected during parse")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_UNKNOWN_ENCODING, "unknown explicit encoding maps error")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created")) return 1;
	if (!check(XML_SetHashSalt16Bytes(NULL, hash_entropy) == XML_FALSE, "hash salt rejects null parser")) return 1;
	if (!check(XML_SetHashSalt16Bytes(parser, NULL) == XML_FALSE, "hash salt rejects null entropy")) return 1;
	if (!check(XML_SetHashSalt16Bytes(parser, hash_entropy) == XML_TRUE, "hash salt accepts entropy before parse")) return 1;
	if (!check(XML_SetHashSalt16Bytes(parser, hash_entropy) == XML_TRUE, "hash salt accepts repeated entropy before parse")) return 1;
	if (!check(XML_SetHashSalt(parser, 0x12345678UL) == 1, "legacy hash salt accepts value before parse")) return 1;
	status = XML_Parse(parser, "", 0, XML_FALSE);
	if (!check(status == XML_STATUS_OK, "empty non-final parse starts parser")) return 1;
	if (!check(XML_SetHashSalt16Bytes(parser, hash_entropy) == XML_FALSE, "hash salt rejects change after parse starts")) return 1;
	if (!check(XML_SetHashSalt(parser, 0x87654321UL) == 0, "legacy hash salt rejects change after parse starts")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for hash collision check")) return 1;
	if (!check(XML_SetHashSalt(parser, (unsigned long)0xff99fc90UL) == 1, "legacy hash salt accepts collision salt before parse")) return 1;
	hash_collision_len = strlen(hash_collision_input);
	for (hash_index = 0; hash_index < hash_collision_len; hash_index++) {
		status = XML_Parse(
			parser,
			hash_collision_input + hash_index,
			1,
			(hash_index + 1 == hash_collision_len) ? XML_TRUE : XML_FALSE
		);
		if (!check(status == XML_STATUS_OK, "hash collision single-byte parse accepted")) return 1;
	}
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
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
	if (!check(parser != NULL, "parser created for default current check")) return 1;
	g_parser = parser;
	g_default_current_failed = 0;
	g_default_current_record_count = 0;
	XML_SetDefaultHandler(parser, default_current_default_handler);
	XML_SetCharacterDataHandler(parser, default_current_cdata_handler);
	status = XML_Parse(parser, default_current_input, (int)strlen(default_current_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "default current document accepted")) return 1;
	if (!check(!g_default_current_failed && g_default_current_record_count == 4, "default current records expected calls")) return 1;
	if (!check(check_default_current_record(0, DEFAULT_CURRENT_DEFAULT, 5), "default current start tag defaulted")) return 1;
	if (!check(check_default_current_record(1, DEFAULT_CURRENT_CDATA, 5), "default current cdata handled")) return 1;
	if (!check(check_default_current_record(2, DEFAULT_CURRENT_DEFAULT, 5), "default current cdata replayed")) return 1;
	if (!check(check_default_current_record(3, DEFAULT_CURRENT_DEFAULT, 6), "default current end tag defaulted")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for no default current check")) return 1;
	g_parser = parser;
	g_default_current_failed = 0;
	g_default_current_record_count = 0;
	XML_SetDefaultHandler(parser, default_current_default_handler);
	XML_SetCharacterDataHandler(parser, default_current_cdata_nodefault_handler);
	status = XML_Parse(parser, default_current_input, (int)strlen(default_current_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "no default current document accepted")) return 1;
	if (!check(!g_default_current_failed && g_default_current_record_count == 3, "no default current records expected calls")) return 1;
	if (!check(check_default_current_record(0, DEFAULT_CURRENT_DEFAULT, 5), "no default current start tag defaulted")) return 1;
	if (!check(check_default_current_record(1, DEFAULT_CURRENT_CDATA_NODEFAULT, 5), "no default current cdata handled")) return 1;
	if (!check(check_default_current_record(2, DEFAULT_CURRENT_DEFAULT, 6), "no default current end tag defaulted")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default-suppressed entity check")) return 1;
	g_default_len = 0;
	g_default_text[0] = '\0';
	g_empty_text_failed = 0;
	XML_SetDefaultHandler(parser, default_handler);
	XML_SetCharacterDataHandler(parser, empty_text_handler);
	status = XML_Parse(parser, default_current_entity_input, (int)strlen(default_current_entity_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "default-suppressed internal entity document accepted")) return 1;
	if (!check(strstr(g_default_text, "&entity;") != NULL, "default handler receives suppressed internal entity reference")) return 1;
	if (!check(!g_empty_text_failed, "suppressed internal entity produces no character data")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for skipped internal entity check")) return 1;
	g_default_current_failed = 0;
	g_default_current_record_count = 0;
	g_empty_text_failed = 0;
	XML_SetDefaultHandler(parser, default_handler);
	XML_SetSkippedEntityHandler(parser, default_current_skip_handler);
	XML_SetCharacterDataHandler(parser, empty_text_handler);
	status = XML_Parse(parser, default_current_entity_input, (int)strlen(default_current_entity_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "skipped internal entity document accepted")) return 1;
	if (!check(!g_default_current_failed && g_default_current_record_count > 0, "skipped internal entity recorded callbacks")) return 1;
	if (!check(check_default_current_record(g_default_current_record_count - 3, DEFAULT_CURRENT_SKIP, 0) || check_default_current_record(g_default_current_record_count - 2, DEFAULT_CURRENT_SKIP, 0) || check_default_current_record(g_default_current_record_count - 1, DEFAULT_CURRENT_SKIP, 0), "skipped internal entity callback delegated")) return 1;
	if (!check(!g_empty_text_failed, "skipped internal entity produces no character data")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default-current entity expansion check")) return 1;
	g_parser = parser;
	g_default_current_failed = 0;
	g_default_current_record_count = 0;
	XML_SetDefaultHandlerExpand(parser, default_current_default_handler);
	XML_SetCharacterDataHandler(parser, default_current_cdata_handler);
	status = XML_Parse(parser, default_current_entity_input, (int)strlen(default_current_entity_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "default-current expanded internal entity document accepted")) return 1;
	if (!check(!g_default_current_failed, "default-current expanded entity records did not overflow")) return 1;
	if (!check(g_default_current_record_count >= 2, "default-current expanded entity recorded callbacks")) return 1;
	if (!check(check_default_current_record(g_default_current_record_count - 3, DEFAULT_CURRENT_CDATA, 1) || check_default_current_record(g_default_current_record_count - 2, DEFAULT_CURRENT_CDATA, 1), "default-current expanded entity cdata handled")) return 1;
	if (!check(check_default_current_record(g_default_current_record_count - 2, DEFAULT_CURRENT_DEFAULT, 1) || check_default_current_record(g_default_current_record_count - 1, DEFAULT_CURRENT_DEFAULT, 1), "default-current expanded entity cdata replayed")) return 1;
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
	if (!check(parser != NULL, "parser created for namespace-like default attribute check")) return 1;
	g_parser = parser;
	g_ns_default_attr_start_count = 0;
	g_ns_default_attr_failed = 0;
	XML_SetStartElementHandler(parser, ns_default_attr_start_handler);
	status = XML_Parse(parser, ns_default_attr_input, (int)strlen(ns_default_attr_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "namespace-like default attribute accepted without namespace mode")) return 1;
	if (!check(g_ns_default_attr_start_count == 1 && !g_ns_default_attr_failed, "namespace-like default attribute delegated")) return 1;
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
	if (!check(parser != NULL, "parser created for general entity support check")) return 1;
	g_parser = parser;
	g_entity_decl_count = 0;
	g_entity_decl_failed = 0;
	g_external_entity_ref_count = 0;
	g_general_entity_start_count = 0;
	g_general_entity_failed = 0;
	g_general_entity_len = 0;
	g_general_entity_text[0] = '\0';
	XML_SetEntityDeclHandler(parser, general_entity_decl_handler);
	XML_SetExternalEntityRefHandler(parser, general_external_entity_handler);
	XML_SetStartElementHandler(parser, general_entity_start_handler);
	XML_SetCharacterDataHandler(parser, general_entity_text_handler);
	status = XML_Parse(parser, general_entities_input, (int)strlen(general_entities_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "general entity support document accepted")) return 1;
	if (!check(g_entity_decl_count == 2 && !g_entity_decl_failed, "entity declaration callbacks delegated")) return 1;
	if (!check(g_external_entity_ref_count == 1, "external general entity callback delegated")) return 1;
	if (!check(g_general_entity_start_count == 1 && !g_general_entity_failed, "general entity start callback delegated")) return 1;
	if (!check(strcmp(g_general_entity_text, "[v1][][&'><\"]") == 0, "general entity character data delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for null-context external parser check")) return 1;
	{
		XML_Parser ext_parser = XML_ExternalEntityParserCreate(parser, NULL, NULL);
		if (!check(ext_parser != NULL, "external entity parser accepts null context")) return 1;
		XML_ParserFree(ext_parser);
	}
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for loaded external entity check")) return 1;
	g_parser = parser;
	g_loaded_external_ref_count = 0;
	g_loaded_external_failed = 0;
	g_loaded_external_start_count = 0;
	g_loaded_external_end_count = 0;
	g_loaded_external_start_cdata_count = 0;
	g_loaded_external_end_cdata_count = 0;
	g_loaded_external_len = 0;
	g_loaded_external_text[0] = '\0';
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted")) return 1;
	XML_SetElementHandler(parser, loaded_external_start_handler, loaded_external_end_handler);
	XML_SetCharacterDataHandler(parser, loaded_external_text_handler);
	XML_SetCdataSectionHandler(parser, loaded_external_start_cdata_handler, loaded_external_end_cdata_handler);
	XML_SetExternalEntityRefHandler(parser, loading_external_entity_handler);
	status = XML_Parse(parser, loaded_external_input, (int)strlen(loaded_external_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "loaded external entity document accepted")) return 1;
	if (!check(g_loaded_external_ref_count == 1 && !g_loaded_external_failed, "external entity parser loaded through callback")) return 1;
	if (!check(g_loaded_external_start_count == 2 && g_loaded_external_end_count == 2, "external entity parser inherited element handlers")) return 1;
	if (!check(g_loaded_external_start_cdata_count == 1 && g_loaded_external_end_cdata_count == 1, "external entity parser inherited CDATA handlers")) return 1;
	if (!check(strcmp(g_loaded_external_text, "external cdata tail") == 0, "external entity parser inherited character handler")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for explicit external handler arg check")) return 1;
	g_parser = parser;
	g_expected_external_arg = external_arg_input;
	g_external_arg_ref_count = 0;
	g_external_arg_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for explicit arg")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_arg_checker);
	XML_SetExternalEntityRefHandlerArg(parser, (void *)external_arg_input);
	status = XML_Parse(parser, external_arg_input, (int)strlen(external_arg_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "explicit external handler arg document accepted")) return 1;
	if (!check(g_external_arg_ref_count == 1 && !g_external_arg_failed, "explicit external handler arg forwarded")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default external handler arg check")) return 1;
	g_parser = parser;
	g_expected_external_arg = parser;
	g_external_arg_ref_count = 0;
	g_external_arg_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for default arg")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_arg_checker);
	XML_SetExternalEntityRefHandlerArg(parser, NULL);
	status = XML_Parse(parser, external_arg_input, (int)strlen(external_arg_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "default external handler arg document accepted")) return 1;
	if (!check(g_external_arg_ref_count == 1 && !g_external_arg_failed, "null external handler arg falls back to parser")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for explicit external subset handler arg check")) return 1;
	g_parser = parser;
	g_expected_external_arg = external_ref_parameter_input;
	g_external_arg_ref_count = 0;
	g_external_arg_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for explicit subset arg")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_arg_checker);
	XML_SetExternalEntityRefHandlerArg(parser, (void *)external_ref_parameter_input);
	status = XML_Parse(parser, external_ref_parameter_input, (int)strlen(external_ref_parameter_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "explicit external subset handler arg document accepted")) return 1;
	if (!check(g_external_arg_ref_count == 1 && !g_external_arg_failed, "explicit external subset handler arg forwarded")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for default external subset handler arg check")) return 1;
	g_parser = parser;
	g_expected_external_arg = parser;
	g_external_arg_ref_count = 0;
	g_external_arg_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for default subset arg")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_arg_checker);
	XML_SetExternalEntityRefHandlerArg(parser, NULL);
	status = XML_Parse(parser, external_ref_parameter_input, (int)strlen(external_ref_parameter_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "default external subset handler arg document accepted")) return 1;
	if (!check(g_external_arg_ref_count == 1 && !g_external_arg_failed, "null external subset handler arg falls back to parser")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for unread external subset undefined entity check")) return 1;
	status = XML_Parse(parser, unread_external_subset_input, (int)strlen(unread_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "undefined entity with unread external subset is accepted")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for no external subset undefined entity check")) return 1;
	status = XML_Parse(parser, no_external_subset_undefined_input, (int)strlen(no_external_subset_undefined_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "undefined entity without external subset is rejected")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_UNDEFINED_ENTITY, "undefined entity maps to XML_ERROR_UNDEFINED_ENTITY")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for standalone undefined entity check")) return 1;
	status = XML_Parse(parser, standalone_external_subset_input, (int)strlen(standalone_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "standalone undefined external-subset entity is rejected")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_UNDEFINED_ENTITY, "standalone undefined entity maps to XML_ERROR_UNDEFINED_ENTITY")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for not-standalone reject check")) return 1;
	g_not_standalone_count = 0;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ELEMENT doc (#PCDATA)*>";
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for not-standalone reject")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetNotStandaloneHandler(parser, reject_not_standalone_handler);
	status = XML_Parse(parser, not_standalone_external_subset_input, (int)strlen(not_standalone_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "not-standalone handler can reject external subset")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_NOT_STANDALONE, "not-standalone rejection maps to XML_ERROR_NOT_STANDALONE")) return 1;
	if (!check(g_not_standalone_count == 1, "not-standalone reject callback called once")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for not-standalone accept check")) return 1;
	g_not_standalone_count = 0;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ELEMENT doc (#PCDATA)*>";
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for not-standalone accept")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetNotStandaloneHandler(parser, accept_not_standalone_handler);
	status = XML_Parse(parser, not_standalone_external_subset_input, (int)strlen(not_standalone_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "not-standalone handler can accept external subset")) return 1;
	if (!check(g_not_standalone_count == 1 && g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "not-standalone accept loads external subset")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for not-standalone accept without external handler check")) return 1;
	g_not_standalone_count = 0;
	XML_SetNotStandaloneHandler(parser, accept_not_standalone_handler);
	status = XML_Parse(parser, not_standalone_external_subset_input, (int)strlen(not_standalone_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "not-standalone accept works without loading external subset")) return 1;
	if (!check(g_not_standalone_count == 1, "not-standalone accept without external handler called once")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for unless-standalone external subset check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ENTITY entity 'bar'>";
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE), "unless-standalone parameter parsing accepted")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	status = XML_Parse(parser, standalone_external_subset_input, (int)strlen(standalone_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "standalone document skips unless-standalone external subset load")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_UNDEFINED_ENTITY, "unless-standalone skip maps to undefined entity")) return 1;
	if (!check(g_foreign_dtd_ref_count == 0 && !g_foreign_dtd_failed, "unless-standalone skipped external callback")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for foreign DTD split check")) return 1;
	g_not_standalone_count = 0;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ELEMENT doc (#PCDATA)*>";
	if (!check(XML_SetHashSalt(parser, 0x12345678UL), "foreign DTD hash salt accepted before parse")) return 1;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for foreign DTD")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetNotStandaloneHandler(parser, accept_not_standalone_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "foreign DTD setting accepted before parse")) return 1;
	status = XML_Parse(parser, foreign_dtd_decl_chunk, (int)strlen(foreign_dtd_decl_chunk), XML_FALSE);
	if (!check(status == XML_STATUS_OK, "foreign DTD initial chunk accepted")) return 1;
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_CANT_CHANGE_FEATURE_ONCE_PARSING, "late foreign DTD setting rejected")) return 1;
	if (!check(!XML_SetHashSalt(parser, 0x23456789UL), "late hash salt change rejected during parse")) return 1;
	status = XML_Parse(parser, foreign_dtd_body_chunk, (int)strlen(foreign_dtd_body_chunk), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "foreign DTD split document accepted")) return 1;
	if (!check(g_not_standalone_count == 1 && g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "foreign DTD callback path loaded")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for rejecting foreign DTD not-standalone check")) return 1;
	g_not_standalone_count = 0;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ELEMENT doc (#PCDATA)*>";
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for rejecting foreign DTD")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetNotStandaloneHandler(parser, reject_not_standalone_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "rejecting foreign DTD setting accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_decl_chunk, (int)strlen(foreign_dtd_decl_chunk), XML_FALSE);
	if (!check(status == XML_STATUS_OK, "rejecting foreign DTD initial chunk accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_body_chunk, (int)strlen(foreign_dtd_body_chunk), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "foreign DTD not-standalone handler can reject")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_NOT_STANDALONE, "foreign DTD rejection maps to XML_ERROR_NOT_STANDALONE")) return 1;
	if (!check(g_not_standalone_count == 1 && g_foreign_dtd_ref_count == 0, "foreign DTD rejection happens before loading")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for foreign DTD with doctype check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_text_len = 0;
	g_foreign_text[0] = '\0';
	g_foreign_dtd_text = "<!ELEMENT doc (#PCDATA)*>";
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for foreign DTD with doctype")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetCharacterDataHandler(parser, foreign_text_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "foreign DTD with doctype setting accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_with_doctype_input, (int)strlen(foreign_dtd_with_doctype_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "foreign DTD with doctype accepted")) return 1;
	if (!check(g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "foreign DTD with doctype loaded once")) return 1;
	if (!check(strcmp(g_foreign_text, "hello world") == 0, "foreign DTD with doctype preserved internal entity")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for foreign DTD without external subset check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_text_len = 0;
	g_foreign_text[0] = '\0';
	g_foreign_dtd_text = NULL;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for empty foreign callback")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	XML_SetCharacterDataHandler(parser, foreign_text_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "foreign DTD without external subset setting accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_without_external_subset_input, (int)strlen(foreign_dtd_without_external_subset_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "foreign DTD without external subset accepted")) return 1;
	if (!check(g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "foreign DTD without external subset callback accepted")) return 1;
	if (!check(strcmp(g_foreign_text, "bar") == 0, "foreign DTD without external subset preserved internal entity")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for empty foreign DTD check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = NULL;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for empty foreign DTD")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "empty foreign DTD setting accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_decl_chunk, (int)strlen(foreign_dtd_decl_chunk), XML_FALSE);
	if (!check(status == XML_STATUS_OK, "empty foreign DTD initial chunk accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_body_chunk, (int)strlen(foreign_dtd_body_chunk), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "empty foreign DTD keeps undefined entity rejection")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_UNDEFINED_ENTITY, "empty foreign DTD maps to undefined entity")) return 1;
	if (!check(g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "empty foreign DTD callback accepted")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for invalid foreign DTD check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "$";
	g_expected_foreign_dtd_child_error = XML_ERROR_SYNTAX;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for invalid foreign DTD")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "invalid foreign DTD setting accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_decl_chunk, (int)strlen(foreign_dtd_decl_chunk), XML_FALSE);
	if (!check(status == XML_STATUS_OK, "invalid foreign DTD initial chunk accepted")) return 1;
	status = XML_Parse(parser, foreign_dtd_body_chunk, (int)strlen(foreign_dtd_body_chunk), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "invalid foreign DTD child failure propagates")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_EXTERNAL_ENTITY_HANDLING, "invalid foreign DTD maps to external entity handling")) return 1;
	if (!check(g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "invalid foreign DTD callback observed expected child error")) return 1;
	g_expected_foreign_dtd_child_error = XML_ERROR_NONE;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for external parameter not-standalone check")) return 1;
	g_not_standalone_count = 0;
	g_parameter_entity_ref_count = 0;
	g_parameter_entity_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for external parameter not-standalone")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_entity_not_standalone_handler);
	status = XML_Parse(parser, external_parameter_not_standalone_input, (int)strlen(external_parameter_not_standalone_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "external parameter not-standalone child failure propagates")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_EXTERNAL_ENTITY_HANDLING, "external parameter not-standalone maps to external entity handling")) return 1;
	if (!check(g_not_standalone_count == 1 && g_parameter_entity_ref_count == 1 && !g_parameter_entity_failed, "external parameter not-standalone callback path matched")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for invalid tag in DTD check")) return 1;
	g_parameter_entity_ref_count = 0;
	g_parameter_entity_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for invalid tag in DTD")) return 1;
	XML_SetExternalEntityRefHandler(parser, invalid_tag_in_dtd_external_entity_handler);
	status = XML_Parse(parser, invalid_tag_in_dtd_input, (int)strlen(invalid_tag_in_dtd_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "invalid tag in DTD child failure propagates")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_EXTERNAL_ENTITY_HANDLING, "invalid tag in DTD maps to external entity handling")) return 1;
	if (!check(g_parameter_entity_ref_count == 2 && !g_parameter_entity_failed, "invalid tag in DTD callback path matched")) return 1;
	XML_ParserFree(parser);

	{
		const char *recursive_cases[] = {
			"<!ENTITY % p1 '%p1;'>",
			"<!ENTITY % p1 '%p1;'><!ENTITY % p1 'first declaration wins'>",
			NULL
		};
		const char *accepted_cases[] = {
			"<!ENTITY % p1 'first declaration wins'><!ENTITY % p1 '%p1;'>",
			"<!ENTITY % p1 '&#37;p1;'>",
			NULL
		};
		int case_index;
		for (case_index = 0; recursive_cases[case_index] != NULL; case_index++) {
			XML_Parser parent_parser = XML_ParserCreate("UTF-8");
			XML_Parser ext_parser;
			if (!check(parent_parser != NULL, "parent parser created for direct recursive parameter check")) return 1;
			ext_parser = XML_ExternalEntityParserCreate(parent_parser, NULL, NULL);
			if (!check(ext_parser != NULL, "external parser created for direct recursive parameter check")) return 1;
			status = XML_Parse(ext_parser, recursive_cases[case_index], (int)strlen(recursive_cases[case_index]), XML_TRUE);
			if (!check(status == XML_STATUS_ERROR, "direct recursive parameter entity rejected")) return 1;
			if (!check(XML_GetErrorCode(ext_parser) == XML_ERROR_RECURSIVE_ENTITY_REF, "direct recursive parameter entity maps error")) return 1;
			XML_ParserFree(ext_parser);
			XML_ParserFree(parent_parser);
		}
		for (case_index = 0; accepted_cases[case_index] != NULL; case_index++) {
			XML_Parser parent_parser = XML_ParserCreate("UTF-8");
			XML_Parser ext_parser;
			if (!check(parent_parser != NULL, "parent parser created for accepted parameter check")) return 1;
			ext_parser = XML_ExternalEntityParserCreate(parent_parser, NULL, NULL);
			if (!check(ext_parser != NULL, "external parser created for accepted parameter check")) return 1;
			status = XML_Parse(ext_parser, accepted_cases[case_index], (int)strlen(accepted_cases[case_index]), XML_TRUE);
			if (!check(status == XML_STATUS_OK, "non-recursive parameter entity declaration accepted")) return 1;
			XML_ParserFree(ext_parser);
			XML_ParserFree(parent_parser);
		}
	}

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for recursive external parameter entity check")) return 1;
	g_foreign_dtd_ref_count = 0;
	g_foreign_dtd_failed = 0;
	g_foreign_dtd_text = "<!ENTITY % pe2 '&#37;pe2;'>\n%pe2;";
	g_expected_foreign_dtd_child_error = XML_ERROR_RECURSIVE_ENTITY_REF;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for recursive external parameter")) return 1;
	XML_SetExternalEntityRefHandler(parser, foreign_dtd_external_entity_handler);
	status = XML_Parse(parser, recursive_external_parameter_input, (int)strlen(recursive_external_parameter_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "recursive external parameter child failure propagates")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_EXTERNAL_ENTITY_HANDLING, "recursive external parameter maps to external entity handling")) return 1;
	if (!check(g_foreign_dtd_ref_count == 1 && !g_foreign_dtd_failed, "recursive external parameter callback observed expected child error")) return 1;
	g_expected_foreign_dtd_child_error = XML_ERROR_NONE;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for undefined external parameter check")) return 1;
	g_parameter_entity_ref_count = 0;
	g_parameter_entity_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for undefined external parameter")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_entity_devaluer_handler);
	status = XML_Parse(parser, undefined_external_parameter_input, (int)strlen(undefined_external_parameter_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "undefined external parameter with nested handler accepted")) return 1;
	if (!check(g_parameter_entity_ref_count == 2 && !g_parameter_entity_failed, "undefined external parameter nested callback path matched")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for undefined external parameter without nested handler check")) return 1;
	g_parameter_entity_ref_count = 0;
	g_parameter_entity_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for skipped nested parameter")) return 1;
	XML_SetExternalEntityRefHandler(parser, external_entity_devaluer_handler);
	XML_SetUserData(parser, parser);
	status = XML_Parse(parser, undefined_external_parameter_input, (int)strlen(undefined_external_parameter_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "undefined external parameter without nested handler accepted")) return 1;
	if (!check(g_parameter_entity_ref_count == 1 && !g_parameter_entity_failed, "undefined external parameter skipped nested callback path matched")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for DTD stop-processing parameter check")) return 1;
	g_entity_decl_count = 0;
	g_entity_decl_failed = 0;
	g_parameter_skip_count = 0;
	g_parameter_skip_failed = 0;
	XML_SetEntityDeclHandler(parser, general_entity_decl_handler);
	XML_SetSkippedEntityHandler(parser, parameter_skipped_entity_handler);
	status = XML_Parse(parser, dtd_stop_processing_input, (int)strlen(dtd_stop_processing_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "undefined parameter entity stops DTD processing without failing")) return 1;
	if (!check(g_entity_decl_count == 0 && !g_entity_decl_failed, "DTD processing stopped before later entity declaration")) return 1;
	if (!check(g_parameter_skip_count == 1 && !g_parameter_skip_failed, "undefined parameter entity skip callback delegated")) return 1;
	XML_ParserFree(parser);

	{
		int split;
		int external_bom_len = (int)strlen(external_bom_text);
		for (split = 0; split <= external_bom_len; split++) {
			parser = XML_ParserCreate("UTF-8");
			if (!check(parser != NULL, "parser created for external BOM check")) return 1;
			g_parameter_entity_ref_count = 0;
			g_bom_external_text = external_bom_text;
			g_bom_split = split;
			g_bom_nested_callback_happened = 0;
			g_bom_failed = 0;
			if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for external BOM")) return 1;
			XML_SetExternalEntityRefHandler(parser, external_bom_checker_handler);
			status = XML_Parse(parser, external_bom_input, (int)strlen(external_bom_input), XML_TRUE);
			if (!check(status == XML_STATUS_OK, "external BOM DTD parameter entity accepted")) return 1;
			if (!check(g_bom_nested_callback_happened && !g_bom_failed, "external BOM child callback path matched")) return 1;
			XML_ParserFree(parser);
		}
	}

	for (external_value_index = 0; external_value_index < sizeof(external_value_cases) / sizeof(external_value_cases[0]); external_value_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for external entity value check")) return 1;
		g_external_value_ref_count = 0;
		g_external_value_failed = 0;
		g_external_value_text = external_value_cases[external_value_index].text;
		g_external_value_expected_error = external_value_cases[external_value_index].expected_error;
		if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for external entity value")) return 1;
		XML_SetExternalEntityRefHandler(parser, external_entity_value_handler);
		status = XML_Parse(parser, invalid_tag_in_dtd_input, (int)strlen(invalid_tag_in_dtd_input), XML_TRUE);
		if (!check(status == XML_STATUS_OK, "external entity value document accepted")) return 1;
		if (g_external_value_ref_count < 2 || g_external_value_failed) {
			fprintf(
				stderr,
				"external entity value case %u failed: refs=%d failed=%d expected=%d text=%s\n",
				(unsigned)external_value_index,
				g_external_value_ref_count,
				g_external_value_failed,
				(int)g_external_value_expected_error,
				g_external_value_text
			);
		}
		if (!check(g_external_value_ref_count >= 2 && !g_external_value_failed, "external entity value callback path matched")) return 1;
		XML_ParserFree(parser);
	}

	for (external_trailing_index = 0; external_trailing_index < sizeof(external_trailing_cases) / sizeof(external_trailing_cases[0]); external_trailing_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for external entity trailing check")) return 1;
		g_external_trailing_ref_count = 0;
		g_external_trailing_failed = 0;
		g_external_trailing_found = 0;
		g_external_trailing_text = external_trailing_cases[external_trailing_index].text;
		g_external_trailing_expected_char = external_trailing_cases[external_trailing_index].expected_char;
		g_external_trailing_expected_error = external_trailing_cases[external_trailing_index].expected_error;
		if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for external entity trailing")) return 1;
		XML_SetExternalEntityRefHandler(parser, external_entity_trailing_handler);
		status = XML_Parse(parser, loaded_external_input, (int)strlen(loaded_external_input), XML_TRUE);
		if (!check(status == XML_STATUS_OK, "external entity trailing parent document accepted")) return 1;
		if (g_external_trailing_ref_count != 1 || g_external_trailing_failed || !g_external_trailing_found) {
			fprintf(
				stderr,
				"external entity trailing case %s failed: refs=%d failed=%d found=%d expected=%d text=%s\n",
				external_trailing_cases[external_trailing_index].label,
				g_external_trailing_ref_count,
				g_external_trailing_failed,
				g_external_trailing_found,
				(int)g_external_trailing_expected_error,
				g_external_trailing_text
			);
		}
		if (!check(g_external_trailing_ref_count == 1 && !g_external_trailing_failed && g_external_trailing_found, "external entity trailing callback path matched")) return 1;
		XML_ParserFree(parser);
	}

	for (external_invalid_index = 0; external_invalid_index < sizeof(external_invalid_cases) / sizeof(external_invalid_cases[0]); external_invalid_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for invalid external entity check")) return 1;
		g_external_invalid_ref_count = 0;
		g_external_invalid_failed = 0;
		g_external_invalid_text = external_invalid_cases[external_invalid_index].text;
		g_external_invalid_expected_error = external_invalid_cases[external_invalid_index].expected_error;
		g_external_invalid_actual_error = XML_ERROR_NONE;
		if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for invalid external entity")) return 1;
		XML_SetExternalEntityRefHandler(parser, external_entity_invalid_handler);
		status = XML_Parse(parser, loaded_external_input, (int)strlen(loaded_external_input), XML_TRUE);
		if (status != XML_STATUS_ERROR || XML_GetErrorCode(parser) != XML_ERROR_EXTERNAL_ENTITY_HANDLING) {
			fprintf(
				stderr,
				"invalid external entity case %s parent status=%d error=%d\n",
				external_invalid_cases[external_invalid_index].label,
				(int)status,
				(int)XML_GetErrorCode(parser)
			);
			return 1;
		}
		if (g_external_invalid_ref_count != 1 || g_external_invalid_failed) {
			fprintf(
				stderr,
				"invalid external entity case %s failed: refs=%d failed=%d actual=%d expected=%d text=%s\n",
				external_invalid_cases[external_invalid_index].label,
				g_external_invalid_ref_count,
				g_external_invalid_failed,
				(int)g_external_invalid_actual_error,
				(int)g_external_invalid_expected_error,
				g_external_invalid_text
			);
		}
		if (!check(g_external_invalid_ref_count == 1 && !g_external_invalid_failed, "invalid external entity child error matched")) return 1;
		XML_ParserFree(parser);
	}

	for (external_encoding_index = 0; external_encoding_index < sizeof(external_encoding_cases) / sizeof(external_encoding_cases[0]); external_encoding_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for external entity encoding check")) return 1;
		g_external_encoding_ref_count = 0;
		g_external_encoding_failed = 0;
		g_external_encoding_text = external_encoding_cases[external_encoding_index].text;
		g_external_encoding_name = external_encoding_cases[external_encoding_index].encoding;
		g_external_encoding_expected_error = external_encoding_cases[external_encoding_index].expected_error;
		g_external_encoding_actual_error = XML_ERROR_NONE;
		g_loaded_external_len = 0;
		g_loaded_external_text[0] = '\0';
		if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for external entity encoding")) return 1;
		XML_SetExternalEntityRefHandler(parser, external_entity_encoding_handler);
		XML_SetCharacterDataHandler(parser, loaded_external_text_handler);
		status = XML_Parse(
			parser,
			external_encoding_cases[external_encoding_index].parent_text,
			(int)strlen(external_encoding_cases[external_encoding_index].parent_text),
			XML_TRUE
		);
		if (external_encoding_cases[external_encoding_index].expected_error == XML_ERROR_NONE) {
			if (status != XML_STATUS_OK) {
				fprintf(
					stderr,
					"external entity encoding case %s parent status=%d error=%d child=%d\n",
					external_encoding_cases[external_encoding_index].label,
					(int)status,
					(int)XML_GetErrorCode(parser),
					(int)g_external_encoding_actual_error
				);
				return 1;
			}
			if (
				g_external_encoding_ref_count != 1
				|| g_external_encoding_failed
				|| strcmp(g_loaded_external_text, external_encoding_cases[external_encoding_index].expected_text) != 0
			) {
				fprintf(
					stderr,
					"external entity encoding case %s failed: refs=%d failed=%d text=%s\n",
					external_encoding_cases[external_encoding_index].label,
					g_external_encoding_ref_count,
					g_external_encoding_failed,
					g_loaded_external_text
				);
			}
			if (!check(g_external_encoding_ref_count == 1 && !g_external_encoding_failed, "external entity encoding success child matched")) return 1;
			if (!check(strcmp(g_loaded_external_text, external_encoding_cases[external_encoding_index].expected_text) == 0, "external entity encoding emitted expected text")) return 1;
		} else {
			if (status != XML_STATUS_ERROR || XML_GetErrorCode(parser) != XML_ERROR_EXTERNAL_ENTITY_HANDLING) {
				fprintf(
					stderr,
					"external entity encoding case %s parent status=%d error=%d child=%d\n",
					external_encoding_cases[external_encoding_index].label,
					(int)status,
					(int)XML_GetErrorCode(parser),
					(int)g_external_encoding_actual_error
				);
				return 1;
			}
			if (g_external_encoding_ref_count != 1 || g_external_encoding_failed) {
				fprintf(
					stderr,
					"external entity encoding case %s failed: refs=%d failed=%d actual=%d expected=%d\n",
					external_encoding_cases[external_encoding_index].label,
					g_external_encoding_ref_count,
					g_external_encoding_failed,
					(int)g_external_encoding_actual_error,
					(int)g_external_encoding_expected_error
				);
			}
			if (!check(g_external_encoding_ref_count == 1 && !g_external_encoding_failed, "external entity encoding error child matched")) return 1;
		}
		XML_ParserFree(parser);
	}

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for user parameter check")) return 1;
	g_parser = parser;
	g_expected_user_parameter_data = parser;
	g_user_parameter_comment_count = 0;
	g_user_parameter_skip_count = 0;
	g_user_parameter_xdecl_count = 0;
	g_user_parameter_failed = 0;
	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS), "parameter entity parsing accepted for user parameter check")) return 1;
	XML_SetXmlDeclHandler(parser, user_parameter_xml_decl_handler);
	XML_SetExternalEntityRefHandler(parser, user_parameter_external_entity_handler);
	XML_SetCommentHandler(parser, user_parameter_comment_handler);
	XML_SetSkippedEntityHandler(parser, user_parameter_skip_handler);
	XML_UseParserAsHandlerArg(parser);
	XML_SetUserData(parser, (void *)1);
	status = XML_Parse(parser, user_parameter_input, (int)strlen(user_parameter_input), XML_FALSE);
	if (!check(status == XML_STATUS_OK, "user parameter non-final chunk accepted")) return 1;
	if (!check(!XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_NEVER), "parameter entity parsing rejected mid-parse")) return 1;
	status = XML_Parse(parser, user_parameter_epilog, (int)strlen(user_parameter_epilog), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "user parameter final chunk accepted")) return 1;
	if (!check(!g_user_parameter_failed, "user parameter callbacks receive expected parser data")) return 1;
	if (!check(g_user_parameter_comment_count == 3, "user parameter comment callbacks delegated")) return 1;
	if (!check(g_user_parameter_skip_count == 1, "user parameter skipped entity callback delegated")) return 1;
	if (!check(g_user_parameter_xdecl_count == 1, "user parameter XML declaration callback delegated")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for skipped external entity check")) return 1;
	g_skipped_entity_count = 0;
	g_skipped_entity_failed = 0;
	g_empty_text_failed = 0;
	XML_SetDefaultHandler(parser, default_handler);
	XML_SetSkippedEntityHandler(parser, skipped_entity_handler);
	XML_SetCharacterDataHandler(parser, empty_text_handler);
	status = XML_Parse(parser, skipped_external_input, (int)strlen(skipped_external_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "external entity without handler is skipped")) return 1;
	if (!check(g_skipped_entity_count == 1 && !g_skipped_entity_failed, "skipped external entity callback delegated")) return 1;
	if (!check(!g_empty_text_failed, "skipped external entity produces no character data")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for synchronous entity check")) return 1;
	g_sync_entity_start_count = 0;
	g_sync_entity_failed = 0;
	g_sync_entity_len = 0;
	g_sync_entity_text[0] = '\0';
	XML_SetStartElementHandler(parser, sync_entity_start_handler);
	XML_SetCharacterDataHandler(parser, sync_entity_text_handler);
	status = XML_Parse(parser, sync_entity_input, (int)strlen(sync_entity_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "synchronous nested internal entities are accepted")) return 1;
	if (!check(g_sync_entity_start_count == 7 && !g_sync_entity_failed, "synchronous entity markup is emitted")) return 1;
	if (!check(strcmp(g_sync_entity_text, "twothreefourthreetwo") == 0, "synchronous entity character data is emitted")) return 1;
	XML_ParserFree(parser);

	for (utf16_index = 0; utf16_index < sizeof(utf16_cases) / sizeof(utf16_cases[0]); utf16_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for UTF-16 check")) return 1;
		g_loaded_external_len = 0;
		g_loaded_external_text[0] = '\0';
		XML_SetCharacterDataHandler(parser, loaded_external_text_handler);
		status = XML_Parse(parser, utf16_cases[utf16_index].text, utf16_cases[utf16_index].length, XML_TRUE);
		if (utf16_cases[utf16_index].expected_error == XML_ERROR_NONE) {
			if (status != XML_STATUS_OK) {
				fprintf(
					stderr,
					"UTF-16 case %s failed: status=%d error=%d\n",
					utf16_cases[utf16_index].label,
					(int)status,
					(int)XML_GetErrorCode(parser)
				);
				return 1;
			}
			if (strcmp(g_loaded_external_text, utf16_cases[utf16_index].expected_text) != 0) {
				fprintf(
					stderr,
					"UTF-16 case %s emitted %s expected %s\n",
					utf16_cases[utf16_index].label,
					g_loaded_external_text,
					utf16_cases[utf16_index].expected_text
				);
				return 1;
			}
		} else {
			if (status != XML_STATUS_ERROR || XML_GetErrorCode(parser) != utf16_cases[utf16_index].expected_error) {
				fprintf(
					stderr,
					"UTF-16 case %s error=%d expected=%d\n",
					utf16_cases[utf16_index].label,
					(int)XML_GetErrorCode(parser),
					(int)utf16_cases[utf16_index].expected_error
				);
				return 1;
			}
		}
		XML_ParserFree(parser);
	}

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for UTF-16 attribute check")) return 1;
	g_loaded_external_failed = 0;
	g_loaded_external_len = 0;
	g_loaded_external_text[0] = '\0';
	XML_SetStartElementHandler(parser, utf16_attribute_start_handler);
	status = XML_Parse(parser, utf16_attribute_input, (int)sizeof(utf16_attribute_input) - 1, XML_TRUE);
	if (!check(status == XML_STATUS_OK, "UTF-16 non-ASCII attribute name accepted")) return 1;
	if (!check(!g_loaded_external_failed && strcmp(g_loaded_external_text, "a") == 0, "UTF-16 attribute value delegated")) return 1;
	XML_ParserFree(parser);

	for (async_index = 0; async_index < sizeof(g_async_entity_cases) / sizeof(g_async_entity_cases[0]); async_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for async entity check")) return 1;
		status = XML_Parse(
			parser,
			g_async_entity_cases[async_index].input,
			(int)strlen(g_async_entity_cases[async_index].input),
			XML_TRUE
		);
		if (status != XML_STATUS_ERROR) {
			fprintf(stderr, "FAIL: async entity %s rejected\n", g_async_entity_cases[async_index].label);
			return 1;
		}
		actual_error = XML_GetErrorCode(parser);
		if (actual_error != XML_ERROR_ASYNC_ENTITY) {
			fprintf(
				stderr,
				"FAIL: async entity %s mapped to %d, expected %d\n",
				g_async_entity_cases[async_index].label,
				(int)actual_error,
				(int)XML_ERROR_ASYNC_ENTITY
			);
			return 1;
		}
		if (
			XML_GetCurrentLineNumber(parser) != g_async_entity_cases[async_index].expected_line
			|| XML_GetCurrentColumnNumber(parser) != g_async_entity_cases[async_index].expected_column
		) {
			fprintf(stderr, "FAIL: async entity %s position\n", g_async_entity_cases[async_index].label);
			return 1;
		}
		XML_ParserFree(parser);
	}

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for entity context check")) return 1;
	g_parser = parser;
	g_entity_context_failed = 0;
	XML_SetUserData(parser, parser);
	XML_SetCharacterDataHandler(parser, entity_context_text_handler);
	status = XML_Parse(parser, entity_context_input, (int)strlen(entity_context_input), XML_TRUE);
	if (!check(status == XML_STATUS_OK, "entity context document accepted")) return 1;
	if (!check(!g_entity_context_failed, "entity text callback reports original entity reference context")) return 1;
	XML_ParserFree(parser);

	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created for bad public doctype check")) return 1;
	XML_SetDoctypeDeclHandler(parser, start_doctype_handler, end_doctype_handler);
	status = XML_Parse(parser, bad_public_doctype_input, (int)strlen(bad_public_doctype_input), XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "bad public doctype rejected")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_PUBLICID, "bad public doctype maps to XML_ERROR_PUBLICID")) return 1;
	XML_ParserFree(parser);

	for (malformed_index = 0; malformed_index < sizeof(g_malformed_doctype_cases) / sizeof(g_malformed_doctype_cases[0]); malformed_index++) {
		parser = XML_ParserCreate("UTF-8");
		if (!check(parser != NULL, "parser created for malformed doctype check")) return 1;
		if (g_malformed_doctype_cases[malformed_index].use_unknown_encoding_handler) {
			XML_SetUnknownEncodingHandler(parser, smoke_unknown_encoding_handler, NULL);
		}
		status = XML_Parse(
			parser,
			g_malformed_doctype_cases[malformed_index].input,
			(int)strlen(g_malformed_doctype_cases[malformed_index].input),
			XML_TRUE
		);
		if (status != XML_STATUS_ERROR) {
			fprintf(stderr, "FAIL: %s rejected\n", g_malformed_doctype_cases[malformed_index].label);
			return 1;
		}
		actual_error = XML_GetErrorCode(parser);
		if (actual_error != g_malformed_doctype_cases[malformed_index].expected) {
			fprintf(
				stderr,
				"FAIL: %s mapped to %d, expected %d\n",
				g_malformed_doctype_cases[malformed_index].label,
				(int)actual_error,
				(int)g_malformed_doctype_cases[malformed_index].expected
			);
			return 1;
		}
		XML_ParserFree(parser);
	}

	puts("xpact Eiffel DLL smoke: ok");
	return 0;
}
