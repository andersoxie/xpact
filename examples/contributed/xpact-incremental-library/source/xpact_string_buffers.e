note
	description: "String buffering"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:30:45 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class
	XPACT_STRING_BUFFERS

inherit
	XPACT_BUFFER_CONSTANTS

	STRING_HANDLER

feature {NONE} -- Initialisation

	make
		do
			buffer := new_buffer_area (Default_buffer_size)
			create name_cache.make
			create comment_string.make_shared (default_pointer, 0)
			create attribute_list.make (5)
			create output_buffer.make (10)
			create text_data_intervals.make (5)
		ensure
			empty_buffer: buffer_end = 0 and buffer_index = 0
		end

feature {NONE} -- Implementation

	adjusted_concatenation (text_intervals: EL_ARRAYED_INTERVAL_LIST): STRING_8
		-- concatenated `text_intervals' substrings found in `buffer'
		-- Trims leading and trailing white space and first and last intervals
		local
			i, j, lower, upper: INTEGER; c_i: CHARACTER; first_copied: BOOLEAN
		do
			Result := output_buffer
			Result.wipe_out
			Result.grow (text_intervals.count_sum)
			if attached buffer as buf and then attached Result.area as area_out then
				j := 0
				across text_intervals as interval loop
					lower := interval.lower; upper := interval.upper
					from i := lower until i > upper loop
						c_i := buf [i]
						if not first_copied then
							first_copied := not c_i.is_space
						end
						if first_copied then
							area_out [j] := c_i
							j := j + 1
						end
						i := i + 1
					end
				end
				Result.set_count (j)
				Result.right_adjust
			end
		ensure
			is_text_buffer: Result = output_buffer
		end

	buffer_name (buf: like buffer; tok_start, offset: INTEGER): STRING_8
		local
			name_start, name_count: INTEGER
		do
			name_start := tok_start + offset
			name_count := encoding.name_length (buf, name_start)
			Result := name_cache.item (buf, name_start, name_start + name_count - 1)
		end

	buffer_substring (lower, upper: INTEGER): STRING_8
		-- `lower .. upper' substring of `buffer' placed in `output_buffer'
		local
			count, i: INTEGER
		do
			Result := output_buffer
			Result.wipe_out
			count := upper - lower + 1
			Result.grow (count)
			if attached buffer as buf and then attached Result.area as area_out then
				from i := 0 until i = count loop
					area_out [i] := buf [i + lower]
					i := i + 1
				end
				Result.set_count (i)
			end
		ensure
			is_text_buffer: Result = output_buffer
		end

	is_null_terminated (text: C_STRING_8): BOOLEAN
		local
			c: CHARACTER
		do
			(text.area + text.count).memory_copy ($c, 1)
			Result := c = '%U'
		end

	new_buffer_area (n: INTEGER): like buffer
		do
			create Result.make_filled ('%U', n + 1)
		ensure
			room_for_null_terminator: Result.count = n + 1
		end

feature {NONE} -- Deferred

	encoding: XPACT_NORMAL_ENCODING
		deferred
		end

feature {NONE} -- Internal attributes

	buffer_end: INTEGER
		-- Index one past the last valid data byte in `buffer'

	buffer_index: INTEGER
		-- Index of the first unprocessed byte in `buffer'

	parse_end_index: INTEGER
		-- Snapshot of buffer_end taken at the top of each parse call.

feature {NONE} -- Internal structures

	buffer: SPECIAL [CHARACTER_8]
		-- Raw byte buffer; do not modify indices outside this class.

	attribute_list: XPACT_ATTRIBUTE_LIST
		-- collected attribute buffer

	output_buffer: STRING_8
		-- used to accumulate text for output

	text_data_intervals: EL_ARRAYED_INTERVAL_LIST
		-- list of substring intervals `lower .. upper' of `buffer' text

	name_cache: XPACT_NAME_CACHE
		-- efficient lookup of attribute/

	comment_string: C_STRING_8
		-- shared substring of text `buffer'

end
