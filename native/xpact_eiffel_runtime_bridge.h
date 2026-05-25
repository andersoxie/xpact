#ifndef XPACT_EIFFEL_RUNTIME_BRIDGE_H
#define XPACT_EIFFEL_RUNTIME_BRIDGE_H

#include "xpact_eiffel_bridge.h"

#include <eif_eiffel.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Runtime trampoline from the native bridge table to Eiffel feature pointers.
 *
 * The Eiffel side passes an XP_NATIVE_BRIDGE_INSTALLER object plus addresses
 * of its bridge features, for example `$parser_create'. This layer adopts the
 * installer object, exposes libexpat-shaped C bridge callbacks, and forwards
 * every operation back to Eiffel.
 */

typedef EIF_POINTER (*XPACT_EiffelParserCreateRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER encoding,
	 EIF_POINTER memsuite,
	 EIF_POINTER namespace_separator
);
typedef EIF_BOOLEAN (*XPACT_EiffelParserResetRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER encoding
);
typedef void (*XPACT_EiffelParserFreeRoutine) (EIF_REFERENCE installer, EIF_POINTER parser);
typedef EIF_INTEGER (*XPACT_EiffelSetEncodingRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER encoding
);
typedef void (*XPACT_EiffelParserCommandRoutine) (EIF_REFERENCE installer, EIF_POINTER parser);
typedef EIF_BOOLEAN (*XPACT_EiffelSetHashSaltRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_INTEGER_64 hash_salt
);
typedef EIF_BOOLEAN (*XPACT_EiffelSetPointerBooleanRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER value
);
typedef EIF_BOOLEAN (*XPACT_EiffelSetIntegerBooleanRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_INTEGER value
);
typedef EIF_BOOLEAN (*XPACT_EiffelSetBooleanRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_BOOLEAN value
);
typedef EIF_BOOLEAN (*XPACT_EiffelInheritParserContextRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER parent_parser
);
typedef void (*XPACT_EiffelSetPointerRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER value
);
typedef void (*XPACT_EiffelSetElementHandlerRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER start,
	 EIF_POINTER end
);
typedef void (*XPACT_EiffelSetDefaultHandlerRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER handler,
	 EIF_BOOLEAN expand
);
typedef EIF_INTEGER (*XPACT_EiffelParseRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER bytes,
	 EIF_INTEGER length,
	 EIF_BOOLEAN is_final
);
typedef EIF_POINTER (*XPACT_EiffelGetBufferRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_INTEGER length
);
typedef EIF_INTEGER (*XPACT_EiffelParseBufferRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_INTEGER length,
	 EIF_BOOLEAN is_final
);
typedef EIF_INTEGER (*XPACT_EiffelIntegerQueryRoutine) (EIF_REFERENCE installer, EIF_POINTER parser);
typedef EIF_POINTER (*XPACT_EiffelInputContextRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER offset,
	 EIF_POINTER size
);
typedef void (*XPACT_EiffelParsingStatusRoutine) (
	 EIF_REFERENCE installer,
	 EIF_POINTER parser,
	 EIF_POINTER status
);

XPACT_NATIVE_API XML_Bool XMLCALL
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
	 XPACT_EiffelInheritParserContextRoutine merge_external_entity_context,
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
);

XPACT_NATIVE_API XML_Bool XMLCALL
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
	 EIF_POINTER merge_external_entity_context,
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
);

XPACT_NATIVE_API void XMLCALL
XPACT_UnregisterEiffelRuntimeBridge(void);

#ifdef __cplusplus
}
#endif

#endif
