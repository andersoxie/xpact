note
	description: "Eiffel runtime owner for parser handles used by the native bridge."

class
	XP_NATIVE_BRIDGE_INSTALLER

inherit
	IDENTIFIED_ROUTINES

	EXCEPTION_MANAGER_FACTORY
		export
			{NONE} all
		end

create
	make

feature {NONE} -- Initialization

	make
		do
			create live_parser_ids.make (16)
			create parse_buffers.make (16)
			create input_chunk.make (Input_chunk_reuse_limit)
			create failed_parser_codes.make (4)
			diagnostic_events_enabled := True
			trace_exceptions := attached (create {EXECUTION_ENVIRONMENT}).item ("XPACT_EXCEPTION_TRACE") as l_value
				and then not l_value.is_empty
		ensure
			no_live_parsers: active_parser_count = 0
		end

feature -- Expat-compatible constants

	Xml_status_error: INTEGER = 0

	Xml_status_ok: INTEGER = 1

	Xml_initialized: INTEGER = 0

	Xml_finished: INTEGER = 2

	Xml_error_invalid_argument: INTEGER = 41

	Xml_error_no_memory: INTEGER = 1
			-- Expat's error for an allocation failure.

	Xml_error_unexpected_state: INTEGER = 23
			-- Expat's "unexpected parser state - please send a bug report".

feature -- Access

	active_parser_count: INTEGER
			-- Number of parser handles currently owned by this installer.
		do
			Result := live_parser_ids.count
		ensure
			non_negative: Result >= 0
		end

	diagnostic_events_enabled: BOOLEAN
			-- Should parsers created by this installer record internal diagnostics?

	parser_for (a_handle: POINTER): detachable XP_NATIVE_PARSER
			-- Parser object represented by native opaque `a_handle', if live.
		local
			l_id: INTEGER
		do
			l_id := pointer_to_integer (a_handle)
			if l_id > 0 and then live_parser_ids.has (l_id) and then not failed_parser_codes.has (l_id) then
				Result := live_parser_ids.item (l_id)
			end
		end

	failure_count: INTEGER
			-- Number of Eiffel exceptions caught at a native entry point (#273).

feature -- Parser lifecycle callbacks

	parser_create (a_encoding, a_memsuite, a_namespace_separator: POINTER): POINTER
			-- Create an Eiffel parser and return an opaque native handle.
		local
			l_failed: BOOLEAN
			l_parser: XP_NATIVE_PARSER
			l_id: INTEGER
			l_status: INTEGER
		do
			if l_failed then
				record_failure (default_pointer)
				Result := default_pointer
			else
				create l_parser.make
				l_parser.set_diagnostic_events_enabled (diagnostic_events_enabled)
				if a_namespace_separator /= default_pointer then
					l_parser.set_namespace_mode (character_at (a_namespace_separator))
				end
				if a_encoding /= default_pointer then
					l_status := l_parser.set_initial_encoding (a_encoding)
				end
				l_id := eif_object_id (l_parser)
				live_parser_ids.force (l_parser, l_id)
				Result := integer_to_pointer (l_id)
			end
		ensure
			handle_returned: failure_count = old failure_count implies Result /= default_pointer
			one_more_parser: failure_count = old failure_count implies active_parser_count = old active_parser_count + 1
			parser_registered: failure_count = old failure_count implies attached parser_for (Result)
			null_on_failure: failure_count /= old failure_count implies Result = default_pointer
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_diagnostic_events_enabled (a_enabled: BOOLEAN)
			-- Control diagnostics for subsequently created parsers.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (default_pointer)
				diagnostic_events_enabled := a_enabled
			else
				diagnostic_events_enabled := a_enabled
			end
		ensure
			value_set: diagnostic_events_enabled = a_enabled
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	parser_reset (a_parser, a_encoding: POINTER): BOOLEAN
			-- Reset parser represented by `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.reset
					if Result and then a_encoding /= default_pointer then
						Result := l_parser.set_initial_encoding (a_encoding) = l_parser.Xml_status_ok
					end
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	parser_free (a_parser: POINTER)
			-- Release parser represented by `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				forget_parser (a_parser)
			else
				forget_parser (a_parser)
			end
		ensure
			parser_not_live: not attached parser_for (a_parser)
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_native_parser_handle (a_parser, a_native_parser: POINTER)
			-- Set the public C parser pointer used as native callback argument.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_native_parser_handle (a_native_parser)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_encoding (a_parser, a_encoding: POINTER): INTEGER
			-- Set explicit encoding for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_encoding (a_encoding)
				else
					Result := Xml_status_error
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_external_entity_context (a_parser, a_context: POINTER): BOOLEAN
			-- Mark parser represented by `a_parser' as an external parsed entity parser.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_external_entity_context (a_context)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_external_entity_parameter_context (a_parser: POINTER; a_is_parameter: BOOLEAN): BOOLEAN
			-- Mark whether parser represented by `a_parser' is parsing a DTD/parameter entity.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_external_entity_parameter_context (a_is_parameter)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_external_entity_parameter_literal_context (a_parser: POINTER; a_is_literal: BOOLEAN): BOOLEAN
			-- Mark whether parser represented by `a_parser' is parsing a parameter entity in a literal.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_external_entity_parameter_literal_context (a_is_literal)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	inherit_external_entity_context (a_parser, a_parent: POINTER): BOOLEAN
			-- Import parent DTD entity declarations into child parser `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser and then attached parser_for (a_parent) as l_parent then
					Result := l_parser.inherit_external_entity_context (l_parent)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	merge_external_entity_context (a_parser, a_child: POINTER): BOOLEAN
			-- Merge DTD entity declarations from child parser `a_child' into parent `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser and then attached parser_for (a_child) as l_child then
					Result := l_parser.merge_external_entity_context_from (l_child)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	merge_accounting (a_parser, a_child: POINTER): BOOLEAN
			-- Merge external entity child accounting into parent parser `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser and then attached parser_for (a_child) as l_child then
					Result := l_parser.merge_accounting_from (l_child)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_param_entity_parsing (a_parser: POINTER; a_parsing: INTEGER): BOOLEAN
			-- Set parameter entity parsing policy for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_param_entity_parsing (a_parsing)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_foreign_dtd (a_parser: POINTER; a_use_dtd: BOOLEAN): BOOLEAN
			-- Set foreign-DTD loading for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_foreign_dtd (a_use_dtd)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

feature -- Handler callbacks

	set_user_data (a_parser, a_user_data: POINTER)
			-- Set callback user data for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_user_data (a_user_data)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_element_handler (a_parser, a_start, a_end: POINTER)
			-- Set native element callback slots for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_element_handlers (a_start, a_end)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_character_data_handler (a_parser, a_handler: POINTER)
			-- Set native character-data callback slot for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_character_data_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_processing_instruction_handler (a_parser, a_handler: POINTER)
			-- Record processing-instruction handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_processing_instruction_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_xml_decl_handler (a_parser, a_handler: POINTER)
			-- Record XML declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_xml_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_comment_handler (a_parser, a_handler: POINTER)
			-- Record comment handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_comment_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_cdata_section_handler (a_parser, a_start, a_end: POINTER)
			-- Record CDATA section handler slots.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_cdata_section_handlers (a_start, a_end)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_default_handler (a_parser, a_handler: POINTER; a_expand: BOOLEAN)
			-- Record default handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_default_handler (a_handler, a_expand)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_doctype_decl_handler (a_parser, a_start, a_end: POINTER)
			-- Record doctype declaration handler slots.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_doctype_decl_handlers (a_start, a_end)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_not_standalone_handler (a_parser, a_handler: POINTER)
			-- Record not-standalone handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_not_standalone_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_element_decl_handler (a_parser, a_handler: POINTER)
			-- Record element declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_element_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_notation_decl_handler (a_parser, a_handler: POINTER)
			-- Record notation declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_notation_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_attlist_decl_handler (a_parser, a_handler: POINTER)
			-- Record attribute-list declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_attlist_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_entity_decl_handler (a_parser, a_handler: POINTER)
			-- Record entity declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_entity_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_unparsed_entity_decl_handler (a_parser, a_handler: POINTER)
			-- Record unparsed entity declaration handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_unparsed_entity_decl_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_external_entity_ref_handler (a_parser, a_handler: POINTER)
			-- Record external entity reference handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_external_entity_ref_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_external_entity_ref_handler_arg (a_parser, a_arg: POINTER)
			-- Record external entity reference handler argument.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_external_entity_ref_handler_arg (a_arg)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_skipped_entity_handler (a_parser, a_handler: POINTER)
			-- Record skipped entity handler slot.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.set_skipped_entity_handler (a_handler)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	default_current (a_parser: POINTER)
			-- Replay current callback text through the default handler.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parser.default_current
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_hash_salt (a_parser: POINTER; a_hash_salt: INTEGER_64): BOOLEAN
			-- Set legacy Expat hash salt for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_hash_salt (a_hash_salt)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	set_hash_salt_16_bytes (a_parser, a_entropy: POINTER): BOOLEAN
			-- Set 16-byte Expat hash entropy for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := False
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.set_hash_salt_16_bytes (a_entropy)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

feature -- Parse callbacks

	parse (a_parser, a_bytes: POINTER; a_length: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Parse bytes supplied by the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser and then valid_bytes (a_bytes, a_length) then
					Result := parsed_chunk (l_parser, a_bytes, a_length, a_is_final)
				else
					Result := Xml_status_error
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_buffer (a_parser: POINTER; a_length: INTEGER): POINTER
			-- Allocate or replace the parse buffer for `a_parser'.
		local
			l_failed: BOOLEAN
			l_id: INTEGER
			l_buffer: MANAGED_POINTER
		do
			if l_failed then
				record_failure (a_parser)
				Result := default_pointer
			else
				l_id := pointer_to_integer (a_parser)
				if attached parser_for (a_parser) and then a_length >= 0 then
					create l_buffer.make (a_length + 1)
					parse_buffers.force (l_buffer, l_id)
					Result := l_buffer.item
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	parse_buffer (a_parser: POINTER; a_length: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Parse the current buffer for `a_parser'.
		local
			l_failed: BOOLEAN
			l_id: INTEGER
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				l_id := pointer_to_integer (a_parser)
				if attached parser_for (a_parser) as l_parser and then attached parse_buffers.item (l_id) as l_buffer and then a_length >= 0 and then a_length <= l_buffer.count then
					Result := parsed_chunk (l_parser, l_buffer.item, a_length, a_is_final)
				else
					Result := Xml_status_error
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

feature -- Status callbacks

	get_error_code (a_parser: POINTER): INTEGER
			-- Last Expat-compatible error code for `a_parser'.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := Xml_error_unexpected_state
			else
				if failed_parser_codes.has (pointer_to_integer (a_parser)) then
					Result := failed_parser_codes.item (pointer_to_integer (a_parser))
				elseif attached parser_for (a_parser) as l_parser then
					Result := l_parser.last_error_code
				else
					Result := Xml_error_invalid_argument
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_current_line_number (a_parser: POINTER): INTEGER
			-- Current line number reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.current_line_number
				else
					Result := 1
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_current_column_number (a_parser: POINTER): INTEGER
			-- Current column number reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.current_column_number
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_current_byte_index (a_parser: POINTER): INTEGER
			-- Current byte index reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.current_byte_index
				else
					Result := -1
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_current_byte_count (a_parser: POINTER): INTEGER
			-- Current token byte count reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.current_byte_count
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_accounting_direct_count (a_parser: POINTER): INTEGER_64
			-- Direct byte accounting reported through upstream test hooks.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.accounting_direct_count
				end
			end
		ensure
			non_negative: Result >= 0
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_accounting_indirect_count (a_parser: POINTER): INTEGER_64
			-- Indirect byte accounting reported through upstream test hooks.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.accounting_indirect_count
				end
			end
		ensure
			non_negative: Result >= 0
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_specified_attribute_count (a_parser: POINTER): INTEGER
			-- Current explicit attribute vector count reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := 0
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.specified_attribute_count
				end
			end
		ensure
			non_negative: Result >= 0
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_id_attribute_index (a_parser: POINTER): INTEGER
			-- Current ID attribute vector index reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := -1
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.id_attribute_index
				else
					Result := -1
				end
			end
		ensure
			valid_index: Result >= -1
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_input_context (a_parser, a_offset, a_size: POINTER): POINTER
			-- Current input context buffer reported through the native ABI.
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
				Result := default_pointer
			else
				if attached parser_for (a_parser) as l_parser then
					Result := l_parser.input_context (a_offset, a_size)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

	get_parsing_status (a_parser, a_status: POINTER)
			-- Fill native `XML_ParsingStatus' for `a_parser'.
		local
			l_failed: BOOLEAN
			l_parsing: INTEGER
			l_final: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)
			else
				if attached parser_for (a_parser) as l_parser then
					l_parsing := l_parser.parsing_status
					l_final := l_parser.final_buffer
				else
					l_parsing := Xml_initialized
				end
				if a_status /= default_pointer then
					put_parsing_status (a_status, l_parsing, l_final)
				end
			end
		rescue
			if not l_failed then
				l_failed := True
				retry
			end
		end

feature {NONE} -- Failure handling (#273)

	trace_exceptions: BOOLEAN
			-- Print the Eiffel trace of a caught exception to stderr? (environment variable XPACT_EXCEPTION_TRACE)

	failed_parser_codes: HASH_TABLE [INTEGER, INTEGER]
			-- Error code of each parser whose call ended in an Eiffel exception, keyed by parser id.
			-- Such a parser may be half updated: it is never called again, only freed.

	record_failure (a_parser: POINTER)
			-- An Eiffel exception reached a native entry point and was caught there instead of ending the
			-- process (#273). Mark `a_parser' (if live) as failed with Expat's out-of-memory error, or with
			-- "unexpected parser state" for any other exception.
		local
			l_id, l_code: INTEGER
		do
			failure_count := failure_count + 1
			input_chunk_in_use := False
			l_code := Xml_error_unexpected_state
			if attached exception_manager.last_exception as l_exception then
				if attached {NO_MORE_MEMORY} l_exception then
					l_code := Xml_error_no_memory
				end
				if trace_exceptions then
					io.error.put_string ("xpact: Eiffel exception caught at the native API, call returns an error:%N")
					if attached l_exception.trace as l_trace then
						io.error.put_string (l_trace.to_string_8)
					end
					io.error.put_new_line
				end
			end
			l_id := pointer_to_integer (a_parser)
			if l_id > 0 and then live_parser_ids.has (l_id) then
				failed_parser_codes.force (l_code, l_id)
				parse_buffers.remove (l_id)
			end
		ensure
			counted: failure_count = old failure_count + 1
			reusable_input: not input_chunk_in_use
		end

	forget_parser (a_parser: POINTER)
			-- Drop every reference this installer holds for `a_parser'.
		local
			l_id: INTEGER
		do
			l_id := pointer_to_integer (a_parser)
			if l_id > 0 and then live_parser_ids.has (l_id) then
				parse_buffers.remove (l_id)
				failed_parser_codes.remove (l_id)
				eif_object_id_free (l_id)
				live_parser_ids.remove (l_id)
			end
		ensure
			parser_not_live: not attached parser_for (a_parser)
		end

feature {NONE} -- Byte conversion

	valid_bytes (a_bytes: POINTER; a_length: INTEGER): BOOLEAN
			-- Is the native byte range acceptable?
		do
			Result := a_length >= 0 and then (a_bytes /= default_pointer or else a_length = 0)
		end

	bytes_to_string (a_bytes: POINTER; a_length: INTEGER): STRING_8
			-- Copy `a_length' bytes from `a_bytes' into an Eiffel string.
		require
			valid_range: valid_bytes (a_bytes, a_length)
		do
			if a_length = 0 then
				create Result.make_empty
			else
					-- One copy, NUL bytes included; a C_STRING would copy twice (mass-xpact #43).
				create Result.make (a_length)
				Result.from_c_substring (a_bytes, 1, a_length)
			end
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = a_length
		end

feature {NONE} -- Native helpers

	integer_to_pointer (a_value: INTEGER): POINTER
			-- Opaque pointer encoding of Eiffel object id `a_value'.
		require
			positive_value: a_value > 0
		external
			"C inline use <stdint.h>"
		alias
			"return (EIF_POINTER) (uintptr_t) $a_value;"
		end

	pointer_to_integer (a_pointer: POINTER): INTEGER
			-- Eiffel object id encoded in opaque native `a_pointer'.
		external
			"C inline use <stdint.h>"
		alias
			"return (EIF_INTEGER) (uintptr_t) $a_pointer;"
		end

	character_at (a_pointer: POINTER): CHARACTER_8
			-- C `XML_Char' byte at `a_pointer'.
		require
			pointer_attached: a_pointer /= default_pointer
		external
			"C inline"
		alias
			"return (EIF_CHARACTER_8) *((char *) $a_pointer);"
		end

	put_parsing_status (a_status: POINTER; a_parsing: INTEGER; a_final: BOOLEAN)
			-- Write native `XML_ParsingStatus' layout without taking ownership.
		require
			status_attached: a_status /= default_pointer
		external
			"C inline"
		alias
			"((int *) $a_status)[0] = (int) $a_parsing; *(((unsigned char *) $a_status) + sizeof(int)) = $a_final ? 1 : 0;"
		end

feature {NONE} -- Storage

	live_parser_ids: HASH_TABLE [XP_NATIVE_PARSER, INTEGER]
			-- Strong parser ownership until `parser_free'. Object IDs alone are
			-- weak references in the Eiffel runtime and do not prevent collection.

	parse_buffers: HASH_TABLE [MANAGED_POINTER, INTEGER]
			-- Parse buffers keyed by parser object id.

	input_chunk: STRING_8
			-- String reused for the bytes of one `parse' call, so that small chunks need no new string.

	input_chunk_in_use: BOOLEAN
			-- Is a `parse' call reading `input_chunk' right now (a callback may start another parse)?

	Input_chunk_reuse_limit: INTEGER = 65536
			-- Larger chunks get a string of their own, so that `input_chunk' stays small.

feature {NONE} -- Parsing

	parsed_chunk (a_parser: XP_NATIVE_PARSER; a_bytes: POINTER; a_length: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- `a_parser.parse' of the `a_length' bytes at `a_bytes'. A small chunk is copied into the reused
			-- `input_chunk' instead of a new string, unless a parse is already reading it (mass-xpact #46).
			-- The parser reads its argument only during the call; it keeps copies, not the argument.
		require
			parser_attached: a_parser /= Void
			valid_range: valid_bytes (a_bytes, a_length)
		local
			l_chunk: STRING_8
		do
			if input_chunk_in_use or else a_length = 0 or else a_length > Input_chunk_reuse_limit then
				Result := a_parser.parse (bytes_to_string (a_bytes, a_length), a_is_final)
			else
				l_chunk := input_chunk
				l_chunk.from_c_substring (a_bytes, 1, a_length)
				input_chunk_in_use := True
				Result := a_parser.parse (l_chunk, a_is_final)
				input_chunk_in_use := False
			end
		end

invariant
	live_parser_ids_attached: live_parser_ids /= Void
	parse_buffers_attached: parse_buffers /= Void
	failed_parser_codes_attached: failed_parser_codes /= Void
	non_negative_active_parser_count: active_parser_count >= 0

end
