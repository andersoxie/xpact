note
	description: "Incremental XML file parser"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:21:11 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XPACT_XML_FILE

inherit
	PLAIN_TEXT_FILE
		rename
			make as make_file
		export
			{NONE} all
			{ANY} off, bytes_read
		end

	XPACT_PARSE_CONSTANTS
		export
			{NONE} all
		end

create
	make

feature -- Initialization	

	make (fn: READABLE_STRING_GENERAL; a_parser: like parser; chunk_size: INTEGER)
		do
			make_with_name (fn)
			parser := a_parser
			create chunk.make_filled ('%U', chunk_size)
			if exists then
				open_read; read_line; close
				if last_string.has_substring ("ISO-8859-1") then
					parser.set_encoding (create {XPACT_LATIN1_ENCODING}.make)
				end
			end
		end

feature -- Access

	chunk: SPECIAL [CHARACTER]
		-- incremental chunk

	status: INTEGER
		-- one of `XPACT_PARSE_CONSTANTS' parse status constants

feature -- Basic operations

	parse
		local
			n: INTEGER
		do
			from open_read; status := Status_ok until off or status = Status_error loop
				read_chunk
				n := bytes_read
				if n > 0 then
					status := parser.parse (chunk, 0, n, off)
				end
			end
			close
		end

feature {NONE} -- implementation

	read_chunk
		require
			is_readable: file_readable
		local
			n: INTEGER
		do
			n := chunk.count
			bytes_read := file_gss (file_pointer, chunk.base_address, n)
		end

feature {NONE} -- Internal attributes

	parser: XPACT_INCREMENTAL_PARSER
end
