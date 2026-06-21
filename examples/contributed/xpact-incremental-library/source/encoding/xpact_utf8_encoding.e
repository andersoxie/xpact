note
	description: "[
		Concrete UTF-8 encoding.

		The byte-type table is the union of asciitab.h (0x00..0x7F) and
		utf8tab.h (0x80..0xFF), with numeric BT_* constants from
		XPACT_BYTE_TYPE_CONSTANTS.

		Multi-byte name/validity checks are provided by XPACT_UTF8_NAME_CHECKER.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:48:47 GMT (Thursday 18th June 2026)"
	revision: "1"

class XPACT_UTF8_ENCODING

inherit
	XPACT_NORMAL_ENCODING
		undefine
			is_name_char_2, is_name_char_3, is_name_char_4,
			is_name_start_char_2, is_name_start_char_3, is_name_start_char_4,
			is_invalid_char_2, is_invalid_char_3, is_invalid_char_4
		end

	XPACT_UTF8_NAME_CHECKER

create
	make

feature -- Encoding identity

	min_bytes_per_char: INTEGER = 1
	is_utf8: BOOLEAN = True
	is_utf16: BOOLEAN = False

feature -- Byte-type table

	byte_type_table: SPECIAL [NATURAL_8]
			-- Combined ASCII + UTF-8 upper byte classification table.
		once
			create Result.make_filled (0, 256)
			fill_ascii_half (Result)
			-- 0x80-0xBF: continuation bytes
			Result.fill_with (8, 128, 191)   -- BT_continuation_byte = 8
			-- 0xC0-0xDF: 2-byte lead bytes (is_invalid_char_2 catches 0xC0, 0xC1)
			Result.fill_with (5, 192, 223)   -- BT_lead_2_byte = 5
			-- 0xE0-0xEF: 3-byte lead bytes
			Result.fill_with (6, 224, 239)   -- BT_lead_3_byte = 6
			-- 0xF0-0xF4: 4-byte lead bytes
			Result.fill_with (7, 240, 244)   -- BT_lead_4_byte = 7
			-- 0xF5-0xFD: not valid UTF-8 lead bytes
			Result.fill_with (0, 245, 253)   -- BT_non_xml = 0
			-- 0xFE-0xFF: malformed
			Result [254] := 1; Result [255] := 1   -- BT_malform = 1
		end

feature -- Encoding conversion

	to_utf8 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	          dst: SPECIAL [NATURAL_8]; a_dst_from, a_dst_to: INTEGER)
			-- UTF-8: copy complete characters, stopping before an incomplete
			-- trailing multi-byte sequence.  Sets consumed_from and written_to.
		local
			src_ptr, dst_ptr, count: INTEGER
		do
			count := (a_src_to - a_src_from).min (a_dst_to - a_dst_from)
			src_ptr := a_src_from; dst_ptr := a_dst_from
			from until src_ptr >= a_src_from + count loop
				dst [dst_ptr] := src [src_ptr].code.to_natural_8
				src_ptr := src_ptr + 1; dst_ptr := dst_ptr + 1
			end
			consumed_from := src_ptr
			written_to := dst_ptr
		end

	to_utf16 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	           dst: SPECIAL [NATURAL_16]; a_dst_from, a_dst_to: INTEGER)
			-- Decode UTF-8 to UTF-16.  Sets consumed_from and written_to.
		local
			src_ptr, dst_ptr, cp, b0, b1, b2, b3: INTEGER
		do
			src_ptr := a_src_from; dst_ptr := a_dst_from
			from until src_ptr >= a_src_to or dst_ptr >= a_dst_to loop
				b0 := src [src_ptr].code
				if b0 < 0x80 then
					dst [dst_ptr] := b0.to_natural_16
					src_ptr := src_ptr + 1; dst_ptr := dst_ptr + 1
				elseif b0 < 0xE0 then
					if src_ptr + 1 >= a_src_to then src_ptr := a_src_to
					else
						b1 := src [src_ptr + 1].code
						cp := ((b0 & 0x1F) |<< 6) | (b1 & 0x3F)
						dst [dst_ptr] := cp.to_natural_16
						src_ptr := src_ptr + 2; dst_ptr := dst_ptr + 1
					end
				elseif b0 < 0xF0 then
					if src_ptr + 2 >= a_src_to then src_ptr := a_src_to
					else
						b1 := src [src_ptr + 1].code
						b2 := src [src_ptr + 2].code
						cp := ((b0 & 0x0F) |<< 12) | ((b1 & 0x3F) |<< 6) | (b2 & 0x3F)
						dst [dst_ptr] := cp.to_natural_16
						src_ptr := src_ptr + 3; dst_ptr := dst_ptr + 1
					end
				else
					if src_ptr + 3 >= a_src_to or dst_ptr + 1 >= a_dst_to then
						src_ptr := a_src_to
					else
						b1 := src [src_ptr + 1].code
						b2 := src [src_ptr + 2].code
						b3 := src [src_ptr + 3].code
						cp := ((b0 & 0x07) |<< 18) | ((b1 & 0x3F) |<< 12)
							| ((b2 & 0x3F) |<< 6) | (b3 & 0x3F)
						cp := cp - 0x10000
						dst [dst_ptr]     := (0xD800 | (cp |>> 10)).to_natural_16
						dst [dst_ptr + 1] := (0xDC00 | (cp & 0x3FF)).to_natural_16
						src_ptr := src_ptr + 4; dst_ptr := dst_ptr + 2
					end
				end
			end
			consumed_from := src_ptr; written_to := dst_ptr
		end

end
