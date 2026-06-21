note
	description: "Default events for implementing ${XPACT_INCREMENTAL_PARSER}"
	notes: "[
		**EXAMPLE CODE**
		
			inherit
				XPACT_INCREMENTAL_PARSER

				XPACT_DEFAULT_PARSE_EVENTS
					rename
						on_comment_ as on_comment,
						on_content_ as on_content,
						on_tag_attributes as on_tag_attributes,
						on_tag_end_ as on_tag_end
					end
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:20:41 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XPACT_DEFAULT_PARSE_EVENTS

feature {NONE} -- Event handlers

	on_comment_ (text: C_STRING_8)
		do
		end

	on_content_ (text_intervals: EL_ARRAYED_INTERVAL_LIST)
		do
		end

	on_tag_attributes_ (list: XPACT_ATTRIBUTE_LIST)
		do
		end

	on_tag_end_ (name: STRING_8)
		do
		end

	on_tag_start_ (name: STRING_8; is_empty: BOOLEAN)
		do
		end
end