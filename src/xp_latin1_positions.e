note
	description: "Translates offsets in the UTF-8 parser input to the original ISO-8859-1 byte stream."

class
	XP_LATIN1_POSITIONS

create
	make

feature {NONE} -- Initialization

	make (a_source: STRING_8)
		do
			source := a_source
			create decoded_blocks.make (8)
			create normalized_blocks.make (8)
			decoded_blocks.extend (0)
			normalized_blocks.extend (0)
		end

feature -- Conversion

	raw_offset (a_offset: INTEGER; a_normalized: BOOLEAN): INTEGER
			-- Original byte offset for a boundary in the decoded UTF-8 stream.
			-- The core parser has also folded CRLF if `a_normalized'.
		require
			offset_nonnegative: a_offset >= 0
		local
			l_blocks: ARRAYED_LIST [INTEGER]
			l_low, l_high, l_mid, l_offset, l_next: INTEGER
			l_done: BOOLEAN
		do
			index_new_blocks
			if a_normalized then
				l_blocks := normalized_blocks
			else
				l_blocks := decoded_blocks
			end
			from
				l_low := 1
				l_high := l_blocks.count
			until
				l_low = l_high
			loop
				l_mid := (l_low + l_high + 1) // 2
				if l_blocks.i_th (l_mid) <= a_offset then
					l_low := l_mid
				else
					l_high := l_mid - 1
				end
			end
			Result := (l_low - 1) * Block_size
			l_offset := l_blocks.i_th (l_low)
			if a_normalized then
				if last_normalized_raw > Result and then last_normalized_offset <= a_offset then
					Result := last_normalized_raw
					l_offset := last_normalized_offset
				end
			elseif last_decoded_raw > Result and then last_decoded_offset <= a_offset then
				Result := last_decoded_raw
				l_offset := last_decoded_offset
			end
			from until Result = source.count or l_done loop
				l_next := l_offset + decoded_width (Result + 1)
				if a_normalized and then is_folded_lf (Result + 1) then
					l_next := l_offset
				end
				if l_next > a_offset then
					l_done := True
				else
					Result := Result + 1
					l_offset := l_next
				end
			end
			if a_normalized then
				last_normalized_raw := Result
				last_normalized_offset := l_offset
			else
				last_decoded_raw := Result
				last_decoded_offset := l_offset
			end
		ensure
			in_raw_input: 0 <= Result and Result <= source.count
		end

feature {NONE} -- Sparse index

	source: STRING_8
			-- The native parser's append-only byte buffer for this document.

	Block_size: INTEGER = 256

	decoded_blocks, normalized_blocks: ARRAYED_LIST [INTEGER]
			-- Offset after each complete block of raw input, beginning with zero.

	last_decoded_raw, last_decoded_offset: INTEGER
	last_normalized_raw, last_normalized_offset: INTEGER
			-- Recent lookups avoid rescanning a partial block on successive chunks.

	index_new_blocks
		local
			i, l_end, l_decoded, l_normalized, l_width: INTEGER
		do
			from
				i := (decoded_blocks.count - 1) * Block_size
				l_decoded := decoded_blocks.last
				l_normalized := normalized_blocks.last
			until
				source.count - i < Block_size
			loop
				from l_end := i + Block_size until i = l_end loop
					i := i + 1
					l_width := decoded_width (i)
					l_decoded := l_decoded + l_width
					if not is_folded_lf (i) then
						l_normalized := l_normalized + l_width
					end
				end
				decoded_blocks.extend (l_decoded)
				normalized_blocks.extend (l_normalized)
			end
		end

	decoded_width (i: INTEGER): INTEGER
		do
			if source.item (i).code <= 127 then
				Result := 1
			else
				Result := 2
			end
		end

	is_folded_lf (i: INTEGER): BOOLEAN
		do
			Result := source.item (i) = '%N' and then i > 1 and then source.item (i - 1) = '%R'
		end

end
