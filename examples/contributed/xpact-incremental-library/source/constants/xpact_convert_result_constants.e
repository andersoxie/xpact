note
	description: "Result codes for encoding conversion (XML_Convert_Result from xmltok.h)"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-15 18:46:40 GMT (Monday 15th June 2026)"
	revision: "1"

class XPACT_CONVERT_RESULT_CONSTANTS

feature -- Conversion results

	Convert_completed:        INTEGER = 0  -- all input consumed, all output written
	Convert_input_incomplete: INTEGER = 1  -- partial multibyte char at end of input
	Convert_output_exhausted: INTEGER = 2  -- output buffer full; input may remain

end