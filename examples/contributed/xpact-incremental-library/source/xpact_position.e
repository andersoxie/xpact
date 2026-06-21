note
	description: "[
		Line and column tracking within the input stream.
		Corresponds to the POSITION struct in xmltok.h.

		Both counts are zero-based to match the C original.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-17 6:29:23 GMT (Wednesday 17th June 2026)"
	revision: "1"

class XPACT_POSITION

create make

feature {NONE} -- Initialisation

	make
		do
		end

feature -- State

	line_number: INTEGER_64

	column_number: INTEGER_64

feature -- Status report

	is_at_start: BOOLEAN
		do
			Result := line_number = 0 and column_number = 0
		end

feature -- Element change

	advance_line
		do
			line_number := line_number + 1; column_number := 0
		end

	advance_column
		do
			column_number := column_number + 1
		end

	reset
		do
			line_number := 0; column_number := 0
		end

end