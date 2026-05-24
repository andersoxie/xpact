#if defined(_WIN32) && defined(XPACT_BUILDING_DLL)
#define XMLIMPORT __declspec(dllexport)
#elif defined(XPACT_BUILDING_DLL)
#define XMLIMPORT __attribute__((visibility("default")))
#endif

#include "../include/xpact.h"
#include "xpact_eiffel_bridge.h"

#include <stdlib.h>
#include <string.h>

struct XML_ParserStruct {
	void *userData;
	void *eiffelParser;
	const XPACT_EiffelBridge *bridge;
	XML_Memory_Handling_Suite memory;
	XML_Bool hasCustomMemory;
	XML_Char *base;
	char *buffer;
	int bufferCapacity;
	enum XML_Error errorCode;
	enum XML_Parsing parsing;
	XML_Bool finalBuffer;
	XML_StartElementHandler startElementHandler;
	XML_EndElementHandler endElementHandler;
	XML_CharacterDataHandler characterDataHandler;
	XML_ProcessingInstructionHandler processingInstructionHandler;
	XML_CommentHandler commentHandler;
	XML_StartCdataSectionHandler startCdataSectionHandler;
	XML_EndCdataSectionHandler endCdataSectionHandler;
	XML_DefaultHandler defaultHandler;
	XML_StartDoctypeDeclHandler startDoctypeDeclHandler;
	XML_EndDoctypeDeclHandler endDoctypeDeclHandler;
	XML_AttlistDeclHandler attlistDeclHandler;
	XML_ExternalEntityRefHandler externalEntityRefHandler;
	void *externalEntityRefArg;
};

static const XPACT_EiffelBridge *xp_bridge;

static void *xp_malloc(XML_Parser parser, size_t size) {
	if (parser != NULL && parser->hasCustomMemory && parser->memory.malloc_fcn != NULL) {
		return parser->memory.malloc_fcn(size);
	}
	return malloc(size);
}

static void *xp_realloc(XML_Parser parser, void *ptr, size_t size) {
	if (parser != NULL && parser->hasCustomMemory && parser->memory.realloc_fcn != NULL) {
		return parser->memory.realloc_fcn(ptr, size);
	}
	return realloc(ptr, size);
}

static void xp_free(XML_Parser parser, void *ptr) {
	if (ptr == NULL) {
		return;
	}
	if (parser != NULL && parser->hasCustomMemory && parser->memory.free_fcn != NULL) {
		parser->memory.free_fcn(ptr);
	} else {
		free(ptr);
	}
}

static XML_Char *xp_strdup(XML_Parser parser, const XML_Char *text) {
	size_t bytes;
	XML_Char *copy;
	if (text == NULL) {
		return NULL;
	}
	bytes = (strlen((const char *)text) + 1u) * sizeof(XML_Char);
	copy = (XML_Char *)xp_malloc(parser, bytes);
	if (copy != NULL) {
		memcpy(copy, text, bytes);
	}
	return copy;
}

static void xp_set_error(XML_Parser parser, enum XML_Error code) {
	if (parser != NULL) {
		parser->errorCode = code;
	}
}

static XML_Bool xp_has_valid_bridge(const XPACT_EiffelBridge *bridge) {
	return bridge != NULL
		&& bridge->abi_version == XPACT_EIFFEL_BRIDGE_ABI_VERSION
		&& bridge->size >= sizeof(XPACT_EiffelBridge);
}

XML_Bool XMLCALL
XPACT_SetEiffelBridge(const XPACT_EiffelBridge *bridge) {
	if (!xp_has_valid_bridge(bridge)) {
		return XML_FALSE;
	}
	xp_bridge = bridge;
	return XML_TRUE;
}

void XMLCALL
XPACT_ClearEiffelBridge(void) {
	xp_bridge = NULL;
}

XML_Parser XMLCALL
XML_ParserCreate(const XML_Char *encoding) {
	return XML_ParserCreate_MM(encoding, NULL, NULL);
}

XML_Parser XMLCALL
XML_ParserCreateNS(const XML_Char *encoding, XML_Char namespaceSeparator) {
	return XML_ParserCreate_MM(encoding, NULL, &namespaceSeparator);
}

XML_Parser XMLCALL
XML_ParserCreate_MM(
	const XML_Char *encoding,
	const XML_Memory_Handling_Suite *memsuite,
	const XML_Char *namespaceSeparator
) {
	XML_Parser parser;
	XML_Memory_Handling_Suite localMemory;

	if (memsuite != NULL) {
		if (memsuite->malloc_fcn == NULL || memsuite->realloc_fcn == NULL || memsuite->free_fcn == NULL) {
			return NULL;
		}
		localMemory = *memsuite;
		parser = (XML_Parser)localMemory.malloc_fcn(sizeof(struct XML_ParserStruct));
	} else {
		memset(&localMemory, 0, sizeof(localMemory));
		parser = (XML_Parser)malloc(sizeof(struct XML_ParserStruct));
	}
	if (parser == NULL) {
		return NULL;
	}
	memset(parser, 0, sizeof(struct XML_ParserStruct));
	parser->memory = localMemory;
	parser->hasCustomMemory = memsuite != NULL ? XML_TRUE : XML_FALSE;
	parser->errorCode = XML_ERROR_NONE;
	parser->parsing = XML_INITIALIZED;
	parser->bridge = xp_bridge;

	if (parser->bridge != NULL && parser->bridge->parser_create != NULL) {
		parser->eiffelParser = parser->bridge->parser_create(
			parser->bridge->context,
			encoding,
			memsuite,
			namespaceSeparator
		);
		if (parser->eiffelParser == NULL) {
			xp_free(parser, parser);
			return NULL;
		}
	} else {
		parser->errorCode = XML_ERROR_NOT_STARTED;
	}
	return parser;
}

XML_Bool XMLCALL
XML_ParserReset(XML_Parser parser, const XML_Char *encoding) {
	if (parser == NULL) {
		return XML_FALSE;
	}
	parser->errorCode = XML_ERROR_NONE;
	parser->parsing = XML_INITIALIZED;
	parser->finalBuffer = XML_FALSE;
	if (parser->bridge != NULL && parser->bridge->parser_reset != NULL && parser->eiffelParser != NULL) {
		return parser->bridge->parser_reset(parser->bridge->context, parser->eiffelParser, encoding);
	}
	parser->errorCode = XML_ERROR_NOT_STARTED;
	return XML_FALSE;
}

void XMLCALL
XML_ParserFree(XML_Parser parser) {
	if (parser == NULL) {
		return;
	}
	if (parser->bridge != NULL && parser->bridge->parser_free != NULL && parser->eiffelParser != NULL) {
		parser->bridge->parser_free(parser->bridge->context, parser->eiffelParser);
	}
	xp_free(parser, parser->base);
	xp_free(parser, parser->buffer);
	xp_free(parser, parser);
}

void XMLCALL
XML_SetUserData(XML_Parser parser, void *userData) {
	if (parser == NULL) {
		return;
	}
	parser->userData = userData;
	if (parser->bridge != NULL && parser->bridge->set_user_data != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_user_data(parser->bridge->context, parser->eiffelParser, userData);
	}
}

void XMLCALL
XML_SetElementHandler(XML_Parser parser, XML_StartElementHandler start, XML_EndElementHandler end) {
	if (parser == NULL) {
		return;
	}
	parser->startElementHandler = start;
	parser->endElementHandler = end;
	if (parser->bridge != NULL && parser->bridge->set_element_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_element_handler(parser->bridge->context, parser->eiffelParser, start, end);
	}
}

void XMLCALL
XML_SetStartElementHandler(XML_Parser parser, XML_StartElementHandler handler) {
	if (parser == NULL) {
		return;
	}
	XML_SetElementHandler(parser, handler, parser->endElementHandler);
}

void XMLCALL
XML_SetEndElementHandler(XML_Parser parser, XML_EndElementHandler handler) {
	if (parser == NULL) {
		return;
	}
	XML_SetElementHandler(parser, parser->startElementHandler, handler);
}

void XMLCALL
XML_SetCharacterDataHandler(XML_Parser parser, XML_CharacterDataHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->characterDataHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_character_data_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_character_data_handler(parser->bridge->context, parser->eiffelParser, handler);
	}
}

void XMLCALL
XML_SetProcessingInstructionHandler(XML_Parser parser, XML_ProcessingInstructionHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->processingInstructionHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_processing_instruction_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_processing_instruction_handler(parser->bridge->context, parser->eiffelParser, handler);
	}
}

void XMLCALL
XML_SetCommentHandler(XML_Parser parser, XML_CommentHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->commentHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_comment_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_comment_handler(parser->bridge->context, parser->eiffelParser, handler);
	}
}

void XMLCALL
XML_SetCdataSectionHandler(
	XML_Parser parser,
	XML_StartCdataSectionHandler start,
	XML_EndCdataSectionHandler end
) {
	if (parser == NULL) {
		return;
	}
	parser->startCdataSectionHandler = start;
	parser->endCdataSectionHandler = end;
	if (parser->bridge != NULL && parser->bridge->set_cdata_section_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_cdata_section_handler(parser->bridge->context, parser->eiffelParser, start, end);
	}
}

void XMLCALL
XML_SetStartCdataSectionHandler(XML_Parser parser, XML_StartCdataSectionHandler start) {
	if (parser == NULL) {
		return;
	}
	XML_SetCdataSectionHandler(parser, start, parser->endCdataSectionHandler);
}

void XMLCALL
XML_SetEndCdataSectionHandler(XML_Parser parser, XML_EndCdataSectionHandler end) {
	if (parser == NULL) {
		return;
	}
	XML_SetCdataSectionHandler(parser, parser->startCdataSectionHandler, end);
}

void XMLCALL
XML_SetDefaultHandler(XML_Parser parser, XML_DefaultHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->defaultHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_default_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_default_handler(parser->bridge->context, parser->eiffelParser, handler, XML_FALSE);
	}
}

void XMLCALL
XML_SetDefaultHandlerExpand(XML_Parser parser, XML_DefaultHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->defaultHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_default_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_default_handler(parser->bridge->context, parser->eiffelParser, handler, XML_TRUE);
	}
}

void XMLCALL
XML_SetDoctypeDeclHandler(
	XML_Parser parser,
	XML_StartDoctypeDeclHandler start,
	XML_EndDoctypeDeclHandler end
) {
	if (parser == NULL) {
		return;
	}
	parser->startDoctypeDeclHandler = start;
	parser->endDoctypeDeclHandler = end;
	if (parser->bridge != NULL && parser->bridge->set_doctype_decl_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_doctype_decl_handler(parser->bridge->context, parser->eiffelParser, start, end);
	}
}

void XMLCALL
XML_SetStartDoctypeDeclHandler(XML_Parser parser, XML_StartDoctypeDeclHandler start) {
	if (parser == NULL) {
		return;
	}
	XML_SetDoctypeDeclHandler(parser, start, parser->endDoctypeDeclHandler);
}

void XMLCALL
XML_SetEndDoctypeDeclHandler(XML_Parser parser, XML_EndDoctypeDeclHandler end) {
	if (parser == NULL) {
		return;
	}
	XML_SetDoctypeDeclHandler(parser, parser->startDoctypeDeclHandler, end);
}

void XMLCALL
XML_SetAttlistDeclHandler(XML_Parser parser, XML_AttlistDeclHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->attlistDeclHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_attlist_decl_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_attlist_decl_handler(parser->bridge->context, parser->eiffelParser, handler);
	}
}

void XMLCALL
XML_SetExternalEntityRefHandler(XML_Parser parser, XML_ExternalEntityRefHandler handler) {
	if (parser == NULL) {
		return;
	}
	parser->externalEntityRefHandler = handler;
	if (parser->bridge != NULL && parser->bridge->set_external_entity_ref_handler != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_external_entity_ref_handler(parser->bridge->context, parser->eiffelParser, handler);
	}
}

void XMLCALL
XML_SetExternalEntityRefHandlerArg(XML_Parser parser, void *arg) {
	if (parser == NULL) {
		return;
	}
	parser->externalEntityRefArg = arg;
	if (parser->bridge != NULL && parser->bridge->set_external_entity_ref_handler_arg != NULL && parser->eiffelParser != NULL) {
		parser->bridge->set_external_entity_ref_handler_arg(parser->bridge->context, parser->eiffelParser, arg);
	}
}

#define XPACT_UNUSED_HANDLER_SETTER(name, type) \
	void XMLCALL name(XML_Parser parser, type handler) { (void)parser; (void)handler; }

XPACT_UNUSED_HANDLER_SETTER(XML_SetElementDeclHandler, XML_ElementDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetXmlDeclHandler, XML_XmlDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetEntityDeclHandler, XML_EntityDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetUnparsedEntityDeclHandler, XML_UnparsedEntityDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetNotationDeclHandler, XML_NotationDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetStartNamespaceDeclHandler, XML_StartNamespaceDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetEndNamespaceDeclHandler, XML_EndNamespaceDeclHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetNotStandaloneHandler, XML_NotStandaloneHandler)
XPACT_UNUSED_HANDLER_SETTER(XML_SetSkippedEntityHandler, XML_SkippedEntityHandler)

void XMLCALL
XML_SetNamespaceDeclHandler(
	XML_Parser parser,
	XML_StartNamespaceDeclHandler start,
	XML_EndNamespaceDeclHandler end
) {
	(void)parser;
	(void)start;
	(void)end;
}

void XMLCALL
XML_SetUnknownEncodingHandler(XML_Parser parser, XML_UnknownEncodingHandler handler, void *encodingHandlerData) {
	(void)parser;
	(void)handler;
	(void)encodingHandlerData;
}

void XMLCALL
XML_DefaultCurrent(XML_Parser parser) {
	(void)parser;
}

void XMLCALL
XML_SetReturnNSTriplet(XML_Parser parser, int do_nst) {
	(void)parser;
	(void)do_nst;
}

enum XML_Status XMLCALL
XML_SetEncoding(XML_Parser parser, const XML_Char *encoding) {
	(void)encoding;
	xp_set_error(parser, XML_ERROR_NOT_STARTED);
	return XML_STATUS_ERROR;
}

void XMLCALL
XML_UseParserAsHandlerArg(XML_Parser parser) {
	XML_SetUserData(parser, parser);
}

enum XML_Error XMLCALL
XML_UseForeignDTD(XML_Parser parser, XML_Bool useDTD) {
	(void)useDTD;
	xp_set_error(parser, XML_ERROR_NOT_STARTED);
	return XML_ERROR_NOT_STARTED;
}

enum XML_Status XMLCALL
XML_SetBase(XML_Parser parser, const XML_Char *base) {
	XML_Char *copy;
	if (parser == NULL) {
		return XML_STATUS_ERROR;
	}
	copy = xp_strdup(parser, base);
	if (base != NULL && copy == NULL) {
		parser->errorCode = XML_ERROR_NO_MEMORY;
		return XML_STATUS_ERROR;
	}
	xp_free(parser, parser->base);
	parser->base = copy;
	return XML_STATUS_OK;
}

const XML_Char *XMLCALL
XML_GetBase(XML_Parser parser) {
	return parser != NULL ? parser->base : NULL;
}

int XMLCALL
XML_GetSpecifiedAttributeCount(XML_Parser parser) {
	(void)parser;
	return 0;
}

int XMLCALL
XML_GetIdAttributeIndex(XML_Parser parser) {
	(void)parser;
	return -1;
}

const XML_AttrInfo *XMLCALL
XML_GetAttributeInfo(XML_Parser parser) {
	(void)parser;
	return NULL;
}

enum XML_Status XMLCALL
XML_Parse(XML_Parser parser, const char *s, int len, int isFinal) {
	enum XML_Status status;
	if (parser == NULL || len < 0 || (s == NULL && len > 0)) {
		xp_set_error(parser, XML_ERROR_INVALID_ARGUMENT);
		return XML_STATUS_ERROR;
	}
	if (parser->bridge == NULL || parser->bridge->parse == NULL || parser->eiffelParser == NULL) {
		parser->errorCode = XML_ERROR_NOT_STARTED;
		parser->parsing = XML_FINISHED;
		parser->finalBuffer = isFinal ? XML_TRUE : XML_FALSE;
		return XML_STATUS_ERROR;
	}
	parser->parsing = XML_PARSING;
	status = parser->bridge->parse(parser->bridge->context, parser->eiffelParser, s, len, isFinal);
	parser->parsing = (status == XML_STATUS_SUSPENDED) ? XML_SUSPENDED : XML_FINISHED;
	parser->finalBuffer = isFinal ? XML_TRUE : XML_FALSE;
	return status;
}

void *XMLCALL
XML_GetBuffer(XML_Parser parser, int len) {
	char *resized;
	if (parser == NULL || len < 0) {
		xp_set_error(parser, XML_ERROR_INVALID_ARGUMENT);
		return NULL;
	}
	if (parser->bridge != NULL && parser->bridge->get_buffer != NULL && parser->eiffelParser != NULL) {
		return parser->bridge->get_buffer(parser->bridge->context, parser->eiffelParser, len);
	}
	if (len > parser->bufferCapacity) {
		resized = (char *)xp_realloc(parser, parser->buffer, (size_t)len);
		if (resized == NULL) {
			parser->errorCode = XML_ERROR_NO_MEMORY;
			return NULL;
		}
		parser->buffer = resized;
		parser->bufferCapacity = len;
	}
	return parser->buffer;
}

enum XML_Status XMLCALL
XML_ParseBuffer(XML_Parser parser, int len, int isFinal) {
	if (parser == NULL || len < 0) {
		xp_set_error(parser, XML_ERROR_INVALID_ARGUMENT);
		return XML_STATUS_ERROR;
	}
	if (parser->bridge != NULL && parser->bridge->parse_buffer != NULL && parser->eiffelParser != NULL) {
		return parser->bridge->parse_buffer(parser->bridge->context, parser->eiffelParser, len, isFinal);
	}
	return XML_Parse(parser, parser->buffer, len, isFinal);
}

enum XML_Status XMLCALL
XML_StopParser(XML_Parser parser, XML_Bool resumable) {
	(void)resumable;
	xp_set_error(parser, XML_ERROR_NOT_STARTED);
	return XML_STATUS_ERROR;
}

enum XML_Status XMLCALL
XML_ResumeParser(XML_Parser parser) {
	xp_set_error(parser, XML_ERROR_NOT_STARTED);
	return XML_STATUS_ERROR;
}

void XMLCALL
XML_GetParsingStatus(XML_Parser parser, XML_ParsingStatus *status) {
	if (status == NULL) {
		return;
	}
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_parsing_status != NULL
		&& parser->eiffelParser != NULL
	) {
		parser->bridge->get_parsing_status(parser->bridge->context, parser->eiffelParser, status);
		return;
	}
	status->parsing = parser != NULL ? parser->parsing : XML_INITIALIZED;
	status->finalBuffer = parser != NULL ? parser->finalBuffer : XML_FALSE;
}

XML_Parser XMLCALL
XML_ExternalEntityParserCreate(XML_Parser parser, const XML_Char *context, const XML_Char *encoding) {
	(void)context;
	(void)encoding;
	xp_set_error(parser, XML_ERROR_NOT_STARTED);
	return NULL;
}

int XMLCALL
XML_SetParamEntityParsing(XML_Parser parser, enum XML_ParamEntityParsing parsing) {
	(void)parser;
	(void)parsing;
	return 0;
}

int XMLCALL
XML_SetHashSalt(XML_Parser parser, unsigned long hash_salt) {
	(void)parser;
	(void)hash_salt;
	return 1;
}

XML_Bool XMLCALL
XML_SetHashSalt16Bytes(XML_Parser parser, const uint8_t entropy[16]) {
	(void)parser;
	(void)entropy;
	return XML_TRUE;
}

enum XML_Error XMLCALL
XML_GetErrorCode(XML_Parser parser) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_error_code != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_error_code(parser->bridge->context, parser->eiffelParser);
	}
	return parser != NULL ? parser->errorCode : XML_ERROR_INVALID_ARGUMENT;
}

XML_Size XMLCALL
XML_GetCurrentLineNumber(XML_Parser parser) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_current_line_number != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_current_line_number(parser->bridge->context, parser->eiffelParser);
	}
	return 1;
}

XML_Size XMLCALL
XML_GetCurrentColumnNumber(XML_Parser parser) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_current_column_number != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_current_column_number(parser->bridge->context, parser->eiffelParser);
	}
	return 0;
}

XML_Index XMLCALL
XML_GetCurrentByteIndex(XML_Parser parser) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_current_byte_index != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_current_byte_index(parser->bridge->context, parser->eiffelParser);
	}
	return -1;
}

int XMLCALL
XML_GetCurrentByteCount(XML_Parser parser) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_current_byte_count != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_current_byte_count(parser->bridge->context, parser->eiffelParser);
	}
	return 0;
}

const char *XMLCALL
XML_GetInputContext(XML_Parser parser, int *offset, int *size) {
	if (
		parser != NULL
		&& parser->bridge != NULL
		&& parser->bridge->get_input_context != NULL
		&& parser->eiffelParser != NULL
	) {
		return parser->bridge->get_input_context(parser->bridge->context, parser->eiffelParser, offset, size);
	}
	if (offset != NULL) {
		*offset = 0;
	}
	if (size != NULL) {
		*size = 0;
	}
	return NULL;
}

void XMLCALL
XML_FreeContentModel(XML_Parser parser, XML_Content *model) {
	xp_free(parser, model);
}

void *XMLCALL
XML_MemMalloc(XML_Parser parser, size_t size) {
	return xp_malloc(parser, size);
}

void *XMLCALL
XML_MemRealloc(XML_Parser parser, void *ptr, size_t size) {
	return xp_realloc(parser, ptr, size);
}

void XMLCALL
XML_MemFree(XML_Parser parser, void *ptr) {
	xp_free(parser, ptr);
}

const XML_LChar *XMLCALL
XML_ErrorString(enum XML_Error code) {
	static const XML_LChar *const messages[] = {
		"no error",
		"out of memory",
		"syntax error",
		"no element found",
		"not well-formed (invalid token)",
		"unclosed token",
		"partial character",
		"mismatched tag",
		"duplicate attribute",
		"junk after document element",
		"illegal parameter entity reference",
		"undefined entity",
		"recursive entity reference",
		"asynchronous entity",
		"reference to invalid character number",
		"reference to binary entity",
		"reference to external entity in attribute",
		"XML or text declaration not at start of entity",
		"unknown encoding",
		"encoding specified in XML declaration is incorrect",
		"unclosed CDATA section",
		"error in processing external entity reference",
		"document is not standalone",
		"unexpected parser state",
		"entity declared in parameter entity",
		"requested feature requires XML_DTD support",
		"cannot change setting after parsing has started",
		"unbound prefix",
		"must not undeclare prefix",
		"incomplete markup in parameter entity",
		"XML declaration not well-formed",
		"text declaration not well-formed",
		"illegal character in public id",
		"parser suspended",
		"parser not suspended",
		"parsing aborted",
		"parsing finished",
		"cannot suspend in external parameter entity",
		"reserved prefix (xml)",
		"reserved prefix (xmlns)",
		"reserved namespace URI",
		"invalid argument",
		"buffer allocation failed",
		"amplification limit breached",
		"Eiffel parser bridge is not installed"
	};
	if (code < XML_ERROR_NONE || code > XML_ERROR_NOT_STARTED) {
		return NULL;
	}
	return messages[(int)code];
}

const XML_LChar *XMLCALL
XML_ExpatVersion(void) {
	return "expat_2.8.1-xpact-eiffel-bridge";
}

XML_Expat_Version XMLCALL
XML_ExpatVersionInfo(void) {
	XML_Expat_Version version;
	version.major = XML_MAJOR_VERSION;
	version.minor = XML_MINOR_VERSION;
	version.micro = XML_MICRO_VERSION;
	return version;
}

const XML_Feature *XMLCALL
XML_GetFeatureList(void) {
	static const XML_Feature features[] = {
		{XML_FEATURE_SIZEOF_XML_CHAR, "sizeof(XML_Char)", sizeof(XML_Char)},
		{XML_FEATURE_SIZEOF_XML_LCHAR, "sizeof(XML_LChar)", sizeof(XML_LChar)},
		{XML_FEATURE_END, NULL, 0}
	};
	return features;
}

XML_Bool XMLCALL
XML_SetBillionLaughsAttackProtectionMaximumAmplification(
	XML_Parser parser,
	float maximumAmplificationFactor
) {
	(void)parser;
	(void)maximumAmplificationFactor;
	return XML_TRUE;
}

XML_Bool XMLCALL
XML_SetBillionLaughsAttackProtectionActivationThreshold(
	XML_Parser parser,
	unsigned long long activationThresholdBytes
) {
	(void)parser;
	(void)activationThresholdBytes;
	return XML_TRUE;
}

XML_Bool XMLCALL
XML_SetAllocTrackerMaximumAmplification(XML_Parser parser, float maximumAmplificationFactor) {
	(void)parser;
	(void)maximumAmplificationFactor;
	return XML_TRUE;
}

XML_Bool XMLCALL
XML_SetAllocTrackerActivationThreshold(XML_Parser parser, unsigned long long activationThresholdBytes) {
	(void)parser;
	(void)activationThresholdBytes;
	return XML_TRUE;
}

XML_Bool XMLCALL
XML_SetReparseDeferralEnabled(XML_Parser parser, XML_Bool enabled) {
	(void)parser;
	(void)enabled;
	return XML_TRUE;
}
