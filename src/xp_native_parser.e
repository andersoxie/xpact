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

	Xml_status_suspended: INTEGER = 2

	Xml_initialized: INTEGER = 0

	Xml_parsing: INTEGER = 1

	Xml_finished: INTEGER = 2

	Xml_suspended: INTEGER = 3

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

	Xml_error_unbound_prefix: INTEGER = 27

	Xml_error_undeclaring_prefix: INTEGER = 28

	Xml_error_xml_decl: INTEGER = 30

	Xml_error_publicid: INTEGER = 32

	Xml_error_suspended: INTEGER = 33

	Xml_error_not_suspended: INTEGER = 34

	Xml_error_aborted: INTEGER = 35

	Xml_error_finished: INTEGER = 36

	Xml_error_suspend_pe: INTEGER = 37

	Xml_error_reserved_prefix_xml: INTEGER = 38

	Xml_error_reserved_prefix_xmlns: INTEGER = 39

	Xml_error_reserved_namespace_uri: INTEGER = 40

	Xml_error_invalid_argument: INTEGER = 41

	Xml_error_amplification_limit_breach: INTEGER = 43

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

	external_entity_is_parameter_literal: BOOLEAN
			-- Is this external parameter entity used inside an entity literal?

	param_entity_parsing: INTEGER
			-- Expat-compatible parameter entity parsing mode.

	use_foreign_dtd: BOOLEAN
			-- Should a foreign DTD be loaded when no external subset is declared?

	explicit_encoding: detachable STRING_8
			-- Native `XML_SetEncoding' value, if any.

	has_unsupported_explicit_encoding: BOOLEAN
			-- Should the next parse fail because `explicit_encoding' is unsupported?

	explicit_encoding_overrides_declaration: BOOLEAN
			-- Did `explicit_encoding' come from `XML_SetEncoding' rather than parser creation/reset?

	hash_salt: INTEGER_64
			-- Last legacy Expat hash salt accepted before parsing started.

	has_hash_salt: BOOLEAN
			-- Has `hash_salt' been explicitly configured?

	hash_salt_16_bytes: STRING_8
			-- Last 16-byte Expat hash entropy accepted before parsing started.

	has_hash_salt_16_bytes: BOOLEAN
			-- Has `hash_salt_16_bytes' been explicitly configured?

	namespace_mode: BOOLEAN
			-- Was this parser created with namespace expansion enabled?

	namespace_separator: CHARACTER_8
			-- Namespace separator configured by `XML_ParserCreateNS'.

	input_buffer: STRING_8
			-- Native chunks accumulated until the final parse call.

	delivered_callback_count: INTEGER
			-- Number of native callbacks already delivered from `input_buffer'.

	deferred_reparse_start_index: INTEGER
			-- Start index of the token currently delayed by reparse deferral.

	deferred_reparse_end_index: INTEGER
			-- End index of the delayed token once it has become complete.

	deferred_reparse_scan_index: INTEGER
			-- Next byte index to inspect while looking for the end of a delayed start tag.

	deferred_reparse_scan_in_quote: BOOLEAN
			-- Is the incremental delayed start-tag scan currently inside an attribute value?

	deferred_reparse_scan_quote: CHARACTER_8
			-- Quote that ends the current delayed start-tag attribute value.

	ready_plain_start_tag_start_index: INTEGER
			-- Start index of a completed plain start tag that can be emitted directly.

	ready_plain_start_tag_end_index: INTEGER
			-- End index of a completed plain start tag that can be emitted directly.

	accounting_direct_count: INTEGER_64
			-- Direct input bytes supplied to this parser.

	accounting_indirect_count: INTEGER_64
			-- Indirect entity replacement bytes accounted by this parser.

	accounting_external_child_count: INTEGER_64
			-- Direct and indirect bytes accounted by external entity child parsers.

	native_parser_handle: POINTER
			-- Public native parser handle used for native-only API callback state.

	context_buffer: detachable C_STRING
			-- C-visible copy of the current final input while parsing.

	suspend_gc_during_parse: BOOLEAN
			-- Should `parse' temporarily suspend Eiffel garbage collection?

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

	set_namespace_mode (a_separator: CHARACTER_8)
			-- Enable namespace processing for this native parser.
		do
			namespace_mode := True
			namespace_separator := a_separator
			parser.set_namespace_mode (a_separator)
		ensure
			namespace_enabled: namespace_mode
			separator_set: namespace_separator = a_separator
		end

	default_current
			-- Replay current callback text through the default handler.
		do
			handler.default_current
		end

	set_native_parser_handle (a_parser: POINTER)
			-- Set native parser handle used by native callbacks.
		do
			native_parser_handle := a_parser
			handler.set_native_parser_handle (a_parser)
		ensure
			native_handle_set: native_parser_handle = a_parser
			handle_set: handler.native_parser_handle = a_parser
		end

	set_encoding (a_encoding: POINTER): INTEGER
			-- Set explicit native input encoding.
		do
			Result := set_encoding_with_precedence (a_encoding, True)
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error
			rejected_only_while_parsing: Result = Xml_status_error implies parsing_status = Xml_parsing
		end

	set_initial_encoding (a_encoding: POINTER): INTEGER
			-- Set parser-creation protocol encoding.
		do
			Result := set_encoding_with_precedence (a_encoding, False)
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error
			rejected_only_while_parsing: Result = Xml_status_error implies parsing_status = Xml_parsing
		end

	set_encoding_with_precedence (a_encoding: POINTER; a_overrides_declaration: BOOLEAN): INTEGER
			-- Set native input encoding and whether it overrides XML declarations.
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
					explicit_encoding_overrides_declaration := False
				else
					create l_encoding.make_by_pointer (a_encoding)
					l_name := l_encoding.string
					explicit_encoding := l_name.twin
					has_unsupported_explicit_encoding := not is_supported_explicit_encoding (l_name)
					explicit_encoding_overrides_declaration := a_overrides_declaration
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

	set_external_entity_parameter_literal_context (a_is_literal: BOOLEAN): BOOLEAN
			-- Mark whether this external parameter parser is used in an entity literal.
		do
			if parsing_status = Xml_initialized then
				external_entity_is_parameter_literal := a_is_literal
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
			accepted_sets_value: Result implies external_entity_is_parameter_literal = a_is_literal
		end

	inherit_external_entity_context (a_parent: XP_NATIVE_PARSER): BOOLEAN
			-- Import parent DTD entity declarations for an external entity child parser.
		require
			parent_attached: a_parent /= Void
		do
			if parsing_status = Xml_initialized then
				parser.import_entity_context (a_parent.parser)
				Result := True
			end
		ensure
			accepted_only_before_parse: Result implies parsing_status = Xml_initialized
		end

	merge_external_entity_context_from (a_child: XP_NATIVE_PARSER): BOOLEAN
			-- Merge DTD entity declarations parsed by external entity child `a_child'.
		require
			child_attached: a_child /= Void
		do
			parser.merge_entity_context_from (a_child.parser)
			Result := True
		ensure
			merged: Result
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

	set_suspend_gc_during_parse (a_enabled: BOOLEAN)
			-- Control temporary garbage-collection suspension around `parse'.
		do
			suspend_gc_during_parse := a_enabled
		ensure
			value_set: suspend_gc_during_parse = a_enabled
		end

	set_diagnostic_events_enabled (a_enabled: BOOLEAN)
			-- Control internal diagnostic event recording.
		do
			handler.set_diagnostic_events_enabled (a_enabled)
		ensure
			value_set: handler.diagnostic_events_enabled = a_enabled
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
			delivered_callback_count := 0
			deferred_reparse_start_index := 0
			deferred_reparse_end_index := 0
			deferred_reparse_scan_index := 0
			deferred_reparse_scan_in_quote := False
			deferred_reparse_scan_quote := '%U'
			ready_plain_start_tag_start_index := 0
			ready_plain_start_tag_end_index := 0
			accounting_direct_count := 0
			accounting_indirect_count := 0
			accounting_external_child_count := 0
			context_buffer := Void
			handler.reset_events
			handler.finish_successful_parse_callbacks
			last_error_code := Xml_error_none
			parsing_status := Xml_initialized
			final_buffer := False
			is_external_entity_parser := False
			external_entity_context := Void
			external_entity_is_parameter := False
			external_entity_is_parameter_literal := False
			param_entity_parsing := Xml_param_entity_parsing_never
			use_foreign_dtd := False
			parser.reset_for_reuse
			if namespace_mode then
				parser.set_namespace_mode (namespace_separator)
			end
			parser.set_external_entity_resolver (handler)
			configure_external_entity_policy
			explicit_encoding := Void
			has_unsupported_explicit_encoding := False
			explicit_encoding_overrides_declaration := False
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
			not_external_parameter_literal_parser: not external_entity_is_parameter_literal
			param_entity_parsing_reset: param_entity_parsing = Xml_param_entity_parsing_never
			foreign_dtd_reset: not use_foreign_dtd
			no_explicit_encoding: explicit_encoding = Void and not has_unsupported_explicit_encoding
			no_hash_salt: not has_hash_salt and not has_hash_salt_16_bytes
			no_delivered_callbacks: delivered_callback_count = 0
			no_deferred_reparse: deferred_reparse_start_index = 0 and deferred_reparse_end_index = 0 and deferred_reparse_scan_index = 0
			no_ready_plain_start_tag: ready_plain_start_tag_start_index = 0 and ready_plain_start_tag_end_index = 0
			no_accounting: accounting_direct_count = 0 and accounting_indirect_count = 0 and accounting_external_child_count = 0
		end

	merge_accounting_from (a_child: XP_NATIVE_PARSER): BOOLEAN
			-- Add completed external entity child accounting into Current.
		require
			child_attached: a_child /= Void
		do
			accounting_external_child_count := accounting_external_child_count + a_child.accounting_direct_count + a_child.accounting_indirect_count
			accounting_indirect_count := accounting_external_child_count + parser.accounting_indirect_byte_count
			Result := True
		ensure
			merged: Result
		end

feature -- Parsing

	parse (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): INTEGER
			-- Parse `a_input' through the Eiffel parser.
		require
			input_attached: a_input /= Void
		local
			l_result: CELL [INTEGER]
			l_section: XP_GC_CRITICAL_SECTION
		do
			if suspend_gc_during_parse then
				create l_result.put (Xml_status_error)
				create l_section.make
				l_section.execute (agent parse_status_into_cell (a_input, a_is_final, l_result))
				Result := l_result.item
			else
				Result := parse_with_current_gc_policy (a_input, a_is_final)
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error or Result = Xml_status_suspended
			success_has_no_error: Result = Xml_status_ok implies last_error_code = Xml_error_none
			final_finished_or_suspended: a_is_final implies (parsing_status = Xml_finished or parsing_status = Xml_suspended)
			success_non_final_parsing: Result = Xml_status_ok and not a_is_final implies parsing_status = Xml_parsing
			final_recorded: final_buffer = a_is_final
		end

feature {NONE} -- Parsing implementation

	parse_with_current_gc_policy (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): INTEGER
			-- Parse `a_input' without changing garbage-collection policy.
		require
			input_attached: a_input /= Void
		local
			l_ok: BOOLEAN
			l_input: detachable STRING_8
			l_parse_input: STRING_8
			l_context_input: STRING_8
			l_defer_callbacks: BOOLEAN
			l_direct_callback_count: INTEGER
			l_ready_end: INTEGER
		do
			final_buffer := a_is_final
			accounting_direct_count := accounting_direct_count + a_input.count
			if has_unsupported_explicit_encoding and then explicit_encoding_overrides_declaration and then not native_unknown_encoding_handler_available then
				last_error_code := Xml_error_unknown_encoding
				parsing_status := Xml_finished
				Result := Xml_status_error
			else
				input_buffer.append (a_input)
				if native_amplification_limit_breached (native_parser_handle, input_buffer.count, amplification_estimate) then
					last_error_code := Xml_error_amplification_limit_breach
					parsing_status := Xml_finished
					input_buffer.wipe_out
					delivered_callback_count := 0
					Result := Xml_status_error
				elseif not a_is_final and then has_partial_encoding_signature_prefix (input_buffer) then
					last_error_code := Xml_error_none
					parsing_status := Xml_parsing
					Result := Xml_status_ok
				else
					parsing_status := Xml_parsing
					handler.reset_events
					if namespace_mode then
						parser.set_return_ns_triplet (native_return_ns_triplet (native_parser_handle))
					end
					l_input := decoded_input (input_buffer)
					if l_input = Void then
						Result := Xml_status_error
					else
						l_defer_callbacks := should_defer_reparse_callbacks (l_input, a_is_final)
						if l_defer_callbacks and then deferred_reparse_start_index > 1 then
							l_parse_input := l_input.substring (1, deferred_reparse_start_index - 1)
							l_context_input := input_buffer.substring (1, deferred_reparse_start_index - 1)
						elseif l_defer_callbacks then
							create l_parse_input.make_empty
							create l_context_input.make_empty
						else
							l_parse_input := l_input
							l_context_input := input_buffer
						end
						handler.prepare_callback_replay (delivered_callback_count)
						if
							not l_defer_callbacks
							and then ready_plain_start_tag_start_index = 0
							and then delivered_callback_count = 0
							and then l_input.count > 0
							and then l_input.item (1) = '<'
						then
							l_ready_end := parser.markup_prefix_end (l_input, 1)
							if l_ready_end > 0 and then is_directly_emittable_completed_start_tag (l_input, 1, l_ready_end) then
								ready_plain_start_tag_start_index := 1
								ready_plain_start_tag_end_index := l_ready_end
							end
						end
						if can_emit_ready_plain_start_tag_directly then
							create context_buffer.make ("")
							l_ok := emit_ready_plain_start_tag_directly (l_input)
							if l_ok then
								l_direct_callback_count := 1
							end
						else
							create context_buffer.make (l_context_input)
						end
						if l_direct_callback_count = 0 then
							if is_external_entity_parser and then external_entity_is_parameter then
								if a_is_final then
									if external_entity_is_parameter_literal then
										l_ok := parser.parse_external_parameter_literal_with_context (l_parse_input, external_entity_context)
									else
										l_ok := parser.parse_external_subset_with_context (l_parse_input, external_entity_context)
									end
								else
									if external_entity_is_parameter_literal then
										l_ok := True
									elseif l_input.has_substring ("<![") or else l_input.has_substring ("%%") then
										l_ok := True
									else
										l_ok := parser.parse_external_subset_prefix (l_parse_input)
									end
								end
							elseif is_external_entity_parser then
								if a_is_final then
									l_ok := parser.parse_external_entity (l_parse_input)
								else
									l_ok := True
								end
							else
								if a_is_final then
									l_ok := parser.parse (l_parse_input)
								else
									l_ok := parser.parse_prefix (l_parse_input)
								end
							end
						end
						if l_ok then
							if a_is_final then
								Result := raw_cr_epilog_stop_status (l_parse_input)
							else
								Result := Xml_status_ok
							end
							if Result = Xml_status_ok then
								last_error_code := Xml_error_none
							end
						elseif parser.is_suspended then
							last_error_code := Xml_error_none
							Result := Xml_status_suspended
						else
							last_error_code := error_code_for (parser.last_error)
							Result := Xml_status_error
						end
					end
					if Result = Xml_status_suspended then
						parsing_status := Xml_suspended
						delivered_callback_count := handler.last_suspending_callback_index
					elseif Result = Xml_status_ok and not a_is_final then
						parsing_status := Xml_parsing
						if l_direct_callback_count > 0 then
							delivered_callback_count := delivered_callback_count + l_direct_callback_count
						else
							delivered_callback_count := handler.callback_sequence_count
						end
						accounting_indirect_count := accounting_external_child_count + parser.accounting_indirect_byte_count
					else
						if Result = Xml_status_ok then
							accounting_indirect_count := accounting_external_child_count + parser.accounting_indirect_byte_count
						end
						handler.finish_successful_parse_callbacks
						parsing_status := Xml_finished
						input_buffer.wipe_out
						delivered_callback_count := 0
						deferred_reparse_start_index := 0
						deferred_reparse_end_index := 0
					end
				end
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error or Result = Xml_status_suspended
			success_has_no_error: Result = Xml_status_ok implies last_error_code = Xml_error_none
			final_finished_or_suspended: a_is_final implies (parsing_status = Xml_finished or parsing_status = Xml_suspended)
			success_non_final_parsing: Result = Xml_status_ok and not a_is_final implies parsing_status = Xml_parsing
			final_recorded: final_buffer = a_is_final
		end

	parse_status_into_cell (a_input: READABLE_STRING_8; a_is_final: BOOLEAN; a_result: CELL [INTEGER])
			-- Store `parse_with_current_gc_policy (a_input, a_is_final)' in `a_result'.
		require
			input_attached: a_input /= Void
			result_attached: a_result /= Void
		do
			a_result.put (parse_with_current_gc_policy (a_input, a_is_final))
		ensure
			valid_status: a_result.item = Xml_status_ok or a_result.item = Xml_status_error or a_result.item = Xml_status_suspended
		end

feature -- Parsing

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

	has_partial_encoding_signature_prefix (a_input: READABLE_STRING_8): BOOLEAN
			-- Does `a_input' end inside an initial encoding signature that needs more bytes?
		require
			input_attached: a_input /= Void
		do
			Result :=
				(a_input.count = 1 and then (a_input.item (1).code = 239 or else a_input.item (1).code = 254 or else a_input.item (1).code = 255))
				or else (a_input.count = 2 and then a_input.item (1).code = 239 and then a_input.item (2).code = 187)
		end

	should_defer_reparse_callbacks (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): BOOLEAN
			-- Should callbacks newly discovered by reparsing `a_input' remain hidden for now?
		require
			input_attached: a_input /= Void
		local
			l_start: INTEGER
			l_end: INTEGER
			l_token_length: INTEGER
			l_bytes_after_token: INTEGER
		do
			ready_plain_start_tag_start_index := 0
			ready_plain_start_tag_end_index := 0
			if a_is_final or else not native_reparse_deferral_enabled (native_parser_handle) then
				clear_deferred_reparse
			else
				if deferred_reparse_start_index = 0 then
					if delivered_callback_count = 0 and then a_input.count > 0 and then is_deferred_start_tag_prefix (a_input, 1) then
						deferred_reparse_start_index := 1
					else
						l_start := parser.incomplete_markup_prefix_start (a_input)
						if l_start > 0 then
							deferred_reparse_start_index := l_start
						end
					end
					if deferred_reparse_start_index > 0 then
						deferred_reparse_end_index := 0
						deferred_reparse_scan_index := 0
						deferred_reparse_scan_in_quote := False
						deferred_reparse_scan_quote := '%U'
					end
				end
				if deferred_reparse_start_index > 0 then
					if deferred_reparse_end_index > 0 then
						l_end := deferred_reparse_end_index
					elseif is_deferred_start_tag_prefix (a_input, deferred_reparse_start_index) then
						l_end := incremental_deferred_start_tag_end (a_input)
					else
						l_end := parser.markup_prefix_end (a_input, deferred_reparse_start_index)
					end
					if l_end = 0 then
						Result := True
					else
						if deferred_reparse_end_index = 0 then
							deferred_reparse_end_index := l_end
						end
						if is_directly_emittable_completed_start_tag (a_input, deferred_reparse_start_index, deferred_reparse_end_index) then
							ready_plain_start_tag_start_index := deferred_reparse_start_index
							ready_plain_start_tag_end_index := deferred_reparse_end_index
							clear_deferred_reparse
						else
							l_token_length := deferred_reparse_end_index - deferred_reparse_start_index + 1
							l_bytes_after_token := a_input.count - deferred_reparse_end_index
							if l_bytes_after_token < l_token_length then
								Result := True
							else
								clear_deferred_reparse
							end
						end
					end
				end
			end
		end

	clear_deferred_reparse
			-- Forget any delayed token and incremental scan state.
		do
			deferred_reparse_start_index := 0
			deferred_reparse_end_index := 0
			deferred_reparse_scan_index := 0
			deferred_reparse_scan_in_quote := False
			deferred_reparse_scan_quote := '%U'
		ensure
			cleared: deferred_reparse_start_index = 0 and deferred_reparse_end_index = 0 and deferred_reparse_scan_index = 0
		end

	can_emit_ready_plain_start_tag_directly: BOOLEAN
			-- Can the completed plain start tag be emitted without a full parser replay?
		do
			Result :=
				ready_plain_start_tag_start_index > 0
				and then ready_plain_start_tag_end_index >= ready_plain_start_tag_start_index
				and then not namespace_mode
				and then not is_external_entity_parser
				and then native_has_start_element_handler (native_parser_handle)
				and then not native_has_character_or_default_handler (native_parser_handle)
		end

	emit_ready_plain_start_tag_directly (a_input: READABLE_STRING_8): BOOLEAN
			-- Emit the ready start tag through the native handler.
		require
			input_attached: a_input /= Void
			ready: can_emit_ready_plain_start_tag_directly
		local
			l_name: detachable STRING_8
			l_attributes: detachable XP_ATTRIBUTES
		do
			l_name := direct_start_tag_name (a_input, ready_plain_start_tag_start_index, ready_plain_start_tag_end_index)
			l_attributes := direct_start_tag_attributes (a_input, ready_plain_start_tag_start_index, ready_plain_start_tag_end_index)
			if attached l_name as l_attached_name and then attached l_attributes as l_attached_attributes then
				handler.prepare_callback_replay (0)
				handler.on_start_element (l_attached_name, l_attached_attributes)
				Result := not handler.stop_requested
			end
			ready_plain_start_tag_start_index := 0
			ready_plain_start_tag_end_index := 0
		ensure
			ready_consumed: ready_plain_start_tag_start_index = 0 and ready_plain_start_tag_end_index = 0
		end

	is_directly_emittable_completed_start_tag (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): BOOLEAN
			-- Can completed start tag be emitted without reparsing the whole input?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			valid_end: a_end_index >= a_start_index and a_end_index <= a_input.count
		do
			Result := attached direct_start_tag_name (a_input, a_start_index, a_end_index)
				and then attached direct_start_tag_attributes (a_input, a_start_index, a_end_index)
		end

	direct_start_tag_name (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): detachable STRING_8
			-- Name of a directly emittable start tag, if the token shape is supported.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			valid_end: a_end_index >= a_start_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			if
				a_input.item (a_start_index) = '<'
				and then a_start_index + 1 < a_end_index
				and then a_input.item (a_end_index) = '>'
				and then a_input.item (a_start_index + 1) /= '/'
				and then a_input.item (a_start_index + 1) /= '!'
				and then a_input.item (a_start_index + 1) /= '?'
			then
				create l_attributes.make
				i := a_start_index + 1
				if l_attributes.is_name_start_character (a_input.item (i)) then
					l_name_start := i
					from
						i := i + 1
					until
						i >= a_end_index or else not l_attributes.is_name_character (a_input.item (i))
					loop
						i := i + 1
					variant
						a_end_index - i
					end
					create Result.make_from_string (a_input.substring (l_name_start, i - 1))
				end
			end
		end

	direct_start_tag_attributes (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): detachable XP_ATTRIBUTES
			-- Attributes for a directly emittable start tag, if all values are literal.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			valid_end: a_end_index >= a_start_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_value_start: INTEGER
			l_quote: CHARACTER_8
			l_name: STRING_8
			l_value: STRING_8
			l_attributes: XP_ATTRIBUTES
			l_valid: BOOLEAN
			l_done: BOOLEAN
		do
			if attached direct_start_tag_name (a_input, a_start_index, a_end_index) then
				create l_attributes.make
				l_valid := True
				i := a_start_index + 2
				from
				until
					i >= a_end_index or else not l_attributes.is_name_character (a_input.item (i))
				loop
					i := i + 1
				variant
					a_end_index - i
				end
				from
				until
					i >= a_end_index or else not l_valid or else l_done
				loop
					i := skip_reparse_tag_spaces (a_input, i, a_end_index)
					if i >= a_end_index then
						l_done := True
					elseif a_input.item (i) = '/' then
						l_valid := False
					elseif not l_attributes.is_name_start_character (a_input.item (i)) then
						l_valid := False
					else
						l_name_start := i
						from
							i := i + 1
						until
							i >= a_end_index or else not l_attributes.is_name_character (a_input.item (i))
						loop
							i := i + 1
						variant
							a_end_index - i
						end
						create l_name.make_from_string (a_input.substring (l_name_start, i - 1))
						i := skip_reparse_tag_spaces (a_input, i, a_end_index)
						if i >= a_end_index or else a_input.item (i) /= '=' then
							l_valid := False
						else
							i := skip_reparse_tag_spaces (a_input, i + 1, a_end_index)
							if i >= a_end_index or else not is_reparse_tag_quote (a_input.item (i)) then
								l_valid := False
							else
								l_quote := a_input.item (i)
								l_value_start := i + 1
								from
									i := i + 1
								until
									i >= a_end_index or else a_input.item (i) = l_quote
								loop
									i := i + 1
								variant
									a_end_index - i
								end
								if i >= a_end_index then
									l_valid := False
								else
									create l_value.make_from_string (a_input.substring (l_value_start, i - 1))
									if l_value.has ('&') or else l_attributes.has (l_name) then
										l_valid := False
									else
										l_attributes.put (l_name, l_value)
										i := i + 1
									end
								end
							end
						end
					end
				variant
					a_end_index - i
				end
				if l_valid and then i = a_end_index then
					Result := l_attributes
				end
			end
		end

	skip_reparse_tag_spaces (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- First non-space index at or after `a_start_index', bounded by `a_end_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_end_index
			valid_end: a_end_index <= a_input.count
		do
			from
				Result := a_start_index
			until
				Result >= a_end_index or else not is_reparse_tag_space (a_input.item (Result))
			loop
				Result := Result + 1
			variant
				a_end_index - Result
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index
		end

	is_deferred_start_tag_prefix (a_input: READABLE_STRING_8; a_start_index: INTEGER): BOOLEAN
			-- Does the deferred token look like a normal start tag?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		do
			Result :=
				a_input.item (a_start_index) = '<'
				and then a_start_index + 1 <= a_input.count
				and then a_input.item (a_start_index + 1) /= '/'
				and then a_input.item (a_start_index + 1) /= '!'
				and then a_input.item (a_start_index + 1) /= '?'
		end

	incremental_deferred_start_tag_end (a_input: READABLE_STRING_8): INTEGER
			-- End index of the deferred start tag, scanning only bytes not checked before.
		require
			input_attached: a_input /= Void
			has_deferred_token: deferred_reparse_start_index >= 1 and deferred_reparse_start_index <= a_input.count
		local
			i: INTEGER
			c: CHARACTER_8
		do
			if deferred_reparse_scan_index <= deferred_reparse_start_index then
				deferred_reparse_scan_index := deferred_reparse_start_index + 1
				deferred_reparse_scan_in_quote := False
				deferred_reparse_scan_quote := '%U'
			end
			from
				i := deferred_reparse_scan_index
			until
				i > a_input.count or Result > 0
			loop
				c := a_input.item (i)
				if deferred_reparse_scan_in_quote then
					if c = deferred_reparse_scan_quote then
						deferred_reparse_scan_in_quote := False
					end
				elseif is_reparse_tag_quote (c) then
					deferred_reparse_scan_in_quote := True
					deferred_reparse_scan_quote := c
				elseif c = '>' then
					Result := i
				end
				i := i + 1
			variant
				a_input.count - i + 1
			end
			deferred_reparse_scan_index := i
		ensure
			result_in_bounds: Result >= 0 and Result <= a_input.count
		end

	is_plain_completed_start_tag (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): BOOLEAN
			-- Is the completed token a start tag that contains only its name and whitespace?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			valid_end: a_end_index >= a_start_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			if
				a_input.item (a_start_index) = '<'
				and then a_start_index + 1 <= a_end_index
				and then a_input.item (a_start_index + 1) /= '/'
				and then a_input.item (a_start_index + 1) /= '!'
				and then a_input.item (a_start_index + 1) /= '?'
			then
				create l_attributes.make
				i := a_start_index + 1
				if l_attributes.is_name_start_character (a_input.item (i)) then
					from
						i := i + 1
					until
						i > a_end_index or else not l_attributes.is_name_character (a_input.item (i))
					loop
						i := i + 1
					variant
						a_end_index - i + 1
					end
					from
					until
						i > a_end_index or else not is_reparse_tag_space (a_input.item (i))
					loop
						i := i + 1
					variant
						a_end_index - i + 1
					end
					if i <= a_end_index and then a_input.item (i) = '/' then
						i := i + 1
					end
					Result := i = a_end_index and then a_input.item (i) = '>'
				end
			end
		end

	is_reparse_tag_space (a_character: CHARACTER_8): BOOLEAN
			-- Is `a_character' XML whitespace inside a deferred start tag?
		do
			Result := a_character = ' ' or else a_character = '%T' or else a_character = '%N' or else a_character = '%R'
		end

	is_reparse_tag_quote (a_character: CHARACTER_8): BOOLEAN
			-- Is `a_character' an XML attribute quote?
		do
			Result := a_character = '%"' or else a_character = '%''
		end

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
		local
			l_declared_encoding: detachable STRING_8
		do
			if explicit_encoding_overrides_declaration and then attached explicit_encoding as l_explicit_encoding then
				Result := decoded_input_with_encoding (a_input, l_explicit_encoding)
			elseif has_utf16le_signature (a_input) then
				Result := decoded_utf16_input (a_input, True)
			elseif has_utf16be_signature (a_input) then
				Result := decoded_utf16_input (a_input, False)
			else
				l_declared_encoding := declared_xml_encoding (a_input)
				if explicit_encoding_is_utf16 or else attached l_declared_encoding as l_encoding and then is_utf16_encoding_name (l_encoding) then
					last_error_code := Xml_error_incorrect_encoding
				elseif attached l_declared_encoding as l_encoding then
					if is_latin1_encoding_name (l_encoding) then
						Result := decoded_latin1_input (a_input)
					elseif is_ascii_encoding_name (l_encoding) then
						Result := decoded_ascii_input (a_input)
					elseif is_utf8_encoding_name (l_encoding) then
						Result := same_or_copied_input (a_input)
					elseif native_unknown_encoding_handler_available then
						Result := decoded_unknown_encoding_input (a_input, l_encoding)
					else
						last_error_code := Xml_error_unknown_encoding
					end
				elseif has_utf16_declaration_in_utf8_input (a_input) then
					last_error_code := Xml_error_incorrect_encoding
				elseif attached explicit_encoding as l_initial_encoding then
					Result := decoded_input_with_encoding (a_input, l_initial_encoding)
				else
					Result := same_or_copied_input (a_input)
				end
			end
		end

	decoded_input_with_encoding (a_input, a_encoding: READABLE_STRING_8): detachable STRING_8
			-- Decode `a_input' using `a_encoding' as a native encoding choice.
		require
			input_attached: a_input /= Void
			encoding_attached: a_encoding /= Void
		do
			if is_latin1_encoding_name (a_encoding) then
				Result := decoded_latin1_input (a_input)
			elseif is_ascii_encoding_name (a_encoding) then
				Result := decoded_ascii_input (a_input)
			elseif a_encoding.same_string ("UTF-16BE") or else a_encoding.same_string ("utf-16be") then
				Result := decoded_utf16_input (a_input, False)
			elseif a_encoding.same_string ("UTF-16LE") or else a_encoding.same_string ("utf-16le") then
				Result := decoded_utf16_input (a_input, True)
			elseif a_encoding.same_string ("UTF-16") or else a_encoding.same_string ("utf-16") then
				if has_utf16le_signature (a_input) then
					Result := decoded_utf16_input (a_input, True)
				elseif has_utf16be_signature (a_input) then
					Result := decoded_utf16_input (a_input, False)
				else
					last_error_code := Xml_error_incorrect_encoding
				end
			elseif is_utf8_encoding_name (a_encoding) then
				Result := same_or_copied_input (a_input)
			elseif native_unknown_encoding_handler_available then
				Result := decoded_unknown_encoding_input (a_input, a_encoding)
			else
				last_error_code := Xml_error_unknown_encoding
			end
		end

	same_or_copied_input (a_input: READABLE_STRING_8): STRING_8
			-- `a_input' as a mutable UTF-8 string without copying when already stored that way.
		require
			input_attached: a_input /= Void
		do
			if attached {STRING_8} a_input as l_input then
				Result := l_input
			else
				create Result.make_from_string (a_input)
			end
		ensure
			result_attached: Result /= Void
			same_text: Result.same_string (a_input)
		end

	declared_xml_encoding (a_input: READABLE_STRING_8): detachable STRING_8
			-- Encoding declared in an ASCII XML/text declaration, if present.
		require
			input_attached: a_input /= Void
		local
			l_end: INTEGER
			l_pos: INTEGER
			l_index: INTEGER
			l_quote: CHARACTER_8
			l_start: INTEGER
		do
			if a_input.count >= 5 and then a_input.substring (1, 5).same_string ("<?xml") then
				l_end := a_input.substring_index ("?>", 1)
				if l_end = 0 then
					l_end := a_input.count
				end
				l_pos := a_input.substring_index ("encoding", 1)
				if l_pos > 0 and then l_pos < l_end then
					l_index := l_pos + 8
					from
					until
						l_index > l_end or else not is_xml_space (a_input.item (l_index))
					loop
						l_index := l_index + 1
					end
					if l_index <= l_end and then a_input.item (l_index) = '=' then
						l_index := l_index + 1
						from
						until
							l_index > l_end or else not is_xml_space (a_input.item (l_index))
						loop
							l_index := l_index + 1
						end
						if l_index <= l_end and then (a_input.item (l_index) = '%'' or else a_input.item (l_index) = '%"') then
							l_quote := a_input.item (l_index)
							l_start := l_index + 1
							l_index := l_start
							from
							until
								l_index > l_end or else a_input.item (l_index) = l_quote
							loop
								l_index := l_index + 1
							end
							if l_index <= l_end then
								create Result.make_from_string (a_input.substring (l_start, l_index - 1))
							end
						end
					end
				end
			end
		end

	decoded_unknown_encoding_input (a_input, a_encoding: READABLE_STRING_8): detachable STRING_8
			-- Decode native input through the registered Expat unknown-encoding handler.
		require
			input_attached: a_input /= Void
			encoding_attached: a_encoding /= Void
		local
			l_input: C_STRING
			l_encoding: C_STRING
			l_length: MANAGED_POINTER
			l_error: MANAGED_POINTER
			l_decoded: POINTER
			l_decoded_length: INTEGER
			l_decoded_string: C_STRING
		do
			create l_input.make (a_input)
			create l_encoding.make (a_encoding)
			create l_length.make (4)
			create l_error.make (4)
			l_decoded := c_decode_unknown_encoding_input (
				native_parser_handle,
				l_encoding.item,
				l_input.item,
				a_input.count,
				l_length.item,
				l_error.item
			)
			if l_decoded = default_pointer then
				last_error_code := integer_at (l_error.item)
			else
				l_decoded_length := integer_at (l_length.item)
				create l_decoded_string.make_by_pointer_and_count (l_decoded, l_decoded_length)
				Result := l_decoded_string.substring_8 (1, l_decoded_length)
				c_free_unknown_encoding_input (l_decoded)
			end
		end

	native_unknown_encoding_handler_available: BOOLEAN
			-- Is a public native parser handle present with an unknown-encoding handler?
		do
			Result := native_parser_handle /= default_pointer and then has_native_unknown_encoding_handler (native_parser_handle)
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
			l_prefix: detachable STRING_8
		do
			if a_input.count \\ 2 /= 0 then
				l_prefix := decoded_utf16_prefix_before_partial_byte (a_input, a_little_endian)
				if attached l_prefix as l_decoded_prefix and then has_open_cdata_section (l_decoded_prefix) then
					last_error_code := Xml_error_unclosed_cdata_section
				elseif l_prefix /= Void and then is_partial_utf16_ascii_byte (a_input.item (a_input.count).code, a_little_endian) then
					last_error_code := Xml_error_unclosed_token
				else
					last_error_code := Xml_error_partial_char
				end
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

	decoded_utf16_prefix_before_partial_byte (a_input: READABLE_STRING_8; a_little_endian: BOOLEAN): detachable STRING_8
			-- Decode complete UTF-16 units before a final dangling byte, if they are valid.
		require
			input_attached: a_input /= Void
			odd_byte_count: a_input.count \\ 2 /= 0
		local
			i: INTEGER
			l_limit: INTEGER
			l_unit: INTEGER
			l_low: INTEGER
			l_code: INTEGER
		do
			l_limit := a_input.count - 1
			create Result.make (l_limit)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_limit + 1
			until
				i > l_limit or Result = Void
			loop
				l_unit := utf16_unit_at (a_input, i, a_little_endian)
				if i = 1 and then l_unit = 65279 then
					i := i + 2
				elseif l_unit >= 55296 and then l_unit <= 56319 then
					if i + 3 > l_limit then
						Result := Void
					else
						l_low := utf16_unit_at (a_input, i + 2, a_little_endian)
						if l_low < 56320 or else l_low > 57343 then
							Result := Void
						else
							l_code := 65536 + ((l_unit - 55296) * 1024) + (l_low - 56320)
							append_utf8_codepoint (Result, l_code)
							i := i + 4
						end
					end
				elseif l_unit >= 56320 and then l_unit <= 57343 then
					Result := Void
				else
					append_utf8_codepoint (Result, l_unit)
					i := i + 2
				end
			variant
				l_limit - i + 1
			end
		end

	has_open_cdata_section (a_input: READABLE_STRING_8): BOOLEAN
			-- Does `a_input' end inside a CDATA section?
		require
			input_attached: a_input /= Void
		local
			l_index: INTEGER
			l_last_open: INTEGER
			l_last_close: INTEGER
		do
			from
				l_index := a_input.substring_index ("<![CDATA[", 1)
			until
				l_index = 0
			loop
				l_last_open := l_index
				l_index := a_input.substring_index ("<![CDATA[", l_index + 1)
			end
			from
				l_index := a_input.substring_index ("]]>", 1)
			until
				l_index = 0
			loop
				l_last_close := l_index
				l_index := a_input.substring_index ("]]>", l_index + 1)
			end
			Result := l_last_open > 0 and then l_last_open > l_last_close
		end

	is_partial_utf16_ascii_byte (a_byte: INTEGER; a_little_endian: BOOLEAN): BOOLEAN
			-- Is `a_byte' the first byte of an incomplete ASCII-range UTF-16 unit?
		do
			if a_little_endian then
				Result := a_byte > 0 and then a_byte <= 127
			else
				Result := a_byte = 0
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
				a_input.count >= 5
				and then a_input.substring (1, 5).same_string ("<?xml")
				and then (
					a_input.has_substring ("encoding='utf-16'")
					or else a_input.has_substring ("encoding=%"utf-16%"")
					or else a_input.has_substring ("encoding='UTF-16'")
					or else a_input.has_substring ("encoding=%"UTF-16%"")
				)
		end

	explicit_encoding_is_utf16: BOOLEAN
			-- Did the caller explicitly select UTF-16 with auto endian detection?
		do
			Result := attached explicit_encoding as l_encoding and then (l_encoding.same_string ("UTF-16") or else l_encoding.same_string ("utf-16"))
		end

	explicit_encoding_is_utf8: BOOLEAN
			-- Did the caller explicitly select UTF-8?
		do
			Result := attached explicit_encoding as l_encoding and then is_utf8_encoding_name (l_encoding)
		end

	is_utf8_encoding_name (a_encoding: READABLE_STRING_8): BOOLEAN
			-- Is `a_encoding' a UTF-8 spelling?
		require
			encoding_attached: a_encoding /= Void
		do
			Result :=
				a_encoding.same_string ("UTF-8")
				or else a_encoding.same_string ("utf-8")
				or else a_encoding.same_string ("UTF8")
				or else a_encoding.same_string ("utf8")
		end

	is_ascii_encoding_name (a_encoding: READABLE_STRING_8): BOOLEAN
			-- Is `a_encoding' an ASCII spelling?
		require
			encoding_attached: a_encoding /= Void
		do
			Result :=
				a_encoding.same_string ("US-ASCII")
				or else a_encoding.same_string ("us-ascii")
				or else a_encoding.same_string ("ASCII")
				or else a_encoding.same_string ("ascii")
		end

	is_latin1_encoding_name (a_encoding: READABLE_STRING_8): BOOLEAN
			-- Is `a_encoding' an ISO-8859-1 spelling?
		require
			encoding_attached: a_encoding /= Void
		do
			Result := a_encoding.same_string ("ISO-8859-1") or else a_encoding.same_string ("iso-8859-1")
		end

	is_utf16_encoding_name (a_encoding: READABLE_STRING_8): BOOLEAN
			-- Is `a_encoding' a UTF-16 spelling?
		require
			encoding_attached: a_encoding /= Void
		do
			Result :=
				a_encoding.same_string ("UTF-16")
				or else a_encoding.same_string ("utf-16")
				or else a_encoding.same_string ("UTF-16LE")
				or else a_encoding.same_string ("utf-16le")
				or else a_encoding.same_string ("UTF-16BE")
				or else a_encoding.same_string ("utf-16be")
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

	is_xml_space (a_character: CHARACTER_8): BOOLEAN
			-- Is `a_character' XML whitespace?
		do
			Result := a_character = ' ' or else a_character = '%T' or else a_character = '%N' or else a_character = '%R'
		end

	raw_cr_epilog_stop_status (a_input: READABLE_STRING_8): INTEGER
			-- Native parse status after replaying a raw carriage return in final
			-- epilog whitespace, matching Expat's single-byte feed callback path.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_epilog_start: INTEGER
			l_all_space: BOOLEAN
			l_has_cr: BOOLEAN
		do
			Result := Xml_status_ok
			l_epilog_start := raw_epilog_start (a_input)
			if l_epilog_start > 0 then
				l_all_space := True
				from
					i := l_epilog_start
				invariant
					index_in_bounds: i >= l_epilog_start and i <= a_input.count + 1
				until
					i > a_input.count or not l_all_space
				loop
					l_all_space := is_xml_space (a_input.item (i))
					i := i + 1
				variant
					a_input.count - i + 1
				end
				if l_all_space then
					from
						i := l_epilog_start
					invariant
						index_in_bounds: i >= l_epilog_start and i <= a_input.count + 1
					until
						i > a_input.count or l_has_cr
					loop
						l_has_cr := a_input.item (i) = '%R'
						i := i + 1
					variant
						a_input.count - i + 1
					end
					if l_has_cr then
						handler.on_default ("%R")
						if handler.stop_requested then
							if handler.stop_is_resumable then
								last_error_code := Xml_error_none
								Result := Xml_status_suspended
							else
								last_error_code := Xml_error_aborted
								Result := Xml_status_error
							end
						end
					end
				end
			end
		ensure
			valid_status: Result = Xml_status_ok or Result = Xml_status_error or Result = Xml_status_suspended
			error_status_has_error: Result = Xml_status_error implies last_error_code /= Xml_error_none
		end

	raw_epilog_start (a_input: READABLE_STRING_8): INTEGER
			-- Index of decoded epilog text after the final markup close, or zero
			-- when there is no trailing epilog text.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
		do
			from
				i := a_input.count
			invariant
				index_in_bounds: i >= 0 and i <= a_input.count
			until
				i < 1 or Result > 0
			loop
				if a_input.item (i) = '>' then
					if i < a_input.count then
						Result := i + 1
					end
					i := 0
				else
					i := i - 1
				end
			variant
				i
			end
		ensure
			valid_index: Result = 0 or else (Result >= 1 and Result <= a_input.count)
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
			elseif a_error.same_string ("parsing aborted") then
				Result := Xml_error_aborted
			elseif a_error.same_string ("unbound namespace prefix") then
				Result := Xml_error_unbound_prefix
			elseif a_error.same_string ("undeclaring prefix") then
				Result := Xml_error_undeclaring_prefix
			elseif a_error.same_string ("reserved prefix xml") then
				Result := Xml_error_reserved_prefix_xml
			elseif a_error.same_string ("reserved prefix xmlns") then
				Result := Xml_error_reserved_prefix_xmlns
			elseif a_error.same_string ("reserved namespace URI") then
				Result := Xml_error_reserved_namespace_uri
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

	integer_at (a_source: POINTER): INTEGER
			-- C `int' value at `a_source'.
		require
			source_attached: a_source /= default_pointer
		external
			"C inline"
		alias
			"return (EIF_INTEGER) *((int *) $a_source);"
		end

	has_native_unknown_encoding_handler (a_parser: POINTER): BOOLEAN
			-- Does native parser `a_parser' have an unknown-encoding handler?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return xp_has_unknown_encoding_handler((XML_Parser) $a_parser) ? EIF_TRUE : EIF_FALSE;"
		end

	native_return_ns_triplet (a_parser: POINTER): BOOLEAN
			-- Should namespace-expanded names include the original prefix?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return $a_parser != 0 && ((struct XML_ParserStruct *) $a_parser)->returnNsTriplet ? EIF_TRUE : EIF_FALSE;"
		end

	native_reparse_deferral_enabled (a_parser: POINTER): BOOLEAN
			-- Is Expat-compatible reparse deferral enabled on native parser `a_parser'?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return $a_parser != 0 && ((struct XML_ParserStruct *) $a_parser)->reparseDeferralEnabled ? EIF_TRUE : EIF_FALSE;"
		end

	native_has_start_element_handler (a_parser: POINTER): BOOLEAN
			-- Does native parser `a_parser' have a start-element callback?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return $a_parser != 0 && ((struct XML_ParserStruct *) $a_parser)->startElementHandler != 0 ? EIF_TRUE : EIF_FALSE;"
		end

	native_has_character_or_default_handler (a_parser: POINTER): BOOLEAN
			-- Does native parser `a_parser' need character/default text callbacks?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return $a_parser != 0 && (((struct XML_ParserStruct *) $a_parser)->characterDataHandler != 0 || ((struct XML_ParserStruct *) $a_parser)->defaultHandler != 0) ? EIF_TRUE : EIF_FALSE;"
		end

	native_amplification_limit_breached (a_parser: POINTER; a_byte_count: INTEGER; a_amplification: REAL_32): BOOLEAN
			-- Does native attack-protection state reject the current accumulated input?
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"[
				if ($a_parser == 0) {
					return EIF_FALSE;
				} else {
					struct XML_ParserStruct *p = (struct XML_ParserStruct *) $a_parser;
					unsigned long long count = (unsigned long long) $a_byte_count;
					float amplification = (float) $a_amplification;
					return (
						p->hasBillionLaughsMaximumAmplification
						&& p->hasBillionLaughsActivationThreshold
						&& count >= p->billionLaughsActivationThresholdBytes
						&& amplification >= p->billionLaughsMaximumAmplification
					) ? EIF_TRUE : EIF_FALSE;
				}
			]"
		end

	amplification_estimate: REAL_32
			-- Conservative amplification estimate for the current native parse mode.
		do
			if is_external_entity_parser then
				Result := 2.0
			else
				Result := 1.0
			end
		ensure
			at_least_identity: Result >= 1.0
		end

	c_decode_unknown_encoding_input (a_parser, a_encoding, a_input: POINTER; a_length: INTEGER; a_decoded_length, a_error: POINTER): POINTER
			-- Decode `a_input' through native parser's unknown-encoding handler.
		require
			encoding_attached: a_encoding /= default_pointer
			input_attached: a_input /= default_pointer
			decoded_length_attached: a_decoded_length /= default_pointer
			error_attached: a_error /= default_pointer
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"return (EIF_POINTER) xp_decode_unknown_encoding_input((XML_Parser) $a_parser, (const XML_Char *) $a_encoding, (const char *) $a_input, (int) $a_length, (int *) $a_decoded_length, (enum XML_Error *) $a_error);"
		end

	c_free_unknown_encoding_input (a_input: POINTER)
			-- Free buffer returned by `c_decode_unknown_encoding_input'.
		require
			input_attached: a_input /= default_pointer
		external
			"C inline use %"xpact_native_private.h%""
		alias
			"xp_free_unknown_encoding_input((char *) $a_input);"
		end

invariant
	handler_attached: handler /= Void
	parser_attached: parser /= Void
	input_buffer_attached: input_buffer /= Void
	valid_parsing_status: parsing_status = Xml_initialized or parsing_status = Xml_parsing or parsing_status = Xml_finished or parsing_status = Xml_suspended
	valid_last_error_code: last_error_code >= Xml_error_none

end
