note
	description: "Test event handler that records parser callbacks."

class
	XP_COLLECTING_HANDLER

inherit
	XP_EVENT_HANDLER

create
	make

feature {NONE} -- Initialization

	make
		do
			create events.make (16)
			create last_attribute_value.make_empty
		ensure
			empty: events.count = 0
		end

feature -- Access

	events: ARRAYED_LIST [STRING_8]
			-- Captured events.

	last_attribute_value: STRING_8
			-- Last value of attribute `a' seen by `on_start_element'.

feature -- Events

	on_start_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
		local
			l_event: STRING_8
		do
			create l_event.make_from_string ("start:")
			l_event.append (a_name)
			l_event.append_character (':')
			l_event.append_integer (a_attributes.count)
			if a_attributes.has ("a") and then attached a_attributes.item ("a") as l_value then
				last_attribute_value.wipe_out
				last_attribute_value.append (l_value)
			end
			events.extend (l_event)
		end

	on_end_element (a_name: READABLE_STRING_8)
		local
			l_event: STRING_8
		do
			create l_event.make_from_string ("end:")
			l_event.append (a_name)
			events.extend (l_event)
		end

	on_character_data (a_text: READABLE_STRING_8)
		local
			l_event: STRING_8
		do
			create l_event.make_from_string ("text:")
			l_event.append (a_text)
			events.extend (l_event)
		end

invariant
	events_attached: events /= Void
	last_attribute_value_attached: last_attribute_value /= Void

end
