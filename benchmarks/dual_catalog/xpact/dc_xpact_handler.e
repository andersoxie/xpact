note
	description: "Copies only the catalog's required raw events into its independent oracle observer."

class
	DC_XPACT_HANDLER

inherit
	XP_EVENT_HANDLER

create
	make

feature {NONE} -- Initialization

	make (a_observer: DC_CATALOG_OBSERVER)
		do
			observer := a_observer
		end

feature -- Events

	on_start_element (name: READABLE_STRING_8; attributes: XP_ATTRIBUTES)
		do
			if attributes.count = 1 then
				observer.on_start (name, attributes.count, attributes.i_th_name (1), attributes.i_th_value (1))
			else
				observer.on_start (name, attributes.count, "", "")
			end
		end

	on_end_element (name: READABLE_STRING_8)
		do
			observer.on_end (name)
		end

	on_character_data (text: READABLE_STRING_8)
		do
			observer.on_text (text)
		end

feature {NONE} -- Owned observer

	observer: DC_CATALOG_OBSERVER

end
