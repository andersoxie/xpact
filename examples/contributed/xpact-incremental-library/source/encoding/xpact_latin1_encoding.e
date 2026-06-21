note
	description: "[
		Concrete Latin-1 (ISO 8859-1) encoding.

		The byte-type table is the union of asciitab.h (0x00..0x7F) and
		latin1tab.h (0x80..0xFF).  There are no multi-byte sequences so
		all is_name_char_2/3/4 predicates return False.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:02:11 GMT (Thursday 18th June 2026)"
	revision: "1"

class XPACT_LATIN1_ENCODING

inherit
	XPACT_NORMAL_ENCODING

create make

feature -- Encoding identity

	min_bytes_per_char: INTEGER = 1
	is_utf8: BOOLEAN = False
	is_utf16: BOOLEAN = False

feature -- Byte-type table

	byte_type_table: SPECIAL [NATURAL_8]
			-- Combined ASCII + Latin-1 byte classification table.
		once
			create Result.make_filled (0, 256)
			fill_ascii_half (Result)
			-- 0x80-0xA9: BT_other = 28
			Result.fill_with (28, 128, 169)
			Result [170] := 22   -- BT_name_start ª
			Result.fill_with (28, 171, 180)
			Result [181] := 22   -- BT_name_start µ
			Result [182] := 28   -- BT_other ¶
			Result [183] := 26   -- BT_name_only · (middle dot, name-only char)
			Result [184] := 28   -- BT_other ¸
			Result [185] := 28   -- BT_other ¹
			Result [186] := 22   -- BT_name_start º
			Result.fill_with (28, 187, 191)
			-- 0xC0-0xD6: BT_name_start
			Result.fill_with (22, 192, 214)
			Result [215] := 28   -- BT_other × (multiplication sign)
			-- 0xD8-0xF6: BT_name_start
			Result.fill_with (22, 216, 246)
			Result [247] := 28   -- BT_other ÷ (division sign)
			-- 0xF8-0xFF: BT_name_start
			Result.fill_with (22, 248, 255)
		end
		
feature -- Encoding conversion

	to_utf8 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	          dst: SPECIAL [NATURAL_8]; a_dst_from, a_dst_to: INTEGER)
			-- Latin-1 to UTF-8 transcoding.  Sets consumed_from and written_to.
		local
			src_ptr, dst_ptr, b: INTEGER
		do
			src_ptr := a_src_from; dst_ptr := a_dst_from
			from until src_ptr >= a_src_to or dst_ptr >= a_dst_to loop
				b := src [src_ptr].code
				if b < 0x80 then
					dst [dst_ptr] := b.to_natural_8
					dst_ptr := dst_ptr + 1
				elseif dst_ptr + 1 < a_dst_to then
					dst [dst_ptr]     := (0xC0 | (b |>> 6)).to_natural_8
					dst [dst_ptr + 1] := (0x80 | (b & 0x3F)).to_natural_8
					dst_ptr := dst_ptr + 2
				else
					src_ptr := a_src_to  -- no room; stop
				end
				src_ptr := src_ptr + 1
			end
			consumed_from := src_ptr; written_to := dst_ptr
		end

	to_utf16 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	           dst: SPECIAL [NATURAL_16]; a_dst_from, a_dst_to: INTEGER)
			-- Latin-1 to UTF-16: each byte is its code point (U+0000..U+00FF).
		local
			src_ptr, dst_ptr: INTEGER
		do
			src_ptr := a_src_from; dst_ptr := a_dst_from
			from until src_ptr >= a_src_to or dst_ptr >= a_dst_to loop
				dst [dst_ptr] := src [src_ptr].code.to_natural_16
				src_ptr := src_ptr + 1; dst_ptr := dst_ptr + 1
			end
			consumed_from := src_ptr; written_to := dst_ptr
		end

end
