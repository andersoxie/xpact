note
	description: "Test handler that records parser positions during callbacks."

class
	XP_POSITION_COLLECTING_HANDLER

inherit
	XP_EVENT_HANDLER
		redefine
			wants_default_events
		end

create
	make

feature {NONE} -- Initialization

	make
		do
			create events.make (16)
		ensure
			empty: events.count = 0
		end

feature -- Access

	events: ARRAYED_LIST [STRING_8]
			-- Captured positioned events.

	parser: detachable XP_PARSER
			-- Parser whose callback-time positions should be recorded.

feature -- Element change

	set_parser (a_parser: XP_PARSER)
			-- Attach parser to inspect during callbacks.
		require
			parser_attached: a_parser /= Void
		do
			parser := a_parser
		ensure
			parser_set: parser = a_parser
		end

feature -- Events

	wants_default_events: BOOLEAN
			-- Position tests do not inspect raw default-handler text.
		do
			Result := False
		end

	on_start_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
		do
			record_event ("start", a_name)
		end

	on_end_element (a_name: READABLE_STRING_8)
		do
			record_event ("end", a_name)
		end

	on_character_data (a_text: READABLE_STRING_8)
		do
			if not is_all_space (a_text) then
				record_event ("text", a_text)
			end
		end

feature {NONE} -- Recording

	record_event (a_kind, a_value: READABLE_STRING_8)
			-- Record current parser position for `a_kind'.
		require
			kind_attached: a_kind /= Void
			value_attached: a_value /= Void
		local
			l_event: STRING_8
		do
			create l_event.make_from_string (a_kind)
			l_event.append_character (':')
			l_event.append (a_value)
			l_event.append_character (':')
			if attached parser as l_parser then
				l_event.append_integer (l_parser.current_line_number)
				l_event.append_character (':')
				l_event.append_integer (l_parser.current_column_number)
				l_event.append_character (':')
				l_event.append_integer (l_parser.current_byte_index)
				l_event.append_character (':')
				l_event.append_integer (l_parser.current_byte_count)
			else
				l_event.append ("missing")
			end
			events.extend (l_event)
		ensure
			one_more: events.count = old events.count + 1
		end

	is_all_space (a_text: READABLE_STRING_8): BOOLEAN
			-- Does `a_text' contain only XML whitespace?
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			from
				Result := True
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_text.count + 1
			until
				i > a_text.count or not Result
			loop
				Result := a_text.item (i) = ' ' or a_text.item (i) = '%T' or a_text.item (i) = '%N' or a_text.item (i) = '%R'
				i := i + 1
			variant
				a_text.count - i + 1
			end
		end

invariant
	events_attached: events /= Void

end
