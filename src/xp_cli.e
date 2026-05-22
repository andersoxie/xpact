note
	description: "Small xpact command line target."

class
	XP_CLI

create
	make

feature {NONE} -- Initialization

	make
		local
			l_arguments: ARGUMENTS
		do
			create l_arguments
			if l_arguments.argument_count = 0 then
				run_smoke_parse
			elseif l_arguments.argument_count = 2 and then l_arguments.argument (1).same_string ("--parse-file") then
				run_file_parse (l_arguments.argument (2))
			else
				io.put_string ("usage: xpact [--parse-file PATH]%N")
				exit_with_code (2)
			end
		end

feature {NONE} -- Commands

	run_smoke_parse
			-- Run the built-in smoke parse.
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<xpact><phase n=%"1%">credible release</phase></xpact>")
			if l_ok then
				io.put_string ("xpact smoke parse: ok%N")
			else
				io.put_string ("xpact smoke parse: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
				exit_with_code (1)
			end
		end

	run_file_parse (a_path: READABLE_STRING_8)
			-- Parse XML document from `a_path'.
		require
			path_attached: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_text: detachable STRING_8
		do
			l_text := file_text (a_path)
			if l_text = Void then
				io.put_string ("xpact parse: cannot read file: ")
				io.put_string (a_path)
				io.put_new_line
				exit_with_code (2)
			else
				create l_handler.make
				create l_parser.make (l_handler)
				if l_parser.parse (l_text) then
					io.put_string ("xpact parse: ok%N")
				else
					io.put_string ("xpact parse: ")
					io.put_string (l_parser.last_error)
					io.put_new_line
					exit_with_code (1)
				end
			end
		end

feature {NONE} -- Files

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
					l_file.read_stream (8192)
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
