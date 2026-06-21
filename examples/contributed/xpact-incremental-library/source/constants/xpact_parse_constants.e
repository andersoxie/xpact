note
	description: "Constants ported from expat.h and xmlparse.c (libexpat 2.x)"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 8:37:26 GMT (Saturday 20th June 2026)"
	revision: "1"

class XPACT_PARSE_CONSTANTS

feature -- Parsing states (XML_Parsing enum)

	State_initialized: INTEGER = 0
	State_parsing:     INTEGER = 1
	State_finished:    INTEGER = 2
	State_suspended:   INTEGER = 3

feature -- Parse status (XML_Status enum)

	Status_error:     INTEGER = 0
	Status_ok:        INTEGER = 1
	Status_suspended: INTEGER = 2

feature -- Error codes (XML_Error enum)

	Error_none:                              INTEGER = 0
	Error_no_memory:                         INTEGER = 1
	Error_syntax:                            INTEGER = 2
	Error_no_elements:                       INTEGER = 3
	Error_invalid_token:                     INTEGER = 4
	Error_unclosed_token:                    INTEGER = 5
	Error_partial_char:                      INTEGER = 6
	Error_tag_mismatch:                      INTEGER = 7
	Error_duplicate_attribute:               INTEGER = 8
	Error_junk_after_doc_element:            INTEGER = 9
	Error_param_entity_ref:                  INTEGER = 10
	Error_undefined_entity:                  INTEGER = 11
	Error_recursive_entity_ref:              INTEGER = 12
	Error_async_entity:                      INTEGER = 13
	Error_bad_char_ref:                      INTEGER = 14
	Error_binary_entity_ref:                 INTEGER = 15
	Error_attribute_external_entity_ref:     INTEGER = 16
	Error_misplaced_xml_pi:                  INTEGER = 17
	Error_unknown_encoding:                  INTEGER = 18
	Error_incorrect_encoding:                INTEGER = 19
	Error_unclosed_cdata_section:            INTEGER = 20
	Error_external_entity_handling:          INTEGER = 21
	Error_not_standalone:                    INTEGER = 22
	Error_unexpected_state:                  INTEGER = 23
	Error_entity_declared_in_pe:             INTEGER = 24
	Error_feature_requires_xml_dtd:          INTEGER = 25
	Error_cant_change_feature_once_parsing:  INTEGER = 26
	Error_unbound_prefix:                    INTEGER = 27
	Error_undeclaring_prefix:                INTEGER = 28
	Error_incomplete_pe:                     INTEGER = 29
	Error_xml_decl:                          INTEGER = 30
	Error_text_decl:                         INTEGER = 31
	Error_publicid:                          INTEGER = 32
	Error_suspended:                         INTEGER = 33
	Error_not_suspended:                     INTEGER = 34
	Error_aborted:                           INTEGER = 35
	Error_finished:                          INTEGER = 36
	Error_suspend_pe:                        INTEGER = 37
	Error_reserved_prefix_xml:              INTEGER = 38
	Error_reserved_prefix_xmlns:            INTEGER = 39
	Error_reserved_namespace_uri:           INTEGER = 40
	Error_invalid_argument:                 INTEGER = 41
	Error_no_buffer:                        INTEGER = 42
	Error_amplification_limit_breach:       INTEGER = 43
	Error_not_started:                      INTEGER = 44

end