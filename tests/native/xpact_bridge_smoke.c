#include "native/xpact_eiffel_bridge.h"

#include <stdio.h>
#include <string.h>

typedef struct FakeParser {
	int create_count;
	int reset_count;
	int free_count;
	int set_native_handle_count;
	int set_encoding_count;
	int set_external_entity_context_count;
	int set_external_entity_parameter_context_count;
	int set_param_entity_parsing_count;
	int set_foreign_dtd_count;
	int user_data_count;
	int element_handler_count;
	int text_handler_count;
	int xml_decl_handler_count;
	int not_standalone_handler_count;
	int hash_salt_count;
	int hash_salt_16_count;
	int parse_count;
	void *user_data;
	XML_StartElementHandler start_handler;
	XML_EndElementHandler end_handler;
	XML_CharacterDataHandler text_handler;
	XML_XmlDeclHandler xml_decl_handler;
	XML_NotStandaloneHandler not_standalone_handler;
	void *native_handle;
	const XML_Char *last_encoding;
	const XML_Char *last_external_entity_context;
	XML_Bool last_external_entity_is_parameter;
	enum XML_ParamEntityParsing last_param_entity_parsing;
	XML_Bool last_use_foreign_dtd;
	int last_len;
	int last_is_final;
	unsigned long last_hash_salt;
	uint8_t last_hash_salt_16[16];
	char last_input[32];
} FakeParser;

static FakeParser fake_parser;

static void *XMLCALL
fake_create(
	void *context,
	const XML_Char *encoding,
	const XML_Memory_Handling_Suite *memsuite,
	const XML_Char *namespaceSeparator
) {
	FakeParser *fake = (FakeParser *)context;
	(void)encoding;
	(void)memsuite;
	(void)namespaceSeparator;
	fake->create_count++;
	return fake;
}

static XML_Bool XMLCALL
fake_reset(void *context, void *parser, const XML_Char *encoding) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	(void)encoding;
	fake->reset_count++;
	return XML_TRUE;
}

static void XMLCALL
fake_free(void *context, void *parser) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->free_count++;
}

static void XMLCALL
fake_set_native_parser_handle(void *context, void *parser, void *nativeParser) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_native_handle_count++;
	fake->native_handle = nativeParser;
}

static enum XML_Status XMLCALL
fake_set_encoding(void *context, void *parser, const XML_Char *encoding) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_encoding_count++;
	fake->last_encoding = encoding;
	return XML_STATUS_OK;
}

static XML_Bool XMLCALL
fake_set_external_entity_context(void *context, void *parser, const XML_Char *entityContext) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_external_entity_context_count++;
	fake->last_external_entity_context = entityContext;
	return XML_TRUE;
}

static XML_Bool XMLCALL
fake_set_external_entity_parameter_context(void *context, void *parser, XML_Bool isParameter) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_external_entity_parameter_context_count++;
	fake->last_external_entity_is_parameter = isParameter ? XML_TRUE : XML_FALSE;
	return XML_TRUE;
}

static XML_Bool XMLCALL
fake_set_param_entity_parsing(void *context, void *parser, enum XML_ParamEntityParsing parsing) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_param_entity_parsing_count++;
	fake->last_param_entity_parsing = parsing;
	return XML_TRUE;
}

static XML_Bool XMLCALL
fake_set_foreign_dtd(void *context, void *parser, XML_Bool useDTD) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->set_foreign_dtd_count++;
	fake->last_use_foreign_dtd = useDTD ? XML_TRUE : XML_FALSE;
	return XML_TRUE;
}

static void XMLCALL
fake_set_user_data(void *context, void *parser, void *userData) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->user_data_count++;
	fake->user_data = userData;
}

static void XMLCALL
fake_set_element_handler(
	void *context,
	void *parser,
	XML_StartElementHandler start,
	XML_EndElementHandler end
) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->element_handler_count++;
	fake->start_handler = start;
	fake->end_handler = end;
}

static void XMLCALL
fake_set_text_handler(void *context, void *parser, XML_CharacterDataHandler handler) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->text_handler_count++;
	fake->text_handler = handler;
}

static void XMLCALL
fake_set_xml_decl_handler(void *context, void *parser, XML_XmlDeclHandler handler) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->xml_decl_handler_count++;
	fake->xml_decl_handler = handler;
}

static void XMLCALL
fake_set_not_standalone_handler(void *context, void *parser, XML_NotStandaloneHandler handler) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->not_standalone_handler_count++;
	fake->not_standalone_handler = handler;
}

static enum XML_Status XMLCALL
fake_parse(void *context, void *parser, const char *s, int len, int isFinal) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->parse_count++;
	fake->last_len = len;
	fake->last_is_final = isFinal;
	if (len > 0 && len < (int)sizeof(fake->last_input)) {
		memcpy(fake->last_input, s, (size_t)len);
		fake->last_input[len] = '\0';
	}
	return XML_STATUS_OK;
}

static enum XML_Error XMLCALL
fake_error_code(void *context, void *parser) {
	(void)context;
	(void)parser;
	return XML_ERROR_NONE;
}

static XML_Size XMLCALL
fake_line(void *context, void *parser) {
	(void)context;
	(void)parser;
	return 12;
}

static XML_Size XMLCALL
fake_column(void *context, void *parser) {
	(void)context;
	(void)parser;
	return 34;
}

static XML_Index XMLCALL
fake_byte_index(void *context, void *parser) {
	(void)context;
	(void)parser;
	return 56;
}

static int XMLCALL
fake_byte_count(void *context, void *parser) {
	(void)context;
	(void)parser;
	return 7;
}

static XML_Bool XMLCALL
fake_set_hash_salt(void *context, void *parser, unsigned long hash_salt) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->hash_salt_count++;
	fake->last_hash_salt = hash_salt;
	return XML_TRUE;
}

static XML_Bool XMLCALL
fake_set_hash_salt_16_bytes(void *context, void *parser, const uint8_t entropy[16]) {
	FakeParser *fake = (FakeParser *)context;
	(void)parser;
	fake->hash_salt_16_count++;
	memcpy(fake->last_hash_salt_16, entropy, sizeof(fake->last_hash_salt_16));
	return XML_TRUE;
}

static void XMLCALL
fake_parsing_status(void *context, void *parser, XML_ParsingStatus *status) {
	(void)context;
	(void)parser;
	status->parsing = XML_FINISHED;
	status->finalBuffer = XML_TRUE;
}

static void XMLCALL
start_callback(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)name;
	(void)atts;
}

static void XMLCALL
end_callback(void *userData, const XML_Char *name) {
	(void)userData;
	(void)name;
}

static void XMLCALL
text_callback(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	(void)len;
}

static void XMLCALL
xml_decl_callback(void *userData, const XML_Char *version, const XML_Char *encoding, int standalone) {
	(void)userData;
	(void)version;
	(void)encoding;
	(void)standalone;
}

static int XMLCALL
not_standalone_callback(void *userData) {
	(void)userData;
	return XML_STATUS_OK;
}

static int
check(int condition, const char *label) {
	if (!condition) {
		fprintf(stderr, "FAIL: %s\n", label);
		return 0;
	}
	return 1;
}

int
main(void) {
	int marker = 0x454946;
	XML_Parser parser;
	enum XML_Status status;
	XML_ParsingStatus parsing_status;
	XPACT_EiffelBridge bridge;
	const uint8_t entropy[16] = {
		'0', '1', '2', '3', '4', '5', '6', '7',
		'8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
	};

	memset(&fake_parser, 0, sizeof(fake_parser));
	memset(&bridge, 0, sizeof(bridge));
	bridge.abi_version = XPACT_EIFFEL_BRIDGE_ABI_VERSION;
	bridge.size = sizeof(bridge);
	bridge.context = &fake_parser;
	bridge.parser_create = fake_create;
	bridge.parser_reset = fake_reset;
	bridge.parser_free = fake_free;
	bridge.set_native_parser_handle = fake_set_native_parser_handle;
	bridge.set_encoding = fake_set_encoding;
	bridge.set_external_entity_context = fake_set_external_entity_context;
	bridge.set_external_entity_parameter_context = fake_set_external_entity_parameter_context;
	bridge.set_param_entity_parsing = fake_set_param_entity_parsing;
	bridge.set_foreign_dtd = fake_set_foreign_dtd;
	bridge.set_user_data = fake_set_user_data;
	bridge.set_element_handler = fake_set_element_handler;
	bridge.set_character_data_handler = fake_set_text_handler;
	bridge.set_xml_decl_handler = fake_set_xml_decl_handler;
	bridge.set_not_standalone_handler = fake_set_not_standalone_handler;
	bridge.set_hash_salt = fake_set_hash_salt;
	bridge.set_hash_salt_16_bytes = fake_set_hash_salt_16_bytes;
	bridge.parse = fake_parse;
	bridge.get_error_code = fake_error_code;
	bridge.get_current_line_number = fake_line;
	bridge.get_current_column_number = fake_column;
	bridge.get_current_byte_index = fake_byte_index;
	bridge.get_current_byte_count = fake_byte_count;
	bridge.get_parsing_status = fake_parsing_status;

	if (!check(XPACT_SetEiffelBridge(&bridge) == XML_TRUE, "bridge registered")) return 1;
	parser = XML_ParserCreate("UTF-8");
	if (!check(parser != NULL, "parser created through bridge")) return 1;
	if (!check(fake_parser.create_count == 1, "bridge create called")) return 1;
	if (!check(fake_parser.set_native_handle_count == 1, "native parser handle forwarded")) return 1;
	if (!check(fake_parser.native_handle == parser, "native parser handle value forwarded")) return 1;

	if (!check(XML_SetEncoding(parser, "utf-8") == XML_STATUS_OK, "encoding forwarded")) return 1;
	if (!check(fake_parser.set_encoding_count == 1, "bridge set encoding called")) return 1;
	if (!check(strcmp(fake_parser.last_encoding, "utf-8") == 0, "encoding value forwarded")) return 1;

	if (!check(XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS) == XML_TRUE, "param entity parsing forwarded")) return 1;
	if (!check(fake_parser.set_param_entity_parsing_count == 1, "bridge param entity parsing called")) return 1;
	if (!check(fake_parser.last_param_entity_parsing == XML_PARAM_ENTITY_PARSING_ALWAYS, "param entity parsing value forwarded")) return 1;

	if (!check(XML_UseForeignDTD(parser, XML_TRUE) == XML_ERROR_NONE, "foreign DTD setting forwarded")) return 1;
	if (!check(fake_parser.set_foreign_dtd_count == 1, "bridge foreign DTD called")) return 1;
	if (!check(fake_parser.last_use_foreign_dtd == XML_TRUE, "foreign DTD value forwarded")) return 1;

	XML_SetUserData(parser, &marker);
	if (!check(fake_parser.user_data_count == 1, "user data forwarded")) return 1;
	if (!check(fake_parser.user_data == &marker, "user data pointer forwarded")) return 1;

	XML_UseParserAsHandlerArg(parser);
	if (!check(fake_parser.user_data_count == 2, "parser-as-handler arg forwarded")) return 1;
	if (!check(fake_parser.user_data == parser, "parser-as-handler arg value forwarded")) return 1;
	XML_SetUserData(parser, &marker);
	if (!check(fake_parser.user_data_count == 3, "user data preserves parser handler arg")) return 1;
	if (!check(fake_parser.user_data == parser, "parser handler arg survives user data update")) return 1;

	XML_SetElementHandler(parser, start_callback, end_callback);
	if (!check(fake_parser.element_handler_count == 1, "element handlers forwarded")) return 1;
	if (!check(fake_parser.start_handler == start_callback, "start handler forwarded")) return 1;
	if (!check(fake_parser.end_handler == end_callback, "end handler forwarded")) return 1;

	XML_SetCharacterDataHandler(parser, text_callback);
	if (!check(fake_parser.text_handler_count == 1, "text handler forwarded")) return 1;
	if (!check(fake_parser.text_handler == text_callback, "text callback forwarded")) return 1;

	XML_SetXmlDeclHandler(parser, xml_decl_callback);
	if (!check(fake_parser.xml_decl_handler_count == 1, "XML declaration handler forwarded")) return 1;
	if (!check(fake_parser.xml_decl_handler == xml_decl_callback, "XML declaration callback forwarded")) return 1;

	XML_SetNotStandaloneHandler(parser, not_standalone_callback);
	if (!check(fake_parser.not_standalone_handler_count == 1, "not-standalone handler forwarded")) return 1;
	if (!check(fake_parser.not_standalone_handler == not_standalone_callback, "not-standalone callback forwarded")) return 1;

	if (!check(XML_SetHashSalt(parser, 0x12345678UL) == XML_TRUE, "hash salt forwarded")) return 1;
	if (!check(fake_parser.hash_salt_count == 1, "bridge hash salt called")) return 1;
	if (!check(fake_parser.last_hash_salt == 0x12345678UL, "hash salt value forwarded")) return 1;
	if (!check(XML_SetHashSalt16Bytes(parser, entropy) == XML_TRUE, "hash salt 16 forwarded")) return 1;
	if (!check(fake_parser.hash_salt_16_count == 1, "bridge hash salt 16 called")) return 1;
	if (!check(memcmp(fake_parser.last_hash_salt_16, entropy, sizeof(entropy)) == 0, "hash salt 16 bytes forwarded")) return 1;

	status = XML_Parse(parser, "<root/>", 7, XML_TRUE);
	if (!check(status == XML_STATUS_OK, "parse forwarded to bridge")) return 1;
	if (!check(fake_parser.parse_count == 1, "bridge parse called")) return 1;
	if (!check(fake_parser.last_len == 7, "parse length forwarded")) return 1;
	if (!check(fake_parser.last_is_final == XML_TRUE, "parse final flag forwarded")) return 1;
	if (!check(strcmp(fake_parser.last_input, "<root/>") == 0, "parse bytes forwarded")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_NONE, "error code delegated")) return 1;
	if (!check(XML_GetCurrentLineNumber(parser) == 12, "line delegated")) return 1;
	if (!check(XML_GetCurrentColumnNumber(parser) == 34, "column delegated")) return 1;
	if (!check(XML_GetCurrentByteIndex(parser) == 56, "byte index delegated")) return 1;
	if (!check(XML_GetCurrentByteCount(parser) == 7, "byte count delegated")) return 1;

	XML_GetParsingStatus(parser, &parsing_status);
	if (!check(parsing_status.parsing == XML_FINISHED, "status delegated")) return 1;
	if (!check(parsing_status.finalBuffer == XML_TRUE, "final buffer delegated")) return 1;

	{
		XML_Parser child = XML_ExternalEntityParserCreate(parser, "entity-context", "utf-8");
		if (!check(child != NULL, "external entity parser created through bridge")) return 1;
		if (!check(fake_parser.create_count == 2, "bridge create called for external parser")) return 1;
		if (!check(fake_parser.set_external_entity_context_count == 1, "external entity context forwarded")) return 1;
		if (!check(strcmp(fake_parser.last_external_entity_context, "entity-context") == 0, "external entity context value forwarded")) return 1;
		if (!check(fake_parser.set_external_entity_parameter_context_count == 1, "external entity parameter context forwarded")) return 1;
		if (!check(fake_parser.last_external_entity_is_parameter == XML_FALSE, "external entity parameter context defaults false")) return 1;
		if (!check(fake_parser.not_standalone_handler_count == 2, "not-standalone handler inherited by external parser")) return 1;
		XML_ParserFree(child);
		if (!check(fake_parser.free_count == 1, "external entity parser free delegated")) return 1;
	}

	if (!check(XML_ParserReset(parser, NULL) == XML_TRUE, "reset delegated")) return 1;
	if (!check(fake_parser.reset_count == 1, "bridge reset called")) return 1;
	if (!check(fake_parser.set_native_handle_count == 3, "native parser handle forwarded after reset")) return 1;

	XML_ParserFree(parser);
	if (!check(fake_parser.free_count == 2, "bridge free called")) return 1;
	XPACT_ClearEiffelBridge();

	puts("xpact bridge ABI smoke: ok");
	return 0;
}
