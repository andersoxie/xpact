note
	description: "Simple benchmark harness for the Phase 1 parser."

class
	XP_BENCHMARK_ROOT

inherit
	XP_LIMITS

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
			l_suspend_gc: BOOLEAN
		do
			l_iterations := iteration_count
			l_suspend_gc := suspend_gc_during_parse
			l_input := input_document
			create l_handler.make
			create l_parser.make_with_limits (l_handler, input_limit_for (l_input.count), Default_max_element_depth, Default_max_attribute_count, Default_max_token_length)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_iterations + 1
			until
				i > l_iterations
			loop
				if l_suspend_gc then
					l_ok := l_parser.parse_without_garbage_collection (l_input)
				else
					l_ok := l_parser.parse (l_input)
				end
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
				io.put_string (" documents.%N")
			end
		end

feature {NONE} -- Data

	Default_iterations: INTEGER = 1000

	iteration_count: INTEGER
			-- Requested iteration count, or the default.
		local
			l_arguments: ARGUMENTS
			i: INTEGER
		do
			Result := Default_iterations
			create l_arguments
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_arguments.argument_count + 1
			until
				i > l_arguments.argument_count
			loop
				if l_arguments.argument (i).same_string ("--iterations") and then i < l_arguments.argument_count then
					if l_arguments.argument (i + 1).is_integer then
						Result := l_arguments.argument (i + 1).to_integer
						if Result <= 0 then
							Result := Default_iterations
						end
					end
					i := i + 2
				else
					i := i + 1
				end
			variant
				l_arguments.argument_count - i + 1
			end
		ensure
			positive: Result > 0
		end

	suspend_gc_during_parse: BOOLEAN
			-- Should the benchmark suspend garbage collection during each parse?
		local
			l_arguments: ARGUMENTS
			i: INTEGER
		do
			create l_arguments
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_arguments.argument_count + 1
			until
				i > l_arguments.argument_count or Result
			loop
				Result := l_arguments.argument (i).same_string ("--suspend-gc")
				i := i + 1
			variant
				l_arguments.argument_count - i + 1
			end
		end

	input_document: STRING_8
			-- Benchmark input document.
		local
			l_file_text: detachable STRING_8
		do
			if attached file_argument as l_path then
				l_file_text := file_text (l_path)
				if attached l_file_text as l_text then
					Result := l_text
				else
					io.put_string ("benchmark cannot read XML file: ")
					io.put_string (l_path)
					io.put_new_line
					exit_with_code (2)
					create Result.make_empty
				end
			else
				Result := sample_document
			end
		ensure
			result_attached: Result /= Void
		end

	file_argument: detachable STRING_8
			-- `--file' argument value, if provided.
		local
			l_arguments: ARGUMENTS
			i: INTEGER
		do
			create l_arguments
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_arguments.argument_count + 1
			until
				i > l_arguments.argument_count or Result /= Void
			loop
				if l_arguments.argument (i).same_string ("--file") and then i < l_arguments.argument_count then
					create Result.make_from_string (l_arguments.argument (i + 1))
					i := l_arguments.argument_count + 1
				else
					i := i + 1
				end
			variant
				l_arguments.argument_count - i + 1
			end
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

	input_limit_for (a_byte_count: INTEGER): INTEGER
			-- Parser input limit for a benchmark document of `a_byte_count' bytes.
		require
			non_negative: a_byte_count >= 0
		do
			if a_byte_count > Default_max_input_bytes then
				Result := a_byte_count
			else
				Result := Default_max_input_bytes
			end
		ensure
			large_enough: Result >= a_byte_count
		end

	file_text (a_path: READABLE_STRING_8): detachable STRING_8
			-- Entire contents of `a_path', if readable.
		require
			path_attached: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_file: PLAIN_TEXT_FILE
		do
			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.is_readable then
				create Result.make_empty
				l_file.open_read
				from
				invariant
					result_attached: Result /= Void
				until
					l_file.end_of_file
				loop
					l_file.read_stream (65536)
					Result.append (l_file.last_string)
				end
				l_file.close
			end
		end

	exit_with_code (a_code: INTEGER)
			-- End process with `a_code'.
		require
			non_negative: a_code >= 0
		local
			l_exceptions: EXCEPTIONS
		do
			create l_exceptions
			l_exceptions.die (a_code)
		end

end
