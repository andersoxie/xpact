note
	description: "Where a scan for the end of a DOCTYPE declaration stopped, so that it can go on when more input arrives."

class
	XP_DOCTYPE_SCAN

create
	make

feature {NONE} -- Initialization

	make
			-- Create a scan that has not started.
		do
			reset (0)
		ensure
			not_started: start_index = 0
		end

feature -- Access

	start_index: INTEGER
			-- Index of the `<!DOCTYPE' this scan belongs to, or 0.

	next_index: INTEGER
			-- Next byte to inspect.

	depth: INTEGER
			-- Internal subset bracket depth at `next_index'.

	in_quote: BOOLEAN
			-- Is `next_index' inside a quoted literal?

	quote: CHARACTER_8
			-- Quote that ends the current literal.

	scanned_count: INTEGER
			-- Input count when the scan last stopped.

feature -- Element change

	reset (a_start_index: INTEGER)
			-- Start over for the `<!DOCTYPE' at `a_start_index'.
		require
			non_negative_start: a_start_index >= 0
		do
			start_index := a_start_index
			next_index := a_start_index + 9
			depth := 0
			in_quote := False
			quote := '%U'
			scanned_count := 0
		ensure
			start_set: start_index = a_start_index
			at_body: next_index = a_start_index + 9
			outside_subset: depth = 0 and not in_quote
		end

	stop_at (a_index, a_depth: INTEGER; a_in_quote: BOOLEAN; a_quote: CHARACTER_8; a_count: INTEGER)
			-- Remember that the scan stopped at `a_index' after seeing `a_count' bytes.
		require
			index_after_start: a_index >= start_index + 9
			non_negative_depth: a_depth >= 0
		do
			next_index := a_index
			depth := a_depth
			in_quote := a_in_quote
			quote := a_quote
			scanned_count := a_count
		ensure
			index_set: next_index = a_index
			depth_set: depth = a_depth
			count_set: scanned_count = a_count
		end

end
