note
	description: "[
		Concrete ASCII encoding.

		Identical to XPACT_LATIN1_ENCODING for the lower 128 bytes;
		all upper bytes (0x80..0xFF) are BT_non_xml (not valid in ASCII XML).
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-18 19:02:35 GMT (Thursday 18th June 2026)"
	revision: "1"

class XPACT_ASCII_ENCODING

inherit
	XPACT_NORMAL_ENCODING

create make

feature -- Encoding identity

	min_bytes_per_char: INTEGER = 1

	is_utf8: BOOLEAN = False
	is_utf16: BOOLEAN = False

feature -- Byte-type table

	byte_type_table: SPECIAL [NATURAL_8]
			-- ASCII table: lower half from asciitab.h, upper half all BT_non_xml.
		once
			create Result.make_filled (0, 256)  -- 0 = BT_non_xml covers 0x80-0xFF
			fill_ascii_half (Result)
		end

feature -- Encoding conversion

	to_utf8 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	          dst: SPECIAL [NATURAL_8]; a_dst_from, a_dst_to: INTEGER)
			-- ASCII to UTF-8: identical bytes (all code points < 0x80).
		local
			count, src_ptr, dst_ptr: INTEGER
		do
			count := (a_src_to - a_src_from).min (a_dst_to - a_dst_from)
			from src_ptr := a_src_from; dst_ptr := a_dst_from until src_ptr >= a_src_from + count loop
				dst [dst_ptr] := src [src_ptr].code.to_natural_8
				src_ptr := src_ptr + 1; dst_ptr := dst_ptr + 1
			end
			consumed_from := a_src_from + count
			written_to    := a_dst_from + count
		end

	to_utf16 (src: SPECIAL [CHARACTER]; a_src_from, a_src_to: INTEGER;
	           dst: SPECIAL [NATURAL_16]; a_dst_from, a_dst_to: INTEGER)
			-- ASCII to UTF-16.
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
