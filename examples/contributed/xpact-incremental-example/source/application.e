note
	description: "[
		Entry point for the xpact-incremental example.

		Reads an XML file named on the command line and prints each XML
		event to standard output via XPACT_XML_PRINTER.

		Usage:
			xpact_example <operation> <xml-file> [-chunk_size <value>]")
			
		Valid operations: {print, count_tags}

	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:21:11 GMT (Saturday 20th June 2026)"
	revision: "1"

class APPLICATION

inherit
	XPACT_PARSE_CONSTANTS

	ARGUMENTS_32
		export
			{NONE} all
		end

create make

feature {NONE} -- Initialisation

	make
		local
			file: PLAIN_TEXT_FILE
		do
			if argument_count >= 2
				and then attached argument (1).to_string_8 as task
				and then attached argument (2).to_string_8 as file_path
				and then Task_type.has (task)
			then
				create file.make_with_name (file_path)
				if file.exists then
					do_task (task, file_path)
				else
					io.put_string ("File not found: " + file_path + "%N")
				end
			else
				put_usage
			end
		end

feature {NONE} -- Implementation

	chunk_size: INTEGER
		local
			i: INTEGER
		do
			i := index_of_word_option ("chunk_size")
			if i > 0 then
				Result := argument (i + 1).to_integer_32
			else
				Result := Default_chunk_size
			end
		end

	compile: TUPLE [XPACT_ASCII_ENCODING, XPACT_LATIN1_ENCODING]
		do
			create Result
		end

	do_task (task, file_path: STRING)
		local
			file: XPACT_XML_FILE; parser: XPACT_INCREMENTAL_PARSER
			time: C_DATE; millisecond_then: INTEGER
		do
			if task ~ Task_type [1] then
				create {XPACT_TAG_COUNTER} parser.make
			else
				create {XPACT_XML_PRINTER} parser.make
			end

			create file.make (file_path, parser, chunk_size)

			if file.is_readable then
				IO.put_string ("Parsing: " + file_path)
				IO.put_new_line
				create time
				millisecond_then := time.millisecond_now
				Memory.collection_off
				file.parse
				Memory.collection_on
				Memory.full_collect

				time.update
				io.put_string ("Parsing time: "); io.put_integer (time.millisecond_now - millisecond_then)
				io.put_string (" ms")
				io.put_new_line
				if file.status = Status_error then
					io.put_string ("Parse error code: " + parser.error_code.out)

				elseif attached {XPACT_TAG_COUNTER} parser as counter then
					counter.print_stats
				end
				IO.put_new_line; IO.put_new_line
			else
				io.put_string ("Cannot read: " + file_path)
				io.put_new_line
			end
		end

	put_usage
		do
			io.put_string ("Usage: xpact_example <operation> <xml-file> [-chunk_size <value>]")
			io.put_string ("Valid operations: {count_tags, print}")
			io.put_string ("OPTIONAL: -chunk_size. Defaults to: ")
			io.put_integer (Default_chunk_size)
			io.put_new_line
		end

feature {NONE} -- Constants

	Task_type: ARRAY [STRING]
		once
			Result := << "count_tags", "print" >>
			Result.compare_objects
		end

	Default_chunk_size: INTEGER = 4096

	Memory: MEMORY
		once
			create Result
		end

end
