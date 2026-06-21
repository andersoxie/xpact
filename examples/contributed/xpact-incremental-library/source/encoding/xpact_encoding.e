note
	description: "[
		Abstract XML encoding interface.

		Corresponds to `struct encoding' in xmltok.h.
		Each feature maps to one function-pointer slot in that struct.

		After any scan_* call, `next_token_ptr' holds the index of the first
		byte not yet consumed (the C `*nextTokPtr' out-parameter).

		Buffer arguments use integer indices rather than C pointers:
		  start_index  -- start of region to scan (inclusive)
		  a_end  -- end of region (exclusive)
		  buf    -- the shared parse buffer (SPECIAL [CHARACTER])
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:39:38 GMT (Thursday 18th June 2026)"
	revision: "1"

deferred class XPACT_ENCODING

inherit
	XPACT_TOKEN_CONSTANTS   -- XML_TOK_* return values
	XPACT_BYTE_TYPE_CONSTANTS
	XPACT_CONVERT_RESULT_CONSTANTS

feature -- Token scanner dispatch (XML_Parsing state selects which scanner)

	scan_content (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan the next token in element content.
			-- Sets `next_token_ptr'.  Corresponds to scanners[XML_CONTENT_STATE].
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		ensure result_in_range: Result >= Tok_trailing_rsqb and Result <= Tok_ignore_sect
		end

	scan_prolog (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan the next token in the document prolog or DTD.
			-- Corresponds to scanners[XML_PROLOG_STATE].
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		end

	scan_cdata_section (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan the next token inside a CDATA section.
			-- Corresponds to scanners[XML_CDATA_SECTION_STATE].
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		end

	scan_attribute_value (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan the next token inside a quoted attribute value.
			-- Corresponds to literalScanners[XML_ATTRIBUTE_VALUE_LITERAL].
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		end

	scan_entity_value (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan the next token inside an entity value literal.
			-- Corresponds to literalScanners[XML_ENTITY_VALUE_LITERAL].
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		end

feature -- Output of the last scan call

	next_token_index: INTEGER
			-- Index of the first byte after the token just scanned.
			-- Invalid if the last call returned Tok_none or Tok_partial.
		deferred
		end

feature -- Encoding properties

	min_bytes_per_char: INTEGER
			-- Minimum number of bytes used to represent one character.
			-- 1 for UTF-8, Latin-1, ASCII; 2 for UTF-16.
		deferred
		ensure positive: Result >= 1
		end

	is_utf8: BOOLEAN deferred end
	is_utf16: BOOLEAN deferred end

feature -- Name utilities

	name_matches_ascii (buf: SPECIAL [CHARACTER];
	                    start_index, a_end: INTEGER; match: STRING_8): BOOLEAN
			-- True when the encoded name in buf[start_index..a_end) equals match.
		deferred
		end

	name_length (buf: SPECIAL [CHARACTER]; start_index: INTEGER): INTEGER
			-- Number of bytes in the name starting at start_index.
		require start_index >= 0
		deferred
		ensure non_negative: Result >= 0
		end

	skip_s (buf: SPECIAL [CHARACTER]; start_index: INTEGER): INTEGER
			-- Index of the first non-whitespace byte at or after start_index.
		require start_index >= 0
		deferred
		ensure result_gte_ptr: Result >= start_index
		end

feature -- Attribute and reference utilities

	char_ref_number (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Unicode code point of the character reference starting at start_index ('&').
			-- Returns -1 if the value is not a legal XML character.
		deferred
		end

	predefined_entity_name (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Code point for a predefined entity (lt=0x3C, gt=0x3E, amp=0x26,
			-- quot=0x22, apos=0x27), or -1 if not recognized.
		deferred
		end

	is_public_id (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): BOOLEAN
			-- True when buf[start_index..a_end) is a valid PUBLIC identifier literal.
			-- On False, `bad_char_ptr' is set to the invalid character's index.
		deferred
		end

	bad_char_ptr: INTEGER
			-- Set by `is_public_id' on failure: index of the bad character.

feature -- Position tracking

	update_position (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER;
	                 pos: XPACT_POSITION)
			-- Advance `pos' (line/column) by scanning buf[start_index..a_end).
		require
			valid_range: start_index >= 0 and start_index <= a_end and a_end <= buf.count
		deferred
		end

feature -- Encoding conversion

	to_utf8 (src: SPECIAL [CHARACTER]; a_from_ptr, a_from_end: INTEGER;
	          dst: SPECIAL [NATURAL_8]; a_to_ptr, a_to_end: INTEGER)
			-- Convert src[a_from_ptr..a_from_end) to UTF-8 in dst[a_to_ptr..a_to_end).
			-- Sets consumed_from and written_to.
		deferred
		end

	to_utf16 (src: SPECIAL [CHARACTER]; a_from_ptr, a_from_end: INTEGER;
	           dst: SPECIAL [NATURAL_16]; a_to_ptr, a_to_end: INTEGER)
			-- Convert src[a_from_ptr..a_from_end) to UTF-16 in dst.
			-- Sets consumed_from and written_to.
		deferred
		end

	consumed_from: INTEGER
			-- Updated by `to_utf8' / `to_utf16': index after last consumed source byte.

	written_to: INTEGER
			-- Updated by `to_utf8' / `to_utf16': index after last written destination unit.

end