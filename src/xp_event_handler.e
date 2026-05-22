note
	description: "Event sink for the xpact streaming parser."

deferred class
	XP_EVENT_HANDLER

feature -- Events

	on_start_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
			-- A start element was parsed.
		require
			name_attached: a_name /= Void
			attributes_attached: a_attributes /= Void
			valid_name: a_attributes.is_valid_name (a_name)
		deferred
		end

	on_end_element (a_name: READABLE_STRING_8)
			-- An end element was parsed.
		require
			name_attached: a_name /= Void
		deferred
		end

	on_character_data (a_text: READABLE_STRING_8)
			-- Character data was parsed.
		require
			text_attached: a_text /= Void
		deferred
		end

end

