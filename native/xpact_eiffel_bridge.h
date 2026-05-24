#ifndef XPACT_EIFFEL_BRIDGE_H
#define XPACT_EIFFEL_BRIDGE_H

#include "../include/xpact.h"

#if defined(_WIN32) && defined(XPACT_BUILDING_DLL)
#define XPACT_NATIVE_API __declspec(dllexport)
#elif defined(XPACT_BUILDING_DLL)
#define XPACT_NATIVE_API __attribute__((visibility("default")))
#else
#define XPACT_NATIVE_API
#endif

#define XPACT_EIFFEL_BRIDGE_ABI_VERSION 6u

/*
 * Private bridge between the libexpat-compatible C ABI and the Eiffel parser.
 *
 * This is intentionally not a parser API. The C layer owns exported symbol
 * names and C callback shapes; the Eiffel layer owns XML tokenization, entity
 * expansion, validation, and parser state.
 */
typedef struct XPACT_EiffelBridge {
	unsigned int abi_version;
	size_t size;
	void *context;

	void *(XMLCALL *parser_create) (
		void *context,
		const XML_Char *encoding,
		const XML_Memory_Handling_Suite *memsuite,
		const XML_Char *namespaceSeparator
	);
	XML_Bool (XMLCALL *parser_reset) (void *context, void *parser, const XML_Char *encoding);
	void (XMLCALL *parser_free) (void *context, void *parser);
	enum XML_Status (XMLCALL *set_encoding) (void *context, void *parser, const XML_Char *encoding);

	void (XMLCALL *set_user_data) (void *context, void *parser, void *userData);
	void (XMLCALL *set_element_handler) (
		void *context,
		void *parser,
		XML_StartElementHandler start,
		XML_EndElementHandler end
	);
	void (XMLCALL *set_character_data_handler) (
		void *context,
		void *parser,
		XML_CharacterDataHandler handler
	);
	void (XMLCALL *set_processing_instruction_handler) (
		void *context,
		void *parser,
		XML_ProcessingInstructionHandler handler
	);
	void (XMLCALL *set_comment_handler) (void *context, void *parser, XML_CommentHandler handler);
	void (XMLCALL *set_cdata_section_handler) (
		void *context,
		void *parser,
		XML_StartCdataSectionHandler start,
		XML_EndCdataSectionHandler end
	);
	void (XMLCALL *set_default_handler) (void *context, void *parser, XML_DefaultHandler handler, XML_Bool expand);
	void (XMLCALL *set_doctype_decl_handler) (
		void *context,
		void *parser,
		XML_StartDoctypeDeclHandler start,
		XML_EndDoctypeDeclHandler end
	);
	void (XMLCALL *set_element_decl_handler) (
		void *context,
		void *parser,
		XML_ElementDeclHandler handler
	);
	void (XMLCALL *set_notation_decl_handler) (
		void *context,
		void *parser,
		XML_NotationDeclHandler handler
	);
	void (XMLCALL *set_attlist_decl_handler) (
		void *context,
		void *parser,
		XML_AttlistDeclHandler handler
	);
	void (XMLCALL *set_entity_decl_handler) (
		void *context,
		void *parser,
		XML_EntityDeclHandler handler
	);
	void (XMLCALL *set_unparsed_entity_decl_handler) (
		void *context,
		void *parser,
		XML_UnparsedEntityDeclHandler handler
	);
	void (XMLCALL *set_external_entity_ref_handler) (
		void *context,
		void *parser,
		XML_ExternalEntityRefHandler handler
	);
	void (XMLCALL *set_external_entity_ref_handler_arg) (void *context, void *parser, void *arg);
	void (XMLCALL *set_skipped_entity_handler) (
		void *context,
		void *parser,
		XML_SkippedEntityHandler handler
	);
	void (XMLCALL *default_current) (void *context, void *parser);
	XML_Bool (XMLCALL *set_hash_salt) (void *context, void *parser, unsigned long hash_salt);
	XML_Bool (XMLCALL *set_hash_salt_16_bytes) (
		void *context,
		void *parser,
		const uint8_t entropy[16]
	);

	enum XML_Status (XMLCALL *parse) (void *context, void *parser, const char *s, int len, int isFinal);
	void *(XMLCALL *get_buffer) (void *context, void *parser, int len);
	enum XML_Status (XMLCALL *parse_buffer) (void *context, void *parser, int len, int isFinal);

	enum XML_Error (XMLCALL *get_error_code) (void *context, void *parser);
	XML_Size (XMLCALL *get_current_line_number) (void *context, void *parser);
	XML_Size (XMLCALL *get_current_column_number) (void *context, void *parser);
	XML_Index (XMLCALL *get_current_byte_index) (void *context, void *parser);
	int (XMLCALL *get_current_byte_count) (void *context, void *parser);
	int (XMLCALL *get_specified_attribute_count) (void *context, void *parser);
	int (XMLCALL *get_id_attribute_index) (void *context, void *parser);
	const char *(XMLCALL *get_input_context) (void *context, void *parser, int *offset, int *size);
	void (XMLCALL *get_parsing_status) (void *context, void *parser, XML_ParsingStatus *status);
} XPACT_EiffelBridge;

XPACT_NATIVE_API XML_Bool XMLCALL
XPACT_SetEiffelBridge(const XPACT_EiffelBridge *bridge);

XPACT_NATIVE_API void XMLCALL
XPACT_ClearEiffelBridge(void);

#endif
