note
	description: "[
		Token type constants corresponding to XML_TOK_* in xmltok.h.

		Negative values signal incomplete tokens where the caller must
		supply more data before the token type can be determined.
		Zero (Tok_invalid) means a well-formed error was detected.
		Positive values are complete, recognised tokens.

		The naming convention replaces the C prefix XML_TOK_ with Tok_.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-17 19:14:40 GMT (Wednesday 17th June 2026)"
	revision: "1"

class XPACT_TOKEN_CONSTANTS

feature -- Partial / error sentinels (negative or zero)

	Tok_trailing_rsqb: INTEGER = -5
			-- ']' or ']]' at end of buffer might start ']]>'.

	Tok_none: INTEGER = -4
			-- Empty buffer; no token available.

	Tok_trailing_cr: INTEGER = -3
			-- CR at end of buffer might be the first byte of CRLF.

	Tok_partial_char: INTEGER = -2
			-- Multi-byte lead byte at end of buffer; char is incomplete.

	Tok_partial: INTEGER = -1
			-- Token started but buffer ended before it could be completed.

	Tok_invalid: INTEGER = 0
			-- Ill-formed input detected; `bad_char_ptr` points at the byte.

feature -- Element content tokens (positive)

	Tok_start_tag_with_atts: INTEGER = 1
	Tok_start_tag_no_atts: INTEGER = 2
	Tok_empty_element_with_atts: INTEGER = 3
	Tok_empty_element_no_atts: INTEGER = 4
	Tok_end_tag: INTEGER = 5
	Tok_data_chars: INTEGER = 6
	Tok_data_newline: INTEGER = 7
	Tok_cdata_sect_open: INTEGER = 8
	Tok_entity_ref: INTEGER = 9
	Tok_char_ref: INTEGER = 10
	Tok_pi: INTEGER = 11
	Tok_xml_decl: INTEGER = 12
	Tok_comment: INTEGER = 13
	Tok_bom: INTEGER = 14

feature -- Prolog / DTD tokens

	Tok_prolog_s: INTEGER = 15
	Tok_decl_open: INTEGER = 16
	Tok_decl_close: INTEGER = 17
	Tok_name: INTEGER = 18
	Tok_nmtoken: INTEGER = 19
	Tok_pound_name: INTEGER = 20
	Tok_or: INTEGER = 21
	Tok_percent: INTEGER = 22
	Tok_open_paren: INTEGER = 23
	Tok_close_paren: INTEGER = 24
	Tok_open_bracket: INTEGER = 25
	Tok_close_bracket: INTEGER = 26
	Tok_literal: INTEGER = 27
	Tok_param_entity_ref: INTEGER = 28
	Tok_instance_start: INTEGER = 29

feature -- Extended prolog tokens (occurrenceIndicators, conditionals)

	Tok_name_question: INTEGER = 30
	Tok_name_asterisk: INTEGER = 31
	Tok_name_plus: INTEGER = 32
	Tok_cond_sect_open: INTEGER = 33
	Tok_cond_sect_close: INTEGER = 34
	Tok_close_paren_question: INTEGER = 35
	Tok_close_paren_asterisk: INTEGER = 36
	Tok_close_paren_plus: INTEGER = 37
	Tok_comma: INTEGER = 38

feature -- Literal / CDATA tokens

	Tok_attribute_value_s: INTEGER = 39
	Tok_cdata_sect_close: INTEGER = 40
	Tok_prefixed_name: INTEGER = 41
	Tok_ignore_sect: INTEGER = 42

end