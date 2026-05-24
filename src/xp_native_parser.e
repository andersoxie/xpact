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
			parser.set_external_entity_resolver (handler)
			configure_external_entity_policy
			create input_buffer.make_empty
			create hash_salt_16_bytes.make_empty
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
		ensure
			handler_attached: handler /= Void
			parser_attached: parser /= Void
			hash_salt_16_bytes_attached: hash_salt_16_bytes /= Void
			no_error: last_error_code = Xml_error_none
			initialized: parsing_status = Xml_initialized
		end

feature -- Expat-compatible constants

	Xml_status_error: INTEGER = 0

	Xml_status_ok: INTEGER = 1

	Xml_initialized: INTEGER = 0

	Xml_parsing: INTEGER = 1

	Xml_finished: INTEGER = 2

	Xml_param_entity_parsing_never: INTEGER = 0

	Xml_param_entity_parsing_unless_standalone: INTEGER = 1

	Xml_param_entity_parsing_always: INTEGER = 2

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

	Xml_error_async_entity: INTEGER = 13

	Xml_error_bad_char_ref: INTEGER = 14

	Xml_error_unclosed_cdata_section: INTEGER = 20

	Xml_error_external_entity_handling: INTEGER = 21

	Xml_error_unknown_encoding: INTEGER = 18

	Xml_error_publicid: INTEGER = 32

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

	is_external_entity_parser: BOOLEAN
			-- Should input be parsed as an external parsed entity fragment?

	external_entity_context: detachable STRING_8
			-- Native context string supplied to `XML_ExternalEntityParserCreate', if any.

	param_entity_parsing: INTEGER
			-- Expat-compatible parameter entity parsing mode.

	explicit_encoding: detachable STRING_8
			-- Native `XML_SetEncoding' value, if any.

	has_unsupported_explicit_encoding: BOOLEAN
			-- Should the next parse fail because `explicit_encoding' is unsupported?

	hash_salt: INTEGER_64
			-- Last legacy Expat hash salt accepted before parsing started.

	has_hash_salt: BOOLEAN
			-- Has `hash_salt' been explicitly configured?

	hash_salt_16_bytes: STRING_8
			-- Last 16-byte Expat hash entropy accepted before parsing started.

	has_hash_salt_16_bytes: BOOLEAN
			-- Has `hash_salt_16_bytes' been explicitly configured?

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

	set_element_decl_handler (a_handler: POINTER)
			-- Set native element declaration callback.
		do
			handler.set_element_decl_handler (a_handler)
		ensure
			handler_set: handler.element_decl_callback = a_handler
		end

	set_notation_decl_handler (a_handler: POINTER)
			-- Set native notation declaration callback.
		do
			handler.set_notation_decl_handler (a_handler)
		ensure
			handler_set: handler.notation_decl_callback = a_handler
		end

	set_attlist_decl_handler (a_handler: POINTER)
			-- Set native attribute-list declaration callback.
		do
			handler.set_attlist_decl_handler (a_handler)
		ensure
			handler_set: handler.attlist_decl_callback = a_handler
		end

	set_entity_decl_handler (a_handler: POINTER)
			-- Set native entity declaration callback.
		do
			handler.set_entity_decl_handler (a_handler)
		ensure
			handler_set: handler.entity_decl_callback = a_handler
		end

	set_unparsed_entity_decl_handler (a_handler: POINTER)
			-- Set native unparsed entity declaration callback.
		do
			handler.set_unparsed_entity_decl_handler (a_handler)
		ensure
			handler_set: handler.unparsed_entity_decl_callback = a_handler
		end

	set_external_entity_ref_handler (a_handler: POINTER)
			-- Set native external entity reference callback.
		do
			handler.set_external_entity_ref_handler (a_handler)
			configure_external_entity_policy
		ensure
			handler_set: handler.external_entity_ref_callback = a_handler
		end

	set_external_entity_ref_handler_arg (a_arg: POINTER)
			-- Set native external entity reference callback argument.
		do
			handler.set_external_entity_ref_handler_arg (a_arg)
		ensure
			arg_set: handler.external_entity_ref_arg = a_arg
		end

	set_skipped_entity_handler (a_handler: POINTER)
			-- Set native skipped entity callback.
		do
			handler.set_skipped_entity_handler (a_handler)
		ensure
			handler_set: handler.skipped_entity_callback = a_handler
		end

	default_current
			-- Replay current callback text through the default handler.
		do
			handler.default_current
		end

	set_native_parser_handle (a_parser: POINTER)
			-- Set native parser handle used by native callbacks.
		do
			handler.set_native_parser_handle (a_parser)
		ensure
			handle_set: handler.native_parser_handle = a_parser
		end

	set_encoding (a_encoding: POINTER): INTEGER
			-- Set explicit native input encoding.
		local
			l_encoding: C_STRING
			l_name: STRING_8
		do
			if parsing_status = Xml_parsing then
				Result := Xml_status_error
			else
				if a_encoding = default_pointer then
					explicit_encoding := Void
					has_unsupported_explicit_encoding := False
				else
					create l_encoding.make_by_pointer (a_encoding)
					l_name := l_encoding.string
					explicit_encoding := l_name.twin
					has_unsupported_explicit_encoding := not is_supported_explicit_encoding (l_name)
				end
				Result := Xml_status_ok
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error
			rejected_only_while_parsing: Result = Xml_status_error implies parsing_status = Xml_parsing
		end

	set_external_entity_context (a_context: POINTER): BOOLEAN
			-- Mark this parser as an external parsed entity parser.
		local
			l_context: C_STRING
		do
			if parsing_status = Xml_initialized then
				is_external_entity_parser := True
				if a_context = default_pointer then
					external_entity_context := Void
				else
					create l_context.make_by_pointer (a_context)
					external_entity_context := l_context.string.twin
				end
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_marks_external: Result implies is_external_entity_parser
		end

	set_param_entity_parsing (a_parsing: INTEGER): BOOLEAN
			-- Set Expat-compatible parameter entity parsing mode before parsing starts.
		do
			if
				parsing_status = Xml_initialized
				and then (
					a_parsing = Xml_param_entity_parsing_never
					or else a_parsing = Xml_param_entity_parsing_unless_standalone
					or else a_parsing = Xml_param_entity_parsing_always
				)
			then
				param_entity_parsing := a_parsing
				configure_external_entity_policy
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_sets_mode: Result implies param_entity_parsing = a_parsing
		end

	set_hash_salt (a_hash_salt: INTEGER_64): BOOLEAN
			-- Set legacy Expat hash salt before parsing starts.
		do
			if parsing_status = Xml_initialized then
				hash_salt := a_hash_salt
				has_hash_salt := True
				has_hash_salt_16_bytes := False
				hash_salt_16_bytes.wipe_out
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_records_salt: Result implies has_hash_salt and then hash_salt = a_hash_salt
			accepted_clears_16_byte_salt: Result implies not has_hash_salt_16_bytes
		end

	set_hash_salt_16_bytes (a_entropy: POINTER): BOOLEAN
			-- Copy 16 bytes of Expat hash entropy before parsing starts.
		local
			l_entropy: C_STRING
		do
			if a_entropy /= default_pointer and then parsing_status = Xml_initialized then
				create l_entropy.make_by_pointer_and_count (a_entropy, 16)
				hash_salt_16_bytes := l_entropy.substring_8 (1, 16)
				has_hash_salt_16_bytes := True
				has_hash_salt := False
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_records_entropy: Result implies has_hash_salt_16_bytes and then hash_salt_16_bytes.count = 16
			accepted_clears_legacy_salt: Result implies not has_hash_salt
		end

	reset: BOOLEAN
			-- Reset parser state while preserving callback registrations.
		do
			create parser.make (handler)
			parser.set_external_entity_resolver (handler)
			configure_external_entity_policy
			input_buffer.wipe_out
			context_buffer := Void
			handler.reset_events
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
			final_buffer := False
			is_external_entity_parser := False
			external_entity_context := Void
			param_entity_parsing := Xml_param_entity_parsing_never
			explicit_encoding := Void
			has_unsupported_explicit_encoding := False
			hash_salt := 0
			has_hash_salt := False
			hash_salt_16_bytes.wipe_out
			has_hash_salt_16_bytes := False
			Result := True
		ensure
			reset_succeeded: Result
			no_error: last_error_code = Xml_error_none
			initialized: parsing_status = Xml_initialized
			not_final: not final_buffer
			not_external_entity_parser: not is_external_entity_parser
			param_entity_parsing_reset: param_entity_parsing = Xml_param_entity_parsing_never
			no_explicit_encoding: explicit_encoding = Void and not has_unsupported_explicit_encoding
			no_hash_salt: not has_hash_salt and not has_hash_salt_16_bytes
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
			if has_unsupported_explicit_encoding then
				last_error_code := Xml_error_unknown_encoding
				parsing_status := Xml_finished
				Result := Xml_status_error
			else
				input_buffer.append (a_input)
				if not a_is_final then
					last_error_code := Xml_error_none
					parsing_status := Xml_parsing
					Result := Xml_status_ok
				else
					parsing_status := Xml_parsing
					handler.reset_events
					create context_buffer.make (input_buffer)
					if is_external_entity_parser then
						l_ok := parser.parse_external_entity (input_buffer)
					else
						l_ok := parser.parse (input_buffer)
					end
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
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error
			success_has_no_error: Result = Xml_status_ok implies last_error_code = Xml_error_none
			final_finished: a_is_final implies parsing_status = Xml_finished
			success_non_final_parsing: Result = Xml_status_ok and not a_is_final implies parsing_status = Xml_parsing
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

feature {NONE} -- Encoding

	is_supported_explicit_encoding (a_encoding: READABLE_STRING_8): BOOLEAN
			-- Is `a_encoding' supported by the current native parser path?
		require
			encoding_attached: a_encoding /= Void
		do
			Result :=
				a_encoding.same_string ("UTF-8")
				or else a_encoding.same_string ("utf-8")
				or else a_encoding.same_string ("UTF8")
				or else a_encoding.same_string ("utf8")
		end

feature {NONE} -- Error mapping

	configure_external_entity_policy
			-- Keep Eiffel resolver policy aligned with native external entity callbacks.
		do
			if param_entity_parsing = Xml_param_entity_parsing_never then
				parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities)
			else
				parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities)
			end
		end

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
			elseif a_error.same_string ("asynchronous entity") then
				Result := Xml_error_async_entity
			elseif a_error.same_string ("invalid character reference") then
				Result := Xml_error_bad_char_ref
			elseif a_error.same_string ("unterminated CDATA section") then
				Result := Xml_error_unclosed_cdata_section
			elseif a_error.has_substring ("external entity") then
				Result := Xml_error_external_entity_handling
			elseif a_error.same_string ("invalid public identifier") then
				Result := Xml_error_publicid
			elseif a_error.has_substring ("unterminated") or else a_error.has_substring ("unclosed") then
				Result := Xml_error_unclosed_token
			elseif a_error.has_substring ("invalid")
				or else a_error.has_substring ("outside document element")
				or else a_error.same_string ("unexpected end tag")
			then
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
