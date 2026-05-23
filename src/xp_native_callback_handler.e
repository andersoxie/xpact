note
	description: "Eiffel event handler that adapts parser events to native Expat-style callback slots."

class
	XP_NATIVE_CALLBACK_HANDLER

inherit
	XP_EVENT_HANDLER
	PLATFORM

create
	make

feature {NONE} -- Initialization

	make
		do
			create events.make (16)
		ensure
			no_events: events.count = 0
		end

feature -- Access

	user_data: POINTER
			-- Opaque caller data passed back to native callbacks.

	start_element_callback: POINTER
			-- `XML_StartElementHandler' callback pointer.

	end_element_callback: POINTER
			-- `XML_EndElementHandler' callback pointer.

	character_data_callback: POINTER
			-- `XML_CharacterDataHandler' callback pointer.

	events: ARRAYED_LIST [STRING_8]
			-- Eiffel-visible event log used by tests and diagnostics.

feature -- Metrics

	start_element_count: INTEGER
			-- Number of start events emitted.

	end_element_count: INTEGER
			-- Number of end events emitted.

	character_data_count: INTEGER
			-- Number of non-empty character-data events emitted.

feature -- Element change

	set_user_data (a_user_data: POINTER)
			-- Set native callback user data.
		do
			user_data := a_user_data
		ensure
			user_data_set: user_data = a_user_data
		end

	set_element_handlers (a_start, a_end: POINTER)
			-- Set native element callbacks.
		do
			start_element_callback := a_start
			end_element_callback := a_end
		ensure
			start_set: start_element_callback = a_start
			end_set: end_element_callback = a_end
		end

	set_character_data_handler (a_handler: POINTER)
			-- Set native character-data callback.
		do
			character_data_callback := a_handler
		ensure
			handler_set: character_data_callback = a_handler
		end

	reset_events
			-- Clear observable event state.
		do
			events.wipe_out
			start_element_count := 0
			end_element_count := 0
			character_data_count := 0
		ensure
			no_events: events.count = 0
			no_start_events: start_element_count = 0
			no_end_events: end_element_count = 0
			no_text_events: character_data_count = 0
		end

feature -- Events

	on_start_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
		local
			l_event: STRING_8
			l_name: C_STRING
			l_attribute_strings: ARRAYED_LIST [C_STRING]
			l_attributes: MANAGED_POINTER
			i, j: INTEGER
			l_attribute_name: C_STRING
			l_attribute_value: C_STRING
		do
			start_element_count := start_element_count + 1
			create l_event.make_from_string ("start:")
			l_event.append (a_name)
			l_event.append_character (':')
			l_event.append_integer (a_attributes.count)
			events.extend (l_event)
			if start_element_callback /= default_pointer then
				create l_name.make (a_name)
				create l_attribute_strings.make (a_attributes.count * 2)
				create l_attributes.make ((a_attributes.count * 2 + 1) * Pointer_bytes)
				from
					i := 1
					j := 0
				invariant
					index_in_bounds: i >= 1 and i <= a_attributes.count + 1
					pointer_index_valid: j = (i - 1) * 2
				until
					i > a_attributes.count
				loop
					create l_attribute_name.make (a_attributes.i_th_name (i))
					create l_attribute_value.make (a_attributes.i_th_value (i))
					l_attribute_strings.extend (l_attribute_name)
					l_attribute_strings.extend (l_attribute_value)
					l_attributes.put_pointer (l_attribute_name.item, j * Pointer_bytes)
					l_attributes.put_pointer (l_attribute_value.item, (j + 1) * Pointer_bytes)
					i := i + 1
					j := j + 2
				variant
					a_attributes.count - i + 1
				end
				l_attributes.put_pointer (default_pointer, j * Pointer_bytes)
				call_start_element_callback (start_element_callback, user_data, l_name.item, l_attributes.item)
			end
		end

	on_end_element (a_name: READABLE_STRING_8)
		local
			l_event: STRING_8
			l_name: C_STRING
		do
			end_element_count := end_element_count + 1
			create l_event.make_from_string ("end:")
			l_event.append (a_name)
			events.extend (l_event)
			if end_element_callback /= default_pointer then
				create l_name.make (a_name)
				call_end_element_callback (end_element_callback, user_data, l_name.item)
			end
		end

	on_character_data (a_text: READABLE_STRING_8)
		local
			l_event: STRING_8
			l_text: C_STRING
		do
			if not a_text.is_empty then
				character_data_count := character_data_count + 1
				create l_event.make_from_string ("text:")
				l_event.append (a_text)
				events.extend (l_event)
				if character_data_callback /= default_pointer then
					create l_text.make (a_text)
					call_character_data_callback (character_data_callback, user_data, l_text.item, a_text.count)
				end
			end
		end

feature {NONE} -- Native callback calls

	call_start_element_callback (a_callback, a_user_data, a_name, a_attributes: POINTER)
			-- Invoke native `XML_StartElementHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
			attributes_attached: a_attributes /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char **)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, (const char **) $a_attributes);"
		end

	call_end_element_callback (a_callback, a_user_data, a_name: POINTER)
			-- Invoke native `XML_EndElementHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_name);"
		end

	call_character_data_callback (a_callback, a_user_data, a_text: POINTER; a_length: INTEGER)
			-- Invoke native `XML_CharacterDataHandler'.
		require
			callback_attached: a_callback /= default_pointer
			text_attached: a_text /= default_pointer
			non_negative_length: a_length >= 0
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_text, (int) $a_length);"
		end

invariant
	events_attached: events /= Void
	non_negative_start_count: start_element_count >= 0
	non_negative_end_count: end_element_count >= 0
	non_negative_text_count: character_data_count >= 0

end
