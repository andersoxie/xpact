note
	description: "Constants ported from expat.h and xmlparse.c (libexpat 2.x)"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 8:30:39 GMT (Saturday 20th June 2026)"
	revision: "1"

class XPACT_BUFFER_CONSTANTS

feature -- Buffer parameters

	Context_bytes: INTEGER = 32 -- Small for testing `shift_buffer_left'
		-- Bytes of parsed context retained before buffer_ptr for error reporting.
		-- Matches XML_CONTEXT_BYTES in xmlparse.c.

	Default_buffer_size: INTEGER = 256 -- Small for testing `shift_buffer_left'
		-- Initial allocation for the internal parse buffer (INIT_BUFFER_SIZE).

end