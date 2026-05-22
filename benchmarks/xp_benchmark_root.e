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
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_input := sample_document
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= Iterations + 1
			until
				i > Iterations
			loop
				l_ok := l_parser.parse (l_input)
				if not l_ok then
					io.put_string ("benchmark parse failed: ")
					io.put_string (l_parser.last_error)
					io.put_new_line
					i := Iterations + 1
				else
					i := i + 1
				end
			variant
				Iterations - i + 1
			end
			if l_ok then
				io.put_string ("xpact benchmark harness parsed ")
				io.put_integer (Iterations)
				io.put_string (" documents with contracts enabled.%N")
			end
		end

feature {NONE} -- Data

	Iterations: INTEGER = 1000

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
