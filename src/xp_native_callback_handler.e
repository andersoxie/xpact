note
	description: "Eiffel event handler that adapts parser events to native Expat-style callback slots."

class
	XP_NATIVE_CALLBACK_HANDLER

inherit
	XP_EVENT_HANDLER
		redefine
			on_processing_instruction,
			on_xml_declaration,
			on_comment,
			on_start_cdata_section,
			on_end_cdata_section,
			wants_automatic_character_data_default,
			expands_internal_general_entity_references,
			reports_skipped_internal_general_entities,
			on_start_doctype_decl,
			on_end_doctype_decl,
			on_not_standalone,
			on_element_decl,
			on_notation_decl,
			on_attlist_decl,
			on_entity_decl,
			on_unparsed_entity_decl,
			on_skipped_entity,
			on_default
		end
	XP_EXTERNAL_ENTITY_RESOLVER
	PLATFORM

create
	make

feature {NONE} -- Initialization

	make
		do
			create events.make (16)
			current_id_attribute_index := -1
		ensure
			no_events: events.count = 0
			no_current_id_attribute: current_id_attribute_index = -1
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

	xml_decl_callback: POINTER
			-- `XML_XmlDeclHandler' callback pointer.

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

	current_default_text: detachable STRING_8
			-- Current callback text replayable through `XML_DefaultCurrent'.

	start_doctype_decl_callback: POINTER
			-- `XML_StartDoctypeDeclHandler' callback pointer.

	end_doctype_decl_callback: POINTER
			-- `XML_EndDoctypeDeclHandler' callback pointer.

	not_standalone_callback: POINTER
			-- `XML_NotStandaloneHandler' callback pointer.

	element_decl_callback: POINTER
			-- `XML_ElementDeclHandler' callback pointer.

	notation_decl_callback: POINTER
			-- `XML_NotationDeclHandler' callback pointer.

	attlist_decl_callback: POINTER
			-- `XML_AttlistDeclHandler' callback pointer.

	entity_decl_callback: POINTER
			-- `XML_EntityDeclHandler' callback pointer.

	unparsed_entity_decl_callback: POINTER
			-- `XML_UnparsedEntityDeclHandler' callback pointer.

	external_entity_ref_callback: POINTER
			-- `XML_ExternalEntityRefHandler' callback pointer.

	skipped_entity_callback: POINTER
			-- `XML_SkippedEntityHandler' callback pointer.

	external_entity_ref_arg: POINTER
			-- Optional first argument for `XML_ExternalEntityRefHandler'.

	has_external_entity_ref_arg: BOOLEAN
			-- Was `external_entity_ref_arg' explicitly set?

	native_parser_handle: POINTER
			-- Native parser pointer passed to external entity callbacks by default.

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

	xml_decl_count: INTEGER
			-- Number of XML declaration events emitted.

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

	not_standalone_count: INTEGER
			-- Number of not-standalone checks emitted.

	element_decl_count: INTEGER
			-- Number of element declaration events emitted.

	notation_decl_count: INTEGER
			-- Number of notation declaration events emitted.

	attlist_decl_count: INTEGER
			-- Number of attribute-list declaration events emitted.

	entity_decl_count: INTEGER
			-- Number of entity declaration events emitted.

	unparsed_entity_decl_count: INTEGER
			-- Number of unparsed entity declaration events emitted.

	external_entity_ref_count: INTEGER
			-- Number of external entity references delegated to native callbacks.

	skipped_entity_count: INTEGER
			-- Number of skipped entity references reported.

	current_specified_attribute_count: INTEGER
			-- Expat-style count of explicit attribute vector entries for current start event.

	current_id_attribute_index: INTEGER
			-- Expat-style ID attribute name index for current start event, or -1.

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

	set_xml_decl_handler (a_handler: POINTER)
			-- Set native XML declaration callback.
		do
			xml_decl_callback := a_handler
		ensure
			handler_set: xml_decl_callback = a_handler
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

	set_not_standalone_handler (a_handler: POINTER)
			-- Set native not-standalone callback.
		do
			not_standalone_callback := a_handler
		ensure
			handler_set: not_standalone_callback = a_handler
		end

	set_element_decl_handler (a_handler: POINTER)
			-- Set native element declaration callback.
		do
			element_decl_callback := a_handler
		ensure
			handler_set: element_decl_callback = a_handler
		end

	set_notation_decl_handler (a_handler: POINTER)
			-- Set native notation declaration callback.
		do
			notation_decl_callback := a_handler
		ensure
			handler_set: notation_decl_callback = a_handler
		end

	set_attlist_decl_handler (a_handler: POINTER)
			-- Set native attribute-list declaration callback.
		do
			attlist_decl_callback := a_handler
		ensure
			handler_set: attlist_decl_callback = a_handler
		end

	set_entity_decl_handler (a_handler: POINTER)
			-- Set native entity declaration callback.
		do
			entity_decl_callback := a_handler
		ensure
			handler_set: entity_decl_callback = a_handler
		end

	set_unparsed_entity_decl_handler (a_handler: POINTER)
			-- Set native unparsed entity declaration callback.
		do
			unparsed_entity_decl_callback := a_handler
		ensure
			handler_set: unparsed_entity_decl_callback = a_handler
		end

	set_external_entity_ref_handler (a_handler: POINTER)
			-- Set native external entity reference callback.
		do
			external_entity_ref_callback := a_handler
		ensure
			handler_set: external_entity_ref_callback = a_handler
		end

	set_external_entity_ref_handler_arg (a_arg: POINTER)
			-- Set native external entity reference callback argument.
		do
			external_entity_ref_arg := a_arg
			has_external_entity_ref_arg := a_arg /= default_pointer
		ensure
			arg_set: external_entity_ref_arg = a_arg
			arg_marker_matches: has_external_entity_ref_arg = (a_arg /= default_pointer)
		end

	set_skipped_entity_handler (a_handler: POINTER)
			-- Set native skipped entity callback.
		do
			skipped_entity_callback := a_handler
		ensure
			handler_set: skipped_entity_callback = a_handler
		end

	set_native_parser_handle (a_parser: POINTER)
			-- Set native parser handle used for callback APIs that expect it.
		do
			native_parser_handle := a_parser
		ensure
			handle_set: native_parser_handle = a_parser
		end

	emit_xml_declaration (a_version, a_encoding: READABLE_STRING_8; a_standalone: INTEGER)
			-- Emit native XML declaration callback, if configured.
		require
			version_attached: a_version /= Void
			encoding_attached: a_encoding /= Void
			valid_standalone: a_standalone = -1 or a_standalone = 0 or a_standalone = 1
		local
			l_event: STRING_8
			l_version: detachable C_STRING
			l_encoding: detachable C_STRING
			l_version_pointer: POINTER
			l_encoding_pointer: POINTER
		do
			xml_decl_count := xml_decl_count + 1
			create l_event.make_from_string ("xml-decl")
			events.extend (l_event)
			if xml_decl_callback /= default_pointer then
				if not a_version.is_empty then
					create l_version.make (a_version)
					l_version_pointer := l_version.item
				end
				if not a_encoding.is_empty then
					create l_encoding.make (a_encoding)
					l_encoding_pointer := l_encoding.item
				end
				call_xml_decl_callback (xml_decl_callback, user_data, l_version_pointer, l_encoding_pointer, a_standalone)
			end
		end

	reset_events
			-- Clear observable event state.
		do
			events.wipe_out
			start_element_count := 0
			end_element_count := 0
			character_data_count := 0
			processing_instruction_count := 0
			xml_decl_count := 0
			comment_count := 0
			start_cdata_section_count := 0
			end_cdata_section_count := 0
			default_count := 0
			start_doctype_decl_count := 0
			end_doctype_decl_count := 0
			not_standalone_count := 0
			element_decl_count := 0
			notation_decl_count := 0
			attlist_decl_count := 0
			entity_decl_count := 0
			unparsed_entity_decl_count := 0
			external_entity_ref_count := 0
			skipped_entity_count := 0
			current_specified_attribute_count := 0
			current_id_attribute_index := -1
		ensure
			no_events: events.count = 0
			no_start_events: start_element_count = 0
			no_end_events: end_element_count = 0
			no_text_events: character_data_count = 0
			no_pi_events: processing_instruction_count = 0
			no_xml_decl_events: xml_decl_count = 0
			no_comment_events: comment_count = 0
			no_start_cdata_events: start_cdata_section_count = 0
			no_end_cdata_events: end_cdata_section_count = 0
			no_default_events: default_count = 0
			no_start_doctype_events: start_doctype_decl_count = 0
			no_end_doctype_events: end_doctype_decl_count = 0
			no_not_standalone_events: not_standalone_count = 0
			no_element_decl_events: element_decl_count = 0
			no_notation_decl_events: notation_decl_count = 0
			no_attlist_events: attlist_decl_count = 0
			no_entity_decl_events: entity_decl_count = 0
			no_unparsed_entity_decl_events: unparsed_entity_decl_count = 0
			no_external_entity_refs: external_entity_ref_count = 0
			no_skipped_entities: skipped_entity_count = 0
			no_current_specified_attributes: current_specified_attribute_count = 0
			no_current_id_attribute: current_id_attribute_index = -1
		end

feature -- Events

	wants_automatic_character_data_default: BOOLEAN
			-- Should character data also be emitted through `on_default' automatically?
		do
			Result := character_data_callback = default_pointer
		end

	expands_internal_general_entity_references: BOOLEAN
			-- Should internal general entity references be expanded in content?
		do
			Result := default_callback = default_pointer or else default_expands_entities
		end

	reports_skipped_internal_general_entities: BOOLEAN
			-- Should skipped internal general entities be reported through `on_skipped_entity'?
		do
			Result := skipped_entity_callback /= default_pointer
		end

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
			current_specified_attribute_count := a_attributes.specified_attribute_count * 2
			current_id_attribute_index := a_attributes.id_attribute_index
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
					remember_default_text (a_text)
					call_character_data_callback (character_data_callback, user_data, l_text.item, a_text.count)
					forget_default_text
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

	on_xml_declaration (a_version, a_encoding: READABLE_STRING_8; a_standalone: INTEGER)
		do
			emit_xml_declaration (a_version, a_encoding, a_standalone)
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

	on_not_standalone: BOOLEAN
		local
			l_status: INTEGER
		do
			not_standalone_count := not_standalone_count + 1
			events.extend ("not-standalone")
			if not_standalone_callback = default_pointer then
				Result := True
			else
				l_status := call_not_standalone_callback (not_standalone_callback, user_data)
				Result := l_status /= 0
			end
		end

	on_element_decl (a_name: READABLE_STRING_8; a_model: XP_CONTENT_MODEL)
		local
			l_event: STRING_8
			l_name: C_STRING
			l_model_names: ARRAYED_LIST [C_STRING]
			l_model: POINTER
		do
			element_decl_count := element_decl_count + 1
			create l_event.make_from_string ("element-decl:")
			l_event.append (a_name)
			l_event.append_character (':')
			l_event.append_integer (a_model.content_type)
			l_event.append_character (':')
			l_event.append_integer (a_model.quantifier)
			l_event.append_character (':')
			l_event.append_integer (a_model.children.count)
			events.extend (l_event)
			if element_decl_callback /= default_pointer then
				create l_name.make (a_name)
				create l_model_names.make (a_model.node_count)
				l_model := content_model_array (a_model, l_model_names)
				if l_model /= default_pointer then
					call_element_decl_callback (element_decl_callback, user_data, l_name.item, l_model)
				end
			end
		end

	on_notation_decl (a_name: READABLE_STRING_8; a_base, a_system_id, a_public_id: detachable READABLE_STRING_8)
		local
			l_event: STRING_8
			l_name: C_STRING
			l_base: detachable C_STRING
			l_system_id: detachable C_STRING
			l_public_id: detachable C_STRING
			l_base_pointer: POINTER
			l_system_pointer: POINTER
			l_public_pointer: POINTER
		do
			notation_decl_count := notation_decl_count + 1
			create l_event.make_from_string ("notation:")
			l_event.append (a_name)
			l_event.append_character (':')
			if attached a_system_id as l_attached_system_id then
				l_event.append (l_attached_system_id)
			end
			l_event.append_character (':')
			if attached a_public_id as l_attached_public_id then
				l_event.append (l_attached_public_id)
			end
			events.extend (l_event)
			if notation_decl_callback /= default_pointer then
				create l_name.make (a_name)
				if attached a_base as l_attached_base then
					create l_base.make (l_attached_base)
					l_base_pointer := l_base.item
				end
				if attached a_system_id as l_attached_system_id then
					create l_system_id.make (l_attached_system_id)
					l_system_pointer := l_system_id.item
				end
				if attached a_public_id as l_attached_public_id then
					create l_public_id.make (l_attached_public_id)
					l_public_pointer := l_public_id.item
				end
				call_notation_decl_callback (notation_decl_callback, user_data, l_name.item, l_base_pointer, l_system_pointer, l_public_pointer)
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

	on_entity_decl (a_name: READABLE_STRING_8; a_is_parameter: BOOLEAN; a_value: detachable READABLE_STRING_8; a_public_id, a_system_id, a_notation_name: detachable READABLE_STRING_8)
		local
			l_event: STRING_8
			l_name: C_STRING
			l_value: detachable C_STRING
			l_public_id: detachable C_STRING
			l_system_id: detachable C_STRING
			l_notation_name: detachable C_STRING
			l_value_pointer: POINTER
			l_public_pointer: POINTER
			l_system_pointer: POINTER
			l_notation_pointer: POINTER
			l_value_length: INTEGER
		do
			entity_decl_count := entity_decl_count + 1
			create l_event.make_from_string ("entity-decl:")
			l_event.append (a_name)
			l_event.append_character (':')
			if a_is_parameter then
				l_event.append ("1")
			else
				l_event.append ("0")
			end
			l_event.append_character (':')
			if attached a_value as l_attached_value then
				l_event.append (l_attached_value)
			else
				l_event.append ("(null)")
			end
			events.extend (l_event)
			if entity_decl_callback /= default_pointer then
				create l_name.make (a_name)
				if attached a_value as l_attached_value then
					create l_value.make (l_attached_value)
					l_value_pointer := l_value.item
					l_value_length := l_attached_value.count
				end
				if attached a_public_id as l_attached_public_id then
					create l_public_id.make (l_attached_public_id)
					l_public_pointer := l_public_id.item
				end
				if attached a_system_id as l_attached_system_id then
					create l_system_id.make (l_attached_system_id)
					l_system_pointer := l_system_id.item
				end
				if attached a_notation_name as l_attached_notation_name then
					create l_notation_name.make (l_attached_notation_name)
					l_notation_pointer := l_notation_name.item
				end
				call_entity_decl_callback (entity_decl_callback, user_data, l_name.item, a_is_parameter, l_value_pointer, l_value_length, default_pointer, l_system_pointer, l_public_pointer, l_notation_pointer)
			end
		end

	on_unparsed_entity_decl (a_name, a_system_id: READABLE_STRING_8; a_public_id, a_notation_name: detachable READABLE_STRING_8)
		local
			l_event: STRING_8
			l_name: C_STRING
			l_system_id: C_STRING
			l_public_id: detachable C_STRING
			l_notation_name: detachable C_STRING
			l_public_pointer: POINTER
			l_notation_pointer: POINTER
		do
			unparsed_entity_decl_count := unparsed_entity_decl_count + 1
			create l_event.make_from_string ("unparsed-entity:")
			l_event.append (a_name)
			l_event.append_character (':')
			l_event.append (a_system_id)
			events.extend (l_event)
			if unparsed_entity_decl_callback /= default_pointer then
				create l_name.make (a_name)
				create l_system_id.make (a_system_id)
				if attached a_public_id as l_attached_public_id then
					create l_public_id.make (l_attached_public_id)
					l_public_pointer := l_public_id.item
				end
				if attached a_notation_name as l_attached_notation_name then
					create l_notation_name.make (l_attached_notation_name)
					l_notation_pointer := l_notation_name.item
				end
				call_unparsed_entity_decl_callback (unparsed_entity_decl_callback, user_data, l_name.item, default_pointer, l_system_id.item, l_public_pointer, l_notation_pointer)
			end
		end

	on_skipped_entity (a_name: READABLE_STRING_8; a_is_parameter: BOOLEAN)
		local
			l_event: STRING_8
			l_name: C_STRING
		do
			skipped_entity_count := skipped_entity_count + 1
			create l_event.make_from_string ("skipped:")
			l_event.append (a_name)
			l_event.append_character (':')
			if a_is_parameter then
				l_event.append_character ('1')
			else
				l_event.append_character ('0')
			end
			events.extend (l_event)
			if skipped_entity_callback /= default_pointer then
				create l_name.make (a_name)
				call_skipped_entity_callback (skipped_entity_callback, user_data, l_name.item, a_is_parameter)
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

	default_current
			-- Replay the current callback text through the default handler.
		do
			if attached current_default_text as l_text then
				on_default (l_text)
			end
		end

feature -- External entity resolution

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
			-- Delegate external entity loading decision to the native callback slot.
		local
			l_context: C_STRING
			l_system_id: C_STRING
			l_public_id: detachable C_STRING
			l_public_pointer: POINTER
			l_before_external_count: INTEGER
			l_after_external_count: INTEGER
			l_status: INTEGER
		do
			if external_entity_ref_callback /= default_pointer then
				external_entity_ref_count := external_entity_ref_count + 1
				l_before_external_count := external_entity_parse_count (native_parser_handle)
				create l_context.make (a_name)
				create l_system_id.make (a_system_id)
				if not a_public_id.is_empty then
					create l_public_id.make (a_public_id)
					l_public_pointer := l_public_id.item
				end
				mark_next_external_entity_is_parameter (native_parser_handle, a_is_parameter)
				l_status := call_external_entity_ref_callback (external_entity_ref_callback, external_entity_callback_argument, l_context.item, default_pointer, l_system_id.item, l_public_pointer)
				mark_next_external_entity_is_parameter (native_parser_handle, False)
				if l_status /= 0 then
					l_after_external_count := external_entity_parse_count (native_parser_handle)
					if a_is_parameter and then l_after_external_count > l_before_external_count then
						create Result.make_from_string ("%N")
					else
						create Result.make_empty
					end
				end
			else
				on_skipped_entity (a_name, a_is_parameter)
				create Result.make_empty
			end
		end

feature {NONE} -- Native callback calls

	remember_default_text (a_text: READABLE_STRING_8)
			-- Store callback text for `XML_DefaultCurrent'.
		require
			text_attached: a_text /= Void
		do
			create current_default_text.make_from_string (a_text)
		ensure
			text_available: attached current_default_text as l_text and then l_text.same_string (a_text)
		end

	forget_default_text
			-- Clear callback text after returning from the client callback.
		do
			current_default_text := Void
		ensure
			no_current_text: current_default_text = Void
		end

	external_entity_callback_argument: POINTER
			-- First argument for `XML_ExternalEntityRefHandler'.
		do
			if has_external_entity_ref_arg then
				Result := external_entity_ref_arg
			else
				Result := native_parser_handle
			end
		end

	content_model_array (a_model: XP_CONTENT_MODEL; a_name_strings: ARRAYED_LIST [C_STRING]): POINTER
			-- Newly allocated Expat-shaped content model array for `a_model'.
		require
			model_attached: a_model /= Void
			name_strings_attached: a_name_strings /= Void
		local
			l_nodes: ARRAYED_LIST [XP_CONTENT_MODEL]
			l_node: XP_CONTENT_MODEL
			l_name: C_STRING
			l_name_pointer: POINTER
			i: INTEGER
		do
			create l_nodes.make (a_model.node_count)
			append_content_model_nodes (l_nodes, a_model)
			Result := c_malloc (l_nodes.count * content_struct_size)
			if Result /= default_pointer then
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= l_nodes.count + 1
				until
					i > l_nodes.count
				loop
					l_node := l_nodes.i_th (i)
					l_name_pointer := default_pointer
					if attached l_node.name as l_attached_name then
						create l_name.make (l_attached_name)
						a_name_strings.extend (l_name)
						l_name_pointer := l_name.item
					end
					put_content_model_node (
						Result,
						i - 1,
						l_node.content_type,
						l_node.quantifier,
						l_name_pointer,
						l_node.children.count,
						first_content_child_index (l_nodes, l_node)
					)
					i := i + 1
				variant
					l_nodes.count - i + 1
				end
			end
		end

	append_content_model_nodes (a_nodes: ARRAYED_LIST [XP_CONTENT_MODEL]; a_root: XP_CONTENT_MODEL)
			-- Append `a_root' and descendants in Expat's breadth-first array order.
		require
			nodes_attached: a_nodes /= Void
			nodes_empty: a_nodes.is_empty
			root_attached: a_root /= Void
		local
			i, j, l_total: INTEGER
			l_node: XP_CONTENT_MODEL
		do
			a_nodes.extend (a_root)
			l_total := a_root.node_count
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_total + 1
				count_bounded: a_nodes.count <= l_total
			until
				i > l_total
			loop
				l_node := a_nodes.i_th (i)
				from
					j := 1
				invariant
					child_index_in_bounds: j >= 1 and j <= l_node.children.count + 1
				until
					j > l_node.children.count
				loop
					a_nodes.extend (l_node.children.i_th (j))
					j := j + 1
				variant
					l_node.children.count - j + 1
				end
				i := i + 1
			variant
				l_total - i + 1
			end
		ensure
			all_nodes_added: a_nodes.count = old a_nodes.count + a_root.node_count
		end

	first_content_child_index (a_nodes: ARRAYED_LIST [XP_CONTENT_MODEL]; a_node: XP_CONTENT_MODEL): INTEGER
			-- Zero-based index of `a_node''s first child in `a_nodes', or -1.
		require
			nodes_attached: a_nodes /= Void
			node_attached: a_node /= Void
		local
			i: INTEGER
			l_found: BOOLEAN
			l_first_child: XP_CONTENT_MODEL
		do
			Result := -1
			if not a_node.children.is_empty then
				l_first_child := a_node.children.i_th (1)
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= a_nodes.count + 1
				until
					i > a_nodes.count or l_found
				loop
					if a_nodes.i_th (i) = l_first_child then
						Result := i - 1
						l_found := True
					end
					i := i + 1
				variant
					a_nodes.count - i + 1
				end
			end
		ensure
			valid_index: Result >= -1
		end

	content_struct_size: INTEGER
			-- Size of native `XML_Content' under the C ABI used by `include/xpact.h'.
		external
			"C inline"
		alias
			"typedef struct { int type; int quant; char *name; unsigned int numchildren; void *children; } XPACT_EiffelContentModel; return (EIF_INTEGER) sizeof (XPACT_EiffelContentModel);"
		end

	c_malloc (a_size: INTEGER): POINTER
			-- Allocate native memory that `XML_FreeContentModel' can release with the default allocator.
		require
			non_negative_size: a_size >= 0
		external
			"C inline use <stdlib.h>"
		alias
			"return (EIF_POINTER) malloc ((size_t) $a_size);"
		end

	put_content_model_node (a_base: POINTER; a_index, a_type, a_quant: INTEGER; a_name: POINTER; a_numchildren, a_first_child_index: INTEGER)
			-- Write one native content model node.
		require
			base_attached: a_base /= default_pointer
			valid_index: a_index >= 0
			non_negative_children: a_numchildren >= 0
			valid_child_index: a_first_child_index >= -1
		external
			"C inline"
		alias
			"typedef struct { int type; int quant; char *name; unsigned int numchildren; void *children; } XPACT_EiffelContentModel; XPACT_EiffelContentModel *items = (XPACT_EiffelContentModel *) $a_base; items[$a_index].type = (int) $a_type; items[$a_index].quant = (int) $a_quant; items[$a_index].name = (char *) $a_name; items[$a_index].numchildren = (unsigned int) $a_numchildren; items[$a_index].children = ($a_first_child_index >= 0) ? (void *) &items[$a_first_child_index] : (void *) 0;"
		end

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

	call_xml_decl_callback (a_callback, a_user_data, a_version, a_encoding: POINTER; a_standalone: INTEGER)
			-- Invoke native `XML_XmlDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_version, (const char *) $a_encoding, (int) $a_standalone);"
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

	call_skipped_entity_callback (a_callback, a_user_data, a_name: POINTER; a_is_parameter: BOOLEAN)
			-- Invoke native `XML_SkippedEntityHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, int)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, $a_is_parameter ? 1 : 0);"
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

	call_not_standalone_callback (a_callback, a_user_data: POINTER): INTEGER
			-- Invoke native `XML_NotStandaloneHandler'.
		require
			callback_attached: a_callback /= default_pointer
		external
			"C inline"
		alias
			"return (EIF_INTEGER) ((int (*)(void *)) $a_callback) ((void *) $a_user_data);"
		end

	external_entity_parse_count (a_parser: POINTER): INTEGER
			-- Number of successful external child parser parses observed by native parser `a_parser'.
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return $a_parser != 0 ? (EIF_INTEGER) ((struct XML_ParserStruct *) $a_parser)->externalChildParseCount : (EIF_INTEGER) 0;"
		end

	mark_next_external_entity_is_parameter (a_parser: POINTER; a_is_parameter: BOOLEAN)
			-- Tell the native bridge how the next external child parser should parse.
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"if ($a_parser != 0) { ((struct XML_ParserStruct *) $a_parser)->nextExternalEntityIsParameter = $a_is_parameter ? XML_TRUE : XML_FALSE; }"
		end

	call_element_decl_callback (a_callback, a_user_data, a_name, a_model: POINTER)
			-- Invoke native `XML_ElementDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
			model_attached: a_model /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, void *)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, (void *) $a_model);"
		end

	call_notation_decl_callback (a_callback, a_user_data, a_name, a_base, a_system_id, a_public_id: POINTER)
			-- Invoke native `XML_NotationDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *, const char *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, (const char *) $a_base, (const char *) $a_system_id, (const char *) $a_public_id);"
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

	call_entity_decl_callback (a_callback, a_user_data, a_name: POINTER; a_is_parameter: BOOLEAN; a_value: POINTER; a_value_length: INTEGER; a_base, a_system_id, a_public_id, a_notation_name: POINTER)
			-- Invoke native `XML_EntityDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
			non_negative_value_length: a_value_length >= 0
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, int, const char *, int, const char *, const char *, const char *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, $a_is_parameter ? 1 : 0, (const char *) $a_value, (int) $a_value_length, (const char *) $a_base, (const char *) $a_system_id, (const char *) $a_public_id, (const char *) $a_notation_name);"
		end

	call_unparsed_entity_decl_callback (a_callback, a_user_data, a_name, a_base, a_system_id, a_public_id, a_notation_name: POINTER)
			-- Invoke native `XML_UnparsedEntityDeclHandler'.
		require
			callback_attached: a_callback /= default_pointer
			name_attached: a_name /= default_pointer
			system_id_attached: a_system_id /= default_pointer
		external
			"C inline"
		alias
			"((void (*)(void *, const char *, const char *, const char *, const char *, const char *)) $a_callback) ((void *) $a_user_data, (const char *) $a_name, (const char *) $a_base, (const char *) $a_system_id, (const char *) $a_public_id, (const char *) $a_notation_name);"
		end

	call_external_entity_ref_callback (a_callback, a_parser, a_context, a_base, a_system_id, a_public_id: POINTER): INTEGER
			-- Invoke native `XML_ExternalEntityRefHandler'.
		require
			callback_attached: a_callback /= default_pointer
			system_id_attached: a_system_id /= default_pointer
		external
			"C inline"
		alias
			"return (EIF_INTEGER) ((int (*)(void *, const char *, const char *, const char *, const char *)) $a_callback) ((void *) $a_parser, (const char *) $a_context, (const char *) $a_base, (const char *) $a_system_id, (const char *) $a_public_id);"
		end

invariant
	events_attached: events /= Void
	non_negative_start_count: start_element_count >= 0
	non_negative_end_count: end_element_count >= 0
	non_negative_text_count: character_data_count >= 0
	non_negative_pi_count: processing_instruction_count >= 0
	non_negative_xml_decl_count: xml_decl_count >= 0
	non_negative_comment_count: comment_count >= 0
	non_negative_start_cdata_count: start_cdata_section_count >= 0
	non_negative_end_cdata_count: end_cdata_section_count >= 0
	non_negative_default_count: default_count >= 0
	non_negative_start_doctype_count: start_doctype_decl_count >= 0
	non_negative_end_doctype_count: end_doctype_decl_count >= 0
	non_negative_not_standalone_count: not_standalone_count >= 0
	non_negative_element_decl_count: element_decl_count >= 0
	non_negative_notation_decl_count: notation_decl_count >= 0
	non_negative_attlist_count: attlist_decl_count >= 0
	non_negative_entity_decl_count: entity_decl_count >= 0
	non_negative_unparsed_entity_decl_count: unparsed_entity_decl_count >= 0
	non_negative_external_entity_ref_count: external_entity_ref_count >= 0
	non_negative_skipped_entity_count: skipped_entity_count >= 0
	non_negative_current_specified_attribute_count: current_specified_attribute_count >= 0
	current_id_attribute_index_valid: current_id_attribute_index >= -1

end
