note
	description: "Constants ported from expat.h and xmlparse.c (libexpat 2.x)"
	notes: "[
		set ECF variable `buffer_size' to small to trigger 
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 8:36:47 GMT (Saturday 20th June 2026)"
	revision: "1"

class XPACT_BUFFER_CONSTANTS

feature -- Buffer parameters

	Context_bytes: INTEGER = 1024
		-- Bytes of parsed context retained before buffer_ptr for error reporting.
		-- Matches XML_CONTEXT_BYTES in xmlparse.c.

	Default_buffer_size: INTEGER = 4096
		-- Initial allocation for the internal parse buffer (INIT_BUFFER_SIZE).

end