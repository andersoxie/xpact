note
	description: "No-op parser event handler."

class
	XP_NULL_EVENT_HANDLER

inherit
	XP_EVENT_HANDLER

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Events

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

