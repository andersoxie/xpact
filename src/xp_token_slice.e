note
	description: "View over a contiguous token range in a shared 8-bit input buffer."

class
	XP_TOKEN_SLICE

create
	make,
	make_empty

feature {NONE} -- Initialization

	make (a_buffer: READABLE_STRING_8; a_start_index, a_count: INTEGER)
			-- Create a view over `a_count' characters of `a_buffer' at `a_start_index'.
		require
			buffer_attached: a_buffer /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_buffer.count + 1
			non_negative_count: a_count >= 0
			range_in_bounds: a_start_index + a_count - 1 <= a_buffer.count
		do
			buffer := a_buffer
			start_index := a_start_index
			count := a_count
		ensure
			buffer_set: buffer = a_buffer
			start_set: start_index = a_start_index
			count_set: count = a_count
		end

	make_empty (a_buffer: READABLE_STRING_8; a_start_index: INTEGER)
			-- Create an empty view at `a_start_index'.
		require
			buffer_attached: a_buffer /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_buffer.count + 1
		do
			buffer := a_buffer
			start_index := a_start_index
			count := 0
		ensure
			buffer_set: buffer = a_buffer
			start_set: start_index = a_start_index
			empty: is_empty
		end

feature -- Access

	buffer: READABLE_STRING_8
			-- Shared source buffer.

	start_index: INTEGER
			-- 1-based first character index in `buffer'.

	count: INTEGER
			-- Number of characters in this slice.

	end_index: INTEGER
			-- 1-based final character index in `buffer', or `start_index - 1' for empty slices.
		do
			Result := start_index + count - 1
		ensure
			definition: Result = start_index + count - 1
		end

	is_empty: BOOLEAN
			-- Does this slice contain no characters?
		do
			Result := count = 0
		ensure
			definition: Result = (count = 0)
		end

	item (i: INTEGER): CHARACTER_8
			-- Character at 1-based slice index `i'.
		require
			valid_index: i >= 1 and i <= count
		do
			Result := buffer.item (start_index + i - 1)
		end

	to_string_8: STRING_8
			-- Owned string containing this slice's text.
		do
			create Result.make (count)
			append_to (Result)
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = count
			content_preserved: same_string (Result)
		end

	substring (a_start_index, a_end_index: INTEGER): STRING_8
			-- Owned string for slice-relative range `a_start_index' .. `a_end_index'.
		require
			valid_start: a_start_index >= 1 and a_start_index <= count + 1
			valid_end: a_end_index >= a_start_index - 1 and a_end_index <= count
		local
			i: INTEGER
		do
			create Result.make (a_end_index - a_start_index + 1)
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				i > a_end_index
			loop
				Result.append_character (item (i))
				i := i + 1
			variant
				a_end_index - i + 1
			end
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = a_end_index - a_start_index + 1
		end

	subslice (a_start_index, a_count: INTEGER): XP_TOKEN_SLICE
			-- Slice-relative view beginning at `a_start_index' with `a_count' characters.
		require
			valid_start: a_start_index >= 1 and a_start_index <= count + 1
			non_negative_count: a_count >= 0
			range_in_bounds: a_start_index + a_count - 1 <= count
		do
			create Result.make (buffer, start_index + a_start_index - 1, a_count)
		ensure
			result_attached: Result /= Void
			same_buffer: Result.buffer = buffer
			start_set: Result.start_index = start_index + a_start_index - 1
			count_set: Result.count = a_count
		end

	hash_code: INTEGER
			-- Hash code equivalent to the owned string representation.
		do
			Result := to_string_8.hash_code
		ensure
			non_negative: Result >= 0
		end

feature -- Comparison

	same_string (a_text: READABLE_STRING_8): BOOLEAN
			-- Does this slice contain the same characters as `a_text'?
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			if a_text.count = count then
				from
					Result := True
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= count + 1
				until
					i > count or not Result
				loop
					Result := item (i) = a_text.item (i)
					i := i + 1
				variant
					count - i + 1
				end
			end
		end

	same_slice (a_other: XP_TOKEN_SLICE): BOOLEAN
			-- Does this slice contain the same characters as `a_other'?
		require
			other_attached: a_other /= Void
		local
			i: INTEGER
		do
			if a_other.count = count then
				from
					Result := True
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= count + 1
				until
					i > count or not Result
				loop
					Result := item (i) = a_other.item (i)
					i := i + 1
				variant
					count - i + 1
				end
			end
		end

	same_range (a_buffer: READABLE_STRING_8; a_start_index, a_count: INTEGER): BOOLEAN
			-- Does this slice contain the same characters as `a_buffer' range?
		require
			buffer_attached: a_buffer /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_buffer.count + 1
			non_negative_count: a_count >= 0
			range_in_bounds: a_start_index + a_count - 1 <= a_buffer.count
		local
			i: INTEGER
		do
			if a_count = count then
				from
					Result := True
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= count + 1
				until
					i > count or not Result
				loop
					Result := item (i) = a_buffer.item (a_start_index + i - 1)
					i := i + 1
				variant
					count - i + 1
				end
			end
		end

	starts_with (a_prefix: READABLE_STRING_8): BOOLEAN
			-- Does this slice begin with `a_prefix'?
		require
			prefix_attached: a_prefix /= Void
		local
			i: INTEGER
		do
			if a_prefix.count <= count then
				from
					Result := True
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= a_prefix.count + 1
				until
					i > a_prefix.count or not Result
				loop
					Result := item (i) = a_prefix.item (i)
					i := i + 1
				variant
					a_prefix.count - i + 1
				end
			end
		end

feature -- Output

	append_to (a_target: STRING_8)
			-- Append this slice's text to `a_target'.
		require
			target_attached: a_target /= Void
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= count + 1
			until
				i > count
			loop
				a_target.append_character (item (i))
				i := i + 1
			variant
				count - i + 1
			end
		ensure
			count_added: a_target.count = old a_target.count + count
		end

invariant
	buffer_attached: buffer /= Void
	valid_start: start_index >= 1 and start_index <= buffer.count + 1
	non_negative_count: count >= 0
	range_in_bounds: start_index + count - 1 <= buffer.count

end
