note
	description: "Eiffel runtime owner for parser handles used by the native bridge."

class
	XP_NATIVE_BRIDGE_INSTALLER

inherit
	IDENTIFIED_ROUTINES

create
	make

feature {NONE} -- Initialization

	make
		do
			create live_parser_ids.make (16)
			create parse_buffers.make (16)
		ensure
			no_live_parsers: active_parser_count = 0
		end

feature -- Expat-compatible constants

	Xml_status_error: INTEGER = 0

	Xml_initialized: INTEGER = 0

	Xml_finished: INTEGER = 2

	Xml_error_invalid_argument: INTEGER = 41

feature -- Access

	active_parser_count: INTEGER
			-- Number of parser handles currently owned by this installer.
		do
			Result := live_parser_ids.count
		ensure
			non_negative: Result >= 0
		end

	parser_for (a_handle: POINTER): detachable XP_NATIVE_PARSER
			-- Parser object represented by native opaque `a_handle', if live.
		local
			l_id: INTEGER
		do
			l_id := pointer_to_integer (a_handle)
			if l_id > 0 and then live_parser_ids.has (l_id) then
				if attached {XP_NATIVE_PARSER} eif_id_object (l_id) as l_parser then
					Result := l_parser
				end
			end
		end

feature -- Parser lifecycle callbacks

	parser_create (a_encoding, a_memsuite, a_namespace_separator: POINTER): POINTER
			-- Create an Eiffel parser and return an opaque native handle.
		local
			l_parser: XP_NATIVE_PARSER
			l_id: INTEGER
		do
			create l_parser.make
			l_id := eif_object_id (l_parser)
			live_parser_ids.force (True, l_id)
			Result := integer_to_pointer (l_id)
			l_parser.set_native_parser_handle (Result)
		ensure
			handle_returned: Result /= default_pointer
			one_more_parser: active_parser_count = old active_parser_count + 1
			parser_registered: attached parser_for (Result)
		end

	parser_reset (a_parser, a_encoding: POINTER): BOOLEAN
			-- Reset parser represented by `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.reset
			end
		end

	parser_free (a_parser: POINTER)
			-- Release parser represented by `a_parser'.
		local
			l_id: INTEGER
		do
			l_id := pointer_to_integer (a_parser)
			if l_id > 0 and then live_parser_ids.has (l_id) then
				parse_buffers.remove (l_id)
				live_parser_ids.remove (l_id)
				eif_object_id_free (l_id)
			end
		ensure
			parser_not_live: not attached parser_for (a_parser)
		end

feature -- Handler callbacks

	set_user_data (a_parser, a_user_data: POINTER)
			-- Set callback user data for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_user_data (a_user_data)
			end
		end

	set_element_handler (a_parser, a_start, a_end: POINTER)
			-- Set native element callback slots for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_element_handlers (a_start, a_end)
			end
		end

	set_character_data_handler (a_parser, a_handler: POINTER)
			-- Set native character-data callback slot for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_character_data_handler (a_handler)
			end
		end

	set_processing_instruction_handler (a_parser, a_handler: POINTER)
			-- Record processing-instruction handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_processing_instruction_handler (a_handler)
			end
		end

	set_comment_handler (a_parser, a_handler: POINTER)
			-- Record comment handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_comment_handler (a_handler)
			end
		end

	set_cdata_section_handler (a_parser, a_start, a_end: POINTER)
			-- Record CDATA section handler slots.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_cdata_section_handlers (a_start, a_end)
			end
		end

	set_default_handler (a_parser, a_handler: POINTER; a_expand: BOOLEAN)
			-- Record default handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_default_handler (a_handler, a_expand)
			end
		end

	set_doctype_decl_handler (a_parser, a_start, a_end: POINTER)
			-- Record doctype declaration handler slots.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_doctype_decl_handlers (a_start, a_end)
			end
		end

	set_element_decl_handler (a_parser, a_handler: POINTER)
			-- Record element declaration handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_element_decl_handler (a_handler)
			end
		end

	set_notation_decl_handler (a_parser, a_handler: POINTER)
			-- Record notation declaration handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_notation_decl_handler (a_handler)
			end
		end

	set_attlist_decl_handler (a_parser, a_handler: POINTER)
			-- Record attribute-list declaration handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_attlist_decl_handler (a_handler)
			end
		end

	set_entity_decl_handler (a_parser, a_handler: POINTER)
			-- Record entity declaration handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_entity_decl_handler (a_handler)
			end
		end

	set_unparsed_entity_decl_handler (a_parser, a_handler: POINTER)
			-- Record unparsed entity declaration handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_unparsed_entity_decl_handler (a_handler)
			end
		end

	set_external_entity_ref_handler (a_parser, a_handler: POINTER)
			-- Record external entity reference handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_external_entity_ref_handler (a_handler)
			end
		end

	set_external_entity_ref_handler_arg (a_parser, a_arg: POINTER)
			-- Record external entity reference handler argument.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_external_entity_ref_handler_arg (a_arg)
			end
		end

	set_skipped_entity_handler (a_parser, a_handler: POINTER)
			-- Record skipped entity handler slot.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.set_skipped_entity_handler (a_handler)
			end
		end

	default_current (a_parser: POINTER)
			-- Replay current callback text through the default handler.
		do
			if attached parser_for (a_parser) as l_parser then
				l_parser.default_current
			end
		end

	set_hash_salt (a_parser: POINTER; a_hash_salt: INTEGER_64): BOOLEAN
			-- Set legacy Expat hash salt for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.set_hash_salt (a_hash_salt)
			end
		end

	set_hash_salt_16_bytes (a_parser, a_entropy: POINTER): BOOLEAN
			-- Set 16-byte Expat hash entropy for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.set_hash_salt_16_bytes (a_entropy)
			end
		end

feature -- Parse callbacks

	parse (a_parser, a_bytes: POINTER; a_length: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Parse bytes supplied by the native ABI.
		local
			l_input: STRING_8
		do
			if attached parser_for (a_parser) as l_parser and then valid_bytes (a_bytes, a_length) then
				l_input := bytes_to_string (a_bytes, a_length)
				Result := l_parser.parse (l_input, a_is_final)
			else
				Result := Xml_status_error
			end
		end

	get_buffer (a_parser: POINTER; a_length: INTEGER): POINTER
			-- Allocate or replace the parse buffer for `a_parser'.
		local
			l_id: INTEGER
			l_buffer: MANAGED_POINTER
		do
			l_id := pointer_to_integer (a_parser)
			if attached parser_for (a_parser) and then a_length >= 0 then
				create l_buffer.make (a_length + 1)
				parse_buffers.force (l_buffer, l_id)
				Result := l_buffer.item
			end
		end

	parse_buffer (a_parser: POINTER; a_length: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Parse the current buffer for `a_parser'.
		local
			l_id: INTEGER
		do
			l_id := pointer_to_integer (a_parser)
			if attached parser_for (a_parser) as l_parser and then attached parse_buffers.item (l_id) as l_buffer and then a_length >= 0 and then a_length <= l_buffer.count then
				Result := l_parser.parse (bytes_to_string (l_buffer.item, a_length), a_is_final)
			else
				Result := Xml_status_error
			end
		end

feature -- Status callbacks

	get_error_code (a_parser: POINTER): INTEGER
			-- Last Expat-compatible error code for `a_parser'.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.last_error_code
			else
				Result := Xml_error_invalid_argument
			end
		end

	get_current_line_number (a_parser: POINTER): INTEGER
			-- Current line number reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.current_line_number
			else
				Result := 1
			end
		end

	get_current_column_number (a_parser: POINTER): INTEGER
			-- Current column number reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.current_column_number
			end
		end

	get_current_byte_index (a_parser: POINTER): INTEGER
			-- Current byte index reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.current_byte_index
			else
				Result := -1
			end
		end

	get_current_byte_count (a_parser: POINTER): INTEGER
			-- Current token byte count reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.current_byte_count
			end
		end

	get_specified_attribute_count (a_parser: POINTER): INTEGER
			-- Current explicit attribute vector count reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.specified_attribute_count
			end
		ensure
			non_negative: Result >= 0
		end

	get_id_attribute_index (a_parser: POINTER): INTEGER
			-- Current ID attribute vector index reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.id_attribute_index
			else
				Result := -1
			end
		ensure
			valid_index: Result >= -1
		end

	get_input_context (a_parser, a_offset, a_size: POINTER): POINTER
			-- Current input context buffer reported through the native ABI.
		do
			if attached parser_for (a_parser) as l_parser then
				Result := l_parser.input_context (a_offset, a_size)
			end
		end

	get_parsing_status (a_parser, a_status: POINTER)
			-- Fill native `XML_ParsingStatus' for `a_parser'.
		local
			l_parsing: INTEGER
			l_final: BOOLEAN
		do
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
		local
			l_bytes: C_STRING
		do
			if a_length = 0 then
				create Result.make_empty
			else
				create l_bytes.make_by_pointer_and_count (a_bytes, a_length)
				Result := l_bytes.substring_8 (1, a_length)
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

	live_parser_ids: HASH_TABLE [BOOLEAN, INTEGER]
			-- Object ids that are still owned by the bridge.

	parse_buffers: HASH_TABLE [MANAGED_POINTER, INTEGER]
			-- Parse buffers keyed by parser object id.

invariant
	live_parser_ids_attached: live_parser_ids /= Void
	parse_buffers_attached: parse_buffers /= Void
	non_negative_active_parser_count: active_parser_count >= 0

end
