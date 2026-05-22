note
	description: "Simple benchmark harness for the Phase 1 parser."

class
	XP_BENCHMARK_ROOT

create
	make

feature {NONE} -- Initialization

	make
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_input: STRING_8
			i: INTEGER
			l_ok: BOOLEAN
			l_iterations: INTEGER
		do
			l_iterations := iteration_count
			create l_handler.make
			create l_parser.make (l_handler)
			l_input := sample_document
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_iterations + 1
			until
				i > l_iterations
			loop
				l_ok := l_parser.parse (l_input)
				if not l_ok then
					io.put_string ("benchmark parse failed: ")
					io.put_string (l_parser.last_error)
					io.put_new_line
					i := l_iterations + 1
				else
					i := i + 1
				end
			variant
				l_iterations - i + 1
			end
			if l_ok then
				io.put_string ("xpact benchmark harness parsed ")
				io.put_integer (l_iterations)
				io.put_string (" documents with contracts enabled.%N")
			end
		end

feature {NONE} -- Data

	Default_iterations: INTEGER = 1000

	iteration_count: INTEGER
			-- Requested iteration count, or the default.
		local
			l_arguments: ARGUMENTS
		do
			Result := Default_iterations
			create l_arguments
			if l_arguments.argument_count = 2 and then l_arguments.argument (1).same_string ("--iterations") then
				if l_arguments.argument (2).is_integer then
					Result := l_arguments.argument (2).to_integer
					if Result <= 0 then
						Result := Default_iterations
					end
				end
			end
		ensure
			positive: Result > 0
		end

	sample_document: STRING_8
		local
			i: INTEGER
		do
			create Result.make_from_string ("<catalog>")
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= 101
			until
				i > 100
			loop
				Result.append ("<item id=%"")
				Result.append_integer (i)
				Result.append ("%">value</item>")
				i := i + 1
			variant
				101 - i
			end
			Result.append ("</catalog>")
		ensure
			result_attached: Result /= Void
			not_empty: not Result.is_empty
		end

end
