note
	description: "Test event handler that records parser callbacks."

class
	XP_COLLECTING_HANDLER

inherit
	XP_EVENT_HANDLER
		redefine
			on_processing_instruction,
			on_comment,
			on_start_cdata_section,
			on_end_cdata_section,
			on_start_doctype_decl,
			on_end_doctype_decl,
			on_element_decl,
			on_attlist_decl,
			on_default
		end

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

	record_doctype_events: BOOLEAN
			-- Should doctype events be added to `events'?

	record_default_events: BOOLEAN
			-- Should default-handler events be added to `events'?

	record_attlist_events: BOOLEAN
			-- Should attribute-list declaration events be added to `events'?

	record_element_decl_events: BOOLEAN
			-- Should element declaration events be added to `events'?

feature -- Configuration

	enable_doctype_events
			-- Record doctype events in `events'.
		do
			record_doctype_events := True
		ensure
			doctype_events_enabled: record_doctype_events
		end

	enable_default_events
			-- Record default-handler events in `events'.
		do
			record_default_events := True
		ensure
			default_events_enabled: record_default_events
		end

	enable_attlist_events
			-- Record attribute-list declaration events in `events'.
		do
			record_attlist_events := True
		ensure
			attlist_events_enabled: record_attlist_events
		end

	enable_element_decl_events
			-- Record element declaration events in `events'.
		do
			record_element_decl_events := True
		ensure
			element_decl_events_enabled: record_element_decl_events
		end

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

	on_processing_instruction (a_target, a_data: READABLE_STRING_8)
		local
			l_event: STRING_8
		do
			create l_event.make_from_string ("pi:")
			l_event.append (a_target)
			l_event.append_character (':')
			l_event.append (a_data)
			events.extend (l_event)
		end

	on_comment (a_text: READABLE_STRING_8)
		local
			l_event: STRING_8
		do
			create l_event.make_from_string ("comment:")
			l_event.append (a_text)
			events.extend (l_event)
		end

	on_start_cdata_section
		do
			events.extend ("start-cdata")
		end

	on_end_cdata_section
		do
			events.extend ("end-cdata")
		end

	on_start_doctype_decl (a_name: READABLE_STRING_8; a_system_id, a_public_id: detachable READABLE_STRING_8; a_has_internal_subset: BOOLEAN)
		local
			l_event: STRING_8
		do
			if record_doctype_events then
				create l_event.make_from_string ("start-doctype:")
				l_event.append (a_name)
				l_event.append_character (':')
				if attached a_system_id as l_system_id then
					l_event.append (l_system_id)
				end
				l_event.append_character (':')
				if attached a_public_id as l_public_id then
					l_event.append (l_public_id)
				end
				l_event.append_character (':')
				if a_has_internal_subset then
					l_event.append ("1")
				else
					l_event.append ("0")
				end
				events.extend (l_event)
			end
		end

	on_end_doctype_decl
		do
			if record_doctype_events then
				events.extend ("end-doctype")
			end
		end

	on_element_decl (a_name: READABLE_STRING_8; a_model: XP_CONTENT_MODEL)
		local
			l_event: STRING_8
		do
			if record_element_decl_events then
				create l_event.make_from_string ("element-decl:")
				l_event.append (a_name)
				l_event.append_character (':')
				l_event.append_integer (a_model.content_type)
				l_event.append_character (':')
				l_event.append_integer (a_model.quantifier)
				l_event.append_character (':')
				l_event.append_integer (a_model.children.count)
				events.extend (l_event)
			end
		end

	on_attlist_decl (a_element_name, a_attribute_name, a_attribute_type: READABLE_STRING_8; a_default_value: detachable READABLE_STRING_8; a_is_required: BOOLEAN)
		local
			l_event: STRING_8
		do
			if record_attlist_events then
				create l_event.make_from_string ("attlist:")
				l_event.append (a_element_name)
				l_event.append_character (':')
				l_event.append (a_attribute_name)
				l_event.append_character (':')
				l_event.append (a_attribute_type)
				l_event.append_character (':')
				if attached a_default_value as l_default_value then
					l_event.append (l_default_value)
				end
				l_event.append_character (':')
				if a_is_required then
					l_event.append ("1")
				else
					l_event.append ("0")
				end
				events.extend (l_event)
			end
		end

	on_default (a_text: READABLE_STRING_8)
		local
			l_event: STRING_8
		do
			if record_default_events then
				create l_event.make_from_string ("default:")
				l_event.append (a_text)
				events.extend (l_event)
			end
		end

invariant
	events_attached: events /= Void
	last_attribute_value_attached: last_attribute_value /= Void

end
