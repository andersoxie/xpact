note
	description: "[
		Concrete implementations of the nine multi-byte name-checking predicates
		for UTF-8, using the Unicode naming bitmaps from XPACT_NAME_BITMAP.

		Corresponds to the utf8_isName2/3, utf8_isNmstrt2/3, utf8_isInvalid2/3/4
		function pointers and the UTF8_GET_NAMING2/3 macros in xmltok.c.

		4-byte sequences (U+10000 and above) are never name-start or name
		characters in XML 1.0; those predicates always return False.

		Diamond join note: this class and the scanner mixins both inherit
		XPACT_SCANNER_HELPERS.  Eiffel's join rule resolves the shared
		deferred features automatically -- no rename or redefine needed here.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:48:47 GMT (Thursday 18th June 2026)"
	revision: "1"

class XPACT_UTF8_NAME_CHECKER

inherit
	XPACT_NAME_BITMAP

feature -- Name-character predicates (2-byte UTF-8, U+0080..U+07FF)

	is_name_char_2 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 2-byte sequence at ptr a valid XML NameChar?
			-- Uses namePages and the naming bitmap.
		local
			b0, b1, pg, idx: INTEGER
		do
			b0 := buf [ptr].code
			b1 := buf [ptr + 1].code
			pg := name_pages [(b0 |>> 2) & 7].to_integer_32
			idx := (pg |<< 3) + ((b0 & 3) |<< 1) + ((b1 |>> 5) & 1)
			Result := (naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b1 & 0x1F))) /= 0
		end

	is_name_start_char_2 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 2-byte sequence at ptr a valid XML NameStartChar?
			-- Uses nmstrtPages and the naming bitmap.
		local
			b0, b1, pg, idx: INTEGER
		do
			b0 := buf [ptr].code
			b1 := buf [ptr + 1].code
			pg := name_start_pages [(b0 |>> 2) & 7].to_integer_32
			idx := (pg |<< 3) + ((b0 & 3) |<< 1) + ((b1 |>> 5) & 1)
			Result := (naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b1 & 0x1F))) /= 0
		end

	is_invalid_char_2 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- True for overlong sequences (b0 = 0xC0 or 0xC1 → code points U+0000..U+007F).
			-- The byte table maps 0xC0-0xDF all to BT_lead_2_byte; this check catches the two
			-- overlong lead bytes that the table does not exclude.
		do
			Result := buf [ptr].code < 0xC2
		end

feature -- Name-character predicates (3-byte UTF-8, U+0800..U+FFFF)

	is_name_char_3 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 3-byte sequence at ptr a valid XML NameChar?
		local
			b0, b1, b2, pg, idx: INTEGER
		do
			b0 := buf [ptr].code
			b1 := buf [ptr + 1].code
			b2 := buf [ptr + 2].code
			pg := name_pages [((b0 |<< 4) & 0x30) | (b1 |>> 4)].to_integer_32
			idx := (pg |<< 3) + ((b1 & 0xF) |<< 1) + ((b2 |>> 5) & 1)
			Result := (naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b2 & 0x1F))) /= 0
		end

	is_name_start_char_3 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 3-byte sequence at ptr a valid XML NameStartChar?
		local
			b0, b1, b2, pg, idx: INTEGER
		do
			b0 := buf [ptr].code
			b1 := buf [ptr + 1].code
			b2 := buf [ptr + 2].code
			pg := name_start_pages [((b0 |<< 4) & 0x30) | (b1 |>> 4)].to_integer_32
			idx := (pg |<< 3) + ((b1 & 0xF) |<< 1) + ((b2 |>> 5) & 1)
			Result := (naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b2 & 0x1F))) /= 0
		end

	is_invalid_char_3 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 3-byte sequence U+FFFE or U+FFFF (forbidden in XML)?
			-- These are the only forbidden 3-byte codepoints: 0xEF 0xBF 0xBE/0xBF.
		local
			b2: INTEGER
		do
			if buf [ptr].code = 0xEF and buf [ptr + 1].code = 0xBF then
				b2 := buf [ptr + 2].code
				Result := b2 = 0xBE or b2 = 0xBF
			end
		end

feature -- Name-character predicates (4-byte UTF-8, U+10000..U+10FFFF)

	is_name_char_4 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- 4-byte characters are not NameChars in XML 1.0.
		do
			Result := False
		end

	is_name_start_char_4 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- 4-byte characters are not NameStartChars in XML 1.0.
		do
			Result := False
		end

	is_invalid_char_4 (buf: SPECIAL [CHARACTER]; ptr: INTEGER): BOOLEAN
			-- Is the 4-byte sequence beyond U+10FFFF?
			-- Only b0=0xF4 can overflow; any b1 > 0x8F means cp > U+10FFFF.
		do
			Result := buf [ptr].code = 0xF4
				and buf [ptr + 1].code > 0x8F
		end

end
