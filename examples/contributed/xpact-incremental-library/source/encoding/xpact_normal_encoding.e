note
	description: "[
		Abstract base for single-table encodings (UTF-8, Latin-1, ASCII).

		Corresponds to struct normal_encoding and normal_* utility functions
		in xmltok.c.

		All scanner dispatch features delegate to the mixin scanner classes
		(XPACT_CONTENT_SCANNER, XPACT_PROLOG_SCANNER, XPACT_LITERAL_SCANNER).
		The key bridge between the scanner mixins and this class is:
		  byte_type (buf, index) -- reads from byte_type_table
		  char_at   (buf, index) -- reads single byte

		Diamond note: XPACT_SCANNER_HELPERS and XPACT_ENCODING both declare
		next_token_ptr as a stored attribute.  The scanner-mixin parents are
		given `undefine next_token_ptr` so that XPACT_ENCODING's single copy
		is used throughout.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:42:32 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_NORMAL_ENCODING

inherit
	XPACT_ENCODING
	XPACT_CONTENT_SCANNER

	XPACT_PROLOG_SCANNER

	XPACT_LITERAL_SCANNER

feature {NONE} -- Initialisation

	make
		do
		end

feature -- Scanner dispatch (implements XPACT_ENCODING deferred features)

	scan_content (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		do
			Result := content_tok (buf, start_index, a_end)
		end

	scan_prolog (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		do
			Result := prolog_tok (buf, start_index, a_end)
		end

	scan_cdata_section (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		do
			Result := cdata_section_tok (buf, start_index, a_end)
		end

	scan_attribute_value (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		do
			Result := attribute_value_tok (buf, start_index, a_end)
		end

	scan_entity_value (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		do
			Result := entity_value_tok (buf, start_index, a_end)
		end

feature -- Name utilities (implements XPACT_ENCODING deferred features)

	byte_type (buf: SPECIAL [CHARACTER]; index: INTEGER): INTEGER
			-- Byte-type category of the byte at buf[index].
		do
			Result := byte_type_table [buf [index].code].to_integer_32
		end

	name_length (buf: SPECIAL [CHARACTER]; start_index: INTEGER): INTEGER
			-- Byte count of the XML name starting at start_index.
			-- Stops at first byte whose type is not a name-continuation type.
		local
			index: INTEGER; done: BOOLEAN
		do
			if attached byte_type_table as bt_table then
				from index := start_index until index >= buf.count or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_name_start, BT_name_only, BT_hex_digit, BT_digit, BT_minus, BT_colon then
							index := index + min_bytes_per_char
					else
						done := True
					end
				end
			end
			Result := index - start_index
		end

	skip_s (buf: SPECIAL [CHARACTER]; start_index: INTEGER): INTEGER
			-- Index of first non-whitespace byte at or after start_index.
		local
			done: BOOLEAN
		do
			if attached byte_type_table as bt_table then
				from Result := start_index until Result >= buf.count or done loop
					inspect bt_table [buf [Result].code].to_integer_32
						when BT_whitespace, BT_CR, BT_LF then
							Result := Result + min_bytes_per_char
					else
						done := True
					end
				end
			end
		end

	name_matches_ascii (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER;
	                    match: STRING_8): BOOLEAN
			-- True if the name at start_index..a_end equals the ASCII string match.
		local
			index, i: INTEGER; ok: BOOLEAN
		do
			index := start_index; i := 1; ok := True
			from until i > match.count or not ok loop
				if index >= a_end or buf [index] /= match [i] then
					ok := False
				else
					index := index + min_bytes_per_char; i := i + 1
				end
			end
			Result := ok and index = a_end
		end

	predefined_entity_name (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Code point for predefined entity (lt=0x3C, gt=0x3E, amp=0x26,
			-- quot=0x22, apos=0x27), or -1 if not a predefined entity.
		local
			len: INTEGER
		do
			len := (a_end - start_index) // min_bytes_per_char
			Result := -1
			inspect len
				when 2 then
					if buf [start_index] = 'l'
						and buf [start_index + min_bytes_per_char] = 't'
					then
						Result := 0x3C
					elseif buf [start_index] = 'g'
						and buf [start_index + min_bytes_per_char] = 't'
					then
						Result := 0x3E
					end
				when 3 then
					if buf [start_index] = 'a'
						and buf [start_index + min_bytes_per_char] = 'm'
						and buf [start_index + 2 * min_bytes_per_char] = 'p'
					then
						Result := 0x26
					end
				when 4 then
					inspect buf [start_index]
						when 'q' then
							if buf [start_index + min_bytes_per_char] = 'u'
								and buf [start_index + 2 * min_bytes_per_char] = 'o'
								and buf [start_index + 3 * min_bytes_per_char] = 't'
							then
								Result := 0x22
							end
					when 'a' then
						if buf [start_index + min_bytes_per_char] = 'p'
							and buf [start_index + 2 * min_bytes_per_char] = 'o'
							and buf [start_index + 3 * min_bytes_per_char] = 's'
						then
							Result := 0x27
						end
					else -- no match
					end
			else -- no match
			end
		end

feature -- Character reference utilities

	char_ref_number (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Parse &#N; or &#xH; starting at '&'.  Returns the code point or -1.
		local
			index, accum: INTEGER; is_hex: BOOLEAN; c: CHARACTER
		do
			index := start_index + 2 * min_bytes_per_char  -- skip '&' and '#'
			if index < a_end and buf [index] = 'x' then
				is_hex := True; index := index + min_bytes_per_char
			end
			from until index >= a_end or buf [index] = ';' loop
				c := buf [index]
				if is_hex then
					inspect c
						when '0'..'9' then
							accum := (accum |<< 4) | (c - 48).code
						when 'A'..'F' then
							accum := (accum |<< 4) | (c - 55).code
					else
					-- 'a'..'f'
						accum := (accum |<< 4) | (c - 87).code
					end
				else
					accum := accum * 10 + (c - 48).code
				end
				if accum >= 0x110000 then
					accum := -1; index := a_end
				else
					index := index + min_bytes_per_char
				end
			end
			Result := valid_char_ref (accum)
		end

feature -- Public ID validation

	is_public_id (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): BOOLEAN
			-- True if every byte in start_index..a_end-1 is a valid PubidChar.
			-- Sets bad_char_ptr on failure.
		local
			index: INTEGER; ok: BOOLEAN
		do
			ok := True
			if attached byte_type_table as bt_table then
				from index := start_index until index >= a_end or not ok loop
					inspect bt_table [buf [index].code].to_integer_32
						when	BT_digit, BT_hex_digit, BT_minus, BT_apostrophe, BT_left_parenthesis, BT_right_parenthesis,
								BT_plus, BT_comma, BT_forward_slash, BT_equals, BT_question, BT_CR, BT_LF, BT_semicolon,
								BT_exclamation, BT_asterisk, BT_percent, BT_hash, BT_colon, BT_whitespace,
								BT_name_start, BT_name_only
						then
							index := index + min_bytes_per_char
					else
						bad_char_ptr := index; ok := False
					end
				end
			end
			Result := ok
		end

feature -- Position tracking

	update_position (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER; pos: XPACT_POSITION)
			-- Update line and column numbers by scanning buf[start_index..a_end-1].
		local
			index: INTEGER
		do
			if attached byte_type_table as bt_table then
				from index := start_index until index >= a_end loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_CR then
							pos.advance_line
							if index + min_bytes_per_char < a_end
								and bt_table [buf [index + min_bytes_per_char].code].to_integer_32 = BT_LF
							then
								index := index + min_bytes_per_char
							end
						when BT_LF then
							pos.advance_line
					else
						pos.advance_column
					end
					index := index + min_bytes_per_char
				end
			end
		end

feature {NONE} -- Implementation

	valid_char_ref (cp: INTEGER): INTEGER
			-- Return cp if it is a legal XML character, else -1.
		do
			if cp < 0 then
				Result := -1
			elseif (cp |>> 8) >= 0xD8 and (cp |>> 8) <= 0xDF then
				Result := -1  -- UTF-16 surrogate range
			elseif cp < 0x20 and cp /= 0x09 and cp /= 0x0A and cp /= 0x0D then
				Result := -1  -- forbidden C0 control characters
			elseif cp = 0xFFFE or cp = 0xFFFF then
				Result := -1  -- non-characters
			elseif cp > 0x10FFFF then
				Result := -1  -- beyond Unicode range
			else
				Result := cp
			end
		end

feature {NONE} -- ASCII half table builder (shared by all single-byte encodings)

	fill_ascii_half (t: SPECIAL [NATURAL_8])
			-- Fill entries 0..127 with BT_* values from asciitab.h.
		do
			-- 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F: BT_non_xml = 0 (make_filled default)
			t [9]  := 21; t [10] := 10; t [13] := 9   -- tab, LF, CR
			t [32] := 21; t [33] := 16; t [34] := 12; t [35] := 19
			t [36] := 28; t [37] := 30; t [38] := 3;  t [39] := 13
			t [40] := 31; t [41] := 32; t [42] := 33; t [43] := 34
			t [44] := 35; t [45] := 27; t [46] := 26; t [47] := 17
			t.fill_with (25, 48, 57)     -- BT_digit '0'..'9'
			t [58] := 23; t [59] := 18; t [60] := 2;  t [61] := 14
			t [62] := 11; t [63] := 15; t [64] := 28
			t.fill_with (24, 65, 70)     -- BT_hex_digit 'A'..'F'
			t.fill_with (22, 71, 90)     -- BT_name_start 'G'..'Z'
			t [91] := 20; t [92] := 28; t [93] := 4;  t [94] := 28
			t [95] := 22; t [96] := 28  -- '_', '`'
			t.fill_with (24, 97, 102)    -- BT_hex_digit 'a'..'f'
			t.fill_with (22, 103, 122)   -- BT_name_start 'g'..'z'
			t [123] := 28; t [124] := 36; t [125] := 28
			t [126] := 28; t [127] := 28
		end

end
