note
	description: "Build and identity smoke probe for the local xpact implementation."

class
	XPACT_PROBE_ROOT

inherit
	XP_BUILD_IDENTITY
	XP_EVENT_HANDLER

create
	make

feature {NONE} -- Initialization

	make
		local
			parser: XP_PARSER
			exceptions: EXCEPTIONS
		do
			create observed_text.make_empty
			create parser.make (Current)
			if parser.parse ("<root>probe</root>") and then start_count = 1 and then end_count = 1
				and then correct_names and then observed_text.same_string ("probe")
			then
				io.put_string ("XPACT_BUILD_PROBE%T" + implementation_id + "%T" + source_revision + "%T" + build_configuration + "%TOK%N")
			else
				io.error.put_string ("xpact build probe failed: " + parser.last_error + "%N")
				create exceptions
				exceptions.die (1)
			end
		end

feature -- Events

	on_start_element (name: READABLE_STRING_8; attributes: XP_ATTRIBUTES)
		do
			start_count := start_count + 1
			correct_names := name.same_string ("root")
		end

	on_end_element (name: READABLE_STRING_8)
		do
			end_count := end_count + 1
			correct_names := correct_names and name.same_string ("root")
		end

	on_character_data (text: READABLE_STRING_8)
		do
			observed_text.append (text)
		end

feature {NONE} -- Probe observations

	start_count, end_count: INTEGER

	correct_names: BOOLEAN

	observed_text: STRING_8

end
