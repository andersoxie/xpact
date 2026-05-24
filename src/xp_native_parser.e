note
	description: "Eiffel-owned parser object for the native libexpat-compatible bridge."

class
	XP_NATIVE_PARSER

create
	make

feature {NONE} -- Initialization

	make
		do
			create handler.make
			create parser.make (handler)
			create input_buffer.make_empty
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
		ensure
			handler_attached: handler /= Void
			parser_attached: parser /= Void
			no_error: last_error_code = Xml_error_none
			initialized: parsing_status = Xml_initialized
		end

feature -- Expat-compatible constants

	Xml_status_error: INTEGER = 0

	Xml_status_ok: INTEGER = 1

	Xml_initialized: INTEGER = 0

	Xml_parsing: INTEGER = 1

	Xml_finished: INTEGER = 2

	Xml_error_none: INTEGER = 0

	Xml_error_syntax: INTEGER = 2

	Xml_error_no_elements: INTEGER = 3

	Xml_error_invalid_token: INTEGER = 4

	Xml_error_unclosed_token: INTEGER = 5

	Xml_error_tag_mismatch: INTEGER = 7

	Xml_error_duplicate_attribute: INTEGER = 8

	Xml_error_junk_after_doc_element: INTEGER = 9

	Xml_error_undefined_entity: INTEGER = 11

	Xml_error_recursive_entity_ref: INTEGER = 12

	Xml_error_bad_char_ref: INTEGER = 14

	Xml_error_unclosed_cdata_section: INTEGER = 20

	Xml_error_external_entity_handling: INTEGER = 21

	Xml_error_not_started: INTEGER = 44

feature -- Access

	handler: XP_NATIVE_CALLBACK_HANDLER
			-- Native callback adapter.

	parser: XP_PARSER
			-- Eiffel parser implementation.

	last_error_code: INTEGER
			-- Last Expat-compatible error code.

	parsing_status: INTEGER
			-- Last Expat-compatible parsing status.

	final_buffer: BOOLEAN
			-- Was the last parse call final?

	input_buffer: STRING_8
			-- Native chunks accumulated until the final parse call.

	context_buffer: detachable C_STRING
			-- C-visible copy of the current final input while parsing.

	last_error_text: STRING_8
			-- Last Eiffel parser error text.
		do
			create Result.make_from_string (parser.last_error)
		ensure
			result_attached: Result /= Void
		end

	current_line_number: INTEGER
			-- Current 1-based XML line number.
		do
			Result := parser.current_line_number
		ensure
			line_positive: Result >= 1
		end

	current_column_number: INTEGER
			-- Current 0-based XML column number.
		do
			Result := parser.current_column_number
		ensure
			column_non_negative: Result >= 0
		end

	current_byte_index: INTEGER
			-- Current 0-based byte index, or -1 before parsing starts.
		do
			Result := parser.current_byte_index
		ensure
			valid_before_or_after_start: Result >= -1
		end

	current_byte_count: INTEGER
			-- Current token byte count, or zero at parse end and errors.
		do
			Result := parser.current_byte_count
		ensure
			byte_count_non_negative: Result >= 0
		end

	specified_attribute_count: INTEGER
			-- Expat-style count of explicit attribute vector entries for current start event.
		do
			Result := handler.current_specified_attribute_count
		ensure
			non_negative: Result >= 0
		end

	id_attribute_index: INTEGER
			-- Expat-style ID attribute name index for current start event, or -1.
		do
			Result := handler.current_id_attribute_index
		ensure
			valid_index: Result >= -1
		end

feature -- Element change

	set_user_data (a_user_data: POINTER)
			-- Set callback user data.
		do
			handler.set_user_data (a_user_data)
		ensure
			user_data_set: handler.user_data = a_user_data
		end

	set_element_handlers (a_start, a_end: POINTER)
			-- Set native start/end callbacks.
		do
			handler.set_element_handlers (a_start, a_end)
		ensure
			start_set: handler.start_element_callback = a_start
			end_set: handler.end_element_callback = a_end
		end

	set_character_data_handler (a_handler: POINTER)
			-- Set native character-data callback.
		do
			handler.set_character_data_handler (a_handler)
		ensure
			handler_set: handler.character_data_callback = a_handler
		end

	set_processing_instruction_handler (a_handler: POINTER)
			-- Set native processing-instruction callback.
		do
			handler.set_processing_instruction_handler (a_handler)
		ensure
			handler_set: handler.processing_instruction_callback = a_handler
		end

	set_comment_handler (a_handler: POINTER)
			-- Set native comment callback.
		do
			handler.set_comment_handler (a_handler)
		ensure
			handler_set: handler.comment_callback = a_handler
		end

	set_cdata_section_handlers (a_start, a_end: POINTER)
			-- Set native CDATA section callbacks.
		do
			handler.set_cdata_section_handlers (a_start, a_end)
		ensure
			start_set: handler.start_cdata_section_callback = a_start
			end_set: handler.end_cdata_section_callback = a_end
		end

	set_default_handler (a_handler: POINTER; a_expand: BOOLEAN)
			-- Set native default callback.
		do
			handler.set_default_handler (a_handler, a_expand)
		ensure
			handler_set: handler.default_callback = a_handler
			expand_set: handler.default_expands_entities = a_expand
		end

	set_doctype_decl_handlers (a_start, a_end: POINTER)
			-- Set native doctype declaration callbacks.
		do
			handler.set_doctype_decl_handlers (a_start, a_end)
		ensure
			start_set: handler.start_doctype_decl_callback = a_start
			end_set: handler.end_doctype_decl_callback = a_end
		end

	set_attlist_decl_handler (a_handler: POINTER)
			-- Set native attribute-list declaration callback.
		do
			handler.set_attlist_decl_handler (a_handler)
		ensure
			handler_set: handler.attlist_decl_callback = a_handler
		end

	reset: BOOLEAN
			-- Reset parser state while preserving callback registrations.
		do
			create parser.make (handler)
			input_buffer.wipe_out
			context_buffer := Void
			handler.reset_events
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
			final_buffer := False
			Result := True
		ensure
			reset_succeeded: Result
			no_error: last_error_code = Xml_error_none
			initialized: parsing_status = Xml_initialized
			not_final: not final_buffer
		end

feature -- Parsing

	parse (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): INTEGER
			-- Parse `a_input' through the Eiffel parser.
		require
			input_attached: a_input /= Void
		local
			l_ok: BOOLEAN
		do
			final_buffer := a_is_final
			input_buffer.append (a_input)
			if not a_is_final then
				last_error_code := Xml_error_none
				parsing_status := Xml_parsing
				Result := Xml_status_ok
			else
				parsing_status := Xml_parsing
				handler.reset_events
				create context_buffer.make (input_buffer)
				l_ok := parser.parse (input_buffer)
				parsing_status := Xml_finished
				if l_ok then
					last_error_code := Xml_error_none
					Result := Xml_status_ok
				else
					last_error_code := error_code_for (parser.last_error)
					Result := Xml_status_error
				end
				input_buffer.wipe_out
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error
			success_has_no_error: Result = Xml_status_ok implies last_error_code = Xml_error_none
			final_finished: a_is_final implies parsing_status = Xml_finished
			non_final_parsing: not a_is_final implies parsing_status = Xml_parsing
			final_recorded: final_buffer = a_is_final
		end

	input_context (a_offset, a_size: POINTER): POINTER
			-- Current input context buffer for `XML_GetInputContext'.
		do
			if parsing_status = Xml_parsing and then attached context_buffer as l_context then
				if a_offset /= default_pointer then
					put_integer (a_offset, current_byte_index)
				end
				if a_size /= default_pointer then
					put_integer (a_size, l_context.count)
				end
				Result := l_context.item
			else
				if a_offset /= default_pointer then
					put_integer (a_offset, 0)
				end
				if a_size /= default_pointer then
					put_integer (a_size, 0)
				end
			end
		end

feature {NONE} -- Error mapping

	error_code_for (a_error: READABLE_STRING_8): INTEGER
			-- Expat-compatible error code for Eiffel parser error `a_error'.
		require
			error_attached: a_error /= Void
		do
			if a_error.same_string ("missing document element") then
				Result := Xml_error_no_elements
			elseif a_error.same_string ("mismatched end tag") then
				Result := Xml_error_tag_mismatch
			elseif a_error.same_string ("duplicate attribute") then
				Result := Xml_error_duplicate_attribute
			elseif a_error.same_string ("multiple document elements") then
				Result := Xml_error_junk_after_doc_element
			elseif a_error.same_string ("undefined entity") then
				Result := Xml_error_undefined_entity
			elseif a_error.same_string ("recursive entity reference") then
				Result := Xml_error_recursive_entity_ref
			elseif a_error.same_string ("invalid character reference") then
				Result := Xml_error_bad_char_ref
			elseif a_error.same_string ("unterminated CDATA section") then
				Result := Xml_error_unclosed_cdata_section
			elseif a_error.has_substring ("external entity") then
				Result := Xml_error_external_entity_handling
			elseif a_error.has_substring ("unterminated") or else a_error.has_substring ("unclosed") then
				Result := Xml_error_unclosed_token
			elseif a_error.has_substring ("invalid") or else a_error.has_substring ("outside document element") then
				Result := Xml_error_invalid_token
			else
				Result := Xml_error_syntax
			end
		ensure
			known_error: Result /= Xml_error_none
		end

feature {NONE} -- Native helpers

	put_integer (a_target: POINTER; a_value: INTEGER)
			-- Write C `int' value.
		require
			target_attached: a_target /= default_pointer
		external
			"C inline"
		alias
			"*((int *) $a_target) = (int) $a_value;"
		end

invariant
	handler_attached: handler /= Void
	parser_attached: parser /= Void
	input_buffer_attached: input_buffer /= Void
	valid_parsing_status: parsing_status = Xml_initialized or parsing_status = Xml_parsing or parsing_status = Xml_finished
	valid_last_error_code: last_error_code >= Xml_error_none

end
