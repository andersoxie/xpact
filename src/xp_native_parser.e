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

	Xml_error_partial_char: INTEGER = 6

	Xml_error_tag_mismatch: INTEGER = 7

	Xml_error_duplicate_attribute: INTEGER = 8

	Xml_error_junk_after_doc_element: INTEGER = 9

	Xml_error_undefined_entity: INTEGER = 11

	Xml_error_recursive_entity_ref: INTEGER = 12

	Xml_error_async_entity: INTEGER = 13

	Xml_error_bad_char_ref: INTEGER = 14

	Xml_error_misplaced_xml_pi: INTEGER = 17

	Xml_error_unknown_encoding: INTEGER = 18

	Xml_error_incorrect_encoding: INTEGER = 19

	Xml_error_unclosed_cdata_section: INTEGER = 20

	Xml_error_external_entity_handling: INTEGER = 21

	Xml_error_not_standalone: INTEGER = 22

	Xml_error_cant_change_feature_once_parsing: INTEGER = 26

	Xml_error_xml_decl: INTEGER = 30

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

	external_entity_is_parameter: BOOLEAN
			-- Should this external parser parse DTD subset or parameter entity content?

	param_entity_parsing: INTEGER
			-- Expat-compatible parameter entity parsing mode.

	use_foreign_dtd: BOOLEAN
			-- Should a foreign DTD be loaded when no external subset is declared?

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

	set_xml_decl_handler (a_handler: POINTER)
			-- Set native XML declaration callback.
		do
			handler.set_xml_decl_handler (a_handler)
		ensure
			handler_set: handler.xml_decl_callback = a_handler
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

	set_not_standalone_handler (a_handler: POINTER)
			-- Set native not-standalone callback.
		do
			handler.set_not_standalone_handler (a_handler)
		ensure
			handler_set: handler.not_standalone_callback = a_handler
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

	set_external_entity_parameter_context (a_is_parameter: BOOLEAN): BOOLEAN
			-- Mark whether this external parser receives DTD subset content.
		do
			if parsing_status = Xml_initialized then
				external_entity_is_parameter := a_is_parameter
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_sets_value: Result implies external_entity_is_parameter = a_is_parameter
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

	set_foreign_dtd (a_use_dtd: BOOLEAN): BOOLEAN
			-- Set Expat-compatible foreign DTD loading before parsing starts.
		do
			if parsing_status = Xml_initialized then
				use_foreign_dtd := a_use_dtd
				parser.set_use_foreign_dtd (a_use_dtd)
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_sets_value: Result implies use_foreign_dtd = a_use_dtd
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
			input_buffer.wipe_out
			context_buffer := Void
			handler.reset_events
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
			final_buffer := False
			is_external_entity_parser := False
			external_entity_context := Void
			external_entity_is_parameter := False
			param_entity_parsing := Xml_param_entity_parsing_never
			use_foreign_dtd := False
			create parser.make (handler)
			parser.set_external_entity_resolver (handler)
			configure_external_entity_policy
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
			not_external_parameter_entity_parser: not external_entity_is_parameter
			param_entity_parsing_reset: param_entity_parsing = Xml_param_entity_parsing_never
			foreign_dtd_reset: not use_foreign_dtd
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
			l_input: detachable STRING_8
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
					l_input := decoded_input (input_buffer)
					if l_input = Void then
						Result := Xml_status_error
					else
						if is_external_entity_parser and then external_entity_is_parameter then
							l_ok := parser.parse_external_subset_with_context (l_input, external_entity_context)
						elseif is_external_entity_parser then
							l_ok := parser.parse_external_entity (l_input)
						else
							l_ok := parser.parse (l_input)
						end
						if l_ok then
							last_error_code := Xml_error_none
							Result := Xml_status_ok
						else
							last_error_code := error_code_for (parser.last_error)
							Result := Xml_status_error
						end
					end
					parsing_status := Xml_finished
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
				or else a_encoding.same_string ("US-ASCII")
				or else a_encoding.same_string ("us-ascii")
				or else a_encoding.same_string ("ASCII")
				or else a_encoding.same_string ("ascii")
				or else a_encoding.same_string ("ISO-8859-1")
				or else a_encoding.same_string ("iso-8859-1")
				or else a_encoding.same_string ("UTF-16")
				or else a_encoding.same_string ("utf-16")
				or else a_encoding.same_string ("UTF-16LE")
				or else a_encoding.same_string ("utf-16le")
				or else a_encoding.same_string ("UTF-16BE")
				or else a_encoding.same_string ("utf-16be")
		end

	decoded_input (a_input: READABLE_STRING_8): detachable STRING_8
			-- Native input decoded to the parser's UTF-8 byte stream.
		require
			input_attached: a_input /= Void
		do
			if explicit_encoding_is_latin1 then
				Result := decoded_latin1_input (a_input)
			elseif explicit_encoding_is_ascii then
				Result := decoded_ascii_input (a_input)
			elseif explicit_encoding_is_utf16be then
				Result := decoded_utf16_input (a_input, False)
			elseif explicit_encoding_is_utf16le then
				Result := decoded_utf16_input (a_input, True)
			elseif has_utf16le_signature (a_input) then
				Result := decoded_utf16_input (a_input, True)
			elseif has_utf16be_signature (a_input) then
				Result := decoded_utf16_input (a_input, False)
			elseif explicit_encoding_is_utf16 then
				last_error_code := Xml_error_incorrect_encoding
			elseif has_utf16_declaration_in_utf8_input (a_input) then
				last_error_code := Xml_error_incorrect_encoding
			else
				create Result.make_from_string (a_input)
			end
		end

	decoded_latin1_input (a_input: READABLE_STRING_8): STRING_8
			-- Decode ISO-8859-1 bytes to UTF-8.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
		do
			create Result.make (a_input.count)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
			until
				i > a_input.count
			loop
				append_utf8_codepoint (Result, a_input.item (i).code)
				i := i + 1
			variant
				a_input.count - i + 1
			end
		end

	decoded_ascii_input (a_input: READABLE_STRING_8): detachable STRING_8
			-- Validate US-ASCII input and pass it through as UTF-8.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_invalid: BOOLEAN
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
			until
				i > a_input.count or l_invalid
			loop
				if a_input.item (i).code > 127 then
					l_invalid := True
					last_error_code := Xml_error_invalid_token
				end
				i := i + 1
			variant
				a_input.count - i + 1
			end
			if not l_invalid then
				create Result.make_from_string (a_input)
			end
		end

	decoded_utf16_input (a_input: READABLE_STRING_8; a_little_endian: BOOLEAN): detachable STRING_8
			-- Decode UTF-16 bytes to UTF-8, validating surrogate structure.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_unit: INTEGER
			l_low: INTEGER
			l_code: INTEGER
		do
			if a_input.count \\ 2 /= 0 then
				last_error_code := Xml_error_partial_char
			else
				create Result.make (a_input.count)
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= a_input.count + 1
				until
					i > a_input.count or Result = Void
				loop
					l_unit := utf16_unit_at (a_input, i, a_little_endian)
					if i = 1 and then l_unit = 65279 then
						i := i + 2
					elseif l_unit >= 55296 and then l_unit <= 56319 then
						if i + 3 > a_input.count then
							last_error_code := Xml_error_partial_char
							Result := Void
						else
							l_low := utf16_unit_at (a_input, i + 2, a_little_endian)
							if l_low < 56320 or else l_low > 57343 then
								last_error_code := Xml_error_invalid_token
								Result := Void
							else
								l_code := 65536 + ((l_unit - 55296) * 1024) + (l_low - 56320)
								append_utf8_codepoint (Result, l_code)
								i := i + 4
							end
						end
					elseif l_unit >= 56320 and then l_unit <= 57343 then
						last_error_code := Xml_error_invalid_token
						Result := Void
					else
						append_utf8_codepoint (Result, l_unit)
						i := i + 2
					end
				variant
					a_input.count - i + 1
				end
			end
		end

	utf16_unit_at (a_input: READABLE_STRING_8; a_index: INTEGER; a_little_endian: BOOLEAN): INTEGER
			-- UTF-16 code unit at byte index `a_index'.
		require
			input_attached: a_input /= Void
			valid_index: a_index >= 1 and a_index + 1 <= a_input.count
		local
			l_first: INTEGER
			l_second: INTEGER
		do
			l_first := a_input.item (a_index).code
			l_second := a_input.item (a_index + 1).code
			if a_little_endian then
				Result := l_first + (l_second * 256)
			else
				Result := (l_first * 256) + l_second
			end
		end

	append_utf8_codepoint (a_output: STRING_8; a_code: INTEGER)
			-- Append Unicode code point `a_code' as UTF-8 bytes.
		require
			output_attached: a_output /= Void
		do
			if a_code <= 127 then
				a_output.append_character (a_code.to_character_8)
			elseif a_code <= 2047 then
				a_output.append_character ((192 + (a_code // 64)).to_character_8)
				a_output.append_character ((128 + (a_code \\ 64)).to_character_8)
			elseif a_code <= 65535 then
				a_output.append_character ((224 + (a_code // 4096)).to_character_8)
				a_output.append_character ((128 + ((a_code // 64) \\ 64)).to_character_8)
				a_output.append_character ((128 + (a_code \\ 64)).to_character_8)
			else
				a_output.append_character ((240 + (a_code // 262144)).to_character_8)
				a_output.append_character ((128 + ((a_code // 4096) \\ 64)).to_character_8)
				a_output.append_character ((128 + ((a_code // 64) \\ 64)).to_character_8)
				a_output.append_character ((128 + (a_code \\ 64)).to_character_8)
			end
		end

	has_utf16le_signature (a_input: READABLE_STRING_8): BOOLEAN
			-- Does input declare little-endian UTF-16 by BOM or initial token shape?
		require
			input_attached: a_input /= Void
		do
			Result :=
				(a_input.count >= 2 and then a_input.item (1).code = 255 and then a_input.item (2).code = 254)
				or else (a_input.count >= 4 and then a_input.item (1) = '<' and then a_input.item (2).code = 0 and then a_input.item (3) = '?' and then a_input.item (4).code = 0)
				or else (a_input.count >= 4 and then a_input.item (1) = '<' and then a_input.item (2).code = 0 and then a_input.item (3) = '!' and then a_input.item (4).code = 0)
				or else (a_input.count >= 4 and then a_input.item (1) = '<' and then a_input.item (2).code = 0 and then a_input.item (3).is_alpha and then a_input.item (4).code = 0)
		end

	has_utf16be_signature (a_input: READABLE_STRING_8): BOOLEAN
			-- Does input declare big-endian UTF-16 by BOM or initial token shape?
		require
			input_attached: a_input /= Void
		do
			Result :=
				(a_input.count >= 2 and then a_input.item (1).code = 254 and then a_input.item (2).code = 255)
				or else (a_input.count >= 4 and then a_input.item (1).code = 0 and then a_input.item (2) = '<' and then a_input.item (3).code = 0 and then a_input.item (4) = '?')
				or else (a_input.count >= 4 and then a_input.item (1).code = 0 and then a_input.item (2) = '<' and then a_input.item (3).code = 0 and then a_input.item (4) = '!')
				or else (a_input.count >= 4 and then a_input.item (1).code = 0 and then a_input.item (2) = '<' and then a_input.item (3).code = 0 and then a_input.item (4).is_alpha)
		end

	has_utf16_declaration_in_utf8_input (a_input: READABLE_STRING_8): BOOLEAN
			-- Does an otherwise UTF-8 byte stream claim UTF-16 in its XML declaration?
		require
			input_attached: a_input /= Void
		do
			Result :=
				a_input.has_substring ("encoding='utf-16'")
				or else a_input.has_substring ("encoding=%"utf-16%"")
				or else a_input.has_substring ("encoding='UTF-16'")
				or else a_input.has_substring ("encoding=%"UTF-16%"")
		end

	explicit_encoding_is_utf16: BOOLEAN
			-- Did the caller explicitly select UTF-16 with auto endian detection?
		do
			Result := attached explicit_encoding as l_encoding and then (l_encoding.same_string ("UTF-16") or else l_encoding.same_string ("utf-16"))
		end

	explicit_encoding_is_latin1: BOOLEAN
			-- Did the caller explicitly select ISO-8859-1?
		do
			Result := attached explicit_encoding as l_encoding and then (l_encoding.same_string ("ISO-8859-1") or else l_encoding.same_string ("iso-8859-1"))
		end

	explicit_encoding_is_ascii: BOOLEAN
			-- Did the caller explicitly select US-ASCII?
		do
			Result := attached explicit_encoding as l_encoding and then (
				l_encoding.same_string ("US-ASCII")
				or else l_encoding.same_string ("us-ascii")
				or else l_encoding.same_string ("ASCII")
				or else l_encoding.same_string ("ascii")
			)
		end

	explicit_encoding_is_utf16le: BOOLEAN
			-- Did the caller explicitly select UTF-16LE?
		do
			Result := attached explicit_encoding as l_encoding and then (l_encoding.same_string ("UTF-16LE") or else l_encoding.same_string ("utf-16le"))
		end

	explicit_encoding_is_utf16be: BOOLEAN
			-- Did the caller explicitly select UTF-16BE?
		do
			Result := attached explicit_encoding as l_encoding and then (l_encoding.same_string ("UTF-16BE") or else l_encoding.same_string ("utf-16be"))
		end

feature {NONE} -- Error mapping

	configure_external_entity_policy
			-- Keep Eiffel resolver policy aligned with native external entity callbacks.
		do
			if param_entity_parsing = Xml_param_entity_parsing_never then
				parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities)
				parser.set_parameter_entities_unless_standalone (False)
			elseif param_entity_parsing = Xml_param_entity_parsing_unless_standalone then
				parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities)
				parser.set_parameter_entities_unless_standalone (True)
			else
				parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities)
				parser.set_parameter_entities_unless_standalone (False)
			end
			parser.set_use_foreign_dtd (use_foreign_dtd)
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
			elseif a_error.same_string ("not standalone") then
				Result := Xml_error_not_standalone
			elseif a_error.same_string ("misplaced xml declaration") then
				Result := Xml_error_misplaced_xml_pi
			elseif a_error.same_string ("invalid xml declaration") then
				Result := Xml_error_xml_decl
			elseif a_error.same_string ("invalid public identifier") then
				Result := Xml_error_publicid
			elseif a_error.same_string ("incorrect encoding") then
				Result := Xml_error_incorrect_encoding
			elseif a_error.has_substring ("unterminated") or else a_error.has_substring ("unclosed") then
				Result := Xml_error_unclosed_token
			elseif a_error.same_string ("partial character") then
				Result := Xml_error_partial_char
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
