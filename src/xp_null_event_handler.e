note
	description: "No-op parser event handler."

class
	XP_NULL_EVENT_HANDLER

inherit
	XP_EVENT_HANDLER
		redefine
			wants_start_element_events,
			wants_end_element_events,
			wants_character_data_events,
			wants_automatic_character_data_default,
			wants_default_events
		end

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Events

	wants_start_element_events: BOOLEAN
			-- No start-element event objects are needed by this sink.
		do
			Result := False
		end

	wants_end_element_events: BOOLEAN
			-- No end-element event objects are needed by this sink.
		do
			Result := False
		end

	wants_character_data_events: BOOLEAN
			-- No character-data event text is needed by this sink.
		do
			Result := False
		end

	wants_automatic_character_data_default: BOOLEAN
			-- Character data should not be mirrored to the default handler.
		do
			Result := False
		end

	wants_default_events: BOOLEAN
			-- No default-handler text is needed by this sink.
		do
			Result := False
		end

	on_start_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
		do
		end

	on_end_element (a_name: READABLE_STRING_8)
		do
		end

	on_character_data (a_text: READABLE_STRING_8)
		do
		end

end
