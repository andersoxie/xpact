note
	description: "Byte-type codes for the 256-entry classification table (BT_* enum from xmltok_impl.h)"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-16 9:10:09 GMT (Tuesday 16th June 2026)"
	revision: "1"

class XPACT_BYTE_TYPE_CONSTANTS

feature -- Paired Byte types (ordinal matches C enum)

	BT_lt: INTEGER = 2   -- '<'
	BT_gt: INTEGER = 11  -- '>'

	BT_left_parenthesis: INTEGER = 31  -- '('
	BT_right_parenthesis: INTEGER = 32  -- ')'

	BT_left_square_bracket: INTEGER = 20  -- '['
	BT_right_square_bracket: INTEGER = 4   -- ']'

feature -- Punctuation Byte types (ordinal matches C enum)

	BT_colon:    INTEGER = 23  -- ':' (treated as BT_name_start when namespaces disabled)
	BT_quote: INTEGER = 12  -- '"'
	BT_apostrophe: INTEGER = 13  -- "'"
	BT_question:    INTEGER = 15  -- '?'
	BT_exclamation:     INTEGER = 16  -- '!'
	BT_comma:    INTEGER = 35  -- ','
	BT_semicolon:     INTEGER = 18  -- ';'

feature -- Character Byte types (ordinal matches C enum)

	BT_ampersand:      INTEGER = 3   -- '&'
	BT_asterisk:      INTEGER = 33  -- '*'
	BT_equals:   INTEGER = 14  -- '='
	BT_forward_slash:      INTEGER = 17  -- solidus '/'
	BT_hash:      INTEGER = 19  -- '#'
	BT_minus:    INTEGER = 27  -- '-'
	BT_percent:   INTEGER = 30  -- '%'
	BT_plus:     INTEGER = 34  -- '+'
	BT_pipe_symbol:   INTEGER = 36  -- '|'

feature -- Category Byte types (ordinal matches C enum)

	BT_non_xml:   INTEGER = 0   -- e.g. noncharacter-FFFF; also upper-128 in ASCII encoding
	BT_malform:  INTEGER = 1   -- illegal byte for the current encoding
	BT_lead_2_byte:    INTEGER = 5   -- lead byte of a 2-byte UTF-8 sequence (0xC2-0xDF)
	BT_lead_3_byte:    INTEGER = 6   -- lead byte of a 3-byte UTF-8 sequence (0xE0-0xEF)
	BT_lead_4_byte:    INTEGER = 7   -- lead byte of a 4-byte UTF-8 sequence (0xF0-0xF4)
	BT_continuation_byte:    INTEGER = 8   -- continuation byte (0x80-0xBF) or UTF-16 low surrogate
	BT_CR:       INTEGER = 9   -- carriage return '\r'
	BT_LF:       INTEGER = 10  -- line feed '\n'
	BT_whitespace:        INTEGER = 21  -- whitespace: space, tab, sometimes CR
	BT_name_start:   INTEGER = 22  -- name-start: letters (non-hex), underscore, ext chars
	BT_hex_digit:      INTEGER = 24  -- hex digit letter A-F, a-f
	BT_digit:    INTEGER = 25  -- decimal digit 0-9
	BT_name_only:     INTEGER = 26  -- name-only char: '.' and middle-dot U+00B7
	BT_other:    INTEGER = 28  -- known non-name, non-name-start ASCII character
	BT_non_ascii: INTEGER = 29  -- upper byte; might be name or name-start (Latin-1)

end