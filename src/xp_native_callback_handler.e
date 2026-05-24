note
	description: "Eiffel event handler that adapts parser events to native Expat-style callback slots."

class
	XP_NATIVE_CALLBACK_HANDLER

inherit
	XP_EVENT_HANDLER
		redefine
			on_processing_instruction,
			on_comment,
			on_start_cdata_section,
			on_end_cdata_section,
			on_start_doctype_decl,
			on_end_doctype_decl,
			on_attlist_decl,
			on_default
		end
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

	processing_instruction_callback: POINTER
			-- `XML_ProcessingInstructionHandler' callback pointer.

	comment_callback: POINTER
			-- `XML_CommentHandler' callback pointer.

	start_cdata_section_callback: POINTER
			-- `XML_StartCdataSectionHandler' callback pointer.

	end_cdata_section_callback: POINTER
			-- `XML_EndCdataSectionHandler' callback pointer.

	default_callback: POINTER
			-- `XML_DefaultHandler' callback pointer.

	default_expands_entities: BOOLEAN
			-- Was the default handler registered through the expanding API?

	start_doctype_decl_callback: POINTER
			-- `XML_StartDoctypeDeclHandler' callback pointer.

	end_doctype_decl_callback: POINTER
			-- `XML_EndDoctypeDeclHandler' callback pointer.

	attlist_decl_callback: POINTER
			-- `XML_AttlistDeclHandler' callback pointer.

	events: ARRAYED_LIST [STRING_8]
			-- Eiffel-visible event log used by tests and diagnostics.

feature -- Metrics

	start_element_count: INTEGER
			-- Number of start events emitted.

	end_element_count: INTEGER
			-- Number of end events emitted.

	character_data_count: INTEGER
			-- Number of non-empty character-data events emitted.

	processing_instruction_count: INTEGER
			-- Number of processing-instruction events emitted.

	comment_count: INTEGER
			-- Number of comment events emitted.

	start_cdata_section_count: INTEGER
			-- Number of CDATA start events emitted.

	end_cdata_section_count: INTEGER
			-- Number of CDATA end events emitted.

	default_count: INTEGER
			-- Number of default-handler events emitted.

	start_doctype_decl_count: INTEGER
			-- Number of doctype start events emitted.

	end_doctype_decl_count: INTEGER
			-- Number of doctype end events emitted.

	attlist_decl_count: INTEGER
			-- Number of attribute-list declaration events emitted.

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

	set_processing_instruction_handler (a_handler: POINTER)
			-- Set native processing-instruction callback.
		do
			processing_instruction_callback := a_handler
		ensure
			handler_set: processing_instruction_callback = a_handler
		end

	set_comment_handler (a_handler: POINTER)
			-- Set native comment callback.
		do
			comment_callback := a_handler
		ensure
			handler_set: comment_callback = a_handler
		end

	set_cdata_section_handlers (a_start, a_end: POINTER)
			-- Set native CDATA section callbacks.
		do
			start_cdata_section_callback := a_start
			end_cdata_section_callback := a_end
		ensure
			start_set: start_cdata_section_callback = a_start
			end_set: end_cdata_section_callback = a_end
		end

	set_default_handler (a_handler: POINTER; a_expand: BOOLEAN)
			-- Set native default callback.
		do
			default_callback := a_handler
			default_expands_entities := a_expand
		ensure
			handler_set: default_callback = a_handler
			expand_set: default_expands_entities = a_expand
		end

	set_doctype_decl_handlers (a_start, a_end: POINTER)
			-- Set native doctype declaration callbacks.
		do
			start_doctype_decl_callback := a_start
			end_doctype_decl_callback := a_end
		ensure
			start_set: start_doctype_decl_callback = a_start
			end_set: end_doctype_decl_callback = a_end
		end

	set_attlist_decl_handler (a_handler: POINTER)
			-- Set native attribute-list declaration callback.
		do
			attlist_decl_callback := a_handler
		ensure
			handler_set: attlist_decl_callback = a_handler
		end

	reset_events
			-- Clear observable event state.
		do
			events.wipe_out
			start_element_count := 0
			end_element_count := 0
			character_data_count := 0
			processing_instruction_count := 0
			comment_count := 0
			start_cdata_section_count := 0
			end_cdata_section_count := 0
			default_count := 0
			start_doctype_decl_count := 0
			end_doctype_decl_count := 0
			attlist_decl_count := 0
		ensure
			no_events: events.count = 0
			no_start_events: start_element_count = 0
			no_end_events: end_element_count = 0
			no_text_events: character_data_count = 0
			no_pi_events: processing_instruction_count = 0
			no_comment_events: comment_count = 0
			no_start_cdata_events: start_cdata_section_count = 0
			no_end_cdata_events: end_cdata_section_count = 0
			no_default_events: default_count = 0
			no_start_doctype_events: start_doctype_decl_count = 0
			no_end_doctype_events: end_doctype_decl_count = 0
			no_attlist_events: attlist_decl_count = 0
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

	on_processing_instruction (a_target, a_data: READABLE_STRING_8)
		local
			l_event: STRING_8
			l_target: C_STRING
			l_data: C_STRING
		do
			processing_instruction_count := processing_instruction_count + 1
			create l_event.make_from_string ("pi:")
			l_event.append (a_target)
			l_event.append_character (':')
			l_event.append (a_data)
			events.extend (l_event)
			if processing_instruction_callback /= default_pointer then
				create l_target.make (a_target)
				create l_data.make (a_data)
				call_processing_instruction_callback (processing_instruction_callback, user_data, l_target.item, l_data.item)
			end
		end

	on_comment (a_text: READABLE_STRING_8)
		local
			l_event: STRING_8
			l_text: C_STRING
		do
			comment_count := comment_count + 1
			create l_event.make_from_string ("comment:")
			l_event.append (a_text)
			events.extend (l_event)
			if comment_callback /= default_pointer then
				create l_text.make (a_text)
				call_comment_callback (comment_callback, user_data, l_text.item)
			end
		end

	on_start_cdata_section
		do
			start_cdata_section_count := start_cdata_section_count + 1
			events.extend ("start-cdata")
			if start_cdata_section_callback /= default_pointer then
				call_cdata_section_callback (start_cdata_section_callback, user_data)
			end
		end

	on_end_cdata_section
		do
			end_cdata_section_count := end_cdata_section_count + 1
			events.extend ("end-cdata")
			if end_cdata_section_callback /= default_pointer then
				call_cdata_section_callback (end_cdata_section_callback, user_data)
			end
		end

	on_start_doctype_decl (a_name: READABLE_STRING_8; a_system_id, a_public_id: detachable READABLE_STRING_8; a_has_internal_subset: BOOLEAN)
		local
			l_name: C_STRING
			l_system_id: detachable C_STRING
			l_public_id: detachable C_STRING
			l_system_pointer: POINTER
			l_public_pointer: POINTER
		do
			start_doctype_decl_count := start_doctype_decl_count + 1
			if start_doctype_decl_callback /= default_pointer then
				create l_name.make (a_name)
				if attached a_system_id as l_attached_system_id then
					create l_system_id.make (l_attached_system_id)
					l_system_pointer := l_system_id.item
				end
				if attached a_public_id as l_attached_public_id then
					create l_public_id.make (l_attached_public_id)
					l_public_pointer := l_public_id.item
				end
				call_start_doctype_decl_callback (start_doctype_decl_callback, user_data, l_name.item, l_system_pointer, l_public_pointer, a_has_internal_subset)
			end
		end

	on_end_doctype_decl
		do
			end_doctype_decl_count := end_doctype_decl_count + 1
			if end_doctype_decl_callback /= default_pointer then
				call_end_doctype_decl_callback (end_doctype_decl_callback, user_data)
			end
		end

	on_attlist_decl (a_element_name, a_attribute_name, a_attribute_type: READABLE_STRING_8; a_default_value: detachable READABLE_STRING_8; a_is_required: BOOLEAN)
		local
			l_event: STRING_8
			l_element_name: C_STRING
			l_attribute_name: C_STRING
			l_attribute_type: C_STRING
			l_default_value: detachable C_STRING
			l_default_pointer: POINTER
		do
			attlist_decl_count := attlist_decl_count + 1
			create l_event.make_from_string ("attlist:")
			l_event.append (a_element_name)
			l_event.append_character (':')
			l_event.append (a_attribute_name)
			l_event.append_character (':')
			l_event.append (a_attribute_type)
			l_event.append_character (':')
			if attached a_default_value as l_attached_default_value then
				l_event.append (l_attached_default_value)
			end
			l_event.append_character (':')
			if a_is_required then
				l_event.append ("1")
			else
				l_event.append ("0")
			end
			events.extend (l_event)
			if attlist_decl_callback /= default_pointer then
				create l_element_name.make (a_element_name)
				create l_attribute_name.make (a_attribute_name)
				create l_attribute_type.make (a_attribute_type)
				if attached a_default_value as l_attached_default_value then
					create l_default_value.make (l_attached_default_value)
					l_default_pointer := l_default_value.item
				end
				call_attlist_decl_callback (attlist_decl_callback, user_data, l_element_name.item, l_attribute_name.item, l_attribute_type.item, l_default_pointer, a_is_required)
			end
		end

	on_default (a_text: READABLE_STRING_8)
		local
			l_text: C_STRING
		do
			if default_callback /= default_pointer and then not a_text.is_empty then
				default_count := default_count + 1
				create l_text.make (a_text)
				call_default_callback (default_callback, user_data, l_text.item, a_text.count)
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

	call_processing_instruction_callback (a_callback, a_user_data, a_target, a_data: POINTER)
			-- Invoke native `XML_ProcessingInstructionHandler'.
		require
			callback_attached: a_callback /= default_pointer
			target_attached: a_target /= default_pointer
			data_attached: a_data /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_target, (const char *) $a_data);"
		end

	call_comment_callback (a_callback, a_user_data, a_text: POINTER)
			-- Invoke native `XML_CommentHandler'.
		require
			callback_attached: a_callback /= default_pointer
			text_attached: a_text /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_text);"
		end

	call_cdata_section_callback (a_callback, a_user_data: POINTER)
			-- Invoke native CDATA start/end handler.
		require
			callback_attached: a_callback /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *)) $a_callback) ((void *) $a_user_data);"
		end

	call_default_callback (a_callback, a_user_data, a_text: POINTER; a_length: INTEGER)
			-- Invoke native `XML_DefaultHandler'.
		require
			callback_attached: a_callback /= default_pointer
			text_attached: a_text /= default_pointer
			non_negative_length: a_length >= 0
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_text, (int) $a_length);"
		end

	call_start_doctype_decl_callback (a_callback, a_user_data, a_name, a_system_id, a_public_id: POINTER; a_has_internal_subset: BOOLEAN)
			-- Invoke native `XML_StartDoctypeDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, (const char *) $a_system_id, (const char *) $a_public_id, $a_has_internal_subset ? 1 : 0);"
		end

	call_end_doctype_decl_callback (a_callback, a_user_data: POINTER)
			-- Invoke native `XML_EndDoctypeDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *)) $a_callback) ((void *) $a_user_data);"
		end

	call_attlist_decl_callback (a_callback, a_user_data, a_element_name, a_attribute_name, a_attribute_type, a_default_value: POINTER; a_is_required: BOOLEAN)
			-- Invoke native `XML_AttlistDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			element_name_attached: a_element_name /= default_pointer
			attribute_name_attached: a_attribute_name /= default_pointer
			attribute_type_attached: a_attribute_type /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *, const char *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_element_name, (const char *) $a_attribute_name, (const char *) $a_attribute_type, (const char *) $a_default_value, $a_is_required ? 1 : 0);"
		end

invariant
	events_attached: events /= Void
	non_negative_start_count: start_element_count >= 0
	non_negative_end_count: end_element_count >= 0
	non_negative_text_count: character_data_count >= 0
	non_negative_pi_count: processing_instruction_count >= 0
	non_negative_comment_count: comment_count >= 0
	non_negative_start_cdata_count: start_cdata_section_count >= 0
	non_negative_end_cdata_count: end_cdata_section_count >= 0
	non_negative_default_count: default_count >= 0
	non_negative_start_doctype_count: start_doctype_decl_count >= 0
	non_negative_end_doctype_count: end_doctype_decl_count >= 0
	non_negative_attlist_count: attlist_decl_count >= 0

end
