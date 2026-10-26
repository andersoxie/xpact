note
	description: "Build and identity smoke probe for the pinned Xpact-core implementation."

class
	XPACT_CORE_PROBE_ROOT

inherit
	XP_BUILD_IDENTITY
	XT_PARSE_CONSTANTS
	XT_PARSE_ERROR_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make
		local
			parser: XPACT_CORE_PROBE_PARSER
			parse_data: XT_PARSER_DATA
			input: XT_UTF_8_CODEC
			memory: MEMORY
			exceptions: EXCEPTIONS
			was_collecting: BOOLEAN
			parse_status: INTEGER
		do
			create memory
			was_collecting := memory.collecting
			create parse_data.make_default
			create parser.make (parse_data)
			create input.make_from_string ("<root>probe</root>")
			parse_status := parser.parse (input, True)
			restore_collection (memory, was_collecting)
			if parse_status = Status_ok and then parser.error_code = Error_none
				and then parser.start_count = 1 and then parser.end_count = 1
				and then parser.correct_names and then parser.observed_text.same_string ("probe")
			then
				io.put_string ("XPACT_BUILD_PROBE%T" + implementation_id + "%T" + source_revision + "%T" + build_configuration + "%TOK%N")
			else
				io.error.put_string ("xpact-core build probe failed: " + parser.error_description + "%N")
				create exceptions
				exceptions.die (1)
			end
		rescue
			if memory /= Void then
				restore_collection (memory, was_collecting)
			end
		end

	restore_collection (memory: MEMORY; was_collecting: BOOLEAN)
			-- The upstream parser changes collection policy internally.
		do
			if was_collecting then
				memory.collection_on
			else
				memory.collection_off
			end
		end

end
