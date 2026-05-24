note
	description: "Eiffel entry point that installs the native libexpat bridge."

class
	XP_NATIVE_BRIDGE_EXPORT

inherit
	XP_NATIVE_BRIDGE_INSTALLER

create
	make

feature -- Access

	installed: BOOLEAN
			-- Is this installer currently registered with the native bridge?

feature -- Bridge registration

	install: BOOLEAN
			-- Register Current as the Eiffel implementation behind `include/xpact.h'.
		do
			Result := c_register_eiffel_runtime_bridge (
				Current,
				$parser_create,
				$parser_reset,
				$parser_free,
				$set_user_data,
				$set_element_handler,
				$set_character_data_handler,
				$set_processing_instruction_handler,
				$set_comment_handler,
				$set_cdata_section_handler,
				$set_default_handler,
				$set_doctype_decl_handler,
				$set_element_decl_handler,
				$set_notation_decl_handler,
				$set_attlist_decl_handler,
				$set_entity_decl_handler,
				$set_unparsed_entity_decl_handler,
				$set_external_entity_ref_handler,
				$set_external_entity_ref_handler_arg,
				$set_skipped_entity_handler,
				$default_current,
				$set_hash_salt,
				$set_hash_salt_16_bytes,
				$parse,
				$get_buffer,
				$parse_buffer,
				$get_error_code,
				$get_current_line_number,
				$get_current_column_number,
				$get_current_byte_index,
				$get_current_byte_count,
				$get_specified_attribute_count,
				$get_id_attribute_index,
				$get_input_context,
				$get_parsing_status
			)
			installed := Result
		ensure
			installed_recorded: installed = Result
		end

	uninstall
			-- Remove Current from the native bridge.
		do
			c_unregister_eiffel_runtime_bridge
			installed := False
		ensure
			not_installed: not installed
		end

feature {NONE} -- Native calls

	c_register_eiffel_runtime_bridge (
		a_installer: XP_NATIVE_BRIDGE_EXPORT;
		a_parser_create,
		a_parser_reset,
		a_parser_free,
		a_set_user_data,
		a_set_element_handler,
		a_set_character_data_handler,
		a_set_processing_instruction_handler,
		a_set_comment_handler,
		a_set_cdata_section_handler,
		a_set_default_handler,
		a_set_doctype_decl_handler,
		a_set_element_decl_handler,
		a_set_notation_decl_handler,
		a_set_attlist_decl_handler,
		a_set_entity_decl_handler,
		a_set_unparsed_entity_decl_handler,
		a_set_external_entity_ref_handler,
		a_set_external_entity_ref_handler_arg,
		a_set_skipped_entity_handler,
		a_default_current,
		a_set_hash_salt,
		a_set_hash_salt_16_bytes,
		a_parse,
		a_get_buffer,
		a_parse_buffer,
		a_get_error_code,
		a_get_current_line_number,
		a_get_current_column_number,
		a_get_current_byte_index,
		a_get_current_byte_count,
		a_get_specified_attribute_count,
		a_get_id_attribute_index,
		a_get_input_context,
		a_get_parsing_status: POINTER
	): BOOLEAN
			-- Register Eiffel runtime bridge through pointer-based C wrapper.
		require
			installer_attached: a_installer /= Void
			parser_create_attached: a_parser_create /= default_pointer
			parser_reset_attached: a_parser_reset /= default_pointer
			parser_free_attached: a_parser_free /= default_pointer
			parse_attached: a_parse /= default_pointer
			get_buffer_attached: a_get_buffer /= default_pointer
			parse_buffer_attached: a_parse_buffer /= default_pointer
			get_error_code_attached: a_get_error_code /= default_pointer
			get_input_context_attached: a_get_input_context /= default_pointer
			get_parsing_status_attached: a_get_parsing_status /= default_pointer
		external
			"C signature (EIF_OBJECT, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER, EIF_POINTER): EIF_BOOLEAN use %"xpact_eiffel_runtime_bridge.h%""
		alias
			"XPACT_RegisterEiffelRuntimeBridgePointers"
		end

	c_unregister_eiffel_runtime_bridge
			-- Unregister Eiffel runtime bridge.
		external
			"C signature () use %"xpact_eiffel_runtime_bridge.h%""
		alias
			"XPACT_UnregisterEiffelRuntimeBridge"
		end

invariant
	installed_implies_live_object: installed implies active_parser_count >= 0

end
