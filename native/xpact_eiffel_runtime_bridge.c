#include "xpact_eiffel_runtime_bridge.h"

#include <stdint.h>
#include <string.h>

typedef struct XPACT_EiffelRuntimeBridgeState {
	EIF_OBJECT installer;
	XPACT_EiffelParserCreateRoutine parser_create;
	XPACT_EiffelParserResetRoutine parser_reset;
	XPACT_EiffelParserFreeRoutine parser_free;
	XPACT_EiffelSetPointerRoutine set_native_parser_handle;
	XPACT_EiffelSetEncodingRoutine set_encoding;
	XPACT_EiffelSetPointerBooleanRoutine set_external_entity_context;
	XPACT_EiffelSetBooleanRoutine set_external_entity_parameter_context;
	XPACT_EiffelInheritParserContextRoutine inherit_external_entity_context;
	XPACT_EiffelSetIntegerBooleanRoutine set_param_entity_parsing;
	XPACT_EiffelSetBooleanRoutine set_foreign_dtd;
	XPACT_EiffelSetPointerRoutine set_user_data;
	XPACT_EiffelSetElementHandlerRoutine set_element_handler;
	XPACT_EiffelSetPointerRoutine set_character_data_handler;
	XPACT_EiffelSetPointerRoutine set_processing_instruction_handler;
	XPACT_EiffelSetPointerRoutine set_xml_decl_handler;
	XPACT_EiffelSetPointerRoutine set_comment_handler;
	XPACT_EiffelSetElementHandlerRoutine set_cdata_section_handler;
	XPACT_EiffelSetDefaultHandlerRoutine set_default_handler;
	XPACT_EiffelSetElementHandlerRoutine set_doctype_decl_handler;
	XPACT_EiffelSetPointerRoutine set_not_standalone_handler;
	XPACT_EiffelSetPointerRoutine set_element_decl_handler;
	XPACT_EiffelSetPointerRoutine set_notation_decl_handler;
	XPACT_EiffelSetPointerRoutine set_attlist_decl_handler;
	XPACT_EiffelSetPointerRoutine set_entity_decl_handler;
	XPACT_EiffelSetPointerRoutine set_unparsed_entity_decl_handler;
	XPACT_EiffelSetPointerRoutine set_external_entity_ref_handler;
	XPACT_EiffelSetPointerRoutine set_external_entity_ref_handler_arg;
	XPACT_EiffelSetPointerRoutine set_skipped_entity_handler;
	XPACT_EiffelParserCommandRoutine default_current;
	XPACT_EiffelSetHashSaltRoutine set_hash_salt;
	XPACT_EiffelSetPointerBooleanRoutine set_hash_salt_16_bytes;
	XPACT_EiffelParseRoutine parse;
	XPACT_EiffelGetBufferRoutine get_buffer;
	XPACT_EiffelParseBufferRoutine parse_buffer;
	XPACT_EiffelIntegerQueryRoutine get_error_code;
	XPACT_EiffelIntegerQueryRoutine get_current_line_number;
	XPACT_EiffelIntegerQueryRoutine get_current_column_number;
	XPACT_EiffelIntegerQueryRoutine get_current_byte_index;
	XPACT_EiffelIntegerQueryRoutine get_current_byte_count;
	XPACT_EiffelIntegerQueryRoutine get_specified_attribute_count;
	XPACT_EiffelIntegerQueryRoutine get_id_attribute_index;
	XPACT_EiffelInputContextRoutine get_input_context;
	XPACT_EiffelParsingStatusRoutine get_parsing_status;
	XPACT_EiffelBridge bridge;
} XPACT_EiffelRuntimeBridgeState;

static XPACT_EiffelRuntimeBridgeState xp_runtime_bridge;

static EIF_POINTER
xp_callback_pointer(uintptr_t callback) {
	return (EIF_POINTER)callback;
}

static EIF_REFERENCE
xp_installer_reference(XPACT_EiffelRuntimeBridgeState *state) {
	if (state == NULL || state->installer == NULL) {
		return NULL;
	}
	return eif_access(state->installer);
}

static XPACT_EiffelRuntimeBridgeState *
xp_runtime_state(void *context) {
	return (XPACT_EiffelRuntimeBridgeState *)context;
}

static void
xp_release_runtime_bridge(void) {
	if (xp_runtime_bridge.installer != NULL) {
		eif_wean(xp_runtime_bridge.installer);
	}
	memset(&xp_runtime_bridge, 0, sizeof(xp_runtime_bridge));
}

static void *XMLCALL
xp_rt_parser_create(
	void *context,
	const XML_Char *encoding,
	const XML_Memory_Handling_Suite *memsuite,
	const XML_Char *namespaceSeparator
) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->parser_create == NULL) {
		return NULL;
	}
	return (void *)state->parser_create(
		installer,
		(EIF_POINTER)encoding,
		(EIF_POINTER)memsuite,
		(EIF_POINTER)namespaceSeparator
	);
}

static XML_Bool XMLCALL
xp_rt_parser_reset(void *context, void *parser, const XML_Char *encoding) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->parser_reset == NULL) {
		return XML_FALSE;
	}
	return state->parser_reset(installer, (EIF_POINTER)parser, (EIF_POINTER)encoding) ? XML_TRUE : XML_FALSE;
}

static void XMLCALL
xp_rt_parser_free(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->parser_free != NULL) {
		state->parser_free(installer, (EIF_POINTER)parser);
	}
}

static void XMLCALL
xp_rt_set_native_parser_handle(void *context, void *parser, void *nativeParser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_native_parser_handle != NULL) {
		state->set_native_parser_handle(installer, (EIF_POINTER)parser, (EIF_POINTER)nativeParser);
	}
}

static enum XML_Status XMLCALL
xp_rt_set_encoding(void *context, void *parser, const XML_Char *encoding) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_encoding == NULL) {
		return XML_STATUS_ERROR;
	}
	return (enum XML_Status)state->set_encoding(installer, (EIF_POINTER)parser, (EIF_POINTER)encoding);
}

static XML_Bool XMLCALL
xp_rt_set_external_entity_context(void *context, void *parser, const XML_Char *entityContext) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_external_entity_context == NULL) {
		return XML_FALSE;
	}
	return state->set_external_entity_context(installer, (EIF_POINTER)parser, (EIF_POINTER)entityContext)
		? XML_TRUE
		: XML_FALSE;
}

static XML_Bool XMLCALL
xp_rt_set_external_entity_parameter_context(void *context, void *parser, XML_Bool isParameter) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_external_entity_parameter_context == NULL) {
		return XML_FALSE;
	}
	return state->set_external_entity_parameter_context(
		installer,
		(EIF_POINTER)parser,
		(EIF_BOOLEAN)(isParameter != XML_FALSE)
	) ? XML_TRUE : XML_FALSE;
}

static XML_Bool XMLCALL
xp_rt_inherit_external_entity_context(void *context, void *parser, void *parentParser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->inherit_external_entity_context == NULL) {
		return XML_FALSE;
	}
	return state->inherit_external_entity_context(
		installer,
		(EIF_POINTER)parser,
		(EIF_POINTER)parentParser
	) ? XML_TRUE : XML_FALSE;
}

static XML_Bool XMLCALL
xp_rt_set_param_entity_parsing(void *context, void *parser, enum XML_ParamEntityParsing parsing) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_param_entity_parsing == NULL) {
		return XML_FALSE;
	}
	return state->set_param_entity_parsing(installer, (EIF_POINTER)parser, (EIF_INTEGER)parsing)
		? XML_TRUE
		: XML_FALSE;
}

static XML_Bool XMLCALL
xp_rt_set_foreign_dtd(void *context, void *parser, XML_Bool useDTD) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_foreign_dtd == NULL) {
		return XML_FALSE;
	}
	return state->set_foreign_dtd(installer, (EIF_POINTER)parser, (EIF_BOOLEAN)(useDTD != XML_FALSE))
		? XML_TRUE
		: XML_FALSE;
}

static void XMLCALL
xp_rt_set_user_data(void *context, void *parser, void *userData) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_user_data != NULL) {
		state->set_user_data(installer, (EIF_POINTER)parser, (EIF_POINTER)userData);
	}
}

static void XMLCALL
xp_rt_set_element_handler(
	void *context,
	void *parser,
	XML_StartElementHandler start,
	XML_EndElementHandler end
) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_element_handler != NULL) {
		state->set_element_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)start),
			xp_callback_pointer((uintptr_t)end)
		);
	}
}

static void XMLCALL
xp_rt_set_character_data_handler(void *context, void *parser, XML_CharacterDataHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_character_data_handler != NULL) {
		state->set_character_data_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_processing_instruction_handler(
	void *context,
	void *parser,
	XML_ProcessingInstructionHandler handler
) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_processing_instruction_handler != NULL) {
		state->set_processing_instruction_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_xml_decl_handler(void *context, void *parser, XML_XmlDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_xml_decl_handler != NULL) {
		state->set_xml_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_comment_handler(void *context, void *parser, XML_CommentHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_comment_handler != NULL) {
		state->set_comment_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_cdata_section_handler(
	void *context,
	void *parser,
	XML_StartCdataSectionHandler start,
	XML_EndCdataSectionHandler end
) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_cdata_section_handler != NULL) {
		state->set_cdata_section_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)start),
			xp_callback_pointer((uintptr_t)end)
		);
	}
}

static void XMLCALL
xp_rt_set_default_handler(void *context, void *parser, XML_DefaultHandler handler, XML_Bool expand) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_default_handler != NULL) {
		state->set_default_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler),
			(EIF_BOOLEAN)(expand != XML_FALSE)
		);
	}
}

static void XMLCALL
xp_rt_set_doctype_decl_handler(
	void *context,
	void *parser,
	XML_StartDoctypeDeclHandler start,
	XML_EndDoctypeDeclHandler end
) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_doctype_decl_handler != NULL) {
		state->set_doctype_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)start),
			xp_callback_pointer((uintptr_t)end)
		);
	}
}

static void XMLCALL
xp_rt_set_not_standalone_handler(void *context, void *parser, XML_NotStandaloneHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_not_standalone_handler != NULL) {
		state->set_not_standalone_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_element_decl_handler(void *context, void *parser, XML_ElementDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_element_decl_handler != NULL) {
		state->set_element_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_notation_decl_handler(void *context, void *parser, XML_NotationDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_notation_decl_handler != NULL) {
		state->set_notation_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_attlist_decl_handler(void *context, void *parser, XML_AttlistDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_attlist_decl_handler != NULL) {
		state->set_attlist_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_entity_decl_handler(void *context, void *parser, XML_EntityDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_entity_decl_handler != NULL) {
		state->set_entity_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_unparsed_entity_decl_handler(void *context, void *parser, XML_UnparsedEntityDeclHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_unparsed_entity_decl_handler != NULL) {
		state->set_unparsed_entity_decl_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_external_entity_ref_handler(void *context, void *parser, XML_ExternalEntityRefHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_external_entity_ref_handler != NULL) {
		state->set_external_entity_ref_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_set_external_entity_ref_handler_arg(void *context, void *parser, void *arg) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_external_entity_ref_handler_arg != NULL) {
		state->set_external_entity_ref_handler_arg(installer, (EIF_POINTER)parser, (EIF_POINTER)arg);
	}
}

static void XMLCALL
xp_rt_set_skipped_entity_handler(void *context, void *parser, XML_SkippedEntityHandler handler) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->set_skipped_entity_handler != NULL) {
		state->set_skipped_entity_handler(
			installer,
			(EIF_POINTER)parser,
			xp_callback_pointer((uintptr_t)handler)
		);
	}
}

static void XMLCALL
xp_rt_default_current(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer != NULL && state->default_current != NULL) {
		state->default_current(installer, (EIF_POINTER)parser);
	}
}

static enum XML_Status XMLCALL
xp_rt_parse(void *context, void *parser, const char *s, int len, int isFinal) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->parse == NULL) {
		return XML_STATUS_ERROR;
	}
	return (enum XML_Status)state->parse(
		installer,
		(EIF_POINTER)parser,
		(EIF_POINTER)s,
		(EIF_INTEGER)len,
		(EIF_BOOLEAN)(isFinal != 0)
	);
}

static void *XMLCALL
xp_rt_get_buffer(void *context, void *parser, int len) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_buffer == NULL) {
		return NULL;
	}
	return (void *)state->get_buffer(installer, (EIF_POINTER)parser, (EIF_INTEGER)len);
}

static enum XML_Status XMLCALL
xp_rt_parse_buffer(void *context, void *parser, int len, int isFinal) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->parse_buffer == NULL) {
		return XML_STATUS_ERROR;
	}
	return (enum XML_Status)state->parse_buffer(
		installer,
		(EIF_POINTER)parser,
		(EIF_INTEGER)len,
		(EIF_BOOLEAN)(isFinal != 0)
	);
}

static enum XML_Error XMLCALL
xp_rt_get_error_code(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_error_code == NULL) {
		return XML_ERROR_INVALID_ARGUMENT;
	}
	return (enum XML_Error)state->get_error_code(installer, (EIF_POINTER)parser);
}

static XML_Size XMLCALL
xp_rt_get_current_line_number(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_current_line_number == NULL) {
		return 1;
	}
	return (XML_Size)state->get_current_line_number(installer, (EIF_POINTER)parser);
}

static XML_Size XMLCALL
xp_rt_get_current_column_number(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_current_column_number == NULL) {
		return 0;
	}
	return (XML_Size)state->get_current_column_number(installer, (EIF_POINTER)parser);
}

static XML_Index XMLCALL
xp_rt_get_current_byte_index(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_current_byte_index == NULL) {
		return -1;
	}
	return (XML_Index)state->get_current_byte_index(installer, (EIF_POINTER)parser);
}

static int XMLCALL
xp_rt_get_current_byte_count(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_current_byte_count == NULL) {
		return 0;
	}
	return (int)state->get_current_byte_count(installer, (EIF_POINTER)parser);
}

static int XMLCALL
xp_rt_get_specified_attribute_count(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_specified_attribute_count == NULL) {
		return 0;
	}
	return (int)state->get_specified_attribute_count(installer, (EIF_POINTER)parser);
}

static int XMLCALL
xp_rt_get_id_attribute_index(void *context, void *parser) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_id_attribute_index == NULL) {
		return -1;
	}
	return (int)state->get_id_attribute_index(installer, (EIF_POINTER)parser);
}

static const char *XMLCALL
xp_rt_get_input_context(void *context, void *parser, int *offset, int *size) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->get_input_context == NULL) {
		if (offset != NULL) {
			*offset = 0;
		}
		if (size != NULL) {
			*size = 0;
		}
		return NULL;
	}
	return (const char *)state->get_input_context(
		installer,
		(EIF_POINTER)parser,
		(EIF_POINTER)offset,
		(EIF_POINTER)size
	);
}

static void XMLCALL
xp_rt_get_parsing_status(void *context, void *parser, XML_ParsingStatus *status) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (status == NULL) {
		return;
	}
	if (installer != NULL && state->get_parsing_status != NULL) {
		state->get_parsing_status(installer, (EIF_POINTER)parser, (EIF_POINTER)status);
	} else {
		status->parsing = XML_INITIALIZED;
		status->finalBuffer = XML_FALSE;
	}
}

static XML_Bool XMLCALL
xp_rt_set_hash_salt(void *context, void *parser, unsigned long hash_salt) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
	EIF_REFERENCE installer = xp_installer_reference(state);
	if (installer == NULL || state->set_hash_salt == NULL) {
		return XML_FALSE;
	}
	return state->set_hash_salt(installer, (EIF_POINTER)parser, (EIF_INTEGER_64)hash_salt)
		? XML_TRUE
		: XML_FALSE;
}

static XML_Bool XMLCALL
xp_rt_set_hash_salt_16_bytes(void *context, void *parser, const uint8_t entropy[16]) {
	XPACT_EiffelRuntimeBridgeState *state = xp_runtime_state(context);
    EIF_REFERENCE installer;
	installer = xp_installer_reference(state);
	if (installer == NULL || state->set_hash_salt_16_bytes == NULL || entropy == NULL) {
		return XML_FALSE;
	}
	return state->set_hash_salt_16_bytes(installer, (EIF_POINTER)parser, (EIF_POINTER)entropy)
		? XML_TRUE
		: XML_FALSE;
}

static XML_Bool
xp_has_required_eiffel_routines(const XPACT_EiffelRuntimeBridgeState *state) {
	return state->installer != NULL
		&& state->parser_create != NULL
		&& state->parser_reset != NULL
		&& state->parser_free != NULL
		&& state->set_native_parser_handle != NULL
		&& state->set_encoding != NULL
		&& state->set_external_entity_context != NULL
		&& state->set_external_entity_parameter_context != NULL
		&& state->inherit_external_entity_context != NULL
		&& state->set_param_entity_parsing != NULL
		&& state->set_foreign_dtd != NULL
		&& state->set_user_data != NULL
		&& state->set_element_handler != NULL
		&& state->set_character_data_handler != NULL
		&& state->set_xml_decl_handler != NULL
		&& state->set_not_standalone_handler != NULL
		&& state->parse != NULL
		&& state->get_buffer != NULL
		&& state->parse_buffer != NULL
		&& state->get_error_code != NULL
		&& state->get_specified_attribute_count != NULL
		&& state->get_id_attribute_index != NULL
		&& state->get_input_context != NULL
		&& state->default_current != NULL
		&& state->set_hash_salt != NULL
		&& state->set_hash_salt_16_bytes != NULL
		&& state->get_parsing_status != NULL;
}

static void
xp_fill_bridge_table(XPACT_EiffelRuntimeBridgeState *state) {
	XPACT_EiffelBridge *bridge = &state->bridge;
	memset(bridge, 0, sizeof(*bridge));
	bridge->abi_version = XPACT_EIFFEL_BRIDGE_ABI_VERSION;
	bridge->size = sizeof(*bridge);
	bridge->context = state;
	bridge->parser_create = xp_rt_parser_create;
	bridge->parser_reset = xp_rt_parser_reset;
	bridge->parser_free = xp_rt_parser_free;
	bridge->set_native_parser_handle = xp_rt_set_native_parser_handle;
	bridge->set_encoding = xp_rt_set_encoding;
	bridge->set_external_entity_context = xp_rt_set_external_entity_context;
	bridge->set_external_entity_parameter_context = xp_rt_set_external_entity_parameter_context;
	bridge->inherit_external_entity_context = xp_rt_inherit_external_entity_context;
	bridge->set_param_entity_parsing = xp_rt_set_param_entity_parsing;
	bridge->set_foreign_dtd = xp_rt_set_foreign_dtd;
	bridge->set_user_data = xp_rt_set_user_data;
	bridge->set_element_handler = xp_rt_set_element_handler;
	bridge->set_character_data_handler = xp_rt_set_character_data_handler;
	bridge->set_processing_instruction_handler = xp_rt_set_processing_instruction_handler;
	bridge->set_xml_decl_handler = xp_rt_set_xml_decl_handler;
	bridge->set_comment_handler = xp_rt_set_comment_handler;
	bridge->set_cdata_section_handler = xp_rt_set_cdata_section_handler;
	bridge->set_default_handler = xp_rt_set_default_handler;
	bridge->set_doctype_decl_handler = xp_rt_set_doctype_decl_handler;
	bridge->set_not_standalone_handler = xp_rt_set_not_standalone_handler;
	bridge->set_element_decl_handler = xp_rt_set_element_decl_handler;
	bridge->set_notation_decl_handler = xp_rt_set_notation_decl_handler;
	bridge->set_attlist_decl_handler = xp_rt_set_attlist_decl_handler;
	bridge->set_entity_decl_handler = xp_rt_set_entity_decl_handler;
	bridge->set_unparsed_entity_decl_handler = xp_rt_set_unparsed_entity_decl_handler;
	bridge->set_external_entity_ref_handler = xp_rt_set_external_entity_ref_handler;
	bridge->set_external_entity_ref_handler_arg = xp_rt_set_external_entity_ref_handler_arg;
	bridge->set_skipped_entity_handler = xp_rt_set_skipped_entity_handler;
	bridge->default_current = xp_rt_default_current;
	bridge->set_hash_salt = xp_rt_set_hash_salt;
	bridge->set_hash_salt_16_bytes = xp_rt_set_hash_salt_16_bytes;
	bridge->parse = xp_rt_parse;
	bridge->get_buffer = xp_rt_get_buffer;
	bridge->parse_buffer = xp_rt_parse_buffer;
	bridge->get_error_code = xp_rt_get_error_code;
	bridge->get_current_line_number = xp_rt_get_current_line_number;
	bridge->get_current_column_number = xp_rt_get_current_column_number;
	bridge->get_current_byte_index = xp_rt_get_current_byte_index;
	bridge->get_current_byte_count = xp_rt_get_current_byte_count;
	bridge->get_specified_attribute_count = xp_rt_get_specified_attribute_count;
	bridge->get_id_attribute_index = xp_rt_get_id_attribute_index;
	bridge->get_input_context = xp_rt_get_input_context;
	bridge->get_parsing_status = xp_rt_get_parsing_status;
}

XML_Bool XMLCALL
XPACT_RegisterEiffelRuntimeBridge(
	EIF_OBJECT installer,
	XPACT_EiffelParserCreateRoutine parser_create,
	XPACT_EiffelParserResetRoutine parser_reset,
	XPACT_EiffelParserFreeRoutine parser_free,
	XPACT_EiffelSetPointerRoutine set_native_parser_handle,
	XPACT_EiffelSetEncodingRoutine set_encoding,
	XPACT_EiffelSetPointerBooleanRoutine set_external_entity_context,
	XPACT_EiffelSetBooleanRoutine set_external_entity_parameter_context,
	XPACT_EiffelInheritParserContextRoutine inherit_external_entity_context,
	XPACT_EiffelSetIntegerBooleanRoutine set_param_entity_parsing,
	XPACT_EiffelSetBooleanRoutine set_foreign_dtd,
	XPACT_EiffelSetPointerRoutine set_user_data,
	XPACT_EiffelSetElementHandlerRoutine set_element_handler,
	XPACT_EiffelSetPointerRoutine set_character_data_handler,
	XPACT_EiffelSetPointerRoutine set_processing_instruction_handler,
	XPACT_EiffelSetPointerRoutine set_xml_decl_handler,
	XPACT_EiffelSetPointerRoutine set_comment_handler,
	XPACT_EiffelSetElementHandlerRoutine set_cdata_section_handler,
	XPACT_EiffelSetDefaultHandlerRoutine set_default_handler,
	XPACT_EiffelSetElementHandlerRoutine set_doctype_decl_handler,
	XPACT_EiffelSetPointerRoutine set_not_standalone_handler,
	XPACT_EiffelSetPointerRoutine set_element_decl_handler,
	XPACT_EiffelSetPointerRoutine set_notation_decl_handler,
	XPACT_EiffelSetPointerRoutine set_attlist_decl_handler,
	XPACT_EiffelSetPointerRoutine set_entity_decl_handler,
	XPACT_EiffelSetPointerRoutine set_unparsed_entity_decl_handler,
	XPACT_EiffelSetPointerRoutine set_external_entity_ref_handler,
	XPACT_EiffelSetPointerRoutine set_external_entity_ref_handler_arg,
	XPACT_EiffelSetPointerRoutine set_skipped_entity_handler,
	XPACT_EiffelParserCommandRoutine default_current,
	XPACT_EiffelSetHashSaltRoutine set_hash_salt,
	XPACT_EiffelSetPointerBooleanRoutine set_hash_salt_16_bytes,
	XPACT_EiffelParseRoutine parse,
	XPACT_EiffelGetBufferRoutine get_buffer,
	XPACT_EiffelParseBufferRoutine parse_buffer,
	XPACT_EiffelIntegerQueryRoutine get_error_code,
	XPACT_EiffelIntegerQueryRoutine get_current_line_number,
	XPACT_EiffelIntegerQueryRoutine get_current_column_number,
	XPACT_EiffelIntegerQueryRoutine get_current_byte_index,
	XPACT_EiffelIntegerQueryRoutine get_current_byte_count,
	XPACT_EiffelIntegerQueryRoutine get_specified_attribute_count,
	XPACT_EiffelIntegerQueryRoutine get_id_attribute_index,
	XPACT_EiffelInputContextRoutine get_input_context,
	XPACT_EiffelParsingStatusRoutine get_parsing_status
) {
	if (installer == NULL
		|| parser_create == NULL
		|| parser_reset == NULL
		|| parser_free == NULL
		|| set_native_parser_handle == NULL
		|| set_encoding == NULL
		|| set_external_entity_context == NULL
		|| set_external_entity_parameter_context == NULL
		|| inherit_external_entity_context == NULL
		|| set_param_entity_parsing == NULL
		|| set_foreign_dtd == NULL
		|| set_user_data == NULL
		|| set_element_handler == NULL
		|| set_character_data_handler == NULL
		|| set_xml_decl_handler == NULL
		|| set_not_standalone_handler == NULL
		|| default_current == NULL
		|| set_hash_salt == NULL
		|| set_hash_salt_16_bytes == NULL
		|| parse == NULL
		|| get_buffer == NULL
		|| parse_buffer == NULL
		|| get_error_code == NULL
		|| get_specified_attribute_count == NULL
		|| get_id_attribute_index == NULL
		|| get_input_context == NULL
		|| get_parsing_status == NULL) {
		return XML_FALSE;
	}
	XPACT_ClearEiffelBridge();
	xp_release_runtime_bridge();
	xp_runtime_bridge.installer = eif_adopt(installer);
	xp_runtime_bridge.parser_create = parser_create;
	xp_runtime_bridge.parser_reset = parser_reset;
	xp_runtime_bridge.parser_free = parser_free;
	xp_runtime_bridge.set_native_parser_handle = set_native_parser_handle;
	xp_runtime_bridge.set_encoding = set_encoding;
	xp_runtime_bridge.set_external_entity_context = set_external_entity_context;
	xp_runtime_bridge.set_external_entity_parameter_context = set_external_entity_parameter_context;
	xp_runtime_bridge.inherit_external_entity_context = inherit_external_entity_context;
	xp_runtime_bridge.set_param_entity_parsing = set_param_entity_parsing;
	xp_runtime_bridge.set_foreign_dtd = set_foreign_dtd;
	xp_runtime_bridge.set_user_data = set_user_data;
	xp_runtime_bridge.set_element_handler = set_element_handler;
	xp_runtime_bridge.set_character_data_handler = set_character_data_handler;
	xp_runtime_bridge.set_processing_instruction_handler = set_processing_instruction_handler;
	xp_runtime_bridge.set_xml_decl_handler = set_xml_decl_handler;
	xp_runtime_bridge.set_comment_handler = set_comment_handler;
	xp_runtime_bridge.set_cdata_section_handler = set_cdata_section_handler;
	xp_runtime_bridge.set_default_handler = set_default_handler;
	xp_runtime_bridge.set_doctype_decl_handler = set_doctype_decl_handler;
	xp_runtime_bridge.set_not_standalone_handler = set_not_standalone_handler;
	xp_runtime_bridge.set_element_decl_handler = set_element_decl_handler;
	xp_runtime_bridge.set_notation_decl_handler = set_notation_decl_handler;
	xp_runtime_bridge.set_attlist_decl_handler = set_attlist_decl_handler;
	xp_runtime_bridge.set_entity_decl_handler = set_entity_decl_handler;
	xp_runtime_bridge.set_unparsed_entity_decl_handler = set_unparsed_entity_decl_handler;
	xp_runtime_bridge.set_external_entity_ref_handler = set_external_entity_ref_handler;
	xp_runtime_bridge.set_external_entity_ref_handler_arg = set_external_entity_ref_handler_arg;
	xp_runtime_bridge.set_skipped_entity_handler = set_skipped_entity_handler;
	xp_runtime_bridge.default_current = default_current;
	xp_runtime_bridge.set_hash_salt = set_hash_salt;
	xp_runtime_bridge.set_hash_salt_16_bytes = set_hash_salt_16_bytes;
	xp_runtime_bridge.parse = parse;
	xp_runtime_bridge.get_buffer = get_buffer;
	xp_runtime_bridge.parse_buffer = parse_buffer;
	xp_runtime_bridge.get_error_code = get_error_code;
	xp_runtime_bridge.get_current_line_number = get_current_line_number;
	xp_runtime_bridge.get_current_column_number = get_current_column_number;
	xp_runtime_bridge.get_current_byte_index = get_current_byte_index;
	xp_runtime_bridge.get_current_byte_count = get_current_byte_count;
	xp_runtime_bridge.get_specified_attribute_count = get_specified_attribute_count;
	xp_runtime_bridge.get_id_attribute_index = get_id_attribute_index;
	xp_runtime_bridge.get_input_context = get_input_context;
	xp_runtime_bridge.get_parsing_status = get_parsing_status;
	if (!xp_has_required_eiffel_routines(&xp_runtime_bridge)) {
		xp_release_runtime_bridge();
		return XML_FALSE;
	}
	xp_fill_bridge_table(&xp_runtime_bridge);
	if (XPACT_SetEiffelBridge(&xp_runtime_bridge.bridge) != XML_TRUE) {
		xp_release_runtime_bridge();
		return XML_FALSE;
	}
	return XML_TRUE;
}

XML_Bool XMLCALL
XPACT_RegisterEiffelRuntimeBridgePointers(
    EIF_OBJECT installer,
    EIF_POINTER parser_create,
    EIF_POINTER parser_reset,
    EIF_POINTER parser_free,
    EIF_POINTER set_native_parser_handle,
    EIF_POINTER set_encoding,
    EIF_POINTER set_external_entity_context,
    EIF_POINTER set_external_entity_parameter_context,
    EIF_POINTER inherit_external_entity_context,
    EIF_POINTER set_param_entity_parsing,
    EIF_POINTER set_foreign_dtd,
    EIF_POINTER set_user_data,
    EIF_POINTER set_element_handler,
    EIF_POINTER set_character_data_handler,
    EIF_POINTER set_processing_instruction_handler,
    EIF_POINTER set_xml_decl_handler,
    EIF_POINTER set_comment_handler,
    EIF_POINTER set_cdata_section_handler,
    EIF_POINTER set_default_handler,
    EIF_POINTER set_doctype_decl_handler,
    EIF_POINTER set_not_standalone_handler,
    EIF_POINTER set_element_decl_handler,
    EIF_POINTER set_notation_decl_handler,
    EIF_POINTER set_attlist_decl_handler,
    EIF_POINTER set_entity_decl_handler,
    EIF_POINTER set_unparsed_entity_decl_handler,
    EIF_POINTER set_external_entity_ref_handler,
    EIF_POINTER set_external_entity_ref_handler_arg,
    EIF_POINTER set_skipped_entity_handler,
    EIF_POINTER default_current,
    EIF_POINTER set_hash_salt,
    EIF_POINTER set_hash_salt_16_bytes,
    EIF_POINTER parse,
    EIF_POINTER get_buffer,
    EIF_POINTER parse_buffer,
    EIF_POINTER get_error_code,
    EIF_POINTER get_current_line_number,
    EIF_POINTER get_current_column_number,
    EIF_POINTER get_current_byte_index,
    EIF_POINTER get_current_byte_count,
    EIF_POINTER get_specified_attribute_count,
    EIF_POINTER get_id_attribute_index,
    EIF_POINTER get_input_context,
    EIF_POINTER get_parsing_status
) {
	return XPACT_RegisterEiffelRuntimeBridge(
		installer,
		(XPACT_EiffelParserCreateRoutine)parser_create,
		(XPACT_EiffelParserResetRoutine)parser_reset,
		(XPACT_EiffelParserFreeRoutine)parser_free,
		(XPACT_EiffelSetPointerRoutine)set_native_parser_handle,
		(XPACT_EiffelSetEncodingRoutine)set_encoding,
		(XPACT_EiffelSetPointerBooleanRoutine)set_external_entity_context,
		(XPACT_EiffelSetBooleanRoutine)set_external_entity_parameter_context,
		(XPACT_EiffelInheritParserContextRoutine)inherit_external_entity_context,
		(XPACT_EiffelSetIntegerBooleanRoutine)set_param_entity_parsing,
		(XPACT_EiffelSetBooleanRoutine)set_foreign_dtd,
		(XPACT_EiffelSetPointerRoutine)set_user_data,
		(XPACT_EiffelSetElementHandlerRoutine)set_element_handler,
		(XPACT_EiffelSetPointerRoutine)set_character_data_handler,
		(XPACT_EiffelSetPointerRoutine)set_processing_instruction_handler,
		(XPACT_EiffelSetPointerRoutine)set_xml_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_comment_handler,
		(XPACT_EiffelSetElementHandlerRoutine)set_cdata_section_handler,
		(XPACT_EiffelSetDefaultHandlerRoutine)set_default_handler,
		(XPACT_EiffelSetElementHandlerRoutine)set_doctype_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_not_standalone_handler,
		(XPACT_EiffelSetPointerRoutine)set_element_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_notation_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_attlist_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_entity_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_unparsed_entity_decl_handler,
		(XPACT_EiffelSetPointerRoutine)set_external_entity_ref_handler,
		(XPACT_EiffelSetPointerRoutine)set_external_entity_ref_handler_arg,
		(XPACT_EiffelSetPointerRoutine)set_skipped_entity_handler,
		(XPACT_EiffelParserCommandRoutine)default_current,
		(XPACT_EiffelSetHashSaltRoutine)set_hash_salt,
		(XPACT_EiffelSetPointerBooleanRoutine)set_hash_salt_16_bytes,
		(XPACT_EiffelParseRoutine)parse,
		(XPACT_EiffelGetBufferRoutine)get_buffer,
		(XPACT_EiffelParseBufferRoutine)parse_buffer,
		(XPACT_EiffelIntegerQueryRoutine)get_error_code,
		(XPACT_EiffelIntegerQueryRoutine)get_current_line_number,
		(XPACT_EiffelIntegerQueryRoutine)get_current_column_number,
		(XPACT_EiffelIntegerQueryRoutine)get_current_byte_index,
		(XPACT_EiffelIntegerQueryRoutine)get_current_byte_count,
		(XPACT_EiffelIntegerQueryRoutine)get_specified_attribute_count,
		(XPACT_EiffelIntegerQueryRoutine)get_id_attribute_index,
		(XPACT_EiffelInputContextRoutine)get_input_context,
		(XPACT_EiffelParsingStatusRoutine)get_parsing_status
	);
}

void XMLCALL
XPACT_UnregisterEiffelRuntimeBridge(void) {
	XPACT_ClearEiffelBridge();
	xp_release_runtime_bridge();
}
