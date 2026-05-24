note
	description: "Event sink for the xpact streaming parser."

deferred class
	XP_EVENT_HANDLER

feature -- Events

	wants_automatic_character_data_default: BOOLEAN
			-- Should character data also be emitted through `on_default' automatically?
		do
			Result := True
		end

	expands_internal_general_entity_references: BOOLEAN
			-- Should internal general entity references be expanded in content?
		do
			Result := True
		end

	reports_skipped_internal_general_entities: BOOLEAN
			-- Should skipped internal general entities be reported through `on_skipped_entity'?
		do
			Result := False
		end

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

	on_processing_instruction (a_target, a_data: READABLE_STRING_8)
			-- Processing instruction was parsed.
		require
			target_attached: a_target /= Void
			target_not_empty: not a_target.is_empty
			data_attached: a_data /= Void
		do
		end

	on_xml_declaration (a_version, a_encoding: READABLE_STRING_8; a_standalone: INTEGER)
			-- XML declaration was parsed.
		require
			version_attached: a_version /= Void
			encoding_attached: a_encoding /= Void
			valid_standalone: a_standalone = -1 or a_standalone = 0 or a_standalone = 1
		do
		end

	on_comment (a_text: READABLE_STRING_8)
			-- Comment text was parsed.
		require
			text_attached: a_text /= Void
		do
		end

	on_start_cdata_section
			-- CDATA section started.
		do
		end

	on_end_cdata_section
			-- CDATA section ended.
		do
		end

	on_start_doctype_decl (a_name: READABLE_STRING_8; a_system_id, a_public_id: detachable READABLE_STRING_8; a_has_internal_subset: BOOLEAN)
			-- Doctype declaration started.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		do
		end

	on_end_doctype_decl
			-- Doctype declaration ended.
		do
		end

	on_element_decl (a_name: READABLE_STRING_8; a_model: XP_CONTENT_MODEL)
			-- Element declaration was parsed.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			model_attached: a_model /= Void
		do
		end

	on_notation_decl (a_name: READABLE_STRING_8; a_base, a_system_id, a_public_id: detachable READABLE_STRING_8)
			-- Notation declaration was parsed.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		do
		end

	on_attlist_decl (a_element_name, a_attribute_name, a_attribute_type: READABLE_STRING_8; a_default_value: detachable READABLE_STRING_8; a_is_required: BOOLEAN)
			-- Attribute-list declaration was parsed.
		require
			element_name_attached: a_element_name /= Void
			element_name_not_empty: not a_element_name.is_empty
			attribute_name_attached: a_attribute_name /= Void
			attribute_name_not_empty: not a_attribute_name.is_empty
			attribute_type_attached: a_attribute_type /= Void
			attribute_type_not_empty: not a_attribute_type.is_empty
		do
		end

	on_entity_decl (a_name: READABLE_STRING_8; a_is_parameter: BOOLEAN; a_value: detachable READABLE_STRING_8; a_public_id, a_system_id, a_notation_name: detachable READABLE_STRING_8)
			-- Entity declaration was parsed.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		do
		end

	on_unparsed_entity_decl (a_name, a_system_id: READABLE_STRING_8; a_public_id, a_notation_name: detachable READABLE_STRING_8)
			-- Unparsed entity declaration was parsed.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			system_id_attached: a_system_id /= Void
			system_id_not_empty: not a_system_id.is_empty
		do
		end

	on_skipped_entity (a_name: READABLE_STRING_8; a_is_parameter: BOOLEAN)
			-- Entity reference `a_name' was skipped.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		do
		end

	on_default (a_text: READABLE_STRING_8)
			-- Raw default-handler text was parsed.
		require
			text_attached: a_text /= Void
		do
		end

end
