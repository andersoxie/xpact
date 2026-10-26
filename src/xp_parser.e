note
	description: "Phase 1 xpact streaming XML parser with XML 1.0 tokenization and entity contracts."

class
	XP_PARSER

inherit
	XP_LIMITS
	XP_EXTERNAL_ENTITY_POLICY

create
	make,
	make_with_limits

feature {NONE} -- Initialization

	make (a_handler: XP_EVENT_HANDLER)
			-- Create parser with default security limits.
		require
			handler_attached: a_handler /= Void
		do
			is_initialized := False
			handler := a_handler
			max_input_bytes := Default_max_input_bytes
			max_name_length := Default_max_name_length.min (max_input_bytes)
			max_element_depth := Default_max_element_depth
			max_attribute_count := Default_max_attribute_count
			max_token_length := Default_max_token_length
			create element_stack.make (32)
			create entity_stack.make (8)
			create element_slice_stack.make (32)
			create element_stack_marker.make_empty
			create entity_reference_start_stack.make (8)
			create entity_reference_count_stack.make (8)
			create entity_table.make (8)
			create parameter_entity_table.make (4)
			create parameter_entity_accounting_table.make (4)
			create external_entity_table.make (4)
			create external_parameter_entity_table.make (4)
			create attribute_decl_table.make (4)
			create namespace_context_stack.make (8)
			create namespace_declaration_stack.make (8)
			create last_error.make_empty
			create doctype_name.make_empty
			create position_input.make_empty
			external_entity_policy := No_external_entities
			reset
			is_initialized := True
		ensure
			handler_set: handler = a_handler
			default_input_limit: max_input_bytes = Default_max_input_bytes
			default_depth_limit: max_element_depth = Default_max_element_depth
		end

	make_with_limits (a_handler: XP_EVENT_HANDLER; a_max_input_bytes, a_max_element_depth, a_max_attribute_count, a_max_token_length: INTEGER)
			-- Create parser with explicit limits.
		require
			handler_attached: a_handler /= Void
			input_limit_positive: a_max_input_bytes > 0
			depth_limit_positive: a_max_element_depth > 0
			attribute_limit_positive: a_max_attribute_count > 0
			token_limit_positive: a_max_token_length > 0
		do
			is_initialized := False
			handler := a_handler
			max_input_bytes := a_max_input_bytes
			max_name_length := Default_max_name_length.min (max_input_bytes)
			max_element_depth := a_max_element_depth
			max_attribute_count := a_max_attribute_count
			max_token_length := a_max_token_length
			create element_stack.make (32)
			create entity_stack.make (8)
			create element_slice_stack.make (32)
			create element_stack_marker.make_empty
			create entity_reference_start_stack.make (8)
			create entity_reference_count_stack.make (8)
			create entity_table.make (8)
			create parameter_entity_table.make (4)
			create parameter_entity_accounting_table.make (4)
			create external_entity_table.make (4)
			create external_parameter_entity_table.make (4)
			create attribute_decl_table.make (4)
			create namespace_context_stack.make (8)
			create namespace_declaration_stack.make (8)
			create last_error.make_empty
			create doctype_name.make_empty
			create position_input.make_empty
			external_entity_policy := No_external_entities
			reset
			is_initialized := True
		ensure
			handler_set: handler = a_handler
			limits_set: max_input_bytes = a_max_input_bytes and max_element_depth = a_max_element_depth and max_attribute_count = a_max_attribute_count and max_token_length = a_max_token_length
		end

feature -- Access

	handler: XP_EVENT_HANDLER
			-- Event receiver.

	max_input_bytes: INTEGER
			-- Maximum accepted input size.

	max_element_depth: INTEGER
			-- Maximum accepted nesting depth.

	max_name_length: INTEGER
			-- Maximum name bytes; never exceeds the configured input budget.

	set_max_name_length (a_limit: INTEGER)
			-- Set a name ceiling within the parser's existing input budget.
		require
			positive: a_limit > 0
			within_input_budget: a_limit <= max_input_bytes
		do
			if a_limit /= max_name_length then
				clear_cached_doctype
			end
			if a_limit > 0 and then a_limit <= max_input_bytes then
				max_name_length := a_limit
			end
		ensure
			limit_set: max_name_length = a_limit
		end

	uses_legacy_name_character_ranges: BOOLEAN
			-- Use the XML 1.0 fourth-edition name tables required by native Expat.
			-- The generic parser retains the fifth-edition character productions.

	set_legacy_name_character_ranges (a_enabled: BOOLEAN)
			-- Configure name productions; retained across parse resets and child imports.
		do
			if a_enabled /= uses_legacy_name_character_ranges then
				clear_cached_doctype
			end
			uses_legacy_name_character_ranges := a_enabled
		ensure
			policy_set: uses_legacy_name_character_ranges = a_enabled
		end

	max_attribute_count: INTEGER
			-- Maximum attributes accepted on a single element.

	max_token_length: INTEGER
			-- Maximum accepted non-markup token length.

	last_error: STRING_8
			-- Last parse error.

	has_error: BOOLEAN
			-- Did the last parse fail?

	is_suspended: BOOLEAN
			-- Did a resumable callback stop request suspend the active parse?

	current_line_number: INTEGER
			-- Current 1-based XML line number.

	current_column_number: INTEGER
			-- Current 0-based XML column number.

	current_byte_index: INTEGER
			-- Current 0-based byte index, or -1 before parsing starts.

	current_byte_count: INTEGER
			-- Current token byte count, or zero at parse end and errors.

	accounting_indirect_byte_count: INTEGER
			-- Bytes accounted as indirect entity replacement output in the most recent parse.
		do
			Result := expanded_entity_bytes
		ensure
			non_negative: Result >= 0
		end

	external_entity_policy: INTEGER
			-- Current external entity loading policy.

	external_entity_resolver: detachable XP_EXTERNAL_ENTITY_RESOLVER
			-- Application-provided external entity resolver.

	parsing_external_entity: BOOLEAN
			-- Is the active parse for an external parsed entity fragment?

	namespace_mode: BOOLEAN
			-- Should qualified names be resolved using XML namespace declarations?

	namespace_separator: CHARACTER_8
			-- Separator used in expanded namespace names.

	return_ns_triplet: BOOLEAN
			-- Should expanded names include the original prefix as a third field?

	garbage_collection_enabled: BOOLEAN
			-- Is Eiffel garbage collection currently enabled?
		local
			l_memory: MEMORY
		do
			create l_memory
			Result := l_memory.collecting
		end

feature -- Configuration

	set_namespace_mode (a_separator: CHARACTER_8)
			-- Enable XML namespace expansion using `a_separator'.
		do
			if not namespace_mode or else namespace_separator /= a_separator then
				clear_cached_doctype
			end
			namespace_mode := True
			namespace_separator := a_separator
			reset_namespace_context
		ensure
			namespace_enabled: namespace_mode
			separator_set: namespace_separator = a_separator
		end

	set_return_ns_triplet (a_enabled: BOOLEAN)
			-- Control Expat-compatible namespace triplet output.
		do
			if a_enabled /= return_ns_triplet then
				clear_cached_doctype
			end
			return_ns_triplet := a_enabled
		ensure
			value_set: return_ns_triplet = a_enabled
		end

	set_external_entity_policy (a_policy: INTEGER)
			-- Set external entity loading policy.
		require
			valid_policy: is_valid_policy (a_policy)
		do
			if a_policy /= external_entity_policy then
				clear_cached_doctype
			end
			external_entity_policy := a_policy
		ensure
			policy_set: external_entity_policy = a_policy
		end

	set_external_entity_resolver (a_resolver: detachable XP_EXTERNAL_ENTITY_RESOLVER)
			-- Set resolver used when `external_entity_policy' permits loading.
		do
			if a_resolver /= external_entity_resolver then
				clear_cached_doctype
			end
			external_entity_resolver := a_resolver
		ensure
			resolver_set: external_entity_resolver = a_resolver
		end

	import_entity_context (a_parent: XP_PARSER)
			-- Import DTD entity declarations from `a_parent' for an external entity child parser.
		require
			parent_attached: a_parent /= Void
		do
			clear_cached_doctype
			uses_legacy_name_character_ranges := a_parent.uses_legacy_name_character_ranges
			inherited_dtd_declarations_disabled := a_parent.dtd_declarations_disabled
			inherited_dtd_is_standalone := a_parent.dtd_is_standalone
			inherited_entity_table := cloned_string_table (a_parent.general_entity_context_table)
			inherited_parameter_entity_table := cloned_string_table (a_parent.parameter_entity_context_table)
			inherited_parameter_entity_accounting_table := cloned_integer_table (a_parent.parameter_entity_accounting_context_table)
			inherited_external_entity_table := cloned_external_entity_table (a_parent.external_general_entity_context_table)
			inherited_external_parameter_entity_table := cloned_external_entity_table (a_parent.external_parameter_entity_context_table)
			install_inherited_entity_context
		ensure
			internal_general_entities_imported: attached inherited_entity_table
			external_general_entities_imported: attached inherited_external_entity_table
		end


	entity_context_snapshot: XP_PARSER
			-- Detached NEW declarations only; inherited bindings and source are not retained.
		local
			l_handler: XP_NULL_EVENT_HANDLER
		do
			create l_handler.make
			create Result.make_with_limits (l_handler, max_input_bytes, max_element_depth, max_attribute_count, max_token_length)
			Result.set_max_name_length (max_name_length)
			Result.set_legacy_name_character_ranges (uses_legacy_name_character_ranges)
			Result.general_entity_context_table.wipe_out
			copy_string_entity_delta (entity_table, inherited_entity_table, Result.general_entity_context_table, True)
			copy_string_entity_delta (parameter_entity_table, inherited_parameter_entity_table, Result.parameter_entity_context_table, False)
			copy_integer_entity_delta (parameter_entity_accounting_table, inherited_parameter_entity_accounting_table, Result.parameter_entity_accounting_context_table)
			copy_external_entity_delta (external_entity_table, inherited_external_entity_table, Result.external_general_entity_context_table)
			copy_external_entity_delta (external_parameter_entity_table, inherited_external_parameter_entity_table, Result.external_parameter_entity_context_table)
			Result.set_entity_snapshot_state (dtd_declarations_disabled, dtd_is_standalone)
			Result.import_entity_context (Result)
		ensure
			result_attached: Result /= Void
			no_cached_source: Result.cached_doctype_byte_count = 0
		end

	entity_context_definition_count: INTEGER
			-- Definition records currently retained, excluding accounting metadata.
		do
			Result := entity_table.count + parameter_entity_table.count + external_entity_table.count + external_parameter_entity_table.count
		end

	merge_entity_context_from (a_child: XP_PARSER)
			-- Merge DTD entity declarations parsed by external entity child `a_child'.
		require
			child_attached: a_child /= Void
		do
			clear_cached_doctype
			dtd_declarations_disabled := dtd_declarations_disabled or else a_child.dtd_declarations_disabled
			dtd_has_parameter_entity_references := dtd_has_parameter_entity_references or else a_child.dtd_declarations_disabled
			copy_string_table_into (a_child.general_entity_context_table, entity_table)
			copy_string_table_into (a_child.parameter_entity_context_table, parameter_entity_table)
			copy_integer_table_into (a_child.parameter_entity_accounting_context_table, parameter_entity_accounting_table)
			copy_external_entity_table_into (a_child.external_general_entity_context_table, external_entity_table)
			copy_external_entity_table_into (a_child.external_parameter_entity_context_table, external_parameter_entity_table)
		end

	set_parameter_entities_unless_standalone (a_enabled: BOOLEAN)
			-- Honor standalone='yes' for XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE.
		do
			if a_enabled /= parameter_entities_unless_standalone then
				clear_cached_doctype
			end
			parameter_entities_unless_standalone := a_enabled
		ensure
			value_set: parameter_entities_unless_standalone = a_enabled
		end

	set_use_foreign_dtd (a_enabled: BOOLEAN)
			-- Load a foreign DTD when no external subset is declared.
		do
			if a_enabled /= use_foreign_dtd then
				clear_cached_doctype
			end
			use_foreign_dtd := a_enabled
		ensure
			value_set: use_foreign_dtd = a_enabled
		end

	set_input_is_utf8 (a_enabled: BOOLEAN)
			-- Declare that callers convert input to UTF-8 themselves, so byte-order marks and
			-- encoding declarations are not used to convert it again.
		do
			clear_cached_doctype
			input_is_utf8 := a_enabled
		ensure
			value_set: input_is_utf8 = a_enabled
		end

feature {XP_NATIVE_PARSER} -- State

	has_document_type: BOOLEAN
			-- Has the current parse established a DOCTYPE and its declaration context?
		do
			Result := has_doctype
		end

	reset_for_reuse
			-- Reset parse state while preserving parser object storage.
		do
			reset
		ensure
			no_error: not has_error
			no_message: last_error.is_empty
			no_open_elements: element_stack.count = 0
		end

feature {XP_PARSER} -- Entity context import

	set_entity_snapshot_state (a_disabled, a_standalone: BOOLEAN)
			-- Preserve scalar DTD state without retaining a source parser.
		do
			dtd_declarations_disabled := a_disabled
			inherited_dtd_declarations_disabled := a_disabled
			inherited_dtd_is_standalone := a_standalone
		end

	dtd_declarations_disabled: BOOLEAN
			-- Has an unread external parameter entity made later declarations unreliable?

	dtd_is_standalone: BOOLEAN
			-- Does this document or its external-DTD parent declare standalone='yes'?
		do
			Result := xml_standalone = 1 or else inherited_dtd_is_standalone
		end

	general_entity_context_table: HASH_TABLE [STRING_8, STRING_8]
			-- Current internal general entity table for child parser import.
		do
			Result := entity_table
		ensure
			result_attached: Result /= Void
		end

	parameter_entity_context_table: HASH_TABLE [STRING_8, STRING_8]
			-- Current internal parameter entity table for child parser import.
		do
			Result := parameter_entity_table
		ensure
			result_attached: Result /= Void
		end

	parameter_entity_accounting_context_table: HASH_TABLE [INTEGER, STRING_8]
			-- Logical parameter entity replacement byte counts for child parser import.
		do
			Result := parameter_entity_accounting_table
		ensure
			result_attached: Result /= Void
		end

	external_general_entity_context_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- Current external general entity table for child parser import.
		do
			Result := external_entity_table
		ensure
			result_attached: Result /= Void
		end

	external_parameter_entity_context_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- Current external parameter entity table for child parser import.
		do
			Result := external_parameter_entity_table
		ensure
			result_attached: Result /= Void
		end

feature -- Parsing

	parse (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete XML document `a_input'.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			l_input: STRING_8
			l_can_defer_positions: BOOLEAN
		do
			reset
			l_can_defer_positions := can_defer_position_accounting
			l_input := normalized_input (a_input, l_can_defer_positions)
			position_input := l_input
			lazy_position_accounting := l_can_defer_positions
			note_position (1)
			if not has_error then
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= l_input.count + 1
					depth_within_limit: element_stack.count <= max_element_depth
				until
					i > l_input.count or has_error or is_suspended
				loop
					note_position (i)
					if l_input.item (i) = '<' then
						i := parse_markup (l_input, i)
					else
						i := parse_character_data (l_input, i)
					end
					if not has_error then
						note_position (i)
					end
				variant
					l_input.count - i + 1
				end
			end
			if not has_error and not is_suspended and element_stack.count /= 0 then
				note_position (l_input.count + 1)
				set_error ("unclosed element")
			end
			if not has_error and not is_suspended and document_element_count = 0 then
				note_position (l_input.count + 1)
				set_error ("missing document element")
			end
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			force_current_position
			Result := not has_error and not is_suspended
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			success_is_balanced: Result implies element_stack.count = 0
			success_has_root: Result implies document_element_count = 1
		end

	parse_without_garbage_collection (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete XML document `a_input' while temporarily suspending Eiffel garbage collection.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			l_result: CELL [BOOLEAN]
			l_section: XP_GC_CRITICAL_SECTION
		do
			create l_result.put (False)
			create l_section.make
			l_section.execute (agent parse_into_boolean_cell (a_input, l_result))
			Result := l_result.item
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			success_is_balanced: Result implies element_stack.count = 0
			success_has_root: Result implies document_element_count = 1
			garbage_collection_status_preserved: garbage_collection_enabled = old garbage_collection_enabled
		end

	parse_prefix (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete tokens available in a non-final XML document prefix.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			l_input: STRING_8
		do
			reset
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_input.count + 1
				depth_within_limit: element_stack.count <= max_element_depth
			until
				i > l_input.count or has_error or is_suspended
			loop
				note_position (i)
				if l_input.item (i) = '<' then
					if is_incomplete_markup_prefix (l_input, i) then
						if has_at (l_input, i, "<!DOCTYPE") then
							process_incomplete_doctype_prefix (l_input, i)
						end
						i := l_input.count + 1
					else
						i := parse_markup (l_input, i)
					end
				else
					i := parse_character_data_prefix (l_input, i)
				end
				if not has_error then
					note_position (i)
				end
			variant
				l_input.count - i + 1
			end
			Result := not has_error and not is_suspended
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
		end


	cached_doctype_byte_count: INTEGER
			-- Bytes retained by the optional native completed-DOCTYPE cache.
		do
			if attached cached_doctype_prefix as l_prefix then
				Result := l_prefix.count
			end
		ensure
			non_negative: Result >= 0
			within_input_budget: Result <= max_input_bytes
		end

	clear_cached_doctype
			-- Release cached source and snapshot references without changing parse diagnostics.
		do
			cached_doctype_prefix := Void
			cached_doctype_name := Void
			cached_doctype_line := 0
			cached_doctype_column := 0
			cached_doctype_entity_bytes := 0
			cached_doctype_has_external_subset := False
			cached_doctype_has_parameter_references := False
			cached_doctype_declarations_disabled := False
			cached_doctype_standalone := 0
			cached_doctype_foreign_loaded := False
			cached_doctype_not_standalone_checked := False
		ensure
			storage_released: cached_doctype_byte_count = 0 and cached_doctype_name = Void
		end

	parse_with_cached_doctype (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): BOOLEAN
			-- Native-only opt-in: retain an already completed, unobserved initial DTD.
			-- Generic `parse' and `parse_prefix' always reset and reparse normally.
			-- The native caller must clear this cache if DTD observers or policy change.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i, l_end, l_cr, l_prefix_count: INTEGER
			l_ok, l_prepared: BOOLEAN
			l_input, l_body, l_prefix_input: STRING_8
		do
			if a_input.count > max_input_bytes then
				reset
				set_error ("input exceeds limit")
			else
				if attached cached_doctype_prefix as l_prefix and then
					(a_input.count < l_prefix.count or else not a_input.same_characters (l_prefix, 1, l_prefix.count, 1))
				then
					clear_cached_doctype
				end
				if cached_doctype_prefix = Void and then not a_is_final and then has_at (a_input, 1, "<!DOCTYPE") then
					l_end := find_doctype_end (a_input, 1)
					l_cr := find_character (a_input, '%R', 1)
					if l_end > 0 and then (l_cr = 0 or else l_cr > l_end) then
						l_prefix_input := a_input.substring (1, l_end).to_string_8
						l_prepared := True
						l_ok := parse_prefix (l_prefix_input)
						if l_ok and then has_doctype and then document_element_count = 0 then
							force_current_position
							cached_doctype_prefix := l_prefix_input.twin
							cached_doctype_name := doctype_name.twin
							cached_doctype_line := current_line_number
							cached_doctype_column := current_column_number
							cached_doctype_entity_bytes := expanded_entity_bytes
							cached_doctype_has_external_subset := document_has_external_subset
							cached_doctype_has_parameter_references := dtd_has_parameter_entity_references
							cached_doctype_declarations_disabled := dtd_declarations_disabled
							cached_doctype_standalone := xml_standalone
							cached_doctype_foreign_loaded := foreign_dtd_loaded
							cached_doctype_not_standalone_checked := not_standalone_checked
						end
					end
				end
				if attached cached_doctype_prefix as l_prefix and attached cached_doctype_name as l_name then
					l_prefix_count := l_prefix.count
					reset_cached_doctype_body (l_prefix_count, l_name)
					l_body := normalized_input (a_input.substring (l_prefix_count + 1, a_input.count), False)
					l_input := l_prefix.twin
					l_input.append (l_body)
					position_input := l_input
					from
						i := l_prefix_count + 1
					until
						i > l_input.count or has_error or is_suspended
					loop
						note_position (i)
						if l_input.item (i) = '<' then
							if not a_is_final and then is_incomplete_markup_prefix (l_input, i) then
								i := l_input.count + 1
							else
								i := parse_markup (l_input, i)
							end
						elseif a_is_final then
							i := parse_character_data (l_input, i)
						else
							i := parse_character_data_prefix (l_input, i)
						end
						if not has_error then
							note_position (i)
						end
					variant
						l_input.count - i + 1
					end
					if a_is_final and then not has_error and then not is_suspended then
						if element_stack.count /= 0 then
							set_error ("unclosed element")
						elseif document_element_count = 0 then
							set_error ("missing document element")
						end
					end
					if not has_error and not is_suspended then
						note_position (l_input.count + 1)
					end
					force_current_position
					Result := not has_error and not is_suspended
					if has_error or else (a_is_final and then not is_suspended) then
						clear_cached_doctype
					end
				elseif not l_prepared or else (not has_error and then not is_suspended) then
					if a_is_final then
						Result := parse (a_input)
					else
						Result := parse_prefix (a_input)
					end
				end
			end
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			terminal_storage_released: has_error or else (a_is_final and then not is_suspended) implies cached_doctype_byte_count = 0
		end

	parse_external_entity_prefix (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete tokens available in a non-final external general entity.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			l_input: STRING_8
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= l_input.count + 1
				depth_within_limit: element_stack.count <= max_element_depth
			until
				i > l_input.count or has_error or is_suspended
			loop
				note_position (i)
				if l_input.item (i) = '<' then
					if is_incomplete_markup_prefix (l_input, i) then
						if has_at (l_input, i, "<!DOCTYPE") then
							process_incomplete_doctype_prefix (l_input, i)
						end
						i := l_input.count + 1
					else
						i := parse_markup (l_input, i)
					end
				else
					i := parse_character_data_prefix (l_input, i)
				end
				if not has_error then
					note_position (i)
				end
			variant
				l_input.count - i + 1
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			not_external_after_parse: not parsing_external_entity
		end

	parse_external_entity (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse a complete external parsed entity fragment `a_input'.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			l_input: STRING_8
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			if not has_error then
				if looks_like_external_subset (l_input) then
					process_internal_subset (l_input)
				else
					from
						i := 1
					invariant
						index_in_bounds: i >= 1 and i <= l_input.count + 1
						depth_within_limit: element_stack.count <= max_element_depth
					until
						i > l_input.count or has_error or is_suspended
					loop
						note_position (i)
						if l_input.item (i) = '<' then
							i := parse_markup (l_input, i)
						else
							i := parse_character_data (l_input, i)
						end
						if not has_error then
							note_position (i)
						end
					variant
						l_input.count - i + 1
					end
				end
			end
			if not has_error and not is_suspended and element_stack.count /= 0 then
				note_position (l_input.count + 1)
				set_error ("asynchronous entity")
			end
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			success_is_balanced: Result implies element_stack.count = 0
			not_external_after_parse: not parsing_external_entity
		end

	parse_external_subset (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse a complete external DTD subset or parameter entity fragment.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			l_input: STRING_8
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			if not has_error then
				process_internal_subset (l_input)
			end
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			not_external_after_parse: not parsing_external_entity
		end

	parse_external_subset_prefix (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete DTD declarations available in a non-final external subset prefix.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			l_input: STRING_8
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			process_internal_subset_prefix (l_input)
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			not_external_after_parse: not parsing_external_entity
		end

	incomplete_markup_prefix_start (a_input: READABLE_STRING_8): INTEGER
			-- Start index of the first markup token incomplete at the end of `a_input', or zero.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_end: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
				result_in_bounds: Result >= 0 and Result <= a_input.count
			until
				i > a_input.count or Result /= 0
			loop
				if a_input.item (i) = '<' then
					l_end := markup_prefix_end (a_input, i)
					if l_end = 0 then
						Result := i
						i := a_input.count + 1
					else
						i := l_end + 1
					end
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		ensure
			not_found_or_valid: Result = 0 or else (Result >= 1 and Result <= a_input.count and then a_input.item (Result) = '<')
		end

	markup_prefix_end (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- End index of markup at `a_start_index', or zero if incomplete.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		local
			l_end: INTEGER
		do
			if has_at (a_input, a_start_index, "<!--") then
				l_end := find_sequence (a_input, "-->", a_start_index + 4)
				if l_end > 0 then
					Result := l_end + 2
				end
			elseif has_at (a_input, a_start_index, "<![CDATA[") then
				l_end := find_sequence (a_input, "]]>", a_start_index + 9)
				if l_end > 0 then
					Result := l_end + 2
				end
			elseif has_at (a_input, a_start_index, "<!DOCTYPE") then
				Result := find_doctype_end (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<?") then
				l_end := find_sequence (a_input, "?>", a_start_index + 2)
				if l_end > 0 then
					Result := l_end + 1
				end
			else
				Result := find_markup_declaration_end (a_input, a_start_index)
			end
		ensure
			result_in_bounds: Result >= 0 and Result <= a_input.count
		end

	parse_external_subset_with_context (a_input: READABLE_STRING_8; a_context: detachable READABLE_STRING_8): BOOLEAN
			-- Parse a complete external DTD subset with active entity `a_context', if valid.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			l_input: STRING_8
			l_has_active_context: BOOLEAN
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			if attached a_context as l_context and then not l_context.is_empty and then is_valid_name (l_context) then
				push_entity (l_context)
				l_has_active_context := True
			end
			if not has_error then
				process_internal_subset (l_input)
			end
			if l_has_active_context then
				pop_entity
			end
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			not_external_after_parse: not parsing_external_entity
		end

	parse_external_parameter_literal_with_context (a_input: READABLE_STRING_8; a_context: detachable READABLE_STRING_8): BOOLEAN
			-- Parse an external parameter entity used inside an entity literal.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			l_content_start: INTEGER
			l_input: STRING_8
			l_has_active_context: BOOLEAN
		do
			reset
			parsing_external_entity := True
			l_input := normalized_input (a_input, False)
			position_input := l_input
			note_position (1)
			if attached a_context as l_context and then not l_context.is_empty and then is_valid_name (l_context) then
				push_entity (l_context)
				l_has_active_context := True
			end
			if not has_error then
				if looks_like_external_subset (l_input) then
					process_internal_subset (l_input)
				else
					l_content_start := external_parameter_literal_content_start (l_input)
					if l_content_start <= l_input.count and then is_quote (l_input.item (l_content_start)) then
						note_position (l_content_start)
						set_error ("unterminated literal")
					elseif l_content_start <= l_input.count and then l_input.item (l_content_start) = '$' then
						note_position (l_content_start)
						set_error ("invalid token")
					else
						from
							i := 1
						invariant
							index_in_bounds: i >= 1 and i <= l_input.count + 1
							depth_within_limit: element_stack.count <= max_element_depth
						until
							i > l_input.count or has_error or is_suspended
						loop
							note_position (i)
							if l_input.item (i) = '<' then
								i := parse_markup (l_input, i)
							else
								i := parse_character_data (l_input, i)
							end
							if not has_error then
								note_position (i)
							end
						variant
							l_input.count - i + 1
						end
					end
				end
			end
			if l_has_active_context then
				pop_entity
			end
			if not has_error and not is_suspended and element_stack.count /= 0 then
				note_position (l_input.count + 1)
				set_error ("asynchronous entity")
			end
			if not has_error and not is_suspended then
				note_position (l_input.count + 1)
			end
			Result := not has_error and not is_suspended
			parsing_external_entity := False
		ensure
			result_matches_state: Result = (not has_error and not is_suspended)
			not_external_after_parse: not parsing_external_entity
		end

feature {NONE} -- Garbage collection critical sections

	parse_into_boolean_cell (a_input: READABLE_STRING_8; a_result: CELL [BOOLEAN])
			-- Store `parse (a_input)' in `a_result'.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
			result_attached: a_result /= Void
		do
			a_result.put (parse (a_input))
		ensure
			result_recorded: a_result.item = (not has_error and not is_suspended)
		end

feature {NONE} -- Markup parsing

	parse_markup (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse markup beginning at `a_start_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		do
				-- Private once markers are read-only and never retain document input.
			if has_at (a_input, a_start_index, once "</") then
				Result := parse_end_tag (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, once "<!--") then
				Result := parse_comment (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, once "<![CDATA[") then
				Result := parse_cdata (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, once "<?") then
				Result := parse_processing_instruction (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, once "<!DOCTYPE") then
				Result := parse_doctype (a_input, a_start_index)
			elseif is_incomplete_marker_at_end (a_input, a_start_index, once "<![CDATA[") or else is_incomplete_marker_at_end (a_input, a_start_index, once "<!DOCTYPE") then
				set_error ("unterminated declaration")
				Result := a_input.count + 1
			elseif has_at (a_input, a_start_index, once "<!") then
				if has_at (a_input, a_start_index, once "<![") and then not has_at (a_input, a_start_index, once "<![CD") then
					set_error ("unterminated declaration")
				else
					set_error ("invalid declaration")
				end
				Result := a_input.count + 1
			else
				Result := parse_start_tag (a_input, a_start_index)
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_start_tag (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse a start tag.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		local
			i: INTEGER
			name_start: INTEGER
			name_end: INTEGER
			attribute_start: INTEGER
			l_name: detachable STRING_8
			l_attributes: detachable XP_ATTRIBUTES
			l_empty_element: BOOLEAN
			l_use_slice_stack: BOOLEAN
		do
			i := a_start_index + 1
			if i > a_input.count then
				set_error ("unterminated start tag")
				Result := a_input.count + 1
			elseif is_incomplete_utf8_sequence_at (a_input, i) then
				set_error ("partial character")
				Result := a_input.count + 1
			elseif not is_name_start_character (a_input.item (i)) then
				set_error ("invalid start tag name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				name_end := i - 1
				if i - name_start > max_name_length then
					set_error ("element name exceeds limit")
					Result := a_input.count + 1
				else
					l_use_slice_stack := can_use_element_name_slices
					if not l_use_slice_stack then
						create l_name.make_from_string (a_input.substring (name_start, name_end))
						check attached l_name as l_attached_name then
							if namespace_mode and then not is_valid_qualified_name (l_attached_name) then
								set_error ("invalid namespace name")
								Result := a_input.count + 1
							end
							if not has_error and then element_stack.count = 0 and then document_element_count = 0 and then not parsing_external_entity then
								include_foreign_dtd_if_needed (l_attached_name)
							end
						end
					end
					if not has_error then
						i := skip_spaces (a_input, i)
						attribute_start := i
						if l_use_slice_stack then
							i := parse_attributes_no_events (a_input, i)
							if i = 0 then
								l_use_slice_stack := False
								i := attribute_start
								create l_attributes.make
								if not attached l_name then
									create l_name.make_from_string (a_input.substring (name_start, name_end))
								end
							end
						else
							create l_attributes.make
						end
						if not l_use_slice_stack and not has_error then
							check attached l_attributes as l_attached_attributes then
								from
								invariant
									index_in_bounds: i >= 1 and i <= a_input.count + 1
									attributes_within_limit: l_attached_attributes.count <= max_attribute_count
								until
									has_error or is_suspended or i > a_input.count or else a_input.item (i) = '>' or else a_input.item (i) = '/'
								loop
									if l_attached_attributes.count >= max_attribute_count then
										set_error ("attribute count exceeds limit")
										i := a_input.count + 1
									else
										i := parse_attribute (a_input, i, l_attached_attributes)
										if not has_error then
											i := skip_spaces_between_attributes (a_input, i)
										end
									end
								variant
									a_input.count - i + 1
								end
							end
						end
					end
					if not has_error and not is_suspended then
						if i > a_input.count then
							set_error ("unterminated start tag")
							Result := a_input.count + 1
						elseif a_input.item (i) = '/' then
							if i + 1 <= a_input.count and then a_input.item (i + 1) = '>' then
								l_empty_element := True
								Result := i + 2
							else
								set_error ("invalid empty element terminator")
								Result := a_input.count + 1
							end
						else
							Result := i + 1
						end
					else
						Result := a_input.count + 1
					end
					if not has_error and not is_suspended then
						if handler.wants_start_element_default then
							emit_default_range (a_input, a_start_index, Result - 1)
						end
						note_position (a_start_index)
						if l_use_slice_stack then
							open_element_range (a_input, name_start, name_end)
							if l_empty_element and not has_error and not is_suspended then
								note_position (Result)
								close_element_range (a_input, name_start, name_end)
							end
						else
							check attached l_name as l_attached_name and attached l_attributes as l_attached_attributes then
								open_element (l_attached_name, l_attached_attributes)
								if l_empty_element and not has_error and not is_suspended then
									note_position (Result)
									close_element (l_attached_name)
								end
							end
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_end_tag (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse an end tag.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index < a_input.count
			starts_end_tag: has_at (a_input, a_start_index, "</")
		local
			i: INTEGER
			name_start: INTEGER
			name_end: INTEGER
			l_name: detachable STRING_8
		do
			i := a_start_index + 2
			note_position (i)
			if i > a_input.count or else not is_name_start_character (a_input.item (i)) then
				set_error ("invalid end tag name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				name_end := i - 1
				if i - name_start > max_name_length then
					set_error ("end tag name exceeds limit")
					Result := a_input.count + 1
				else
					if namespace_mode then
						create l_name.make_from_string (a_input.substring (name_start, name_end))
						if not is_valid_qualified_name (l_name) then
							set_error ("invalid namespace name")
							Result := a_input.count + 1
						end
					end
					if not has_error then
						i := skip_spaces (a_input, i)
						if i <= a_input.count and then a_input.item (i) = '>' then
							if element_stack.count > 0 and then open_element_matches_range (a_input, name_start, name_end) then
								note_position (a_start_index)
							else
								note_position (name_start)
							end
							if handler.wants_end_element_default then
								emit_default_range (a_input, a_start_index, i)
							end
							if not namespace_mode and then not handler.wants_end_element_events then
								close_element_range (a_input, name_start, name_end)
							else
								if not attached l_name then
									create l_name.make_from_string (a_input.substring (name_start, name_end))
								end
								check attached l_name as l_attached_name then
									close_element (l_attached_name)
								end
							end
							Result := i + 1
						else
							note_position (i)
							set_error ("unterminated end tag")
							Result := a_input.count + 1
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_attributes_no_events (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse attributes without materializing `XP_ATTRIBUTES', or return zero if unsupported.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
			slice_path_available: can_use_element_name_slices
		local
			i: INTEGER
			l_count: INTEGER
			l_first_name_start: INTEGER
			l_first_name_end: INTEGER
			l_name_starts: detachable ARRAYED_LIST [INTEGER]
			l_name_ends: detachable ARRAYED_LIST [INTEGER]
			l_name_set: detachable XP_ATTRIBUTE_NAME_RANGE_SET
			l_unsupported: BOOLEAN
			l_duplicate: BOOLEAN
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
				count_non_negative: l_count >= 0
			until
				has_error or is_suspended or l_unsupported or i > a_input.count or else a_input.item (i) = '>' or else a_input.item (i) = '/'
			loop
				if l_count >= max_attribute_count then
					set_error ("attribute count exceeds limit")
					i := a_input.count + 1
				else
					i := parse_attribute_no_events (a_input, i)
					if i = 0 then
						l_unsupported := True
						i := a_input.count + 1
					elseif not has_error then
						if l_count = 0 then
							l_first_name_start := last_attribute_name_start
							l_first_name_end := last_attribute_name_end
						else
							if attached l_name_set as l_attached_set then
								l_duplicate := l_attached_set.has_or_insert (a_input, last_attribute_name_start, last_attribute_name_end)
							elseif l_count = 16 and then attached l_name_starts as l_attached_starts and then attached l_name_ends as l_attached_ends then
								create l_name_set.make (a_input, l_first_name_start, l_first_name_end, l_attached_starts, l_attached_ends)
								l_duplicate := l_name_set.has_or_insert (a_input, last_attribute_name_start, last_attribute_name_end)
								-- The table now owns only integer metadata; the small lists can be released.
								l_name_starts := Void
								l_name_ends := Void
							else
								l_duplicate := input_ranges_same (a_input, last_attribute_name_start, last_attribute_name_end, l_first_name_start, l_first_name_end)
								if not l_duplicate and then attached l_name_starts as l_attached_starts and then attached l_name_ends as l_attached_ends then
									l_duplicate := has_attribute_name_range (a_input, last_attribute_name_start, last_attribute_name_end, l_attached_starts, l_attached_ends)
								end
							end
							if l_duplicate then
								set_error ("duplicate attribute")
								i := a_input.count + 1
							elseif l_name_set = Void then
								if not attached l_name_starts then
									create l_name_starts.make (4)
									create l_name_ends.make (4)
								end
								if attached l_name_starts as l_attached_starts and then attached l_name_ends as l_attached_ends then
									l_attached_starts.extend (last_attribute_name_start)
									l_attached_ends.extend (last_attribute_name_end)
								else
									check attribute_name_ranges_available: False end
								end
							end
						end
						if not has_error then
							l_count := l_count + 1
							i := skip_spaces_between_attributes (a_input, i)
						end
					end
				end
			variant
				a_input.count - i + 1
			end
			if l_unsupported then
				Result := 0
			elseif has_error or is_suspended then
				Result := a_input.count + 1
			else
				Result := i
			end
		ensure
			unsupported_or_in_bounds: Result = 0 or else (Result >= a_start_index and Result <= a_input.count + 1)
		end

	parse_attribute_no_events (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse one simple attribute without materializing name/value strings, or return zero if unsupported.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			name_start: INTEGER
			name_end: INTEGER
			l_quote: CHARACTER_8
			l_unsupported: BOOLEAN
			c: CHARACTER_8
			l_code: INTEGER
		do
			i := a_start_index
			if not is_name_start_character (a_input.item (i)) then
				set_error ("invalid attribute name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				name_end := i - 1
				i := skip_spaces (a_input, i)
				if i > a_input.count or else a_input.item (i) /= '=' then
					set_error ("missing attribute equals")
					Result := a_input.count + 1
				else
					i := skip_spaces (a_input, i + 1)
					if i > a_input.count or else not is_quote (a_input.item (i)) then
						set_error ("missing attribute quote")
						Result := a_input.count + 1
					else
						l_quote := a_input.item (i)
						from
							i := i + 1
						invariant
							index_in_bounds: i >= 1 and i <= a_input.count + 1
						until
							i > a_input.count or has_error or l_unsupported or else a_input.item (i) = l_quote
						loop
							c := a_input.item (i)
							l_code := c.code
							if c = '<' then
								set_error ("left angle bracket in attribute value")
								i := a_input.count + 1
							elseif c = '&' then
								l_unsupported := True
								i := a_input.count + 1
							elseif (l_code >= 32 and l_code < 128) or else l_code = 9 or else l_code = 10 then
								i := i + 1
							elseif l_code < 128 then
								set_error ("invalid XML character")
								i := a_input.count + 1
							elseif is_incomplete_utf8_sequence_at (a_input, i) then
								set_error ("partial character")
								i := a_input.count + 1
							elseif not is_xml_character_code (l_code) then
								set_error ("invalid XML character")
								i := a_input.count + 1
							else
								i := i + 1
							end
						variant
							a_input.count - i + 1
						end
						if l_unsupported then
							Result := 0
						elseif has_error then
							Result := a_input.count + 1
						elseif i > a_input.count then
							set_error ("unterminated attribute value")
							Result := a_input.count + 1
						else
							last_attribute_name_start := name_start
							last_attribute_name_end := name_end
							Result := i + 1
						end
					end
				end
			end
		ensure
			unsupported_or_progress_or_error: Result = 0 or else Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	skip_spaces_between_attributes (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Index after the spaces following an attribute value; another attribute needs at least one space.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		do
			Result := skip_spaces (a_input, a_start_index)
			if
				Result = a_start_index and then Result <= a_input.count
				and then a_input.item (Result) /= '>' and then a_input.item (Result) /= '/'
			then
				set_error ("missing space between attributes")
				Result := a_input.count + 1
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_input.count + 1
		end

	has_attribute_name_range (a_input: READABLE_STRING_8; a_name_start, a_name_end: INTEGER; a_name_starts, a_name_ends: ARRAYED_LIST [INTEGER]): BOOLEAN
			-- Do stored attribute name ranges contain `a_input [a_name_start..a_name_end]'?
		require
			input_attached: a_input /= Void
			valid_start: a_name_start >= 1 and a_name_start <= a_input.count
			valid_end: a_name_end >= a_name_start and a_name_end <= a_input.count
			starts_attached: a_name_starts /= Void
			ends_attached: a_name_ends /= Void
			ranges_aligned: a_name_starts.count = a_name_ends.count
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_name_starts.count + 1
			until
				i > a_name_starts.count or Result
			loop
				if input_ranges_same (a_input, a_name_start, a_name_end, a_name_starts.i_th (i), a_name_ends.i_th (i)) then
					Result := True
					i := a_name_starts.count + 1
				else
					i := i + 1
				end
			variant
				a_name_starts.count - i + 1
			end
		end

	parse_attribute (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_attributes: XP_ATTRIBUTES): INTEGER
			-- Parse one attribute beginning at `a_start_index'.
		require
			input_attached: a_input /= Void
			attributes_attached: a_attributes /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			space_available: a_attributes.count < max_attribute_count
		local
			i: INTEGER
			name_start: INTEGER
			l_quote: CHARACTER_8
			l_name: STRING_8
			l_value: STRING_8
		do
			i := a_start_index
			if not a_attributes.is_name_start_character (a_input.item (i)) then
				set_error ("invalid attribute name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				create l_name.make_from_string (a_input.substring (name_start, i - 1))
				if namespace_mode and then not is_valid_qualified_name (l_name) then
					set_error ("invalid namespace name")
					Result := a_input.count + 1
				else
					i := skip_spaces (a_input, i)
					if i > a_input.count or else a_input.item (i) /= '=' then
					set_error ("missing attribute equals")
					Result := a_input.count + 1
					else
						i := skip_spaces (a_input, i + 1)
						if i > a_input.count or else not is_quote (a_input.item (i)) then
							set_error ("missing attribute quote")
							Result := a_input.count + 1
						else
							l_quote := a_input.item (i)
							create l_value.make_empty
							i := parse_attribute_value (a_input, i + 1, l_quote, l_value)
							if not has_error then
								if a_attributes.has_string (l_name) then
									set_error ("duplicate attribute")
									Result := a_input.count + 1
								else
									a_attributes.put_owned (l_name, l_value)
									Result := i + 1
								end
							else
								Result := a_input.count + 1
							end
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_attribute_value (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_quote: CHARACTER_8; a_value: STRING_8): INTEGER
			-- Parse and normalize attribute value content until `a_quote'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
			quote_valid: is_quote (a_quote)
			value_attached: a_value /= Void
		local
			i: INTEGER
			c: CHARACTER_8
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or has_error or else a_input.item (i) = a_quote
			loop
				c := a_input.item (i)
				if c = '<' then
					set_error ("left angle bracket in attribute value")
					i := a_input.count + 1
				elseif c = '&' then
					i := append_reference_in_literal (a_input, i, a_value)
				elseif is_incomplete_utf8_sequence_at (a_input, i) then
					set_error ("partial character")
					i := a_input.count + 1
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					if is_xml_space (c) then
						a_value.append_character (' ')
					else
						a_value.append_character (c)
					end
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
			if not has_error then
				if i > a_input.count then
					set_error ("unterminated attribute value")
					Result := a_input.count + 1
				else
					Result := i
				end
			else
				Result := a_input.count + 1
			end
		ensure
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_comment (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse an XML comment.
		require
			input_attached: a_input /= Void
			starts_comment: has_at (a_input, a_start_index, "<!--")
		local
			l_end: INTEGER
			i: INTEGER
			l_text: STRING_8
		do
			l_end := find_sequence (a_input, "-->", a_start_index + 4)
			if l_end = 0 then
				set_error ("unterminated comment")
				Result := a_input.count + 1
			elseif l_end - a_start_index > max_token_length then
				set_error ("comment token exceeds limit")
				Result := a_input.count + 1
			else
				from
					i := a_start_index + 4
				invariant
					index_in_bounds: i >= a_start_index + 4 and i <= l_end + 1
				until
					i >= l_end or has_error
				loop
						-- At `l_end - 1' this also rejects a comment ending in '-' ("--->").
					if has_at (a_input, i, "--") then
						set_error ("double hyphen in comment")
						i := l_end
					elseif not is_xml_character_code (a_input.item (i).code) then
						set_error ("invalid XML character")
						i := l_end
					else
						i := i + 1
					end
				variant
					l_end - i
				end
				if has_error then
					Result := a_input.count + 1
				else
					create l_text.make_from_string (a_input.substring (a_start_index + 4, l_end - 1))
					if handler.wants_comment_default then
						emit_default (a_input.substring (a_start_index, l_end + 2))
					end
					note_token_position (a_start_index, l_end + 3 - a_start_index)
					handler.on_comment (l_text)
					check_handler_stop
					Result := l_end + 3
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_cdata (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse a CDATA section.
		require
			input_attached: a_input /= Void
			starts_cdata: has_at (a_input, a_start_index, "<![CDATA[")
		local
			l_end: INTEGER
			l_text: STRING_8
		do
			if element_stack.count = 0 and then not parsing_external_entity then
				set_error ("CDATA outside document element")
				Result := a_input.count + 1
			else
				l_end := find_sequence (a_input, "]]>", a_start_index + 9)
				if l_end = 0 then
					set_error ("unterminated CDATA section")
					Result := a_input.count + 1
				elseif l_end - (a_start_index + 9) > max_token_length then
					set_error ("CDATA token exceeds limit")
					Result := a_input.count + 1
				else
					if handler.wants_start_cdata_default then
						emit_default ("<![CDATA[")
					end
					note_position (a_start_index)
					handler.on_start_cdata_section
					check_handler_stop
					if not is_suspended and then l_end > a_start_index + 9 then
						create l_text.make_from_string (a_input.substring (a_start_index + 9, l_end - 1))
						validate_xml_text (l_text)
						if not has_error then
							note_token_position (a_start_index + 9, l_text.count)
							emit_text (l_text)
							if not has_error and not is_suspended and then handler.wants_automatic_character_data_default then
								emit_default (l_text)
							end
						end
					end
					if not has_error and not is_suspended then
						if handler.wants_end_cdata_default then
							emit_default ("]]>")
						end
						note_position (l_end + 3)
						handler.on_end_cdata_section
						check_handler_stop
					end
					if has_error then
						Result := a_input.count + 1
					else
						Result := l_end + 3
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_processing_instruction (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse processing instruction or XML declaration.
		require
			input_attached: a_input /= Void
			starts_pi: has_at (a_input, a_start_index, "<?")
		local
			l_end: INTEGER
			i: INTEGER
			name_start: INTEGER
			l_target: STRING_8
			l_data: STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			l_end := find_sequence (a_input, "?>", a_start_index + 2)
			if l_end = 0 then
				set_error ("unterminated processing instruction")
				Result := a_input.count + 1
			elseif l_end - a_start_index > max_token_length then
				set_error ("processing instruction exceeds limit")
				Result := a_input.count + 1
			else
				i := a_start_index + 2
				if i > a_input.count or else not l_attributes.is_name_start_character (a_input.item (i)) then
					set_error ("invalid processing instruction target")
					Result := a_input.count + 1
				else
					name_start := i
					i := scan_name (a_input, i)
					create l_target.make_from_string (a_input.substring (name_start, i - 1))
					if has_error then
						Result := a_input.count + 1
					elseif same_name_case_insensitive (l_target, "xml") and then not l_target.same_string ("xml") then
						set_error ("reserved processing instruction target")
						Result := a_input.count + 1
					elseif l_target.same_string ("xml") and then a_start_index /= 1 then
						set_error ("misplaced xml declaration")
						Result := a_input.count + 1
					elseif i < l_end and then not is_xml_space (a_input.item (i)) then
						set_error ("missing space after processing instruction target")
						Result := a_input.count + 1
					elseif namespace_mode and then l_target.has (':') then
						set_error ("colon in processing instruction target")
						Result := a_input.count + 1
					else
						create l_data.make_empty
						if same_name_case_insensitive (l_target, "xml") then
							if i < l_end and then is_xml_space (a_input.item (i)) then
								i := skip_spaces (a_input, i)
							end
							if i <= l_end - 1 then
								l_data.append (a_input.substring (i, l_end - 1))
							end
							parse_xml_declaration_data (l_data)
							if not has_error and not is_suspended and then handler.wants_xml_declaration_default then
								emit_default_range (a_input, a_start_index, l_end + 1)
							end
						else
							if i < l_end and then is_xml_space (a_input.item (i)) then
								i := skip_spaces (a_input, i)
							end
							if i <= l_end - 1 then
								l_data.append (a_input.substring (i, l_end - 1))
							end
							if handler.wants_processing_instruction_default then
								emit_default (a_input.substring (a_start_index, l_end + 1))
							end
							note_token_position (a_start_index, l_end + 2 - a_start_index)
							handler.on_processing_instruction (l_target, l_data)
							check_handler_stop
						end
						Result := l_end + 2
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_xml_declaration_data (a_data: READABLE_STRING_8)
			-- Parse attributes in an XML declaration and emit the declaration event.
		require
			data_attached: a_data /= Void
		local
			i: INTEGER
			name_start: INTEGER
			value_start: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_version: STRING_8
			l_encoding: STRING_8
			l_standalone: INTEGER
			l_quote: CHARACTER_8
			l_attributes: XP_ATTRIBUTES
			l_previous_order: INTEGER
			l_current_order: INTEGER
			l_needs_space: BOOLEAN
		do
			create l_attributes.make
			create l_version.make_empty
			create l_encoding.make_empty
			l_standalone := -1
			l_needs_space := False
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_data.count + 1
			until
				i > a_data.count or has_error
			loop
				if l_needs_space then
					if i <= a_data.count and then not is_xml_space (a_data.item (i)) then
						set_error ("invalid xml declaration")
						i := a_data.count + 1
					else
						i := skip_spaces (a_data, i)
					end
				else
					i := skip_spaces (a_data, i)
				end
				if i <= a_data.count then
					if not l_attributes.is_name_start_character (a_data.item (i)) then
						set_error ("invalid xml declaration")
						i := a_data.count + 1
					else
						name_start := i
						i := scan_name (a_data, i)
						create l_name.make_from_string (a_data.substring (name_start, i - 1))
						i := skip_spaces (a_data, i)
						if i > a_data.count or else a_data.item (i) /= '=' then
							set_error ("invalid xml declaration")
							i := a_data.count + 1
						else
							i := skip_spaces (a_data, i + 1)
							if i > a_data.count or else not is_quote (a_data.item (i)) then
								set_error ("invalid xml declaration")
								i := a_data.count + 1
							else
								l_quote := a_data.item (i)
								value_start := i + 1
								i := find_character (a_data, l_quote, value_start)
								if i = 0 then
									set_error ("invalid xml declaration")
									i := a_data.count + 1
								else
									create l_value.make_from_string (a_data.substring (value_start, i - 1))
									if l_attributes.has (l_name) then
										set_error ("invalid xml declaration")
									elseif l_name.same_string ("version") then
										l_current_order := 1
										if l_previous_order /= 0 or else not is_valid_version_number (l_value) then
											set_error ("invalid xml declaration")
										end
										l_version.wipe_out
										l_version.append (l_value)
									elseif l_name.same_string ("encoding") then
										l_current_order := 2
										if
											(not parsing_external_entity and then l_previous_order = 0)
											or else l_previous_order >= l_current_order
											or else not is_valid_encoding_name (l_value)
										then
											set_error ("invalid xml declaration")
										end
										l_encoding.wipe_out
										l_encoding.append (l_value)
									elseif l_name.same_string ("standalone") then
										l_current_order := 3
										if parsing_external_entity or else l_previous_order = 0 or else l_previous_order >= l_current_order then
											set_error ("invalid xml declaration")
										end
										if l_value.same_string ("yes") then
											l_standalone := 1
										elseif l_value.same_string ("no") then
											l_standalone := 0
										else
											set_error ("invalid xml declaration")
										end
									else
										set_error ("invalid xml declaration")
									end
									if not has_error then
										l_attributes.put (l_name, l_value)
										l_previous_order := l_current_order
										l_needs_space := True
									end
									i := i + 1
								end
							end
						end
					end
				end
			variant
				a_data.count - i + 1
			end
			if not has_error then
				if l_version.is_empty and then not (parsing_external_entity and then not l_encoding.is_empty) then
					set_error ("invalid xml declaration")
				else
					xml_standalone := l_standalone
					handler.on_xml_declaration (l_version, l_encoding, l_standalone)
					check_handler_stop
				end
			end
		end

	parse_doctype (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse document type declaration and internal entity declarations.
		require
			input_attached: a_input /= Void
			starts_doctype: has_at (a_input, a_start_index, "<!DOCTYPE")
		local
			i: INTEGER
			name_start: INTEGER
			l_end: INTEGER
			l_subset_start: INTEGER
			l_subset_end: INTEGER
			l_external_end: INTEGER
			l_subset: STRING_8
			l_public_id: STRING_8
			l_system_id: STRING_8
			l_event_public_id: detachable READABLE_STRING_8
			l_event_system_id: detachable READABLE_STRING_8
			l_has_external_subset: BOOLEAN
			l_has_internal_subset: BOOLEAN
			l_name_end: INTEGER
			l_attributes: XP_ATTRIBUTES
			l_previous_subset_offset: INTEGER
		do
			create l_attributes.make
			create l_public_id.make_empty
			create l_system_id.make_empty
			if has_doctype or document_element_count > 0 or element_stack.count > 0 then
				set_error ("doctype not allowed here")
				Result := a_input.count + 1
			else
				l_end := find_doctype_end (a_input, a_start_index)
				if l_end = 0 then
					process_incomplete_doctype_prefix (a_input, a_start_index)
					if not has_error and not is_suspended then
						set_error ("unterminated doctype")
					end
					Result := a_input.count + 1
				elseif l_end - a_start_index > max_token_length then
					set_error ("doctype token exceeds limit")
					Result := a_input.count + 1
				else
					i := skip_required_spaces (a_input, a_start_index + 9, "missing space after DOCTYPE")
					if has_error or else i > a_input.count or else not l_attributes.is_name_start_character (a_input.item (i)) then
						set_error ("invalid doctype name")
						Result := a_input.count + 1
					else
						name_start := i
						i := scan_name (a_input, i)
						l_name_end := i - 1
						doctype_name.wipe_out
						doctype_name.append (a_input.substring (name_start, l_name_end))
						if namespace_mode and then not is_valid_qualified_name (doctype_name) then
							if has_multiple_colons (doctype_name) then
								set_error ("namespace syntax")
							else
								set_error ("invalid namespace name")
							end
						else
							has_doctype := True
						end
						l_subset_start := find_unquoted_character (a_input, '[', i, l_end)
						if not has_error and then l_subset_start > 0 then
							l_external_end := l_subset_start
						else
							l_external_end := l_end
						end
						if not has_error and then skip_spaces (a_input, i) < l_external_end and then skip_spaces (a_input, i) = i then
							set_error ("missing space before doctype external identifier")
						end
						i := skip_spaces (a_input, i)
						if not has_error and then i < l_external_end then
							if has_keyword_at (a_input, i, "SYSTEM") then
								l_has_external_subset := True
								i := skip_spaces_before_literal (a_input, i + 6, "missing space after SYSTEM")
								if not has_error and then i < l_external_end and then is_quote (a_input.item (i)) then
									i := read_quoted_literal (a_input, i, l_external_end, l_system_id)
								else
									set_error ("missing external system identifier")
								end
							elseif has_keyword_at (a_input, i, "PUBLIC") then
								l_has_external_subset := True
								i := skip_spaces_before_literal (a_input, i + 6, "missing space after PUBLIC")
								if not has_error and then i < l_external_end and then is_quote (a_input.item (i)) then
									i := read_public_id_literal (a_input, i, l_external_end, l_public_id)
									if not has_error then
										i := skip_spaces_before_literal (a_input, i, "missing space between public and system identifiers")
										if not has_error and then i < l_external_end and then is_quote (a_input.item (i)) then
											i := read_quoted_literal (a_input, i, l_external_end, l_system_id)
										else
											set_error ("missing external system identifier")
										end
									end
								else
									set_error ("missing external public identifier")
								end
							else
								set_error ("invalid doctype external identifier")
							end
							if not has_error then
								i := skip_spaces (a_input, i)
								if i /= l_external_end then
									set_error ("unexpected doctype declaration content")
								end
							end
						end
						if l_subset_start > 0 then
							l_has_internal_subset := True
						end
						if not has_error and then handler.wants_start_doctype_default then
							emit_doctype_default_open (a_input, a_start_index, name_start, l_name_end, l_subset_start, l_end)
						end
						if not has_error and not is_suspended then
							if not l_public_id.is_empty then
								l_event_public_id := l_public_id
							end
							if not l_system_id.is_empty then
								l_event_system_id := l_system_id
							end
							document_has_external_subset := l_has_external_subset
							if l_has_external_subset then
								check_not_standalone
							end
							if not has_error then
								handler.on_start_doctype_decl (doctype_name, l_event_system_id, l_event_public_id, l_has_internal_subset)
								check_handler_stop
							end
						end
						if not has_error and not is_suspended and then l_subset_start > 0 then
							l_subset_end := find_subset_end (a_input, l_subset_start + 1, l_end)
							if l_subset_end = 0 then
								set_error ("unterminated internal subset")
							elseif skip_spaces (a_input, l_subset_end + 1) /= l_end then
								set_error ("unexpected content after internal subset")
							else
								create l_subset.make_from_string (a_input.substring (l_subset_start + 1, l_subset_end - 1))
								l_previous_subset_offset := dtd_subset_position_offset
								dtd_subset_position_offset := l_subset_start
								process_internal_subset (l_subset)
								dtd_subset_position_offset := l_previous_subset_offset
							end
						end
						if not has_error and not is_suspended and l_has_external_subset then
							include_external_subset (l_public_id, l_system_id)
						end
						if not has_error and not is_suspended and then handler.wants_end_doctype_default then
							emit_doctype_default_close (l_has_internal_subset)
						end
						if has_error then
							Result := a_input.count + 1
						else
							if not is_suspended then
								handler.on_end_doctype_decl
								check_handler_stop
							end
							Result := l_end + 1
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

feature {NONE} -- Character data and references

	process_incomplete_doctype_prefix (a_input: READABLE_STRING_8; a_start_index: INTEGER)
			-- Process complete declarations before an internal subset's outer ]> arrives.
		local
			i, l_subset_start, l_subset_end, l_name_start, l_name_end, l_previous_offset: INTEGER
			l_subset: STRING_8
		do
			if a_start_index + 9 <= a_input.count then
				l_subset_start := find_unquoted_character (a_input, '[', a_start_index + 9, a_input.count)
				if l_subset_start > 0 then
					i := skip_spaces (a_input, a_start_index + 9)
					if i > a_start_index + 9 and then i < l_subset_start and then is_name_start_character (a_input.item (i)) then
						l_name_start := i
						i := scan_name (a_input, i)
						l_name_end := i - 1
						if not has_error and then skip_spaces (a_input, i) = l_subset_start then
							has_doctype := True
							doctype_name := a_input.substring (l_name_start, l_name_end).to_string_8
							if handler.wants_start_doctype_default then
								emit_doctype_default_open (a_input, a_start_index, l_name_start, l_name_end, l_subset_start, a_input.count)
							end
							if not has_error and not is_suspended then
								handler.on_start_doctype_decl (doctype_name, Void, Void, True)
								check_handler_stop
							end
							if not has_error and not is_suspended then
								l_subset_end := 0
								if l_subset_start < a_input.count then
									l_subset_end := find_subset_end (a_input, l_subset_start + 1, a_input.count)
								end
								if l_subset_end = 0 then
									l_subset_end := a_input.count + 1
								end
								l_subset := a_input.substring (l_subset_start + 1, l_subset_end - 1).to_string_8
								l_previous_offset := dtd_subset_position_offset
								dtd_subset_position_offset := l_subset_start
								process_internal_subset_prefix (l_subset)
								dtd_subset_position_offset := l_previous_offset
							end
						end
					end
				end
			end
		end

	parse_character_data (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse character data until next markup delimiter.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			not_markup: a_input.item (a_start_index) /= '<'
		local
			i: INTEGER
			c: CHARACTER_8
			l_text: detachable STRING_8
			l_materialize_text: BOOLEAN
			l_literal_default: BOOLEAN
			l_default_start, l_default_end, l_reference_end: INTEGER
			l_all_space: BOOLEAN
			l_pending_literal_position: INTEGER
		do
			l_materialize_text := handler.wants_character_data_events or else handler.wants_default_events or else handler.wants_automatic_character_data_default
			l_literal_default := handler.wants_automatic_character_data_default and then handler.wants_literal_character_data_default
			l_default_start := a_start_index
			l_default_end := a_start_index - 1
			if lazy_position_accounting and then not l_materialize_text then
				Result := parse_character_data_no_events (a_input, a_start_index)
			end
			if Result = 0 then
				force_current_position
				if l_materialize_text then
					create l_text.make_empty
				end
				l_all_space := True
				from
					i := a_start_index
				invariant
					index_in_bounds: i >= a_start_index and i <= a_input.count + 1
				until
					i > a_input.count or has_error or is_suspended or else a_input.item (i) = '<'
				loop
					c := a_input.item (i)
					if c = ']' then
						note_position (i)
						l_pending_literal_position := 0
					end
					-- The fixed marker is read-only; ordinary bytes need no prefix check.
					if c = ']' and then has_at (a_input, i, once "]]>") then
						set_error ("CDATA close marker in character data")
						i := a_input.count + 1
					elseif c = '&' then
						note_position (i)
						l_pending_literal_position := 0
						if element_stack.count = 0 and then not parsing_external_entity then
							set_error ("entity reference outside document element")
							i := a_input.count + 1
						else
							if not attached l_text then
								create l_text.make_empty
								if l_materialize_text and then i > a_start_index then
									l_text.append (a_input.substring (a_start_index, i - 1))
								end
							end
							check attached l_text as l_attached_text then
								l_reference_end := find_character (a_input, ';', i + 1)
								if l_literal_default and then l_reference_end > i + 1 and then a_input.item (i + 1) /= '#' and then not is_predefined_entity (a_input.substring (i + 1, l_reference_end - 1)) then
									emit_default_range (a_input, l_default_start, i - 1)
									if not has_error and not is_suspended then
										i := append_reference_in_content (a_input, i, l_attached_text)
										l_default_start := i
									end
								else
									i := append_reference_in_content (a_input, i, l_attached_text)
								end
								l_default_end := i - 1
							end
						end
					elseif c.code >= 128 and then is_incomplete_utf8_sequence_at (a_input, i) then
						note_position (i)
						l_pending_literal_position := 0
						set_error ("partial character")
						i := a_input.count + 1
					elseif not is_xml_character_code (c.code) then
						note_position (i)
						l_pending_literal_position := 0
						set_error ("invalid XML character")
						i := a_input.count + 1
					else
						if l_all_space then
							l_all_space := is_xml_space (c)
						end
						if attached l_text as l_attached_text then
							-- Appending may allocate; preserve its exception-time position.
							note_position (i)
							l_pending_literal_position := 0
							l_attached_text.append_character (c)
						else
							l_pending_literal_position := i
						end
						i := i + 1
						l_default_end := i - 1
					end
				variant
					a_input.count - i + 1
				end
				if l_pending_literal_position > 0 then
					-- Included entity text has no surrounding position commit.
					note_position (l_pending_literal_position)
				end
				if not has_error and not is_suspended then
					if element_stack.count = 0 and then not parsing_external_entity then
						if not attached l_text and l_materialize_text then
							create l_text.make_from_string (a_input.substring (a_start_index, i - 1))
						end
						if attached l_text as l_attached_text then
							l_all_space := is_all_xml_space (l_attached_text)
						end
						if not l_all_space then
							set_error ("character data outside document element")
							Result := a_input.count + 1
						else
							if attached l_text as l_attached_text then
								emit_default (l_attached_text)
							end
							Result := i
						end
					else
						if not attached l_text and l_materialize_text then
							create l_text.make_from_string (a_input.substring (a_start_index, i - 1))
						end
						if attached l_text as l_attached_text then
							if handler.wants_automatic_character_data_default then
								if l_literal_default then
									emit_default_range (a_input, l_default_start, l_default_end)
								else
									emit_default (l_attached_text)
								end
							end
							if entity_reference_count_stack.count > 0 then
								note_token_position (entity_reference_start_stack.i_th (entity_reference_start_stack.count), entity_reference_count_stack.i_th (entity_reference_count_stack.count))
							else
								note_token_position (a_start_index, l_attached_text.count)
							end
							emit_text (l_attached_text)
						end
						Result := i
					end
				else
					Result := a_input.count + 1
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_character_data_no_events (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse no-callback character data, or return zero when entity expansion is needed.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			not_markup: a_input.item (a_start_index) /= '<'
			lazy_positions_enabled: lazy_position_accounting
		local
			i: INTEGER
			c: CHARACTER_8
			l_outside_document: BOOLEAN
			l_all_space: BOOLEAN
			l_fallback: BOOLEAN
			l_code: INTEGER
		do
			l_outside_document := element_stack.count = 0 and then not parsing_external_entity
			l_all_space := True
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or has_error or is_suspended or l_fallback or else a_input.item (i) = '<'
			loop
				c := a_input.item (i)
				l_code := c.code
				if c = '&' then
					l_fallback := True
					i := a_input.count + 1
				elseif c = ']' and then has_at (a_input, i, once "]]>") then
					note_position (i)
					set_error ("CDATA close marker in character data")
					i := a_input.count + 1
				elseif (l_code >= 32 and l_code < 128) or else l_code = 9 or else l_code = 10 then
					if l_outside_document and then l_all_space then
						l_all_space := is_xml_space_ascii (c)
						if not l_all_space then
							note_position (i)
							set_error ("character data outside document element")
							i := a_input.count + 1
						else
							i := i + 1
						end
					else
						i := i + 1
					end
				elseif l_code < 128 then
					note_position (i)
					set_error ("invalid XML character")
					i := a_input.count + 1
				elseif c.code >= 128 and then is_incomplete_utf8_sequence_at (a_input, i) then
					note_position (i)
					set_error ("partial character")
					i := a_input.count + 1
				elseif not is_xml_character_code (l_code) then
					note_position (i)
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					if l_outside_document and then l_all_space then
						l_all_space := is_xml_space (c)
						if not l_all_space then
							note_position (i)
							set_error ("character data outside document element")
							i := a_input.count + 1
						else
							i := i + 1
						end
					else
						i := i + 1
					end
				end
			variant
				a_input.count - i + 1
			end
			if l_fallback then
				Result := 0
			elseif has_error or is_suspended then
				Result := a_input.count + 1
			else
				Result := i
			end
		ensure
			fallback_or_progress_or_error: Result = 0 or else Result > a_start_index or has_error
			result_in_bounds: Result >= 0 and Result <= a_input.count + 1
		end

	parse_character_data_prefix (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse character data in a non-final prefix, stopping before incomplete references.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			not_markup: a_input.item (a_start_index) /= '<'
		local
			i: INTEGER
			c: CHARACTER_8
			l_text: detachable STRING_8
			l_materialize_text: BOOLEAN
			l_literal_default: BOOLEAN
			l_default_start, l_default_end, l_reference_end: INTEGER
			l_all_space: BOOLEAN
			l_pending_literal_position: INTEGER
			l_done: BOOLEAN
		do
			l_materialize_text := handler.wants_character_data_events or else handler.wants_default_events or else handler.wants_automatic_character_data_default
			l_literal_default := handler.wants_automatic_character_data_default and then handler.wants_literal_character_data_default
			l_default_start := a_start_index
			l_default_end := a_start_index - 1
			if l_materialize_text then
				create l_text.make_empty
			end
			l_all_space := True
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or l_done or has_error or is_suspended or else a_input.item (i) = '<'
			loop
				c := a_input.item (i)
				if c = ']' then
					note_position (i)
					l_pending_literal_position := 0
				end
				if c = ']' and then has_at (a_input, i, once "]]>") then
					set_error ("CDATA close marker in character data")
					i := a_input.count + 1
				elseif c = '&' then
					note_position (i)
					l_pending_literal_position := 0
					if find_character (a_input, ';', i + 1) = 0 then
						l_done := True
						i := a_input.count + 1
					elseif element_stack.count = 0 and then not parsing_external_entity then
						set_error ("entity reference outside document element")
						i := a_input.count + 1
					else
						if not attached l_text then
							create l_text.make_empty
						end
						check attached l_text as l_attached_text then
							l_reference_end := find_character (a_input, ';', i + 1)
							if l_literal_default and then l_reference_end > i + 1 and then a_input.item (i + 1) /= '#' and then not is_predefined_entity (a_input.substring (i + 1, l_reference_end - 1)) then
								emit_default_range (a_input, l_default_start, i - 1)
								if not has_error and not is_suspended then
									i := append_reference_in_content (a_input, i, l_attached_text)
									l_default_start := i
								end
							else
								i := append_reference_in_content (a_input, i, l_attached_text)
							end
							l_default_end := i - 1
						end
					end
				elseif c.code >= 128 and then is_incomplete_utf8_sequence_at (a_input, i) then
					note_position (i)
					l_pending_literal_position := 0
					l_done := True
					i := a_input.count + 1
				elseif not is_xml_character_code (c.code) then
					note_position (i)
					l_pending_literal_position := 0
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					if l_all_space then
						l_all_space := is_xml_space (c)
					end
					if attached l_text as l_attached_text then
						-- Appending may allocate; preserve its exception-time position.
						note_position (i)
						l_pending_literal_position := 0
						l_attached_text.append_character (c)
					else
						l_pending_literal_position := i
					end
					i := i + 1
					l_default_end := i - 1
				end
			variant
				a_input.count - i + 1
			end
			if l_pending_literal_position > 0 then
				-- Included entity text has no surrounding position commit.
				note_position (l_pending_literal_position)
			end
			if not has_error and not is_suspended then
				if element_stack.count = 0 and then not parsing_external_entity then
					if attached l_text as l_attached_text then
						l_all_space := is_all_xml_space (l_attached_text)
					end
					if not l_all_space then
						set_error ("character data outside document element")
						Result := a_input.count + 1
					else
						if attached l_text as l_attached_text then
							emit_default (l_attached_text)
						end
						Result := i
					end
				else
					if attached l_text as l_attached_text then
						if handler.wants_automatic_character_data_default then
							if l_literal_default then
								emit_default_range (a_input, l_default_start, l_default_end)
							else
								emit_default (l_attached_text)
							end
						end
						if entity_reference_count_stack.count > 0 then
							note_token_position (entity_reference_start_stack.i_th (entity_reference_start_stack.count), entity_reference_count_stack.i_th (entity_reference_count_stack.count))
						else
							note_token_position (a_start_index, l_attached_text.count)
						end
						emit_text (l_attached_text)
					end
					Result := i
				end
			else
				Result := a_input.count + 1
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	append_reference_in_content (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_text: STRING_8): INTEGER
			-- Expand a reference in element content.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_reference: a_input.item (a_start_index) = '&'
			text_attached: a_text /= Void
		local
			l_end: INTEGER
			l_name: STRING_8
		do
			l_end := find_character (a_input, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated reference")
				Result := a_input.count + 1
			elseif a_start_index + 1 >= l_end then
				set_error ("empty reference")
				Result := a_input.count + 1
			elseif a_input.item (a_start_index + 1) = '#' then
				append_character_reference (a_input.substring (a_start_index + 2, l_end - 1), a_text)
				Result := l_end + 1
			else
				create l_name.make_from_string (a_input.substring (a_start_index + 1, l_end - 1))
				if not is_valid_name (l_name) then
					set_error ("invalid entity name")
					Result := a_input.count + 1
				elseif is_predefined_entity (l_name) then
					append_predefined_entity (l_name, a_text)
					Result := l_end + 1
				else
					if a_text.count > 0 then
						emit_text (a_text)
						a_text.wipe_out
					end
					if handler.expands_internal_general_entity_references then
						push_entity_reference_position (a_start_index, l_end - a_start_index + 1)
						include_general_entity_in_content (l_name)
						pop_entity_reference_position
						if has_error then
							Result := a_input.count + 1
						else
							Result := l_end + 1
						end
					else
						if handler.reports_skipped_internal_general_entities then
							handler.on_skipped_entity (l_name, False)
							check_handler_stop
						else
							emit_default (a_input.substring (a_start_index, l_end))
						end
						Result := l_end + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	append_reference_in_literal (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_text: STRING_8): INTEGER
			-- Expand a reference in an attribute value or entity literal.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_reference: a_input.item (a_start_index) = '&'
			text_attached: a_text /= Void
		local
			l_end: INTEGER
			l_name: STRING_8
		do
			l_end := find_character (a_input, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated reference")
				Result := a_input.count + 1
			elseif a_start_index + 1 >= l_end then
				set_error ("empty reference")
				Result := a_input.count + 1
			elseif a_input.item (a_start_index + 1) = '#' then
				append_character_reference (a_input.substring (a_start_index + 2, l_end - 1), a_text)
				Result := l_end + 1
			else
				create l_name.make_from_string (a_input.substring (a_start_index + 1, l_end - 1))
				if not is_valid_name (l_name) then
					set_error ("invalid entity name")
					Result := a_input.count + 1
				elseif is_predefined_entity (l_name) then
					append_predefined_entity (l_name, a_text)
					Result := l_end + 1
				else
					include_general_entity_in_literal (l_name, a_text)
					if has_error then
						Result := a_input.count + 1
					else
						Result := l_end + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	single_entity_reference_name (a_value: READABLE_STRING_8; a_marker: CHARACTER_8): detachable STRING_8
			-- Name when the entire replacement is one reference, otherwise Void.
		local
			l_name: STRING_8
		do
			if a_value.count > 2 and then a_value.item (1) = a_marker and then a_value.item (a_value.count) = ';' then
				create l_name.make_from_string (a_value.substring (2, a_value.count - 1))
				if is_valid_name (l_name) then
					Result := l_name
				end
			end
		end

	resolved_general_entity_name (a_name: READABLE_STRING_8): STRING_8
			-- Follow linear aliases without growing the Eiffel call stack.
		local
			l_seen: HASH_TABLE [BOOLEAN, STRING_8]
			l_done: BOOLEAN
		do
			create Result.make_from_string (a_name)
			create l_seen.make (8)
			from
			until
				l_done or has_error
			loop
				if l_seen.has (Result) or else is_entity_active (Result) then
					set_error ("recursive entity reference")
				elseif attached entity_value (Result) as l_value and then attached single_entity_reference_name (l_value, '&') as l_next and then not is_predefined_entity (l_next) and then attached entity_value (l_next) then
					l_seen.force (True, Result)
					note_entity_expansion (l_value.count)
					Result := l_next
				else
					l_done := True
				end
			end
		end

	include_general_entity_in_content (a_name: READABLE_STRING_8)
			-- Include general entity `a_name' as parsed content.
		require
			valid_name: is_valid_name (a_name)
		local
			l_element_depth: INTEGER
			l_previous_floor: INTEGER
			l_name: STRING_8
		do
			l_name := resolved_general_entity_name (a_name)
			if has_error then
			elseif is_entity_active (l_name) then
				set_error ("recursive entity reference")
			elseif entity_stack.count >= Default_max_entity_depth then
				set_error ("entity expansion depth exceeded")
			elseif attached entity_value (l_name) as l_value then
				note_entity_expansion (l_value.count)
				if not has_error then
					l_element_depth := element_stack.count
					l_previous_floor := entity_element_floor
					entity_element_floor := l_element_depth
					push_entity (l_name)
					parse_entity_content (l_value)
					pop_entity
					entity_element_floor := l_previous_floor
					if not has_error and then element_stack.count /= l_element_depth then
						note_current_entity_reference_position
						set_error ("asynchronous entity")
					end
				end
			elseif attached external_entity (l_name) as l_external then
				include_external_entity_in_content (l_external)
			elseif (document_has_external_subset or dtd_has_parameter_entity_references) and then xml_standalone /= 1 then
				-- A non-validating parser may skip externally declared general entities.
				if handler.reports_skipped_internal_general_entities then
					handler.on_skipped_entity (a_name, False)
					check_handler_stop
				end
			else
				set_error ("undefined entity")
			end
		end

	include_general_entity_in_literal (a_name: READABLE_STRING_8; a_text: STRING_8)
			-- Include general entity `a_name' as literal replacement text.
		require
			valid_name: is_valid_name (a_name)
			text_attached: a_text /= Void
		local
			l_name: STRING_8
		do
			l_name := resolved_general_entity_name (a_name)
			if has_error then
			elseif is_entity_active (l_name) then
				set_error ("recursive entity reference")
			elseif entity_stack.count >= Default_max_entity_depth then
				set_error ("entity expansion depth exceeded")
			elseif attached entity_value (l_name) as l_value then
				note_entity_expansion (l_value.count)
				if not has_error then
					push_entity (l_name)
					expand_literal_text (l_value, a_text)
					pop_entity
				end
			elseif attached external_entity (l_name) as l_external then
				include_external_entity_in_literal (l_external, a_text)
			elseif (document_has_external_subset or dtd_has_parameter_entity_references) and then xml_standalone /= 1 then
					-- As in Expat, the entity may be declared where a non-validating parser does not read;
					-- the reference contributes nothing to the value.
			else
				set_error ("undefined entity")
			end
		end

	include_external_entity_in_content (a_entity: XP_EXTERNAL_ENTITY)
			-- Resolve and include external parsed entity as content.
		require
			entity_attached: a_entity /= Void
			general_entity: not a_entity.is_parameter
		do
			if a_entity.is_unparsed then
				set_error ("unparsed entity reference")
			elseif not allows_general_entities (external_entity_policy) then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif attached external_entity_resolver as l_resolver then
				if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, False) as l_value then
					note_entity_expansion (l_value.count)
					if not has_error then
						push_entity (a_entity.name)
						parse_entity_content (l_value)
						pop_entity
					end
				else
					set_error ("external entity not resolved")
				end
			end
		end

	include_external_entity_in_literal (a_entity: XP_EXTERNAL_ENTITY; a_text: STRING_8)
			-- Resolve and include external parsed entity as literal text.
		require
			entity_attached: a_entity /= Void
			general_entity: not a_entity.is_parameter
			text_attached: a_text /= Void
		do
			if a_entity.is_unparsed then
				set_error ("unparsed entity reference")
			elseif not allows_general_entities (external_entity_policy) then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif attached external_entity_resolver as l_resolver then
				if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, False) as l_value then
					note_entity_expansion (l_value.count)
					if not has_error then
						push_entity (a_entity.name)
						expand_literal_text (l_value, a_text)
						pop_entity
					end
				else
					set_error ("external entity not resolved")
				end
			end
		end

	include_external_parameter_entity_in_subset (a_entity: XP_EXTERNAL_ENTITY)
			-- Resolve and process external parameter entity as DTD subset content.
		require
			entity_attached: a_entity /= Void
			parameter_entity: a_entity.is_parameter
		do
			if not parameter_entity_loading_allowed then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif external_entity_resolver /= Void and then attached external_entity_resolver as l_resolver then
				check_not_standalone
				if not has_error then
					if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, True) as l_value then
						if not l_resolver.last_resolution_is_external_child_parse then
							note_entity_expansion (l_value.count)
						end
						if not has_error then
							external_dtd_depth := external_dtd_depth + 1
							process_internal_subset (l_value)
							external_dtd_depth := external_dtd_depth - 1
						end
					else
						set_error ("external entity not resolved")
					end
				end
			end
		end

	append_external_parameter_entity_in_literal (a_entity: XP_EXTERNAL_ENTITY; a_text: STRING_8)
			-- Resolve and append external parameter entity replacement text.
		require
			entity_attached: a_entity /= Void
			parameter_entity: a_entity.is_parameter
			text_attached: a_text /= Void
		do
			if not parameter_entity_loading_allowed then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif external_entity_resolver /= Void and then attached external_entity_resolver as l_resolver then
				check_not_standalone
				if not has_error then
					l_resolver.set_next_resolution_is_parameter_literal (True)
					if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, True) as l_value then
						l_resolver.set_next_resolution_is_parameter_literal (False)
						if not l_resolver.last_resolution_is_external_child_parse then
							note_entity_expansion (l_value.count)
						elseif l_resolver.last_resolution_replacement_byte_count > l_value.count then
							current_entity_literal_accounting_adjustment := current_entity_literal_accounting_adjustment + l_resolver.last_resolution_replacement_byte_count - l_value.count
						end
						if not has_error then
							a_text.append (l_value)
						end
					else
						l_resolver.set_next_resolution_is_parameter_literal (False)
						set_error ("external entity not resolved")
					end
				end
			end
		end

	include_external_subset (a_public_id, a_system_id: READABLE_STRING_8)
			-- Resolve and process external DTD subset if policy permits it.
		require
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
		do
			if parameter_entity_loading_allowed then
				if external_entity_resolver = Void then
					set_error ("external entity resolver missing")
				elseif attached external_entity_resolver as l_resolver then
					if attached l_resolver.resolve_external_entity (doctype_name, a_public_id, a_system_id, True) as l_value then
						if not l_resolver.last_resolution_is_external_child_parse then
							note_entity_expansion (l_value.count)
						end
						if not has_error then
							external_dtd_depth := external_dtd_depth + 1
							process_internal_subset (l_value)
							external_dtd_depth := external_dtd_depth - 1
						end
					else
						set_error ("external entity not resolved")
					end
				end
			end
		end

	include_foreign_dtd_if_needed (a_root_name: READABLE_STRING_8)
			-- Resolve and process configured foreign DTD before the root element.
		require
			root_name_attached: a_root_name /= Void
			root_name_not_empty: not a_root_name.is_empty
		do
			if use_foreign_dtd and then not foreign_dtd_loaded and then not document_has_external_subset then
				foreign_dtd_loaded := True
				check_not_standalone
				if not has_error and then parameter_entity_loading_allowed and then attached external_entity_resolver as l_resolver then
					if attached l_resolver.resolve_external_entity (a_root_name, "", "foreign.dtd", True) as l_value then
						if not l_resolver.last_resolution_is_external_child_parse then
							note_entity_expansion (l_value.count)
						end
						if not has_error then
							if not l_value.is_empty or else l_resolver.last_resolution_is_external_child_parse then
								document_has_external_subset := True
							end
							external_dtd_depth := external_dtd_depth + 1
							process_internal_subset (l_value)
							external_dtd_depth := external_dtd_depth - 1
						end
					else
						set_error ("external entity not resolved")
					end
				end
			end
		end

	check_not_standalone
			-- Ask the handler whether a non-standalone external subset is acceptable.
		do
			if not has_error and then xml_standalone /= 1 and then not not_standalone_checked then
				not_standalone_checked := True
				if not handler.on_not_standalone then
					set_error ("not standalone")
				else
					check_handler_stop
				end
			end
		end

	parameter_entity_loading_allowed: BOOLEAN
			-- May external parameter entities and DTD subsets be loaded now?
		do
			Result := allows_parameter_entities (external_entity_policy)
				and then not (parameter_entities_unless_standalone and then xml_standalone = 1)
		end

	parse_entity_content (a_content: READABLE_STRING_8)
			-- Parse replacement text as included content.
		require
			content_attached: a_content /= Void
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_content.count + 1
			until
				i > a_content.count or has_error or is_suspended
			loop
				if a_content.item (i) = '<' then
					i := parse_markup (a_content, i)
				else
					i := parse_character_data (a_content, i)
				end
			variant
				a_content.count - i + 1
			end
		end

	expand_literal_text (a_content: READABLE_STRING_8; a_text: STRING_8)
			-- Expand replacement text as literal character data.
		require
			content_attached: a_content /= Void
			text_attached: a_text /= Void
		local
			i: INTEGER
			c: CHARACTER_8
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_content.count + 1
			until
				i > a_content.count or has_error or is_suspended
			loop
				c := a_content.item (i)
				if c = '&' then
					i := append_reference_in_literal (a_content, i, a_text)
				elseif c = '<' then
					set_error ("left angle bracket in entity replacement text")
					i := a_content.count + 1
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_content.count + 1
				else
					if is_xml_space (c) then
						a_text.append_character (' ')
					else
						a_text.append_character (c)
					end
					i := i + 1
				end
			variant
				a_content.count - i + 1
			end
		end

feature {NONE} -- DTD entity declarations

	looks_like_external_subset (a_input: READABLE_STRING_8): BOOLEAN
			-- Does `a_input' start with DTD-subset content rather than parsed XML content?
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_end: INTEGER
			l_done: BOOLEAN
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
			until
				i > a_input.count or Result or l_done
			loop
				if is_xml_space (a_input.item (i)) then
					i := i + 1
				elseif has_at (a_input, i, "<!--") then
					l_end := find_sequence (a_input, "-->", i + 4)
					if l_end = 0 then
						l_done := True
						i := a_input.count + 1
					else
						i := l_end + 3
					end
				elseif has_at (a_input, i, "<?") then
					l_end := find_sequence (a_input, "?>", i + 2)
					if l_end = 0 then
						l_done := True
						i := a_input.count + 1
					else
						i := l_end + 2
					end
				elseif
					has_at (a_input, i, "<!ENTITY")
					or else has_at (a_input, i, "<!ATTLIST")
					or else has_at (a_input, i, "<!ELEMENT")
					or else has_at (a_input, i, "<!NOTATION")
					or else has_at (a_input, i, "<![IGNORE[")
					or else has_at (a_input, i, "<![INCLUDE[")
					or else has_at (a_input, i, "<![%%")
					or else a_input.item (i).code = 37
				then
					Result := True
					i := a_input.count + 1
				else
					l_done := True
					i := a_input.count + 1
				end
			variant
				a_input.count - i + 1
			end
		end

	process_internal_subset (a_subset: READABLE_STRING_8)
			-- Process entity declarations and parameter entity references in an internal subset.
		require
			subset_attached: a_subset /= Void
		local
			i: INTEGER
			l_end: INTEGER
			l_text: STRING_8
			l_seen_xml_declaration: BOOLEAN
			l_target_end, l_data_start: INTEGER
			l_target, l_data: STRING_8
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_subset.count + 1
			until
				i > a_subset.count or has_error or is_suspended
			loop
				if dtd_entity_reference_position > 0 then
					note_position (dtd_entity_reference_position)
				else
					note_position (dtd_subset_position_offset + i)
				end
				if has_at (a_subset, i, "<!ENTITY") then
					i := parse_entity_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!ATTLIST") then
					i := parse_attlist_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!ELEMENT") then
					i := parse_element_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!NOTATION") then
					i := parse_notation_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<![") then
					i := parse_conditional_section (a_subset, i)
				elseif has_at (a_subset, i, "<!--") then
					l_end := find_sequence (a_subset, "-->", i + 4)
					if l_end = 0 then
						set_error ("unterminated comment")
						i := a_subset.count + 1
					elseif find_sequence (a_subset, "--", i + 4) < l_end then
						set_error ("double hyphen in comment")
						i := a_subset.count + 1
					else
						if handler.wants_comment_default then
							emit_default (a_subset.substring (i, l_end + 2))
						end
						create l_text.make_from_string (a_subset.substring (i + 4, l_end - 1))
						if not has_error and not is_suspended then
							handler.on_comment (l_text)
							check_handler_stop
						end
						i := l_end + 3
					end
				elseif has_at (a_subset, i, "<?") then
					if starts_xml_declaration_at (a_subset, i) then
						i := parse_processing_instruction (a_subset, i)
						l_seen_xml_declaration := not has_error
					else
						l_end := find_sequence (a_subset, "?>", i + 2)
						if l_end = 0 then
							set_error ("unterminated processing instruction")
							i := a_subset.count + 1
						else
							validate_processing_instruction_target (a_subset, i + 2, l_end)
							if has_error then
								i := a_subset.count + 1
							else
								if handler.wants_processing_instruction_default then
									emit_default (a_subset.substring (i, l_end + 1))
								end
								if not has_error and not is_suspended then
									l_target_end := scan_name (a_subset, i + 2)
									l_target := a_subset.substring (i + 2, l_target_end - 1).to_string_8
									l_data_start := skip_spaces (a_subset, l_target_end).min (l_end)
									l_data := a_subset.substring (l_data_start, l_end - 1).to_string_8
									handler.on_processing_instruction (l_target, l_data)
									check_handler_stop
								end
								i := l_end + 2
							end
						end
					end
				elseif a_subset.item (i).code = 37 then
					i := include_parameter_entity_in_subset (a_subset, i)
				else
					if is_xml_space (a_subset.item (i)) then
						emit_default (a_subset.substring (i, i))
						i := i + 1
					elseif is_incomplete_utf8_sequence_at (a_subset, i) then
						set_error ("partial character")
						i := a_subset.count + 1
					elseif is_quote (a_subset.item (i)) then
						set_error ("unterminated literal")
						i := a_subset.count + 1
					elseif a_subset.item (i) = ']' then
						set_error ("invalid DTD closing delimiter")
						i := a_subset.count + 1
					elseif a_subset.item (i).code = 36 then
						set_error ("invalid DTD content")
						i := a_subset.count + 1
					else
						set_error ("unexpected DTD content")
						i := a_subset.count + 1
					end
				end
			variant
				a_subset.count - i + 1
			end
		end

	validate_processing_instruction_target (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER)
			-- Check the target of a processing instruction (not an XML declaration) that
			-- starts at `a_start_index' and whose "?>" begins at `a_end_index'.
		require
			input_attached: a_input /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_target: STRING_8
		do
			if not is_name_start_character (a_input.item (a_start_index)) then
				set_error ("invalid processing instruction target")
			else
				i := scan_name (a_input, a_start_index)
				if not has_error then
					create l_target.make_from_string (a_input.substring (a_start_index, i - 1))
					if same_name_case_insensitive (l_target, "xml") then
						set_error ("reserved processing instruction target")
					elseif i < a_end_index and then not is_xml_space (a_input.item (i)) then
						set_error ("missing space after processing instruction target")
					elseif namespace_mode and then l_target.has (':') then
						set_error ("colon in processing instruction target")
					end
				end
			end
		end

	process_internal_subset_prefix (a_subset: READABLE_STRING_8)
			-- Process only complete declaration tokens in a non-final subset.
		require
			subset_attached: a_subset /= Void
		local
			l_end: INTEGER
		do
			l_end := complete_dtd_prefix_end (a_subset)
			if l_end > 0 then
				process_internal_subset (a_subset.substring (1, l_end))
			end
		end

	parse_conditional_section (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse a DTD conditional section.
		require
			subset_attached: a_subset /= Void
			starts_conditional_section: has_at (a_subset, a_start_index, "<![")
		local
			i: INTEGER
			l_content_start: INTEGER
			l_end: INTEGER
			l_inner: STRING_8
			l_status: STRING_8
		do
			l_end := find_conditional_section_end (a_subset, a_start_index)
			if l_end = 0 then
				if has_partial_utf8_tail (a_subset) then
					set_error ("partial character")
				else
					set_error ("incomplete conditional section")
				end
				Result := a_subset.count + 1
			else
				create l_status.make_empty
				from
					i := a_start_index + 3
				invariant
					index_in_bounds: i >= a_start_index + 3 and i <= a_subset.count + 1
				until
					i > l_end - 1 or has_error or else a_subset.item (i) = '['
				loop
					if a_subset.item (i).code = 37 then
						i := append_parameter_reference_in_entity_value (a_subset, i, l_status)
					else
						l_status.append_character (a_subset.item (i))
						i := i + 1
					end
				variant
					a_subset.count - i + 1
				end
				if has_error then
					Result := a_subset.count + 1
				elseif i > l_end - 1 or else a_subset.item (i) /= '[' then
					set_error ("invalid conditional section")
					Result := a_subset.count + 1
				else
					l_status.left_adjust
					l_status.right_adjust
					if l_status.same_string ("IGNORE") then
						emit_default (a_subset.substring (a_start_index, l_end + 2))
						Result := l_end + 3
					elseif l_status.same_string ("INCLUDE") then
						l_content_start := i + 1
						if l_content_start <= l_end - 1 then
							create l_inner.make_from_string (a_subset.substring (l_content_start, l_end - 1))
							process_internal_subset (l_inner)
						end
						if has_error then
							Result := a_subset.count + 1
						else
							Result := l_end + 3
						end
					else
						set_error ("invalid conditional section")
						Result := a_subset.count + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	find_conditional_section_end (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Closing marker of a possibly nested conditional section.
		local
			i, l_depth: INTEGER
		do
			from
				i := a_start_index + 3
				l_depth := 1
			until
				i > a_input.count or Result > 0
			loop
				if has_at (a_input, i, "<![") then
					l_depth := l_depth + 1
					i := i + 3
				elseif has_at (a_input, i, "]]>") then
					l_depth := l_depth - 1
					if l_depth = 0 then
						Result := i
					end
					i := i + 3
				else
					i := i + 1
				end
			end
		end

	has_partial_utf8_tail (a_input: READABLE_STRING_8): BOOLEAN
		local
			i: INTEGER
		do
			from
				i := (a_input.count - 3).max (1)
			until
				i > a_input.count or Result
			loop
				Result := is_incomplete_utf8_sequence_at (a_input, i)
				i := i + 1
			end
		end

	starts_xml_declaration_at (a_input: READABLE_STRING_8; a_start_index: INTEGER): BOOLEAN
			-- Does `a_input' contain an XML declaration PI at `a_start_index'?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			name_start: INTEGER
			l_target: STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			if has_at (a_input, a_start_index, "<?") and then a_start_index + 2 <= a_input.count then
				create l_attributes.make
				i := a_start_index + 2
				if l_attributes.is_name_start_character (a_input.item (i)) then
					name_start := i
					i := scan_name (a_input, i)
					create l_target.make_from_string (a_input.substring (name_start, i - 1))
					Result := same_name_case_insensitive (l_target, "xml")
				end
			end
		end

	external_parameter_literal_content_start (a_input: READABLE_STRING_8): INTEGER
			-- First significant content byte after an optional text declaration.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			l_end: INTEGER
		do
			i := skip_spaces (a_input, 1)
			if i <= a_input.count and then starts_xml_declaration_at (a_input, i) then
				l_end := find_sequence (a_input, "?>", i + 2)
				if l_end > 0 then
					i := skip_spaces (a_input, l_end + 2)
				else
					i := a_input.count + 1
				end
			end
			Result := i
		ensure
			result_in_bounds: Result >= 1 and Result <= a_input.count + 1
		end

	is_incomplete_utf8_sequence_at (a_input: READABLE_STRING_8; a_start_index: INTEGER): BOOLEAN
			-- Does a UTF-8 leading byte at `a_start_index' lack enough trailing bytes?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			l_code: INTEGER
			l_required: INTEGER
			i: INTEGER
		do
			l_code := a_input.item (a_start_index).code
			if l_code >= 194 and then l_code <= 223 then
				l_required := 1
			elseif l_code >= 224 and then l_code <= 239 then
				l_required := 2
			elseif l_code >= 240 and then l_code <= 244 then
				l_required := 3
			end
			if l_required > 0 and then a_start_index + l_required > a_input.count then
				Result := True
				from
					i := a_start_index + 1
				invariant
					index_in_bounds: i >= a_start_index + 1 and i <= a_input.count + 1
				until
					i > a_input.count or not Result
				loop
					Result := is_utf8_continuation_byte (a_input.item (i).code)
					i := i + 1
				variant
					a_input.count - i + 1
				end
			end
		end

	is_utf8_continuation_byte (a_code: INTEGER): BOOLEAN
			-- Is `a_code' a UTF-8 continuation byte?
		do
			Result := a_code >= 128 and then a_code <= 191
		end

	utf8_character_length (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Byte length of the UTF-8 sequence at `a_start_index' when it encodes an XML character,
			-- which is then available as `last_utf8_code'; 0 when the bytes are not well-formed
			-- UTF-8 or the character is not allowed in XML; -1 when the sequence is well-formed
			-- so far but cut off by the end of `a_input'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			l_lead: INTEGER
			l_count: INTEGER
			l_minimum: INTEGER
			l_code: INTEGER
			l_byte: INTEGER
			l_invalid: BOOLEAN
			j: INTEGER
		do
			l_lead := a_input.item (a_start_index).code
			if l_lead < 128 then
				if is_xml_character_code (l_lead) then
					last_utf8_code := l_lead
					Result := 1
				end
			else
				if l_lead >= 194 and then l_lead <= 223 then
					l_count := 2
					l_code := l_lead - 192
					l_minimum := 128
				elseif l_lead >= 224 and then l_lead <= 239 then
					l_count := 3
					l_code := l_lead - 224
					l_minimum := 2048
				elseif l_lead >= 240 and then l_lead <= 244 then
					l_count := 4
					l_code := l_lead - 240
					l_minimum := 65536
				end
				if l_count > 0 then
					from
						j := 1
					invariant
						offset_in_bounds: j >= 1 and j <= l_count
					until
						j = l_count
					loop
						if a_start_index + j > a_input.count then
							Result := -1
							j := l_count
						else
							l_byte := a_input.item (a_start_index + j).code
							if is_utf8_continuation_byte (l_byte) then
								l_code := l_code * 64 + l_byte - 128
								j := j + 1
							else
								l_invalid := True
								j := l_count
							end
						end
					variant
						l_count - j
					end
					if Result = 0 and then not l_invalid and then l_code >= l_minimum and then is_xml_character_code (l_code) then
						last_utf8_code := l_code
						Result := l_count
					end
				end
			end
		ensure
			result_in_range: Result >= -1 and Result <= 4
			ascii_has_length_one: a_input.item (a_start_index).code < 128 implies Result <= 1
		end

	is_name_start_code (a_code: INTEGER): BOOLEAN
			-- Is `a_code' accepted by the configured XML name production?
		do
			if uses_legacy_name_character_ranges then
				Result := code_in_ranges (a_code, name_start_ranges)
			else
				Result := (a_code >= 65 and a_code <= 90) or else (a_code >= 97 and a_code <= 122)
					or else a_code = 58 or else a_code = 95
					or else (a_code >= 0xC0 and a_code <= 0xD6) or else (a_code >= 0xD8 and a_code <= 0xF6)
					or else (a_code >= 0xF8 and a_code <= 0x2FF) or else (a_code >= 0x370 and a_code <= 0x37D)
					or else (a_code >= 0x37F and a_code <= 0x1FFF) or else (a_code >= 0x200C and a_code <= 0x200D)
					or else (a_code >= 0x2070 and a_code <= 0x218F) or else (a_code >= 0x2C00 and a_code <= 0x2FEF)
					or else (a_code >= 0x3001 and a_code <= 0xD7FF) or else (a_code >= 0xF900 and a_code <= 0xFDCF)
					or else (a_code >= 0xFDF0 and a_code <= 0xFFFD) or else (a_code >= 0x10000 and a_code <= 0xEFFFF)
			end
		end

	is_name_code (a_code: INTEGER): BOOLEAN
			-- Is `a_code' accepted by the configured XML name production?
		do
			if uses_legacy_name_character_ranges then
				Result := is_name_start_code (a_code) or else code_in_ranges (a_code, name_extra_ranges)
			else
				Result := is_name_start_code (a_code) or else (a_code >= 48 and a_code <= 57)
					or else a_code = 45 or else a_code = 46 or else a_code = 0xB7
					or else (a_code >= 0x300 and a_code <= 0x36F) or else (a_code >= 0x203F and a_code <= 0x2040)
			end
		end

	code_in_ranges (a_code: INTEGER; a_ranges: ARRAY [INTEGER]): BOOLEAN
			-- Binary lookup in inclusive lower/upper pairs.
		local
			l_low, l_high, l_middle, l_index: INTEGER
		do
			from
				l_high := a_ranges.count // 2 - 1
			until
				l_low > l_high or Result
			loop
				l_middle := (l_low + l_high) // 2
				l_index := l_middle * 2 + 1
				if a_code < a_ranges [l_index] then
					l_high := l_middle - 1
				elseif a_code > a_ranges [l_index + 1] then
					l_low := l_middle + 1
				else
					Result := True
				end
			end
		end

	name_start_ranges: ARRAY [INTEGER]
			-- Sorted inclusive ranges from XML 1.0 fourth-edition name productions.
		once
			Result := <<
				0x3A, 0x3A, 0x41, 0x5A, 0x5F, 0x5F, 0x61, 0x7A, 0xC0, 0xD6,
				0xD8, 0xF6, 0xF8, 0x131, 0x134, 0x13E, 0x141, 0x148, 0x14A, 0x17E,
				0x180, 0x1C3, 0x1CD, 0x1F0, 0x1F4, 0x1F5, 0x1FA, 0x217, 0x250, 0x2A8,
				0x2BB, 0x2C1, 0x386, 0x386, 0x388, 0x38A, 0x38C, 0x38C, 0x38E, 0x3A1,
				0x3A3, 0x3CE, 0x3D0, 0x3D6, 0x3DA, 0x3DA, 0x3DC, 0x3DC, 0x3DE, 0x3DE,
				0x3E0, 0x3E0, 0x3E2, 0x3F3, 0x401, 0x40C, 0x40E, 0x44F, 0x451, 0x45C,
				0x45E, 0x481, 0x490, 0x4C4, 0x4C7, 0x4C8, 0x4CB, 0x4CC, 0x4D0, 0x4EB,
				0x4EE, 0x4F5, 0x4F8, 0x4F9, 0x531, 0x556, 0x559, 0x559, 0x561, 0x586,
				0x5D0, 0x5EA, 0x5F0, 0x5F2, 0x621, 0x63A, 0x641, 0x64A, 0x671, 0x6B7,
				0x6BA, 0x6BE, 0x6C0, 0x6CE, 0x6D0, 0x6D3, 0x6D5, 0x6D5, 0x6E5, 0x6E6,
				0x905, 0x939, 0x93D, 0x93D, 0x958, 0x961, 0x985, 0x98C, 0x98F, 0x990,
				0x993, 0x9A8, 0x9AA, 0x9B0, 0x9B2, 0x9B2, 0x9B6, 0x9B9, 0x9DC, 0x9DD,
				0x9DF, 0x9E1, 0x9F0, 0x9F1, 0xA05, 0xA0A, 0xA0F, 0xA10, 0xA13, 0xA28,
				0xA2A, 0xA30, 0xA32, 0xA33, 0xA35, 0xA36, 0xA38, 0xA39, 0xA59, 0xA5C,
				0xA5E, 0xA5E, 0xA72, 0xA74, 0xA85, 0xA8B, 0xA8D, 0xA8D, 0xA8F, 0xA91,
				0xA93, 0xAA8, 0xAAA, 0xAB0, 0xAB2, 0xAB3, 0xAB5, 0xAB9, 0xABD, 0xABD,
				0xAE0, 0xAE0, 0xB05, 0xB0C, 0xB0F, 0xB10, 0xB13, 0xB28, 0xB2A, 0xB30,
				0xB32, 0xB33, 0xB36, 0xB39, 0xB3D, 0xB3D, 0xB5C, 0xB5D, 0xB5F, 0xB61,
				0xB85, 0xB8A, 0xB8E, 0xB90, 0xB92, 0xB95, 0xB99, 0xB9A, 0xB9C, 0xB9C,
				0xB9E, 0xB9F, 0xBA3, 0xBA4, 0xBA8, 0xBAA, 0xBAE, 0xBB5, 0xBB7, 0xBB9,
				0xC05, 0xC0C, 0xC0E, 0xC10, 0xC12, 0xC28, 0xC2A, 0xC33, 0xC35, 0xC39,
				0xC60, 0xC61, 0xC85, 0xC8C, 0xC8E, 0xC90, 0xC92, 0xCA8, 0xCAA, 0xCB3,
				0xCB5, 0xCB9, 0xCDE, 0xCDE, 0xCE0, 0xCE1, 0xD05, 0xD0C, 0xD0E, 0xD10,
				0xD12, 0xD28, 0xD2A, 0xD39, 0xD60, 0xD61, 0xE01, 0xE2E, 0xE30, 0xE30,
				0xE32, 0xE33, 0xE40, 0xE45, 0xE81, 0xE82, 0xE84, 0xE84, 0xE87, 0xE88,
				0xE8A, 0xE8A, 0xE8D, 0xE8D, 0xE94, 0xE97, 0xE99, 0xE9F, 0xEA1, 0xEA3,
				0xEA5, 0xEA5, 0xEA7, 0xEA7, 0xEAA, 0xEAB, 0xEAD, 0xEAE, 0xEB0, 0xEB0,
				0xEB2, 0xEB3, 0xEBD, 0xEBD, 0xEC0, 0xEC4, 0xF40, 0xF47, 0xF49, 0xF69,
				0x10A0, 0x10C5, 0x10D0, 0x10F6, 0x1100, 0x1100, 0x1102, 0x1103, 0x1105, 0x1107,
				0x1109, 0x1109, 0x110B, 0x110C, 0x110E, 0x1112, 0x113C, 0x113C, 0x113E, 0x113E,
				0x1140, 0x1140, 0x114C, 0x114C, 0x114E, 0x114E, 0x1150, 0x1150, 0x1154, 0x1155,
				0x1159, 0x1159, 0x115F, 0x1161, 0x1163, 0x1163, 0x1165, 0x1165, 0x1167, 0x1167,
				0x1169, 0x1169, 0x116D, 0x116E, 0x1172, 0x1173, 0x1175, 0x1175, 0x119E, 0x119E,
				0x11A8, 0x11A8, 0x11AB, 0x11AB, 0x11AE, 0x11AF, 0x11B7, 0x11B8, 0x11BA, 0x11BA,
				0x11BC, 0x11C2, 0x11EB, 0x11EB, 0x11F0, 0x11F0, 0x11F9, 0x11F9, 0x1E00, 0x1E9B,
				0x1EA0, 0x1EF9, 0x1F00, 0x1F15, 0x1F18, 0x1F1D, 0x1F20, 0x1F45, 0x1F48, 0x1F4D,
				0x1F50, 0x1F57, 0x1F59, 0x1F59, 0x1F5B, 0x1F5B, 0x1F5D, 0x1F5D, 0x1F5F, 0x1F7D,
				0x1F80, 0x1FB4, 0x1FB6, 0x1FBC, 0x1FBE, 0x1FBE, 0x1FC2, 0x1FC4, 0x1FC6, 0x1FCC,
				0x1FD0, 0x1FD3, 0x1FD6, 0x1FDB, 0x1FE0, 0x1FEC, 0x1FF2, 0x1FF4, 0x1FF6, 0x1FFC,
				0x2126, 0x2126, 0x212A, 0x212B, 0x212E, 0x212E, 0x2180, 0x2182, 0x3007, 0x3007,
				0x3021, 0x3029, 0x3041, 0x3094, 0x30A1, 0x30FA, 0x3105, 0x312C, 0x4E00, 0x9FA5,
				0xAC00, 0xD7A3
			>>
		end

	name_extra_ranges: ARRAY [INTEGER]
			-- Sorted inclusive ranges from XML 1.0 fourth-edition name productions.
		once
			Result := <<
				0x2D, 0x2E, 0x30, 0x39, 0xB7, 0xB7, 0x2D0, 0x2D1, 0x300, 0x345,
				0x360, 0x361, 0x387, 0x387, 0x483, 0x486, 0x591, 0x5A1, 0x5A3, 0x5B9,
				0x5BB, 0x5BD, 0x5BF, 0x5BF, 0x5C1, 0x5C2, 0x5C4, 0x5C4, 0x640, 0x640,
				0x64B, 0x652, 0x660, 0x669, 0x670, 0x670, 0x6D6, 0x6E4, 0x6E7, 0x6E8,
				0x6EA, 0x6ED, 0x6F0, 0x6F9, 0x901, 0x903, 0x93C, 0x93C, 0x93E, 0x94D,
				0x951, 0x954, 0x962, 0x963, 0x966, 0x96F, 0x981, 0x983, 0x9BC, 0x9BC,
				0x9BE, 0x9C4, 0x9C7, 0x9C8, 0x9CB, 0x9CD, 0x9D7, 0x9D7, 0x9E2, 0x9E3,
				0x9E6, 0x9EF, 0xA02, 0xA02, 0xA3C, 0xA3C, 0xA3E, 0xA42, 0xA47, 0xA48,
				0xA4B, 0xA4D, 0xA66, 0xA71, 0xA81, 0xA83, 0xABC, 0xABC, 0xABE, 0xAC5,
				0xAC7, 0xAC9, 0xACB, 0xACD, 0xAE6, 0xAEF, 0xB01, 0xB03, 0xB3C, 0xB3C,
				0xB3E, 0xB43, 0xB47, 0xB48, 0xB4B, 0xB4D, 0xB56, 0xB57, 0xB66, 0xB6F,
				0xB82, 0xB83, 0xBBE, 0xBC2, 0xBC6, 0xBC8, 0xBCA, 0xBCD, 0xBD7, 0xBD7,
				0xBE7, 0xBEF, 0xC01, 0xC03, 0xC3E, 0xC44, 0xC46, 0xC48, 0xC4A, 0xC4D,
				0xC55, 0xC56, 0xC66, 0xC6F, 0xC82, 0xC83, 0xCBE, 0xCC4, 0xCC6, 0xCC8,
				0xCCA, 0xCCD, 0xCD5, 0xCD6, 0xCE6, 0xCEF, 0xD02, 0xD03, 0xD3E, 0xD43,
				0xD46, 0xD48, 0xD4A, 0xD4D, 0xD57, 0xD57, 0xD66, 0xD6F, 0xE31, 0xE31,
				0xE34, 0xE3A, 0xE46, 0xE4E, 0xE50, 0xE59, 0xEB1, 0xEB1, 0xEB4, 0xEB9,
				0xEBB, 0xEBC, 0xEC6, 0xEC6, 0xEC8, 0xECD, 0xED0, 0xED9, 0xF18, 0xF19,
				0xF20, 0xF29, 0xF35, 0xF35, 0xF37, 0xF37, 0xF39, 0xF39, 0xF3E, 0xF3F,
				0xF71, 0xF84, 0xF86, 0xF8B, 0xF90, 0xF95, 0xF97, 0xF97, 0xF99, 0xFAD,
				0xFB1, 0xFB7, 0xFB9, 0xFB9, 0x20D0, 0x20DC, 0x20E1, 0x20E1, 0x3005, 0x3005,
				0x302A, 0x302F, 0x3031, 0x3035, 0x3099, 0x309A, 0x309D, 0x309E, 0x30FC, 0x30FE
			>>
		end

	decoded_input (a_input: READABLE_STRING_8): READABLE_STRING_8
			-- `a_input' as UTF-8. UTF-16 with a byte-order mark and declared ISO-8859-1 or
			-- US-ASCII input are converted; an encoding declaration that contradicts the
			-- byte-order mark is an error. Other input is returned unchanged.
		require
			input_attached: a_input /= Void
		local
			l_encoding: STRING_8
			l_text: STRING_8
			l_has_utf8_bom: BOOLEAN
			i: INTEGER
		do
			Result := a_input
			if input_is_utf8 then
					-- Already converted by the caller (the native layer).
			elseif
				a_input.count >= 2
				and then ((a_input.item (1).code = 255 and a_input.item (2).code = 254)
					or (a_input.item (1).code = 254 and a_input.item (2).code = 255))
			then
				Result := utf_16_as_utf_8 (a_input, a_input.item (1).code = 254)
				l_encoding := declared_encoding (Result, 1)
				if not l_encoding.is_empty and then not l_encoding.starts_with ("utf-16") then
					set_error ("incorrect encoding")
				end
			else
				l_has_utf8_bom := a_input.count >= 3 and then a_input.item (1).code = 239
					and then a_input.item (2).code = 187 and then a_input.item (3).code = 191
				if l_has_utf8_bom then
					l_encoding := declared_encoding (a_input, 4)
				else
					l_encoding := declared_encoding (a_input, 1)
				end
				if l_has_utf8_bom and then not l_encoding.is_empty and then not l_encoding.same_string ("utf-8") then
					set_error ("incorrect encoding")
				elseif l_encoding.starts_with ("utf-16") then
					set_error ("incorrect encoding")
				elseif l_encoding.same_string ("iso-8859-1") or else l_encoding.same_string ("latin1") or else l_encoding.same_string ("iso_8859-1") then
					create l_text.make (a_input.count + a_input.count // 8)
					from
						i := 1
					invariant
						index_in_bounds: i >= 1 and i <= a_input.count + 1
					until
						i > a_input.count
					loop
						{UTF_CONVERTER}.utf_32_code_into_utf_8_string_8 (a_input.item (i).natural_32_code, l_text)
						i := i + 1
					variant
						a_input.count - i + 1
					end
					Result := l_text
				elseif l_encoding.same_string ("us-ascii") or else l_encoding.same_string ("ascii") then
					from
						i := 1
					invariant
						index_in_bounds: i >= 1 and i <= a_input.count + 1
					until
						i > a_input.count or has_error
					loop
						if a_input.item (i).code >= 128 then
							set_error ("invalid XML character")
						end
						i := i + 1
					variant
						a_input.count - i + 1
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	declared_encoding (a_input: READABLE_STRING_8; a_start_index: INTEGER): STRING_8
			-- Lower-case encoding name declared by an XML or text declaration at `a_start_index', or empty.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1
		local
			l_end: INTEGER
			i: INTEGER
			l_close: INTEGER
		do
			create Result.make_empty
			if
				has_at (a_input, a_start_index, "<?xml") and then a_start_index + 5 <= a_input.count
				and then is_xml_space (a_input.item (a_start_index + 5))
			then
				l_end := find_sequence (a_input, "?>", a_start_index + 5)
				if l_end > 0 then
					i := find_sequence (a_input, "encoding", a_start_index + 5)
					if i > 0 and then i < l_end then
						i := skip_spaces (a_input, i + 8)
						if i < l_end and then a_input.item (i) = '=' then
							i := skip_spaces (a_input, i + 1)
							if i < l_end and then is_quote (a_input.item (i)) then
								l_close := find_character (a_input, a_input.item (i), i + 1)
								if l_close > 0 and then l_close < l_end then
									Result.append (a_input.substring (i + 1, l_close - 1))
									Result.to_lower
								end
							end
						end
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	utf_16_as_utf_8 (a_input: READABLE_STRING_8; a_big_endian: BOOLEAN): STRING_8
			-- UTF-8 form of UTF-16 `a_input' after its two-byte byte-order mark.
			-- A trailing odd byte or unpaired high surrogate at the end is dropped, as more input may follow.
		require
			input_attached: a_input /= Void
			has_byte_order_mark: a_input.count >= 2
		local
			i: INTEGER
			l_unit: INTEGER
			l_next: INTEGER
		do
			create Result.make (a_input.count)
			from
				i := 3
			invariant
				index_in_bounds: i >= 3 and i <= a_input.count + 2
			until
				i + 1 > a_input.count or has_error
			loop
				l_unit := utf_16_unit_at (a_input, i, a_big_endian)
				if l_unit >= 0xD800 and l_unit <= 0xDBFF then
					if i + 3 <= a_input.count then
						l_next := utf_16_unit_at (a_input, i + 2, a_big_endian)
						if l_next >= 0xDC00 and l_next <= 0xDFFF then
							{UTF_CONVERTER}.utf_32_code_into_utf_8_string_8 ((0x10000 + (l_unit - 0xD800) * 1024 + (l_next - 0xDC00)).to_natural_32, Result)
							i := i + 4
						else
							set_error ("invalid XML character")
							i := i + 2
						end
					else
						i := a_input.count + 1
					end
				elseif l_unit >= 0xDC00 and l_unit <= 0xDFFF then
					set_error ("invalid XML character")
					i := i + 2
				else
					{UTF_CONVERTER}.utf_32_code_into_utf_8_string_8 (l_unit.to_natural_32, Result)
					i := i + 2
				end
			variant
				a_input.count - i + 2
			end
		ensure
			result_attached: Result /= Void
		end

	utf_16_unit_at (a_input: READABLE_STRING_8; a_index: INTEGER; a_big_endian: BOOLEAN): INTEGER
			-- 16-bit code unit stored at `a_index' and `a_index + 1'.
		require
			input_attached: a_input /= Void
			valid_index: a_index >= 1 and a_index + 1 <= a_input.count
		do
			if a_big_endian then
				Result := a_input.item (a_index).code * 256 + a_input.item (a_index + 1).code
			else
				Result := a_input.item (a_index + 1).code * 256 + a_input.item (a_index).code
			end
		ensure
			sixteen_bits: Result >= 0 and Result <= 65535
		end

	is_valid_version_number (a_version: READABLE_STRING_8): BOOLEAN
			-- Does `a_version' satisfy the XML 1.0 fifth edition VersionNum production ('1.' [0-9]+)?
		require
			version_attached: a_version /= Void
		local
			i: INTEGER
		do
			if a_version.count >= 3 and then a_version.item (1) = '1' and then a_version.item (2) = '.' then
				from
					Result := True
					i := 3
				invariant
					index_in_bounds: i >= 3 and i <= a_version.count + 1
				until
					i > a_version.count or not Result
				loop
					Result := a_version.item (i).is_digit
					i := i + 1
				variant
					a_version.count - i + 1
				end
			end
		end

	is_valid_encoding_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Does `a_name' satisfy the XML 1.0 EncName production?
		require
			name_attached: a_name /= Void
		local
			i: INTEGER
			c: CHARACTER_8
		do
			if not a_name.is_empty and then ((a_name.item (1) >= 'A' and a_name.item (1) <= 'Z') or (a_name.item (1) >= 'a' and a_name.item (1) <= 'z')) then
				from
					Result := True
					i := 2
				invariant
					index_in_bounds: i >= 2 and i <= a_name.count + 1
				until
					i > a_name.count or not Result
				loop
					c := a_name.item (i)
					Result := (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9')
						or c = '.' or c = '_' or c = '-'
					i := i + 1
				variant
					a_name.count - i + 1
				end
			end
		end

	parse_element_declaration (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse an element declaration and emit its content model.
		require
			subset_attached: a_subset /= Void
			starts_element: has_at (a_subset, a_start_index, "<!ELEMENT")
		local
			i: INTEGER
			l_end: INTEGER
			name_start: INTEGER
			l_name: STRING_8
			l_model: detachable XP_CONTENT_MODEL
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated element declaration")
				Result := a_subset.count + 1
			else
				i := skip_required_spaces (a_subset, a_start_index + 9, "missing space in element declaration")
				if has_error or else i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid element declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					if not has_error then
						i := skip_required_spaces (a_subset, i, "missing space before content model")
					end
					parsed_content_model := Void
					if has_error then
					elseif has_keyword_at (a_subset, i, "EMPTY") then
						create l_model.make ({XP_CONTENT_MODEL}.Type_empty, {XP_CONTENT_MODEL}.Quant_none, Void)
						i := i + 5
					elseif has_keyword_at (a_subset, i, "ANY") then
						create l_model.make ({XP_CONTENT_MODEL}.Type_any, {XP_CONTENT_MODEL}.Quant_none, Void)
						i := i + 3
					elseif i <= l_end - 1 and then a_subset.item (i) = '(' then
						i := parse_content_particle (a_subset, i, l_end - 1, True)
						if not has_error then
							l_model := parsed_content_model
						end
					else
						set_error ("invalid element content model")
					end
					if not has_error then
						i := skip_spaces (a_subset, i)
						if i /= l_end then
							set_error ("unexpected element declaration content")
							Result := a_subset.count + 1
						elseif attached l_model as l_attached_model then
							if handler.wants_element_decl_default then
								emit_default (a_subset.substring (a_start_index, l_end))
							end
							if not has_error and not is_suspended then
								handler.on_element_decl (l_name, l_attached_model)
								check_handler_stop
							end
							Result := l_end + 1
						else
							set_error ("invalid element content model")
							Result := a_subset.count + 1
						end
					else
						Result := a_subset.count + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	parse_content_particle (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_top_level: BOOLEAN): INTEGER
			-- Parse content-model groups with an explicit stack, including very deep groups.
		require
			subset_attached: a_subset /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index < a_subset.count
		local
			i, name_start: INTEGER
			l_nodes: ARRAYED_STACK [XP_CONTENT_MODEL]
			l_separators: ARRAYED_STACK [CHARACTER_8]
			l_node, l_group: XP_CONTENT_MODEL
			l_result: detachable XP_CONTENT_MODEL
			l_name: STRING_8
			l_expect_child, l_done: BOOLEAN
			c, l_separator: CHARACTER_8
		do
			i := a_start_index
			parsed_content_model := Void
			if a_subset.item (i) = '(' and then has_at (a_subset, skip_spaces (a_subset, i + 1), "#PCDATA") then
				Result := parse_mixed_content_particle (a_subset, a_start_index, a_end_index, a_top_level)
			else
				create l_nodes.make (8)
				create l_separators.make (8)
				l_expect_child := True
				from
				until
					l_done or has_error
				loop
					i := skip_spaces (a_subset, i).min (a_end_index + 1)
					if i > a_end_index then
						set_error ("unterminated element content model")
					elseif l_expect_child then
						if a_subset.item (i) = '(' then
							create l_group.make ({XP_CONTENT_MODEL}.Type_sequence, {XP_CONTENT_MODEL}.Quant_none, Void)
							l_nodes.extend (l_group)
							l_separators.extend (' ')
							i := i + 1
						elseif is_name_start_character (a_subset.item (i)) then
							name_start := i
							i := scan_name (a_subset, i).min (a_end_index + 1)
							if not has_error then
								create l_name.make_from_string (a_subset.substring (name_start, i - 1))
								create l_node.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, l_name)
								i := apply_content_quantifier (l_node, a_subset, i, a_end_index)
								if l_nodes.is_empty then
									l_result := l_node
									l_done := True
								else
									l_nodes.item.add_child (l_node)
									l_expect_child := False
								end
							end
						else
							set_error ("invalid element content particle")
						end
					else
						c := a_subset.item (i)
						if c = ',' or c = '|' then
							l_separator := l_separators.item
							if l_separator = ' ' then
								l_separators.remove
								l_separators.extend (c)
								if c = '|' then
									create l_group.make ({XP_CONTENT_MODEL}.Type_choice, {XP_CONTENT_MODEL}.Quant_none, Void)
									l_group.add_child (l_nodes.item.children.first)
									l_nodes.remove
									l_nodes.extend (l_group)
								end
							elseif l_separator /= c then
								set_error ("invalid element content separator")
							end
							i := i + 1
							l_expect_child := True
						elseif c = ')' then
							l_node := l_nodes.item
							l_nodes.remove
							l_separators.remove
							i := apply_content_quantifier (l_node, a_subset, i + 1, a_end_index)
							if l_nodes.is_empty then
								l_result := l_node
								l_done := True
							else
								l_nodes.item.add_child (l_node)
							end
						else
							set_error ("invalid element content separator")
						end
					end
				end
				if has_error then
					Result := a_end_index + 1
				else
					parsed_content_model := l_result
					Result := i
				end
			end
		ensure
			result_in_bounds: Result > a_start_index and Result <= a_end_index + 1
			error_at_end: has_error implies Result = a_end_index + 1
		end

	parse_mixed_content_particle (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_top_level: BOOLEAN): INTEGER
			-- Parse one element-content particle and store it in `parsed_content_model'.
			-- Only the top-level group of a content model may be mixed content (#PCDATA).
			-- On error the result is `a_end_index + 1'.
		require
			subset_attached: a_subset /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index < a_subset.count
		local
			i: INTEGER
			name_start: INTEGER
			l_name: STRING_8
			l_node: XP_CONTENT_MODEL
			l_child: XP_CONTENT_MODEL
			l_separator: CHARACTER_8
			l_done: BOOLEAN
			l_type: INTEGER
			l_attributes: XP_ATTRIBUTES
			l_name_count: INTEGER
		do
			create l_attributes.make
			i := a_start_index
			parsed_content_model := Void
			if a_subset.item (i) = '(' then
				i := skip_spaces (a_subset, i + 1).min (a_end_index + 1)
				if has_at (a_subset, i, "#PCDATA") then
					if not a_top_level then
						set_error ("#PCDATA in a nested content group")
						i := a_end_index + 1
					else
						create l_node.make ({XP_CONTENT_MODEL}.Type_mixed, {XP_CONTENT_MODEL}.Quant_none, Void)
						i := skip_spaces (a_subset, i + 7).min (a_end_index + 1)
						from
						invariant
							index_in_bounds: i >= 1 and i <= a_end_index + 1
						until
							has_error or l_done
						loop
							if i <= a_end_index and then a_subset.item (i) = ')' then
								i := i + 1
								l_done := True
							elseif i <= a_end_index and then a_subset.item (i) = '|' then
								i := skip_spaces (a_subset, i + 1).min (a_end_index + 1)
								if i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
									name_start := i
									i := scan_name (a_subset, i).min (a_end_index + 1)
									create l_name.make_from_string (a_subset.substring (name_start, i - 1))
									create l_child.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, l_name)
									l_node.add_child (l_child)
									l_name_count := l_name_count + 1
									i := skip_spaces (a_subset, i).min (a_end_index + 1)
								else
									set_error ("invalid mixed content model")
									i := a_end_index + 1
								end
							else
								set_error ("invalid mixed content model")
								i := a_end_index + 1
							end
						variant
							a_end_index - i + 2
						end
						if not has_error then
							if i <= a_end_index and then a_subset.item (i) = '*' then
								l_node.set_quantifier ({XP_CONTENT_MODEL}.Quant_repetition)
								i := i + 1
							elseif l_name_count > 0 then
								set_error ("mixed content with element names must end with )*")
							elseif i <= a_end_index and then (a_subset.item (i) = '?' or a_subset.item (i) = '+') then
								set_error ("invalid quantifier on mixed content")
							end
						end
						if not has_error then
							parsed_content_model := l_node
						end
					end
				elseif i > a_end_index then
					set_error ("unterminated element content model")
				else
					i := parse_content_particle (a_subset, i, a_end_index, False)
					if not has_error and then attached parsed_content_model as l_first_child then
						i := skip_spaces (a_subset, i).min (a_end_index + 1)
						if i <= a_end_index and then (a_subset.item (i) = ',' or else a_subset.item (i) = '|') then
							l_separator := a_subset.item (i)
							if l_separator = ',' then
								l_type := {XP_CONTENT_MODEL}.Type_sequence
							else
								l_type := {XP_CONTENT_MODEL}.Type_choice
							end
							create l_node.make (l_type, {XP_CONTENT_MODEL}.Quant_none, Void)
							l_node.add_child (l_first_child)
							from
							invariant
								index_in_bounds: i >= 1 and i <= a_end_index + 1
							until
								has_error or l_done
							loop
								i := skip_spaces (a_subset, i + 1).min (a_end_index + 1)
								if i > a_end_index then
									set_error ("unterminated element content model")
								else
									i := parse_content_particle (a_subset, i, a_end_index, False)
								end
								if not has_error and then attached parsed_content_model as l_next_child then
									l_node.add_child (l_next_child)
									i := skip_spaces (a_subset, i).min (a_end_index + 1)
									if i <= a_end_index and then a_subset.item (i) = l_separator then
									elseif i <= a_end_index and then a_subset.item (i) = ')' then
										i := i + 1
										l_done := True
									else
										set_error ("invalid element content separator")
									end
								end
								if has_error then
									i := a_end_index + 1
								end
							variant
								a_end_index - i + 2
							end
						elseif i <= a_end_index and then a_subset.item (i) = ')' then
							create l_node.make ({XP_CONTENT_MODEL}.Type_sequence, {XP_CONTENT_MODEL}.Quant_none, Void)
							l_node.add_child (l_first_child)
							i := i + 1
						else
							set_error ("unterminated element content model")
						end
						if not has_error and then attached l_node as l_attached_node then
							i := apply_content_quantifier (l_attached_node, a_subset, i, a_end_index)
							parsed_content_model := l_attached_node
						end
					end
				end
			elseif l_attributes.is_name_start_character (a_subset.item (i)) then
				name_start := i
				i := scan_name (a_subset, i).min (a_end_index + 1)
				if not has_error then
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					create l_node.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, l_name)
					i := apply_content_quantifier (l_node, a_subset, i, a_end_index)
					parsed_content_model := l_node
				end
			else
				set_error ("invalid element content particle")
			end
			if has_error then
				parsed_content_model := Void
				Result := a_end_index + 1
			else
				Result := i
			end
		ensure
			result_in_bounds: Result > a_start_index and Result <= a_end_index + 1
			error_at_end: has_error implies Result = a_end_index + 1
		end

	apply_content_quantifier (a_model: XP_CONTENT_MODEL; a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- Apply optional quantifier at `a_start_index' and return next index.
		require
			model_attached: a_model /= Void
			subset_attached: a_subset /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_end_index + 1
		do
			Result := a_start_index
			if Result <= a_end_index then
				if a_subset.item (Result) = '?' then
					a_model.set_quantifier ({XP_CONTENT_MODEL}.Quant_optional)
					Result := Result + 1
				elseif a_subset.item (Result) = '*' then
					a_model.set_quantifier ({XP_CONTENT_MODEL}.Quant_repetition)
					Result := Result + 1
				elseif a_subset.item (Result) = '+' then
					a_model.set_quantifier ({XP_CONTENT_MODEL}.Quant_plus)
					Result := Result + 1
				end
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index + 1
		end

	parse_notation_declaration (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse a notation declaration and emit it.
		require
			subset_attached: a_subset /= Void
			starts_notation: has_at (a_subset, a_start_index, "<!NOTATION")
		local
			i: INTEGER
			l_end: INTEGER
			name_start: INTEGER
			l_name: STRING_8
			l_public_id: STRING_8
			l_system_id: STRING_8
			l_public: detachable STRING_8
			l_system: detachable STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated notation declaration")
				Result := a_subset.count + 1
			else
				i := skip_required_spaces (a_subset, a_start_index + 10, "missing space in notation declaration")
				if has_error or else i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid notation declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					if not has_error and then namespace_mode and then l_name.has (':') then
						set_error ("colon in notation name")
					end
					create l_public_id.make_empty
					create l_system_id.make_empty
					if not has_error then
						i := skip_required_spaces (a_subset, i, "missing space after notation name")
					end
					if has_error then
					elseif has_keyword_at (a_subset, i, "SYSTEM") then
						i := skip_spaces_before_literal (a_subset, i + 6, "missing space after SYSTEM")
						if not has_error and then i <= l_end - 1 and then is_quote (a_subset.item (i)) then
							i := read_quoted_literal (a_subset, i, l_end - 1, l_system_id)
							l_system := l_system_id
						else
							set_error ("missing notation system identifier")
						end
					elseif has_keyword_at (a_subset, i, "PUBLIC") then
						i := skip_spaces_before_literal (a_subset, i + 6, "missing space after PUBLIC")
						if not has_error and then i <= l_end - 1 and then is_quote (a_subset.item (i)) then
							i := read_public_id_literal (a_subset, i, l_end - 1, l_public_id)
							l_public := l_public_id
							if not has_error and then skip_spaces (a_subset, i) <= l_end - 1 and then is_quote (a_subset.item (skip_spaces (a_subset, i))) then
								i := skip_spaces_before_literal (a_subset, i, "missing space between public and system identifiers")
								if not has_error and then i <= l_end - 1 and then is_quote (a_subset.item (i)) then
									i := read_quoted_literal (a_subset, i, l_end - 1, l_system_id)
									l_system := l_system_id
								end
							end
						else
							set_error ("missing notation public identifier")
						end
					else
						set_error ("invalid notation declaration")
					end
					if not has_error then
						i := skip_spaces (a_subset, i)
						if i = l_end then
							if handler.wants_notation_decl_default then
								emit_default (a_subset.substring (a_start_index, l_end))
							end
							if not has_error and not is_suspended then
								handler.on_notation_decl (l_name, Void, l_system, l_public)
								check_handler_stop
							end
							Result := l_end + 1
						else
							set_error ("unexpected notation declaration content")
							Result := a_subset.count + 1
						end
					else
						Result := a_subset.count + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	parse_attlist_declaration (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse an attribute-list declaration and emit one callback per attribute definition.
		require
			subset_attached: a_subset /= Void
			starts_attlist: has_at (a_subset, a_start_index, "<!ATTLIST")
		local
			i: INTEGER
			l_end: INTEGER
			name_start: INTEGER
			l_element_name: STRING_8
			l_attribute_name: STRING_8
			l_attribute_type: STRING_8
			l_default_value: detachable STRING_8
			l_new_default_value: STRING_8
			l_is_required: BOOLEAN
			l_attributes: XP_ATTRIBUTES
			j: INTEGER
		do
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated attlist declaration")
				Result := a_subset.count + 1
			elseif skip_declaration_for_undefined_parameter (a_subset, a_start_index, l_end) then
				Result := l_end + 1
			else
				i := skip_required_spaces (a_subset, a_start_index + 9, "missing space in attlist declaration")
				if has_error or else i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid attlist element name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i).min (l_end)
					create l_element_name.make_from_string (a_subset.substring (name_start, i - 1))
					from
					invariant
						index_in_bounds: i >= 1 and i <= l_end
						element_name_attached: l_element_name /= Void
					until
						has_error or is_suspended or i >= l_end
					loop
							-- `i' is just after the element name or the previous attribute definition.
						j := skip_spaces (a_subset, i).min (l_end)
						if j >= l_end then
							i := l_end
						elseif j = i then
							set_error ("missing space before attribute definition")
						elseif not l_attributes.is_name_start_character (a_subset.item (j)) then
							set_error ("invalid attlist attribute name")
						else
							name_start := j
							j := scan_name (a_subset, j).min (l_end)
							create l_attribute_name.make_from_string (a_subset.substring (name_start, j - 1))
							if not has_error then
								j := skip_required_spaces (a_subset, j, "missing space before attribute type").min (l_end)
							end
							create l_attribute_type.make_empty
							if not has_error then
								if j < l_end then
									j := parse_attlist_type (a_subset, j, l_end - 1, l_attribute_type)
								else
									set_error ("missing attlist type")
								end
							end
							if not has_error then
								j := skip_required_spaces (a_subset, j, "missing space before attribute default").min (l_end)
							end
							l_default_value := Void
							l_is_required := False
							if has_error then
							elseif has_keyword_at (a_subset, j, "#REQUIRED") then
								l_is_required := True
								j := j + 9
							elseif has_keyword_at (a_subset, j, "#IMPLIED") then
								j := j + 8
							elseif has_keyword_at (a_subset, j, "#FIXED") then
								j := skip_required_spaces (a_subset, j + 6, "missing space after #FIXED").min (l_end)
								if not has_error and then j < l_end and then is_quote (a_subset.item (j)) then
									create l_new_default_value.make_empty
									j := parse_attlist_default_value (a_subset, j, l_end - 1, l_new_default_value)
									l_default_value := l_new_default_value
								else
									set_error ("missing fixed attlist default")
								end
							elseif j < l_end and then is_quote (a_subset.item (j)) then
								create l_new_default_value.make_empty
								j := parse_attlist_default_value (a_subset, j, l_end - 1, l_new_default_value)
								l_default_value := l_new_default_value
							else
								if j < l_end and then a_subset.item (j) = '#' and then j + 1 < l_end and then a_subset.item (j + 1).code < 128 then
									set_error ("invalid attlist default keyword")
								else
									set_error ("missing attlist default declaration")
								end
							end
							if not has_error and then not dtd_declarations_disabled then
								record_attribute_decl (l_element_name, l_attribute_name, l_attribute_type, l_default_value, l_is_required)
								handler.on_attlist_decl (l_element_name, l_attribute_name, l_attribute_type, l_default_value, l_is_required)
								check_handler_stop
							end
							if not has_error and then j > i and then j <= l_end then
								i := j
							end
						end
						if has_error or is_suspended then
							i := l_end
						end
					variant
						l_end - i
					end
					if has_error then
						Result := a_subset.count + 1
					else
						if dtd_declarations_disabled or else handler.wants_attlist_decl_default then
							emit_default (a_subset.substring (a_start_index, l_end))
						end
						Result := l_end + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	skip_declaration_for_undefined_parameter (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): BOOLEAN
			-- A non-validating external subset may skip declarations using unknown PEs.
		local
			i, l_end: INTEGER
			l_quote: CHARACTER_8
			l_in_quote: BOOLEAN
			l_name: STRING_8
		do
			from
				i := a_start_index
			until
				i > a_end_index or has_error or Result
			loop
				if l_in_quote then
					if a_subset.item (i) = l_quote then
						l_in_quote := False
					end
					i := i + 1
				elseif is_quote (a_subset.item (i)) then
					l_quote := a_subset.item (i)
					l_in_quote := True
					i := i + 1
				elseif a_subset.item (i).code = 37 then
					if not parsing_external_entity and then external_dtd_depth = 0 and then parameter_subset_expansion_depth = 0 then
						set_error ("parameter entity reference in internal subset declaration")
					else
						l_end := find_character (a_subset, ';', i + 1)
						if l_end > i + 1 and then l_end <= a_end_index then
							l_name := a_subset.substring (i + 1, l_end - 1).to_string_8
							if is_valid_name (l_name) and then not is_parameter_entity_declared (l_name) then
								dtd_has_parameter_entity_references := True
								dtd_declarations_disabled := not dtd_is_standalone
								Result := True
							end
						end
					end
					i := i + 1
				else
					i := i + 1
				end
			end
		end

	parse_attlist_type (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_type: STRING_8): INTEGER
			-- Parse an attribute type and append Expat-compatible spelling to `a_type'.
			-- On error the result is `a_end_index + 1'.
		require
			subset_attached: a_subset /= Void
			type_attached: a_type /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index < a_subset.count
		local
			i: INTEGER
		do
			i := a_start_index
			if has_keyword_at (a_subset, i, "NOTATION") then
				a_type.append ("NOTATION")
				i := skip_required_spaces (a_subset, i + 8, "missing space after NOTATION").min (a_end_index + 1)
				if not has_error and then i <= a_end_index and then a_subset.item (i) = '(' then
					Result := append_attlist_group (a_subset, i, a_end_index, a_type, True)
				else
					set_error ("missing notation attlist group")
				end
			elseif a_subset.item (i) = '(' then
				Result := append_attlist_group (a_subset, i, a_end_index, a_type, False)
			elseif
				has_keyword_at (a_subset, i, "CDATA") or else has_keyword_at (a_subset, i, "ID")
				or else has_keyword_at (a_subset, i, "IDREF") or else has_keyword_at (a_subset, i, "IDREFS")
				or else has_keyword_at (a_subset, i, "ENTITY") or else has_keyword_at (a_subset, i, "ENTITIES")
				or else has_keyword_at (a_subset, i, "NMTOKEN") or else has_keyword_at (a_subset, i, "NMTOKENS")
			then
				i := scan_name (a_subset, i).min (a_end_index + 1)
				a_type.append (a_subset.substring (a_start_index, i - 1))
				Result := i
			else
				set_error ("invalid attlist type")
			end
			if has_error then
				Result := a_end_index + 1
			end
		ensure
			result_in_bounds: Result > a_start_index and Result <= a_end_index + 1
		end

	append_attlist_group (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_type: STRING_8; a_names: BOOLEAN): INTEGER
			-- Parse an enumeration ('(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')') or, when `a_names',
			-- a notation group of Names, and append it to `a_type' with whitespace removed.
			-- On error the result is `a_end_index + 1'.
		require
			subset_attached: a_subset /= Void
			type_attached: a_type /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index < a_subset.count
			starts_group: a_subset.item (a_start_index) = '('
		local
			i: INTEGER
			l_token_end: INTEGER
			l_done: BOOLEAN
		do
			a_type.append_character ('(')
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				has_error or l_done
			loop
					-- `i' is at '(' or at the '|' before the next token.
				i := skip_spaces (a_subset, i + 1).min (a_end_index + 1)
				if i <= a_end_index and then (is_name_character (a_subset.item (i)) and (a_names implies is_name_start_character (a_subset.item (i)))) then
					if a_names then
						l_token_end := scan_name (a_subset, i).min (a_end_index + 1)
					else
						l_token_end := scan_nmtoken (a_subset, i).min (a_end_index + 1)
					end
					if not has_error then
						a_type.append (a_subset.substring (i, l_token_end - 1))
						i := skip_spaces (a_subset, l_token_end).min (a_end_index + 1)
						if i <= a_end_index and then a_subset.item (i) = '|' then
							a_type.append_character ('|')
						elseif i <= a_end_index and then a_subset.item (i) = ')' then
							a_type.append_character (')')
							l_done := True
						else
							set_error ("invalid attlist group separator")
						end
					end
				else
					set_error ("invalid attlist group token")
				end
				if has_error then
					i := a_end_index + 1
				end
			variant
				a_end_index - i + 1
			end
			if has_error then
				Result := a_end_index + 1
			else
				Result := i + 1
			end
		ensure
			result_in_bounds: Result > a_start_index and Result <= a_end_index + 1
		end

	scan_nmtoken (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Index immediately after the Nmtoken beginning at `a_start_index';
			-- unlike a Name, it may start with any name character.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			l_length: INTEGER
			l_stopped: BOOLEAN
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or else l_stopped
			loop
				if a_input.item (i).code >= 128 then
					l_length := utf8_character_length (a_input, i)
					if l_length > 0 and then is_name_code (last_utf8_code) then
						i := i + l_length
					else
						set_error ("invalid name character")
						l_stopped := True
					end
				elseif is_name_character (a_input.item (i)) then
					i := i + 1
				else
					l_stopped := True
				end
			variant
				a_input.count - i + 1 + (not l_stopped).to_integer
			end
			Result := i.max (a_start_index + 1)
		ensure
			progress: Result > a_start_index
			result_in_bounds: Result <= a_input.count + 1
		end

	parse_attlist_default_value (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_value: STRING_8): INTEGER
			-- Parse and normalize an attribute default literal bounded by `a_end_index'.
		require
			subset_attached: a_subset /= Void
			value_attached: a_value /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_subset.count
			starts_with_quote: is_quote (a_subset.item (a_start_index))
		local
			i: INTEGER
			l_quote: CHARACTER_8
			l_reference_end: INTEGER
			c: CHARACTER_8
		do
			l_quote := a_subset.item (a_start_index)
			from
				i := a_start_index + 1
			invariant
				index_in_bounds: i >= a_start_index + 1 and i <= a_end_index + 1
			until
				i > a_end_index or has_error or else a_subset.item (i) = l_quote
			loop
				c := a_subset.item (i)
				if c = '<' then
					set_error ("left angle bracket in attlist default")
				elseif c = '&' then
					l_reference_end := find_character (a_subset, ';', i + 1)
					if l_reference_end = 0 or else l_reference_end > a_end_index then
						set_error ("invalid reference in attlist default")
					else
						if dtd_declarations_disabled then
							i := append_reference_in_entity_value (a_subset, i, a_value)
						else
							i := append_reference_in_literal (a_subset, i, a_value)
						end
					end
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
				else
					if is_xml_space (c) then
						a_value.append_character (' ')
					else
						a_value.append_character (c)
					end
					i := i + 1
				end
				if has_error or i > a_end_index then
					i := a_end_index + 1
				end
			variant
				a_end_index - i + 1
			end
			if not has_error and then i > a_end_index then
				set_error ("unterminated attlist default")
			end
			if has_error then
				Result := a_end_index + 1
			else
				Result := i + 1
			end
		ensure
			result_in_bounds: Result > a_start_index and Result <= a_end_index + 1
		end

	record_attribute_decl (a_element_name, a_attribute_name, a_attribute_type: READABLE_STRING_8; a_default_value: detachable READABLE_STRING_8; a_is_required: BOOLEAN)
			-- Retain first binding for an attribute declaration.
		require
			valid_element_name: is_valid_name (a_element_name)
			valid_attribute_name: is_valid_name (a_attribute_name)
			attribute_type_attached: a_attribute_type /= Void
			attribute_type_not_empty: not a_attribute_type.is_empty
		local
			l_element_name: STRING_8
			l_decls: ARRAYED_LIST [XP_ATTRIBUTE_DECL]
			l_decl: XP_ATTRIBUTE_DECL
		do
			create l_element_name.make_from_string (a_element_name)
			if attached attribute_decl_table.item (l_element_name) as l_existing_decls then
				l_decls := l_existing_decls
			else
				create l_decls.make (4)
				attribute_decl_table.put (l_decls, l_element_name)
			end
			if not has_attribute_decl (l_decls, a_attribute_name) then
				create l_decl.make (a_attribute_name, a_attribute_type, a_default_value, a_is_required)
				l_decls.extend (l_decl)
			end
		end

	has_attribute_decl (a_decls: ARRAYED_LIST [XP_ATTRIBUTE_DECL]; a_attribute_name: READABLE_STRING_8): BOOLEAN
			-- Does `a_decls' already bind `a_attribute_name'?
		require
			decls_attached: a_decls /= Void
			valid_attribute_name: is_valid_name (a_attribute_name)
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_decls.count + 1
			until
				i > a_decls.count or Result
			loop
				if a_decls.i_th (i).name.same_string (a_attribute_name) then
					Result := True
					i := a_decls.count + 1
				else
					i := i + 1
				end
			variant
				a_decls.count - i + 1
			end
		end

	apply_default_attributes (a_element_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
			-- Add DTD default attributes for `a_element_name' when absent.
		require
			valid_element_name: is_valid_name (a_element_name)
			attributes_attached: a_attributes /= Void
		local
			l_element_name: STRING_8
			i: INTEGER
			l_decl: XP_ATTRIBUTE_DECL
		do
			create l_element_name.make_from_string (a_element_name)
			if attached attribute_decl_table.item (l_element_name) as l_decls then
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= l_decls.count + 1
				until
					i > l_decls.count or has_error
				loop
					l_decl := l_decls.i_th (i)
					if l_decl.is_id and then a_attributes.has (l_decl.name) then
						a_attributes.mark_id_attribute (l_decl.name)
					end
					if not l_decl.attribute_type.same_string ("CDATA") and then attached a_attributes.item (l_decl.name) as l_value then
							-- Attribute-value normalization for declared non-CDATA types (XML 1.0 section 3.3.3).
						collapse_spaces (l_value)
					end
					if attached l_decl.default_value as l_default_value and then not a_attributes.has (l_decl.name) then
						if a_attributes.count >= max_attribute_count then
							set_error ("attribute count exceeds limit")
						else
							a_attributes.put_default (l_decl.name, l_default_value)
							if l_decl.is_id then
								a_attributes.mark_id_attribute (l_decl.name)
							end
						end
					end
					i := i + 1
				variant
					l_decls.count - i + 1
				end
			end
		end

	collapse_spaces (a_value: STRING_8)
			-- Remove leading and trailing spaces from `a_value' and replace each run of spaces by one.
		require
			value_attached: a_value /= Void
		local
			i: INTEGER
			j: INTEGER
		do
			from
				i := 1
				j := 0
			invariant
				read_index_in_bounds: i >= 1 and i <= a_value.count + 1
				write_index_behind: j < i
			until
				i > a_value.count
			loop
				if a_value.item (i) /= ' ' or else (j > 0 and then a_value.item (j) /= ' ') then
					j := j + 1
					a_value.put (a_value.item (i), j)
				end
				i := i + 1
			variant
				a_value.count - i + 1
			end
			if j > 0 and then a_value.item (j) = ' ' then
				j := j - 1
			end
			a_value.keep_head (j)
		ensure
			no_leading_space: not a_value.is_empty implies a_value.item (1) /= ' '
			no_trailing_space: not a_value.is_empty implies a_value.item (a_value.count) /= ' '
		end

	parse_entity_declaration (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse an internal-subset entity declaration.
		require
			subset_attached: a_subset /= Void
			starts_entity: has_at (a_subset, a_start_index, "<!ENTITY")
		local
			i: INTEGER
			l_end: INTEGER
			name_start: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_is_parameter: BOOLEAN
			l_quote: CHARACTER_8
			l_attributes: XP_ATTRIBUTES
			l_existing_parameter: BOOLEAN
			l_name_end: INTEGER
			l_literal_start: INTEGER
			l_literal_end: INTEGER
			l_accounting_count: INTEGER
			l_default_entity_unparsed: BOOLEAN
			l_process_entity: BOOLEAN
		do
			l_process_entity := not dtd_declarations_disabled
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated entity declaration")
				Result := a_subset.count + 1
			else
				i := skip_required_spaces (a_subset, a_start_index + 8, "missing space in entity declaration")
				if not has_error and then i <= a_subset.count and then a_subset.item (i).code = 37 then
					l_is_parameter := True
					i := skip_required_spaces (a_subset, i + 1, "missing space after %% in entity declaration")
				end
				if has_error or else i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid entity declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					l_name_end := i - 1
					create l_name.make_from_string (a_subset.substring (name_start, l_name_end))
					if not has_error and then namespace_mode and then l_name.has (':') then
						set_error ("colon in entity name")
					end
					if not has_error then
						i := skip_required_spaces (a_subset, i, "missing space after entity name")
					end
					if has_error then
						Result := a_subset.count + 1
					elseif i <= a_subset.count and then is_quote (a_subset.item (i)) then
						l_quote := a_subset.item (i)
						l_literal_start := i
						create l_value.make_empty
						current_entity_literal_accounting_adjustment := 0
						l_existing_parameter := l_is_parameter and then is_parameter_entity_declared (l_name)
						if not l_process_entity then
							i := read_quoted_literal (a_subset, i, l_end, l_value) - 1
						elseif l_is_parameter and then not l_existing_parameter then
							push_entity (l_name)
							i := parse_entity_literal (a_subset, i + 1, l_quote, l_value)
							pop_entity
						else
							i := parse_entity_literal (a_subset, i + 1, l_quote, l_value)
						end
						l_literal_end := i
						l_accounting_count := l_value.count + current_entity_literal_accounting_adjustment
						current_entity_literal_accounting_adjustment := 0
						if not has_error and then skip_spaces (a_subset, l_literal_end + 1) /= l_end then
								-- Only one literal, and no NDATA or other content, may follow the name.
							set_error ("unexpected entity declaration content")
						end
						if not has_error then
							if not l_process_entity then
							elseif l_is_parameter then
								put_parameter_entity (l_name, l_value, l_accounting_count)
							else
								put_general_entity (l_name, l_value)
							end
							if not l_process_entity or else handler.wants_entity_decl_default (False) then
								emit_internal_entity_declaration_default (a_subset, a_start_index, name_start, l_name_end, l_literal_start, l_literal_end, l_end)
							end
							if l_process_entity and then not has_error and then not is_suspended then
								handler.on_entity_decl (l_name, l_is_parameter, l_value, Void, Void, Void)
								check_handler_stop
							end
							Result := l_end + 1
						else
							Result := a_subset.count + 1
						end
					else
						Result := parse_external_entity_declaration (a_subset, i, l_end, l_name, l_is_parameter)
						if not l_is_parameter and then attached external_entity (l_name) as l_external then
							l_default_entity_unparsed := l_external.is_unparsed
						end
						if not has_error and not is_suspended and then (not l_process_entity or else handler.wants_entity_decl_default (l_default_entity_unparsed)) then
							emit_default (a_subset.substring (a_start_index, Result - 1))
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	parse_external_entity_declaration (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_name: READABLE_STRING_8; a_is_parameter: BOOLEAN): INTEGER
			-- Parse external ID and optional NDATA for entity `a_name'.
		require
			subset_attached: a_subset /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_subset.count
			valid_name: is_valid_name (a_name)
		local
			i: INTEGER
			l_public_id: STRING_8
			l_system_id: STRING_8
			l_notation_name: STRING_8
			l_is_unparsed: BOOLEAN
			name_start: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			create l_public_id.make_empty
			create l_system_id.make_empty
			create l_notation_name.make_empty
			create l_attributes.make
			i := a_start_index
			if has_keyword_at (a_subset, i, "SYSTEM") then
				i := skip_spaces_before_literal (a_subset, i + 6, "missing space after SYSTEM")
				if not has_error and then i <= a_end_index and then is_quote (a_subset.item (i)) then
					i := read_quoted_literal (a_subset, i, a_end_index, l_system_id)
				else
					set_error ("missing external system identifier")
				end
			elseif has_keyword_at (a_subset, i, "PUBLIC") then
				i := skip_spaces_before_literal (a_subset, i + 6, "missing space after PUBLIC")
				if not has_error and then i <= a_end_index and then is_quote (a_subset.item (i)) then
					i := read_public_id_literal (a_subset, i, a_end_index, l_public_id)
					if not has_error then
						i := skip_spaces_before_literal (a_subset, i, "missing space between public and system identifiers")
						if not has_error and then i <= a_end_index and then is_quote (a_subset.item (i)) then
							i := read_quoted_literal (a_subset, i, a_end_index, l_system_id)
						else
							set_error ("missing external system identifier")
						end
					end
				else
					set_error ("missing external public identifier")
				end
			else
				set_error ("invalid external entity declaration")
			end
			if not has_error and then i <= a_end_index then
				name_start := i
				i := skip_spaces (a_subset, i)
				if not a_is_parameter and then i < a_end_index and then has_keyword_at (a_subset, i, "NDATA") then
					if i = name_start then
						set_error ("missing space before NDATA")
					end
					l_is_unparsed := True
					if not has_error then
						i := skip_required_spaces (a_subset, i + 5, "missing space after NDATA")
					end
					if not has_error and then i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
						name_start := i
						i := scan_name (a_subset, i)
						l_notation_name.append (a_subset.substring (name_start, i - 1))
						i := skip_spaces (a_subset, i)
					else
						set_error ("missing notation name")
					end
				end
			end
			if not has_error then
				if i /= a_end_index then
					set_error ("unexpected external entity declaration content")
					Result := a_subset.count + 1
				else
					if not dtd_declarations_disabled then
						put_external_entity (a_name, l_public_id, l_system_id, l_notation_name, a_is_parameter, l_is_unparsed)
						handler.on_entity_decl (a_name, a_is_parameter, Void, optional_string (l_public_id), optional_string (l_system_id), optional_string (l_notation_name))
						check_handler_stop
						if l_is_unparsed then
							handler.on_unparsed_entity_decl (a_name, l_system_id, optional_string (l_public_id), optional_string (l_notation_name))
							check_handler_stop
						end
					end
					Result := a_end_index + 1
				end
			else
				Result := a_subset.count + 1
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	parse_entity_literal (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_quote: CHARACTER_8; a_value: STRING_8): INTEGER
			-- Parse an entity value literal, expanding character and parameter references.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
			quote_valid: is_quote (a_quote)
			value_attached: a_value /= Void
		local
			i: INTEGER
			c: CHARACTER_8
		do
			entity_literal_ended_by_undefined_parameter := False
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or has_error or entity_literal_ended_by_undefined_parameter or else a_input.item (i) = a_quote
			loop
				c := a_input.item (i)
				if c = '&' then
					i := append_reference_in_entity_value (a_input, i, a_value)
				elseif c.code = 37 then
					i := append_parameter_reference_in_entity_value (a_input, i, a_value)
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					a_value.append_character (c)
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
			if not has_error then
				if entity_literal_ended_by_undefined_parameter then
					i := find_character (a_input, a_quote, i)
					if i = 0 then
						i := a_input.count + 1
					end
				end
				if i > a_input.count then
					set_error ("unterminated entity literal")
					Result := a_input.count + 1
				else
					Result := i
				end
			else
				Result := a_input.count + 1
			end
		ensure
			result_in_bounds: Result <= a_input.count + 1
		end

	append_reference_in_entity_value (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_text: STRING_8): INTEGER
			-- Expand character references and bypass general references in an entity value.
		require
			input_attached: a_input /= Void
			starts_reference: a_input.item (a_start_index) = '&'
			text_attached: a_text /= Void
		local
			l_end: INTEGER
			l_name: STRING_8
		do
			l_end := find_character (a_input, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated reference")
				Result := a_input.count + 1
			elseif a_start_index + 1 >= l_end then
				set_error ("empty reference")
				Result := a_input.count + 1
			elseif a_input.item (a_start_index + 1) = '#' then
				append_character_reference (a_input.substring (a_start_index + 2, l_end - 1), a_text)
				Result := l_end + 1
			else
				create l_name.make_from_string (a_input.substring (a_start_index + 1, l_end - 1))
				if not is_valid_name (l_name) then
					set_error ("invalid entity name")
					Result := a_input.count + 1
				else
					a_text.append (a_input.substring (a_start_index, l_end))
					Result := l_end + 1
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	append_parameter_entity_literal (a_name: READABLE_STRING_8; a_text: STRING_8)
			-- Expand parameter replacement text without recursion for linear alias chains.
		local
			l_name: STRING_8
			l_seen: HASH_TABLE [BOOLEAN, STRING_8]
			l_done: BOOLEAN
			i, l_output_start, l_accounting_start, l_adjustment: INTEGER
		do
			l_output_start := a_text.count
			l_accounting_start := expanded_entity_bytes
			l_adjustment := current_entity_literal_accounting_adjustment
			create l_name.make_from_string (a_name)
			create l_seen.make (8)
			from
			until
				l_done or has_error
			loop
				if is_entity_active (l_name) or else l_seen.has (l_name) then
					set_error ("recursive entity reference")
				elseif attached parameter_entity_value (l_name) as l_value then
					l_seen.force (True, l_name)
					note_entity_expansion (parameter_entity_accounting_value (l_name))
					if not has_error then
						if attached single_entity_reference_name (l_value, '%%') as l_next and then attached parameter_entity_value (l_next) then
							l_name := l_next
						elseif entity_stack.count >= Default_max_entity_depth then
							set_error ("entity expansion depth exceeded")
						else
							push_entity (l_name)
							from
								i := 1
							until
								i > l_value.count or has_error or entity_literal_ended_by_undefined_parameter
							loop
								if l_value.item (i).code = 37 then
									i := append_parameter_reference_in_entity_value (l_value, i, a_text)
								else
									a_text.append_character (l_value.item (i))
									i := i + 1
								end
							end
							pop_entity
							l_done := True
						end
					end
				else
					set_error ("undefined parameter entity")
				end
			end
			current_entity_literal_accounting_adjustment := l_adjustment + expanded_entity_bytes - l_accounting_start - (a_text.count - l_output_start)
		end

	append_parameter_reference_in_entity_value (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_text: STRING_8): INTEGER
			-- Expand parameter entity reference in an entity value.
		require
			input_attached: a_input /= Void
			starts_reference: a_input.item (a_start_index).code = 37
			text_attached: a_text /= Void
		local
			l_end: INTEGER
			l_name: STRING_8
		do
			l_end := find_character (a_input, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated parameter entity reference")
				Result := a_input.count + 1
			else
				create l_name.make_from_string (a_input.substring (a_start_index + 1, l_end - 1))
				if not is_valid_name (l_name) then
					set_error ("invalid parameter entity name")
					Result := a_input.count + 1
				elseif not parsing_external_entity and then external_dtd_depth = 0 and then parameter_subset_expansion_depth = 0 then
						-- WFC "PEs in Internal Subset": not inside markup declarations there.
					set_error ("parameter entity reference in internal subset declaration")
					Result := a_input.count + 1
				elseif is_entity_active (l_name) then
					set_error ("recursive entity reference")
					Result := a_input.count + 1
				elseif attached parameter_entity_value (l_name) then
					append_parameter_entity_literal (l_name, a_text)
					Result := l_end + 1
				elseif attached external_parameter_entity (l_name) as l_external then
					append_external_parameter_entity_in_literal (l_external, a_text)
					if has_error then
						Result := a_input.count + 1
					else
						Result := l_end + 1
					end
				else
					dtd_has_parameter_entity_references := True
					dtd_declarations_disabled := not dtd_is_standalone
					entity_literal_ended_by_undefined_parameter := True
					Result := l_end + 1
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end


	resolved_parameter_entity_name (a_name: READABLE_STRING_8): STRING_8
			-- Collapse pure subset aliases, charging each link without a recursive frame.
		local
			l_seen: HASH_TABLE [BOOLEAN, STRING_8]
			l_done: BOOLEAN
		do
			create Result.make_from_string (a_name)
			create l_seen.make (8)
			from
			until
				l_done or has_error
			loop
				if l_seen.has (Result) or else is_entity_active (Result) then
					set_error ("recursive entity reference")
				elseif attached parameter_entity_value (Result) as l_value and then attached single_entity_reference_name (l_value, '%%') as l_next and then attached parameter_entity_value (l_next) then
					l_seen.force (True, Result)
					note_entity_expansion (parameter_entity_accounting_value (Result))
					Result := l_next
				else
					l_done := True
				end
			end
		end

	include_parameter_entity_in_subset (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Include a parameter entity reference in the internal subset.
		require
			subset_attached: a_subset /= Void
			starts_reference: a_subset.item (a_start_index).code = 37
		local
			l_end: INTEGER
			l_name: STRING_8
			l_previous_reference_position: INTEGER
		do
			dtd_has_parameter_entity_references := True
			l_end := find_character (a_subset, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated parameter entity reference")
				Result := a_subset.count + 1
			else
				create l_name.make_from_string (a_subset.substring (a_start_index + 1, l_end - 1))
				if is_valid_name (l_name) then
					l_name := resolved_parameter_entity_name (l_name)
				end
				if not is_valid_name (l_name) then
					set_error ("invalid parameter entity name")
					Result := a_subset.count + 1
				elseif has_error then
					Result := a_subset.count + 1
				elseif is_entity_active (l_name) then
					set_error ("recursive entity reference")
					Result := a_subset.count + 1
				elseif entity_stack.count >= Default_max_entity_depth then
					set_error ("entity expansion depth exceeded")
					Result := a_subset.count + 1
				elseif attached parameter_entity_value (l_name) as l_value then
					note_entity_expansion (parameter_entity_accounting_value (l_name))
					if not has_error then
						push_entity (l_name)
						l_previous_reference_position := dtd_entity_reference_position
						if dtd_entity_reference_position = 0 then
							dtd_entity_reference_position := dtd_subset_position_offset + a_start_index
						end
						parameter_subset_expansion_depth := parameter_subset_expansion_depth + 1
						process_internal_subset (l_value)
						parameter_subset_expansion_depth := parameter_subset_expansion_depth - 1
						dtd_entity_reference_position := l_previous_reference_position
						pop_entity
					end
					if has_error then
						Result := a_subset.count + 1
					else
						Result := l_end + 1
					end
				elseif attached external_parameter_entity (l_name) as l_external then
					push_entity (l_name)
					include_external_parameter_entity_in_subset (l_external)
					pop_entity
					if has_error then
						Result := a_subset.count + 1
					else
						Result := l_end + 1
					end
				else
					if not parsing_external_entity and then external_dtd_depth = 0 and then parameter_subset_expansion_depth = 0 and then dtd_is_standalone then
						set_error ("undefined entity")
						Result := a_subset.count + 1
					else
						dtd_declarations_disabled := not dtd_is_standalone
						handler.on_skipped_entity (l_name, True)
						check_handler_stop
						Result := l_end + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

feature {NONE} -- Event dispatch

	can_use_element_name_slices: BOOLEAN
			-- Can the current parse state keep open element names as input slices?
		do
			Result :=
				not namespace_mode
				and then not handler.wants_start_element_events
				and then not handler.wants_end_element_events
				and then not handler.wants_character_data_events
				and then not handler.wants_automatic_character_data_default
				and then not handler.wants_default_events
				and then not use_foreign_dtd
				-- A DOCTYPE alone needs no materialization for a pure no-op sink.
				-- Keep callbacks, raw replacement buffers and larger attribute limits
				-- on their existing path, including ownership and diagnostic behavior.
				and then (doctype_name.is_empty or else
					(handler.generating_type.type_id = ({detachable XP_NULL_EVENT_HANDLER}).type_id
					and then external_entity_resolver = Void
					and then entity_stack.is_empty
					and then max_attribute_count <= Default_max_attribute_count))
				and then attribute_decl_table.count = 0
				and then element_slice_stack.count = element_stack.count
		end

	can_defer_position_accounting: BOOLEAN
			-- Can this parse defer line/column accounting until an error or final query?
		do
			Result :=
				not handler.requires_eager_position_accounting
				and then not handler.wants_start_element_events
				and then not handler.wants_end_element_events
				and then not handler.wants_character_data_events
				and then not handler.wants_automatic_character_data_default
				and then not handler.wants_default_events
				and then not handler.reports_skipped_internal_general_entities
		end

	open_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
			-- Push `a_name' and emit start-element event.
		require
			name_attached: a_name /= Void
			attributes_attached: a_attributes /= Void
			attributes_bounded: a_attributes.count <= max_attribute_count
		local
			l_name: STRING_8
			l_event_name: detachable STRING_8
			l_event_attributes: detachable XP_ATTRIBUTES
			l_namespace_scope: detachable HASH_TABLE [STRING_8, STRING_8]
			l_namespace_prefixes: detachable ARRAYED_LIST [STRING_8]
			l_wants_start_events: BOOLEAN
		do
			l_wants_start_events := handler.wants_start_element_events
			if l_wants_start_events then
				create l_event_name.make_from_string (a_name)
				l_event_attributes := a_attributes
			end
			if element_stack.count >= max_element_depth then
				set_error ("maximum element depth exceeded")
			elseif element_stack.count = 0 and then document_element_count > 0 and then not parsing_external_entity then
				set_error ("multiple document elements")
				-- A root element whose name differs from the DOCTYPE name violates only the
				-- "Root Element Type" validity constraint, so a non-validating parser accepts it.
			else
				if element_stack.count = 0 then
					document_element_count := document_element_count + 1
				end
				apply_default_attributes (a_name, a_attributes)
				if not has_error then
					if namespace_mode then
						create l_namespace_prefixes.make (4)
						l_namespace_scope := namespace_scope_for_element (a_attributes, l_namespace_prefixes)
						if not has_error then
							if attached l_namespace_scope as l_attached_scope then
									-- Always resolved: an unbound or reserved prefix is an error even without events.
								l_event_name := expanded_element_name (a_name, l_attached_scope)
								if not l_wants_start_events then
									l_event_name := Void
								end
							else
								check namespace_scope_available: False end
							end
						end
						if not has_error then
							if attached l_namespace_scope as l_attached_scope then
								l_event_attributes := expanded_attributes (a_attributes, l_attached_scope)
								if not l_wants_start_events then
									l_event_attributes := Void
								end
							else
								check namespace_scope_available: False end
							end
						end
					else
						if l_wants_start_events then
							l_event_attributes := a_attributes
						end
					end
				end
				if not has_error then
					create l_name.make_from_string (a_name)
					element_stack.extend (l_name)
					if namespace_mode then
						if attached l_namespace_scope as l_attached_scope and then attached l_namespace_prefixes as l_attached_prefixes then
							namespace_context_stack.extend (l_attached_scope)
							namespace_declaration_stack.extend (l_attached_prefixes)
							emit_start_namespace_declarations (l_attached_prefixes, l_attached_scope)
						else
							check namespace_state_available: False end
						end
					end
				end
				if not has_error and not is_suspended and l_wants_start_events then
					if attached l_event_name as l_attached_event_name and then attached l_event_attributes as l_attached_event_attributes then
						handler.on_start_element (l_attached_event_name, l_attached_event_attributes)
						check_handler_stop
					else
						check event_state_available: False end
					end
				end
			end
		ensure
			pushed_or_error: (not has_error) implies element_stack.count = old element_stack.count + 1
			depth_bounded: element_stack.count <= max_element_depth
		end

	open_element_range (a_input: READABLE_STRING_8; a_name_start, a_name_end: INTEGER)
			-- Push an element name represented as a range in `a_input' without materializing it.
		require
			input_attached: a_input /= Void
			start_valid: a_name_start >= 1 and a_name_start <= a_input.count
			end_valid: a_name_end >= a_name_start and a_name_end <= a_input.count
			slice_path_available: can_use_element_name_slices
		local
			l_name: XP_TOKEN_SLICE
		do
			if element_stack.count >= max_element_depth then
				set_error ("maximum element depth exceeded")
			elseif element_stack.count = 0 and then document_element_count > 0 and then not parsing_external_entity then
				set_error ("multiple document elements")
			else
				if element_stack.count = 0 then
					document_element_count := document_element_count + 1
				end
				create l_name.make (a_input, a_name_start, a_name_end - a_name_start + 1)
				element_slice_stack.extend (l_name)
				element_stack.extend (element_stack_marker)
			end
		ensure
			pushed_or_error: (not has_error) implies element_stack.count = old element_stack.count + 1
			slice_pushed_or_error: (not has_error) implies element_slice_stack.count = old element_slice_stack.count + 1
			depth_bounded: element_stack.count <= max_element_depth
		end

	close_element (a_name: READABLE_STRING_8)
			-- Pop `a_name' and emit end-element event.
		require
			name_attached: a_name /= Void
		local
			l_event_name: detachable STRING_8
			l_wants_end_events: BOOLEAN
		do
			l_wants_end_events := handler.wants_end_element_events
			if element_stack.count = 0 then
				set_error ("unexpected end tag")
			elseif element_stack.count <= entity_element_floor then
					-- WFC "Parsed Entity": an entity may not close an element opened outside it.
				note_current_entity_reference_position
				set_error ("asynchronous entity")
			elseif not open_element_matches_string (a_name) then
				set_error ("mismatched end tag")
			else
				if l_wants_end_events then
					if namespace_mode then
						l_event_name := expanded_element_name (a_name, namespace_context_stack.item)
					else
						create l_event_name.make_from_string (a_name)
					end
				end
				pop_open_element
				if not has_error and l_wants_end_events then
					check attached l_event_name as l_attached_event_name then
						handler.on_end_element (l_attached_event_name)
						check_handler_stop
					end
				end
				if namespace_mode then
					emit_end_namespace_declarations
				end
			end
		ensure
			popped_or_error: (not has_error) implies element_stack.count = old element_stack.count - 1
		end

	close_element_range (a_input: READABLE_STRING_8; a_name_start, a_name_end: INTEGER)
			-- Pop an end tag name represented as a range in `a_input' without materializing it.
		require
			input_attached: a_input /= Void
			start_valid: a_name_start >= 1 and a_name_start <= a_input.count
			end_valid: a_name_end >= a_name_start and a_name_end <= a_input.count
		do
			if element_stack.count = 0 then
				set_error ("unexpected end tag")
			elseif element_stack.count <= entity_element_floor then
				note_current_entity_reference_position
				set_error ("asynchronous entity")
			elseif not open_element_matches_range (a_input, a_name_start, a_name_end) then
				set_error ("mismatched end tag")
			else
				pop_open_element
			end
		ensure
			popped_or_error: (not has_error) implies element_stack.count = old element_stack.count - 1
		end

	open_element_matches_range (a_input: READABLE_STRING_8; a_name_start, a_name_end: INTEGER): BOOLEAN
			-- Does the current open element match `a_input [a_name_start..a_name_end]'?
		require
			input_attached: a_input /= Void
			start_valid: a_name_start >= 1 and a_name_start <= a_input.count
			end_valid: a_name_end >= a_name_start and a_name_end <= a_input.count
			has_open_element: element_stack.count > 0
		do
			if element_slice_stack.count = element_stack.count then
				Result := element_slice_stack.item.same_range (a_input, a_name_start, a_name_end - a_name_start + 1)
			else
				Result := input_range_same_string (a_input, a_name_start, a_name_end, element_stack.item)
			end
		end

	open_element_matches_string (a_name: READABLE_STRING_8): BOOLEAN
			-- Does the current open element match `a_name'?
		require
			name_attached: a_name /= Void
			has_open_element: element_stack.count > 0
		do
			if element_slice_stack.count = element_stack.count then
				Result := element_slice_stack.item.same_string (a_name)
			else
				Result := element_stack.item.same_string (a_name)
			end
		end

	pop_open_element
			-- Pop current element name from the active stack representation.
		require
			has_open_element: element_stack.count > 0
		do
			if element_slice_stack.count = element_stack.count then
				element_slice_stack.remove
			end
			element_stack.remove
		ensure
			one_less_element: element_stack.count = old element_stack.count - 1
			slice_not_above_element_stack: element_slice_stack.count <= element_stack.count
		end

	emit_text (a_text: READABLE_STRING_8)
			-- Emit character data.
		require
			text_attached: a_text /= Void
			text_within_limit: a_text.count <= max_token_length
		do
			if handler.wants_character_data_events and then a_text.count > 0 then
				handler.on_character_data (a_text)
				check_handler_stop
			end
		end

	emit_default (a_text: READABLE_STRING_8)
			-- Emit raw default-handler text.
		require
			text_attached: a_text /= Void
		do
			if handler.wants_default_events and then not a_text.is_empty then
				handler.on_default (a_text)
				check_handler_stop
			end
		end

	emit_default_range (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER)
			-- Emit raw default-handler text for `a_input [a_start_index..a_end_index]'.
		require
			input_attached: a_input /= Void
			start_valid: a_start_index >= 1
			end_valid: a_end_index <= a_input.count
		do
			if handler.wants_default_events and then a_start_index <= a_end_index then
				emit_default (a_input.substring (a_start_index, a_end_index))
			end
		end

	emit_doctype_default_open (a_input: READABLE_STRING_8; a_start_index, a_name_start, a_name_end, a_subset_start, a_doctype_end: INTEGER)
			-- Emit Expat-shaped default-handler chunks before a doctype subset.
		require
			input_attached: a_input /= Void
			starts_doctype: has_at (a_input, a_start_index, "<!DOCTYPE")
			valid_name: a_name_start >= a_start_index + 9 and a_name_end >= a_name_start and a_name_end <= a_input.count
			valid_end: a_doctype_end <= a_input.count
		do
			emit_default_range (a_input, a_start_index, a_start_index + 8)
			if not has_error and not is_suspended then
				emit_default_range (a_input, a_start_index + 9, a_name_start - 1)
			end
			if not has_error and not is_suspended then
				emit_default_range (a_input, a_name_start, a_name_end)
			end
			if not has_error and not is_suspended then
				if a_subset_start > 0 then
					emit_doctype_default_tail (a_input, a_name_end + 1, a_subset_start - 1)
					if not has_error and not is_suspended then
						emit_default_range (a_input, a_subset_start, a_subset_start)
					end
				else
					emit_doctype_default_tail (a_input, a_name_end + 1, a_doctype_end - 1)
				end
			end
		end

	emit_doctype_default_tail (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER)
			-- Emit names, whitespace and complete quoted external identifiers separately.
		local
			i, l_end: INTEGER
			l_quote: CHARACTER_8
		do
			from
				i := a_start_index
			until
				i > a_end_index or has_error or is_suspended
			loop
				if is_quote (a_input.item (i)) then
					l_quote := a_input.item (i)
					l_end := find_character (a_input, l_quote, i + 1)
					if l_end = 0 or l_end > a_end_index then
						l_end := a_end_index
					end
				elseif is_xml_space (a_input.item (i)) then
					l_end := skip_spaces (a_input, i).min (a_end_index + 1) - 1
				else
					from
						l_end := i
					until
						l_end >= a_end_index or else is_xml_space (a_input.item (l_end + 1)) or else is_quote (a_input.item (l_end + 1))
					loop
						l_end := l_end + 1
					end
				end
				emit_default_range (a_input, i, l_end)
				i := l_end + 1
			end
		end

	emit_doctype_default_close (a_has_internal_subset: BOOLEAN)
			-- Emit Expat-shaped default-handler chunks at the end of a doctype.
		do
			if a_has_internal_subset then
				emit_default ("]")
			end
			if not has_error and not is_suspended then
				emit_default (">")
			end
		end

	emit_internal_entity_declaration_default (a_subset: READABLE_STRING_8; a_start_index, a_name_start, a_name_end, a_literal_start, a_literal_end, a_declaration_end: INTEGER)
			-- Emit Expat-shaped default-handler chunks for an internal ENTITY declaration.
		require
			subset_attached: a_subset /= Void
			starts_entity: has_at (a_subset, a_start_index, "<!ENTITY")
			valid_name: a_name_start >= a_start_index + 8 and a_name_end >= a_name_start
			valid_literal: a_literal_start > a_name_end and a_literal_end >= a_literal_start
			valid_end: a_declaration_end <= a_subset.count
		do
			emit_default_range (a_subset, a_start_index, a_start_index + 7)
			if not has_error and not is_suspended then
				emit_default_range (a_subset, a_start_index + 8, a_name_start - 1)
			end
			if not has_error and not is_suspended then
				emit_default_range (a_subset, a_name_start, a_name_end)
			end
			if not has_error and not is_suspended then
				emit_default_range (a_subset, a_name_end + 1, a_literal_start - 1)
			end
			if not has_error and not is_suspended then
				emit_default_range (a_subset, a_literal_start, a_literal_end)
			end
			if not has_error and not is_suspended then
				emit_default_range (a_subset, a_literal_end + 1, a_declaration_end)
			end
		end

feature {NONE} -- Namespace handling

	namespace_scope_for_element (a_attributes: XP_ATTRIBUTES; a_declared_prefixes: ARRAYED_LIST [STRING_8]): HASH_TABLE [STRING_8, STRING_8]
			-- Namespace bindings in scope for a start tag after applying namespace declarations.
		require
			attributes_attached: a_attributes /= Void
			prefixes_attached: a_declared_prefixes /= Void
		local
			i: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_prefix: STRING_8
		do
			Result := cloned_namespace_scope (namespace_context_stack.item)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_attributes.count + 1
			until
				i > a_attributes.count or has_error
			loop
				l_name := a_attributes.i_th_name (i)
				if is_namespace_declaration_name (l_name) then
					l_value := a_attributes.i_th_value (i)
					l_prefix := namespace_declaration_prefix (l_name)
					validate_namespace_declaration (l_prefix, l_value)
					if not has_error then
						Result.force (l_value.twin, l_prefix.twin)
						a_declared_prefixes.extend (l_prefix.twin)
					end
				end
				i := i + 1
			variant
				a_attributes.count - i + 1
			end
		ensure
			result_attached: Result /= Void
		end

	expanded_attributes (a_attributes: XP_ATTRIBUTES; a_scope: HASH_TABLE [STRING_8, STRING_8]): XP_ATTRIBUTES
			-- Attribute vector with namespace declarations removed and prefixed names expanded.
		require
			attributes_attached: a_attributes /= Void
			scope_attached: a_scope /= Void
		local
			i: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_expanded_name: STRING_8
		do
			create Result.make
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_attributes.count + 1
				result_bounded: Result.count <= a_attributes.count
			until
				i > a_attributes.count or has_error
			loop
				l_name := a_attributes.i_th_name (i)
				if not is_namespace_declaration_name (l_name) then
					l_value := a_attributes.i_th_value (i)
					l_expanded_name := expanded_attribute_name (l_name, a_scope)
					if not has_error then
						if Result.has (l_expanded_name) then
							set_error ("duplicate attribute")
						else
							if i <= a_attributes.specified_attribute_count then
								Result.put (l_expanded_name, l_value)
							else
								Result.put_default (l_expanded_name, l_value)
							end
							if a_attributes.id_attribute_index = (i - 1) * 2 then
								Result.mark_id_attribute (l_expanded_name)
							end
						end
					end
				end
				i := i + 1
			variant
				a_attributes.count - i + 1
			end
		ensure
			result_attached: Result /= Void
		end

	expanded_element_name (a_name: READABLE_STRING_8; a_scope: HASH_TABLE [STRING_8, STRING_8]): STRING_8
			-- Element name reported through namespace-aware callbacks.
		require
			name_attached: a_name /= Void
			scope_attached: a_scope /= Void
		local
			l_colon: INTEGER
			l_prefix: STRING_8
			l_local_name: STRING_8
		do
			l_colon := a_name.index_of (':', 1)
			if l_colon = 0 then
				if attached a_scope.item ("") as l_uri and then not l_uri.is_empty then
					create l_prefix.make_empty
					create l_local_name.make_from_string (a_name)
					Result := expanded_namespace_name (l_uri, l_local_name, l_prefix)
				else
					create Result.make_from_string (a_name)
				end
			else
				create l_prefix.make_from_string (a_name.substring (1, l_colon - 1))
				create l_local_name.make_from_string (a_name.substring (l_colon + 1, a_name.count))
				if l_prefix.same_string ("xmlns") then
					set_error ("reserved prefix xmlns")
					create Result.make_from_string (a_name)
				elseif attached a_scope.item (l_prefix) as l_uri and then not l_uri.is_empty then
					Result := expanded_namespace_name (l_uri, l_local_name, l_prefix)
				else
					set_error ("unbound namespace prefix")
					create Result.make_from_string (a_name)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	expanded_attribute_name (a_name: READABLE_STRING_8; a_scope: HASH_TABLE [STRING_8, STRING_8]): STRING_8
			-- Attribute name reported through namespace-aware callbacks.
		require
			name_attached: a_name /= Void
			scope_attached: a_scope /= Void
		local
			l_colon: INTEGER
			l_prefix: STRING_8
			l_local_name: STRING_8
		do
			l_colon := a_name.index_of (':', 1)
			if l_colon = 0 then
				create Result.make_from_string (a_name)
			else
				create l_prefix.make_from_string (a_name.substring (1, l_colon - 1))
				create l_local_name.make_from_string (a_name.substring (l_colon + 1, a_name.count))
				if attached a_scope.item (l_prefix) as l_uri and then not l_uri.is_empty then
					Result := expanded_namespace_name (l_uri, l_local_name, l_prefix)
				else
					set_error ("unbound namespace prefix")
					create Result.make_from_string (a_name)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	expanded_namespace_name (a_uri, a_local_name, a_prefix: READABLE_STRING_8): STRING_8
			-- Expat-style expanded namespace name.
		require
			uri_attached: a_uri /= Void
			uri_not_empty: not a_uri.is_empty
			local_attached: a_local_name /= Void
			local_not_empty: not a_local_name.is_empty
			prefix_attached: a_prefix /= Void
		do
			create Result.make (a_uri.count + a_local_name.count + a_prefix.count + 2)
			Result.append (a_uri)
			if namespace_separator.code /= 0 then
				Result.append_character (namespace_separator)
			end
			Result.append (a_local_name)
			if return_ns_triplet and then not a_prefix.is_empty then
				if namespace_separator.code /= 0 then
					Result.append_character (namespace_separator)
				end
				Result.append (a_prefix)
			end
		ensure
			result_attached: Result /= Void
			result_not_empty: not Result.is_empty
		end

	emit_start_namespace_declarations (a_prefixes: ARRAYED_LIST [STRING_8]; a_scope: HASH_TABLE [STRING_8, STRING_8])
			-- Emit start namespace callbacks for declarations on the current element.
		require
			prefixes_attached: a_prefixes /= Void
			scope_attached: a_scope /= Void
		local
			i: INTEGER
			l_prefix: STRING_8
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_prefixes.count + 1
			until
				i > a_prefixes.count or has_error or is_suspended
			loop
				l_prefix := a_prefixes.i_th (i)
				if attached a_scope.item (l_prefix) as l_uri then
					if l_prefix.is_empty then
						handler.on_start_namespace_decl (Void, l_uri)
					else
						handler.on_start_namespace_decl (l_prefix, l_uri)
					end
					check_handler_stop
				end
				i := i + 1
			variant
				a_prefixes.count - i + 1
			end
		end

	emit_end_namespace_declarations
			-- Emit end namespace callbacks for declarations on the current element and pop its namespace scope.
		local
			i: INTEGER
			l_prefix: STRING_8
			l_prefixes: ARRAYED_LIST [STRING_8]
		do
			if namespace_declaration_stack.count > 0 then
				l_prefixes := namespace_declaration_stack.item
				from
					i := l_prefixes.count
				invariant
					index_in_bounds: i >= 0 and i <= l_prefixes.count
				until
					i < 1 or has_error or is_suspended
				loop
					l_prefix := l_prefixes.i_th (i)
					if l_prefix.is_empty then
						handler.on_end_namespace_decl (Void)
					else
						handler.on_end_namespace_decl (l_prefix)
					end
					check_handler_stop
					i := i - 1
				variant
					i
				end
				namespace_declaration_stack.remove
			end
			if namespace_context_stack.count > 1 then
				namespace_context_stack.remove
			end
		end

	validate_namespace_declaration (a_prefix, a_uri: READABLE_STRING_8)
			-- Check XML namespace reserved-prefix and URI rules.
		require
			prefix_attached: a_prefix /= Void
			uri_attached: a_uri /= Void
		do
			if a_prefix.same_string ("xmlns") then
				set_error ("reserved prefix xmlns")
			elseif a_prefix.same_string ("xml") and then not a_uri.same_string (Xml_namespace_uri) then
				set_error ("reserved prefix xml")
			elseif not a_prefix.same_string ("xml") and then (a_uri.same_string (Xml_namespace_uri) or else a_uri.same_string (Xmlns_namespace_uri)) then
				set_error ("reserved namespace URI")
			elseif not a_prefix.is_empty and then a_uri.is_empty then
				set_error ("undeclaring prefix")
			elseif namespace_uri_contains_forbidden_separator (a_uri) then
				set_error ("namespace separator in URI")
			end
		end

	namespace_uri_contains_forbidden_separator (a_uri: READABLE_STRING_8): BOOLEAN
			-- Does `a_uri' contain a separator form that Expat rejects?
		require
			uri_attached: a_uri /= Void
		do
			Result := namespace_separator.code /= 0 and then is_xml_space (namespace_separator) and then a_uri.has (namespace_separator)
		end

	is_namespace_declaration_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' an XML namespace declaration attribute name?
		require
			name_attached: a_name /= Void
		do
			Result := a_name.same_string ("xmlns") or else (a_name.count > 6 and then a_name.substring (1, 6).same_string ("xmlns:"))
		end

	namespace_declaration_prefix (a_name: READABLE_STRING_8): STRING_8
			-- Declared namespace prefix, or empty for the default namespace.
		require
			declaration_name: is_namespace_declaration_name (a_name)
		do
			if a_name.same_string ("xmlns") then
				create Result.make_empty
			else
				create Result.make_from_string (a_name.substring (7, a_name.count))
			end
		ensure
			result_attached: Result /= Void
		end

	is_valid_qualified_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' a syntactically valid XML QName?
		require
			name_attached: a_name /= Void
		local
			l_colon: INTEGER
			l_prefix: STRING_8
			l_local_name: STRING_8
		do
			l_colon := a_name.index_of (':', 1)
			if l_colon = 0 then
				Result := is_valid_ncname (a_name)
			elseif l_colon > 1 and then l_colon < a_name.count and then a_name.index_of (':', l_colon + 1) = 0 then
				create l_prefix.make_from_string (a_name.substring (1, l_colon - 1))
				create l_local_name.make_from_string (a_name.substring (l_colon + 1, a_name.count))
				Result := is_valid_ncname (l_prefix) and then is_valid_ncname (l_local_name)
			end
		end

	has_multiple_colons (a_name: READABLE_STRING_8): BOOLEAN
			-- Does `a_name' contain more than one colon?
		require
			name_attached: a_name /= Void
		local
			l_first: INTEGER
		do
			l_first := a_name.index_of (':', 1)
			Result := l_first > 0 and then a_name.index_of (':', l_first + 1) > 0
		end

	doctype_matches_element_name (a_doctype_name, a_element_name: READABLE_STRING_8): BOOLEAN
			-- Does document type declaration name match the root element name?
		require
			doctype_attached: a_doctype_name /= Void
			element_attached: a_element_name /= Void
		local
			l_element_colon: INTEGER
		do
			if a_doctype_name.same_string (a_element_name) then
				Result := True
			elseif namespace_mode and then not a_doctype_name.has (':') then
				l_element_colon := a_element_name.index_of (':', 1)
				Result := l_element_colon > 1
					and then a_element_name.index_of (':', l_element_colon + 1) = 0
					and then a_doctype_name.same_string (a_element_name.substring (l_element_colon + 1, a_element_name.count))
			end
		end

	is_valid_ncname (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' an XML name with no namespace colon?
		require
			name_attached: a_name /= Void
		do
			Result := is_valid_name (a_name) and then not a_name.has (':')
		end

	cloned_namespace_scope (a_source: HASH_TABLE [STRING_8, STRING_8]): HASH_TABLE [STRING_8, STRING_8]
			-- Copy namespace bindings from `a_source'.
		require
			source_attached: a_source /= Void
		local
			l_key: STRING_8
			l_value: STRING_8
		do
			create Result.make (a_source.count + 1)
			from
				a_source.start
			until
				a_source.after
			loop
				create l_key.make_from_string (a_source.key_for_iteration)
				create l_value.make_from_string (a_source.item_for_iteration)
				Result.force (l_value, l_key)
				a_source.forth
			end
		ensure
			result_attached: Result /= Void
		end

	reset_namespace_context
			-- Reset namespace stacks while preserving namespace mode settings.
		local
			l_scope: HASH_TABLE [STRING_8, STRING_8]
			l_xml_prefix: STRING_8
			l_xml_uri: STRING_8
		do
			namespace_context_stack.wipe_out
			namespace_declaration_stack.wipe_out
			create l_scope.make (4)
			create l_xml_prefix.make_from_string ("xml")
			create l_xml_uri.make_from_string (Xml_namespace_uri)
			l_scope.force (l_xml_uri, l_xml_prefix)
			namespace_context_stack.extend (l_scope)
		ensure
			one_base_scope: namespace_context_stack.count = 1
			no_element_declarations: namespace_declaration_stack.count = 0
		end

	Xml_namespace_uri: STRING_8 = "http://www.w3.org/XML/1998/namespace"
			-- Reserved XML namespace URI.

	Xmlns_namespace_uri: STRING_8 = "http://www.w3.org/2000/xmlns/"
			-- Reserved xmlns namespace URI.

feature {NONE} -- Scanning

	normalized_input (a_input: READABLE_STRING_8; a_allow_alias: BOOLEAN): STRING_8
			-- XML line-end normalized UTF-8 form of `a_input'; every character must be an XML Char.
			-- A UTF-8 sequence cut off by the end of `a_input' is kept for the markup parser.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			c: CHARACTER_8
			l_needs_copy: BOOLEAN
			l_length: INTEGER
			l_source: READABLE_STRING_8
		do
			l_source := decoded_input (a_input)
			if a_allow_alias and then l_source = a_input then
				if
					l_source.count >= 3
					and then l_source.item (1).code = 239
					and then l_source.item (2).code = 187
					and then l_source.item (3).code = 191
				then
					l_needs_copy := True
					i := 4
				else
					i := 1
				end
				from
				invariant
					index_in_bounds: i >= 1 and i <= l_source.count + 1
				until
					i > l_source.count or has_error or l_needs_copy
				loop
					c := l_source.item (i)
					if c = '%R' then
						l_needs_copy := True
						i := i + 1
					elseif c.code < 128 then
						if c.code >= 32 or else c = '%T' or else c = '%N' then
							i := i + 1
						else
							set_error ("invalid XML character")
							i := l_source.count + 1
						end
					else
						l_length := utf8_character_length (l_source, i)
						if l_length > 0 then
							i := i + l_length
						elseif l_length < 0 then
							i := l_source.count + 1
						else
							set_error ("invalid XML character")
							i := l_source.count + 1
						end
					end
				variant
					l_source.count - i + 1
				end
			end
			if a_allow_alias and then l_source = a_input and then not has_error and then not l_needs_copy and then attached {STRING_8} a_input as l_string then
				Result := l_string
			else
				create Result.make (l_source.count)
				if
					l_source.count >= 3
					and then l_source.item (1).code = 239
					and then l_source.item (2).code = 187
					and then l_source.item (3).code = 191
				then
					i := 4
				else
					i := 1
				end
				from
				invariant
					index_in_bounds: i >= 1 and i <= l_source.count + 1
				until
					i > l_source.count or has_error
				loop
					c := l_source.item (i)
					if c = '%R' then
						Result.append_character ('%N')
						if i + 1 <= l_source.count and then l_source.item (i + 1) = '%N' then
							i := i + 2
						else
							i := i + 1
						end
					elseif c.code < 128 then
						if c.code >= 32 or else c = '%T' or else c = '%N' then
							Result.append_character (c)
							i := i + 1
						else
							set_error ("invalid XML character")
							i := l_source.count + 1
						end
					else
						l_length := utf8_character_length (l_source, i)
						if l_length > 0 then
							Result.append_substring (l_source, i, i + l_length - 1)
							i := i + l_length
						elseif l_length < 0 then
							Result.append_substring (l_source, i, l_source.count)
							i := l_source.count + 1
						else
							set_error ("invalid XML character")
							i := l_source.count + 1
						end
					end
				variant
					l_source.count - i + 1
				end
			end
		ensure
			result_attached: Result /= Void
		end

	scan_name (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Index immediately after the XML name beginning at `a_start_index'.
			-- Non-ASCII characters are decoded; one that is not allowed at its position in a
			-- name is an error, since markup never continues a name with a non-ASCII character.
			-- A UTF-8 sequence cut off by the end of `a_input' is kept for prefix parsing.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			l_code: INTEGER
			l_length: INTEGER
			l_stopped: BOOLEAN
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or else l_stopped
			loop
				l_code := a_input.item (i).code
				if l_code >= 128 then
					l_length := utf8_character_length (a_input, i)
					if l_length > 0 and then (is_name_start_code (last_utf8_code) or else (i > a_start_index and then is_name_code (last_utf8_code))) then
						i := i + l_length
					elseif l_length < 0 then
						i := a_input.count + 1
					else
						set_error ("invalid name character")
						l_stopped := True
						i := i + 1
					end
				elseif
					(l_code >= 65 and l_code <= 90)
					or else (l_code >= 97 and l_code <= 122)
					or else (l_code >= 48 and l_code <= 57)
					or else l_code = 95
					or else l_code = 58
					or else l_code = 45
					or else l_code = 46
				then
					i := i + 1
				else
					l_stopped := True
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
			if l_stopped then
				Result := (i - 1).max (a_start_index + 1)
			else
				Result := i
			end
		ensure
			progress: Result > a_start_index
			result_in_bounds: Result <= a_input.count + 1
		end

	skip_spaces_before_literal (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_message: READABLE_STRING_8): INTEGER
			-- First non-XML-space index at or after `a_start_index'; reports `a_message'
			-- when a quoted literal follows a keyword or literal without whitespace.
			-- Callers report a missing literal themselves.
		require
			input_attached: a_input /= Void
			message_attached: a_message /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		do
			if a_start_index <= a_input.count and then is_quote (a_input.item (a_start_index)) then
				set_error (a_message)
				Result := a_start_index
			else
				Result := skip_spaces (a_input, a_start_index)
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_input.count + 1
		end

	input_range_same_string (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_text: READABLE_STRING_8): BOOLEAN
			-- Is `a_input [a_start_index..a_end_index]' equal to `a_text'?
		require
			input_attached: a_input /= Void
			text_attached: a_text /= Void
			start_valid: a_start_index >= 1 and a_start_index <= a_input.count
			end_valid: a_end_index >= a_start_index and a_end_index <= a_input.count
		local
			i: INTEGER
			j: INTEGER
		do
			if a_end_index - a_start_index + 1 = a_text.count then
				from
					Result := True
					i := a_start_index
					j := 1
				invariant
					input_index_in_bounds: i >= a_start_index and i <= a_end_index + 1
					text_index_in_bounds: j >= 1 and j <= a_text.count + 1
					indexes_aligned: i - a_start_index = j - 1
				until
					i > a_end_index or not Result
				loop
					Result := a_input.item (i) = a_text.item (j)
					i := i + 1
					j := j + 1
				variant
					a_end_index - i + 1
				end
			end
		end

	input_ranges_same (a_input: READABLE_STRING_8; a_left_start, a_left_end, a_right_start, a_right_end: INTEGER): BOOLEAN
			-- Are the two ranges in `a_input' equal?
		require
			input_attached: a_input /= Void
			left_start_valid: a_left_start >= 1 and a_left_start <= a_input.count
			left_end_valid: a_left_end >= a_left_start and a_left_end <= a_input.count
			right_start_valid: a_right_start >= 1 and a_right_start <= a_input.count
			right_end_valid: a_right_end >= a_right_start and a_right_end <= a_input.count
		local
			i: INTEGER
			j: INTEGER
		do
			if a_left_end - a_left_start = a_right_end - a_right_start then
				from
					Result := True
					i := a_left_start
					j := a_right_start
				invariant
					left_index_in_bounds: i >= a_left_start and i <= a_left_end + 1
					right_index_in_bounds: j >= a_right_start and j <= a_right_end + 1
					indexes_aligned: i - a_left_start = j - a_right_start
				until
					i > a_left_end or not Result
				loop
					Result := a_input.item (i) = a_input.item (j)
					i := i + 1
					j := j + 1
				variant
					a_left_end - i + 1
				end
			end
		end

	is_name_start_character (c: CHARACTER_8): BOOLEAN
			-- Is `c' an XML 1.0 name-start character representable in CHARACTER_8?
		local
			l_code: INTEGER
		do
			l_code := c.code
			Result :=
				(l_code >= 65 and l_code <= 90)
				or else (l_code >= 97 and l_code <= 122)
				or else l_code = 95
				or else l_code = 58
				or else (l_code >= 192 and l_code <= 255)
		end

	is_name_character (c: CHARACTER_8): BOOLEAN
			-- Is `c' an XML 1.0 name character representable in CHARACTER_8?
		local
			l_code: INTEGER
		do
			l_code := c.code
			Result :=
				(l_code >= 65 and l_code <= 90)
				or else (l_code >= 97 and l_code <= 122)
				or else (l_code >= 48 and l_code <= 57)
				or else l_code = 95
				or else l_code = 58
				or else l_code = 45
				or else l_code = 46
				or else l_code = 183
				or else (l_code >= 128 and l_code <= 255)
		end

	skip_spaces (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- First non-XML-space index at or after `a_start_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		local
			i: INTEGER
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or else not is_xml_space (a_input.item (i))
			loop
				i := i + 1
			variant
				a_input.count - i + 1
			end
			Result := i
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_input.count + 1
		end

	skip_required_spaces (a_input: READABLE_STRING_8; a_start_index: INTEGER; a_message: READABLE_STRING_8): INTEGER
			-- First non-XML-space index after the whitespace at `a_start_index';
			-- reports `a_message' when there is no whitespace there.
		require
			input_attached: a_input /= Void
			message_attached: a_message /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		do
			if a_start_index <= a_input.count and then is_xml_space (a_input.item (a_start_index)) then
				Result := skip_spaces (a_input, a_start_index)
			else
				set_error (a_message)
				Result := a_start_index
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_input.count + 1
			space_or_error: Result > a_start_index or has_error
		end

	find_sequence (a_input, a_marker: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- First index of `a_marker' at or after `a_start_index', or 0.
		require
			input_attached: a_input /= Void
			marker_attached: a_marker /= Void
			marker_not_empty: a_marker.count > 0
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		local
			i: INTEGER
			l_last_start: INTEGER
		do
			l_last_start := a_input.count - a_marker.count + 1
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > l_last_start or Result /= 0
			loop
				if has_at (a_input, i, a_marker) then
					Result := i
					i := a_input.count + 1
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		ensure
			not_found_or_valid: Result = 0 or else has_at (a_input, Result, a_marker)
		end

	find_character (a_input: READABLE_STRING_8; a_character: CHARACTER_8; a_start_index: INTEGER): INTEGER
			-- First index of `a_character' at or after `a_start_index', or 0.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count + 1
		local
			i: INTEGER
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or Result /= 0
			loop
				if a_input.item (i) = a_character then
					Result := i
					i := a_input.count + 1
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		ensure
			not_found_or_valid: Result = 0 or else a_input.item (Result) = a_character
		end

	find_markup_declaration_end (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- End of a declaration that may contain quoted `>' characters.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			l_in_quote: BOOLEAN
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			from
					-- A prefix may end within the first two bytes ("<" or "<!"): nothing to scan then.
				i := (a_start_index + 2).min (a_input.count + 1)
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or Result /= 0
			loop
				c := a_input.item (i)
				if l_in_quote then
					if c = l_quote then
						l_in_quote := False
					end
					i := i + 1
				elseif is_quote (c) then
					l_in_quote := True
					l_quote := c
					i := i + 1
				elseif c = '>' then
					Result := i
					i := a_input.count + 1
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		end

	is_incomplete_markup_prefix (a_input: READABLE_STRING_8; a_start_index: INTEGER): BOOLEAN
			-- Does markup at `a_start_index' lack its closing delimiter in this non-final prefix?
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		local
			l_end: INTEGER
		do
			if has_at (a_input, a_start_index, "<!--") then
				l_end := find_sequence (a_input, "-->", a_start_index + 4)
			elseif has_at (a_input, a_start_index, "<![CDATA[") then
				l_end := find_sequence (a_input, "]]>", a_start_index + 9)
			elseif has_at (a_input, a_start_index, "<!DOCTYPE") then
				l_end := find_doctype_end (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<?") then
				l_end := find_sequence (a_input, "?>", a_start_index + 2)
			else
				l_end := find_markup_declaration_end (a_input, a_start_index)
			end
			Result := l_end = 0
		end

	complete_dtd_prefix_end (a_subset: READABLE_STRING_8): INTEGER
			-- Last index that belongs to a complete DTD token prefix.
		require
			subset_attached: a_subset /= Void
		local
			i: INTEGER
			l_end: INTEGER
			l_done: BOOLEAN
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_subset.count + 1
				result_in_bounds: Result >= 0 and Result <= a_subset.count
			until
				i > a_subset.count or l_done
			loop
				if is_xml_space (a_subset.item (i)) then
					Result := i
					i := i + 1
				elseif has_at (a_subset, i, "<!--") then
					l_end := find_sequence (a_subset, "-->", i + 4)
					if l_end = 0 then
						l_done := True
					else
						Result := l_end + 2
						i := l_end + 3
					end
				elseif has_at (a_subset, i, "<?") then
					l_end := find_sequence (a_subset, "?>", i + 2)
					if l_end = 0 then
						l_done := True
					else
						Result := l_end + 1
						i := l_end + 2
					end
				elseif has_at (a_subset, i, "<![") then
					l_end := find_sequence (a_subset, "]]>", i + 3)
					if l_end = 0 then
						l_done := True
					else
						Result := l_end + 2
						i := l_end + 3
					end
				elseif has_at (a_subset, i, "<!") then
					l_end := find_markup_declaration_end (a_subset, i)
					if l_end = 0 then
						l_done := True
					else
						Result := l_end
						i := l_end + 1
					end
				elseif a_subset.item (i).code = 37 then
					l_end := find_character (a_subset, ';', i + 1)
					if l_end = 0 then
						l_done := True
					else
						Result := l_end
						i := l_end + 1
					end
				elseif a_subset.item (i) = '<' then
					l_done := True
				else
					Result := a_subset.count
					i := a_subset.count + 1
				end
			variant
				a_subset.count - i + 1 + (not l_done).to_integer
			end
		ensure
			result_in_bounds: Result >= 0 and Result <= a_subset.count
		end

	find_doctype_end (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- End of a doctype declaration with an optional internal subset.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			l_depth: INTEGER
			l_in_quote: BOOLEAN
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			from
				i := a_start_index + 9
			invariant
				index_in_bounds: i >= a_start_index + 9 and i <= a_input.count + 1
				depth_non_negative: l_depth >= 0
			until
				i > a_input.count or Result /= 0
			loop
				c := a_input.item (i)
				if l_in_quote then
					if c = l_quote then
						l_in_quote := False
					end
					i := i + 1
				elseif l_depth > 0 and then c = '<' and then (has_at (a_input, i, "<!--") or has_at (a_input, i, "<?")) then
						-- Quotes in comments and processing instructions do not start literals.
					i := index_after_subset_comment_or_pi (a_input, i, a_input.count)
				elseif is_quote (c) then
					l_in_quote := True
					l_quote := c
					i := i + 1
				elseif c = '[' then
					l_depth := l_depth + 1
					i := i + 1
				elseif c = ']' and l_depth > 0 then
					l_depth := l_depth - 1
					i := i + 1
				elseif c = '>' and l_depth = 0 then
					Result := i
					i := a_input.count + 1
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		end

	index_after_subset_comment_or_pi (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- Index after the comment or processing instruction at `a_start_index', or
			-- `a_end_index + 1' when it is not terminated by `a_end_index'.
		require
			input_attached: a_input /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
			at_comment_or_pi: has_at (a_input, a_start_index, "<!--") or has_at (a_input, a_start_index, "<?")
		local
			l_end: INTEGER
		do
			if has_at (a_input, a_start_index, "<!--") then
				l_end := find_sequence (a_input, "-->", a_start_index + 4)
				if l_end > 0 and then l_end + 2 <= a_end_index then
					Result := l_end + 3
				end
			else
				l_end := find_sequence (a_input, "?>", a_start_index + 2)
				if l_end > 0 and then l_end + 1 <= a_end_index then
					Result := l_end + 2
				end
			end
			if Result = 0 then
				Result := a_end_index + 1
			end
		ensure
			progress: Result > a_start_index
			result_in_bounds: Result <= a_end_index + 1
		end

	find_unquoted_character (a_input: READABLE_STRING_8; a_character: CHARACTER_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- First unquoted `a_character' in `a_input' between the given bounds, or 0.
		require
			input_attached: a_input /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_in_quote: BOOLEAN
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				i > a_end_index or Result /= 0
			loop
				c := a_input.item (i)
				if l_in_quote then
					if c = l_quote then
						l_in_quote := False
					end
					i := i + 1
				elseif is_quote (c) then
					l_in_quote := True
					l_quote := c
					i := i + 1
				elseif c = a_character then
					Result := i
					i := a_end_index + 1
				else
					i := i + 1
				end
			variant
				a_end_index - i + 1
			end
		end

	find_subset_end (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- Matching unquoted `]' before `a_end_index', or 0. Comments and processing
			-- instructions are skipped, so quotes inside them do not start literals.
		require
			input_attached: a_input /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
		local
			i: INTEGER
			l_in_quote: BOOLEAN
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				i > a_end_index or Result /= 0
			loop
				c := a_input.item (i)
				if l_in_quote then
					if c = l_quote then
						l_in_quote := False
					end
					i := i + 1
				elseif c = '<' and then (has_at (a_input, i, "<!--") or has_at (a_input, i, "<?")) then
					i := index_after_subset_comment_or_pi (a_input, i, a_end_index)
				elseif is_quote (c) then
					l_in_quote := True
					l_quote := c
					i := i + 1
				elseif c = ']' then
					Result := i
					i := a_end_index + 1
				else
					i := i + 1
				end
			variant
				a_end_index - i + 1
			end
		end

	read_quoted_literal (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_value: STRING_8): INTEGER
			-- Read quoted literal starting at `a_start_index' and return index after closing quote.
		require
			input_attached: a_input /= Void
			value_attached: a_value /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
			starts_with_quote: is_quote (a_input.item (a_start_index))
		local
			i: INTEGER
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			l_quote := a_input.item (a_start_index)
			from
				i := a_start_index + 1
			invariant
				index_in_bounds: i >= a_start_index + 1 and i <= a_end_index + 1
			until
				i > a_end_index or has_error or else a_input.item (i) = l_quote
			loop
				c := a_input.item (i)
				if not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_end_index + 1
				else
					a_value.append_character (c)
					i := i + 1
				end
			variant
				a_end_index - i + 1
			end
			if not has_error then
				if i > a_end_index then
					set_error ("unterminated literal")
					Result := a_input.count + 1
				else
					Result := i + 1
				end
			else
				Result := a_input.count + 1
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	read_public_id_literal (a_input: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_value: STRING_8): INTEGER
			-- Read public identifier literal and reject characters outside XML `PubidChar'.
		require
			input_attached: a_input /= Void
			value_attached: a_value /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
			starts_with_quote: is_quote (a_input.item (a_start_index))
		do
			Result := read_quoted_literal (a_input, a_start_index, a_end_index, a_value)
			if not has_error and then not is_valid_public_id (a_value) then
				set_error ("invalid public identifier")
				Result := a_input.count + 1
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	has_at (a_input: READABLE_STRING_8; a_index: INTEGER; a_marker: READABLE_STRING_8): BOOLEAN
			-- Does `a_marker' appear at `a_index' in `a_input'?
		require
			input_attached: a_input /= Void
			marker_attached: a_marker /= Void
			marker_not_empty: a_marker.count > 0
			valid_index: a_index >= 1 and a_index <= a_input.count + 1
		local
			i: INTEGER
		do
			if a_index + a_marker.count - 1 <= a_input.count then
				from
					Result := True
					i := 1
				invariant
					marker_index_in_bounds: i >= 1 and i <= a_marker.count + 1
				until
					i > a_marker.count or not Result
				loop
					Result := a_input.item (a_index + i - 1) = a_marker.item (i)
					i := i + 1
				variant
					a_marker.count - i + 1
				end
			end
		end

	is_incomplete_marker_at_end (a_input: READABLE_STRING_8; a_index: INTEGER; a_marker: READABLE_STRING_8): BOOLEAN
			-- Does input ending at `a_input.count' contain a proper prefix of `a_marker' at `a_index'?
		require
			input_attached: a_input /= Void
			marker_attached: a_marker /= Void
			marker_not_empty: a_marker.count > 0
			valid_index: a_index >= 1 and a_index <= a_input.count + 1
		local
			i: INTEGER
			l_remaining: INTEGER
		do
			l_remaining := a_input.count - a_index + 1
			if l_remaining > 0 and then l_remaining < a_marker.count then
				from
					Result := True
					i := 1
				invariant
					prefix_index_in_bounds: i >= 1 and i <= l_remaining + 1
				until
					i > l_remaining or not Result
				loop
					Result := a_input.item (a_index + i - 1) = a_marker.item (i)
					i := i + 1
				variant
					l_remaining - i + 1
				end
			end
		end

	has_keyword_at (a_input: READABLE_STRING_8; a_index: INTEGER; a_keyword: READABLE_STRING_8): BOOLEAN
			-- Does keyword `a_keyword' appear at `a_index' with a token boundary after it?
		require
			input_attached: a_input /= Void
			keyword_attached: a_keyword /= Void
			keyword_not_empty: not a_keyword.is_empty
			valid_index: a_index >= 1 and a_index <= a_input.count + 1
		local
			l_next: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			if has_at (a_input, a_index, a_keyword) then
				l_next := a_index + a_keyword.count
				Result := l_next > a_input.count or else not l_attributes.is_name_character (a_input.item (l_next))
			end
		end

feature {NONE} -- Character and name validation

	is_quote (c: CHARACTER_8): BOOLEAN
			-- Is `c' a single or double quote?
		do
			Result := c.code = 34 or c.code = 39
		end

	is_xml_space (c: CHARACTER_8): BOOLEAN
			-- Is `c' XML whitespace?
		do
			Result := c = ' ' or c = '%T' or c = '%N' or c = '%R'
		end

	is_xml_space_ascii (c: CHARACTER_8): BOOLEAN
			-- Is `c' normalized ASCII XML whitespace?
		do
			Result := c = ' ' or c = '%T' or c = '%N'
		end

	is_all_xml_space (a_text: READABLE_STRING_8): BOOLEAN
			-- Does `a_text' contain only XML whitespace?
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			from
				Result := True
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_text.count + 1
			until
				i > a_text.count or not Result
			loop
				Result := is_xml_space (a_text.item (i))
				i := i + 1
			variant
				a_text.count - i + 1
			end
		end

	is_valid_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' accepted as an XML name?
		require
			name_attached: a_name /= Void
		local
			i, l_length: INTEGER
		do
			if a_name.count > 0 and then a_name.count <= max_name_length then
				from
					Result := True
					i := 1
				until
					i > a_name.count or not Result
				loop
					l_length := utf8_character_length (a_name, i)
					if l_length > 0 then
						if i = 1 then
							Result := is_name_start_code (last_utf8_code)
						else
							Result := is_name_code (last_utf8_code)
						end
						i := i + l_length
					else
						Result := False
					end
				end
			end
		end

	is_valid_public_id (a_text: READABLE_STRING_8): BOOLEAN
			-- Does `a_text' satisfy XML 1.0 `PubidChar*'?
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			from
				Result := True
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_text.count + 1
			until
				i > a_text.count or not Result
			loop
				Result := is_public_id_character (a_text.item (i))
				i := i + 1
			variant
				a_text.count - i + 1
			end
		end

	is_public_id_character (c: CHARACTER_8): BOOLEAN
			-- Is `c' an XML 1.0 public identifier character?
		local
			l_code: INTEGER
		do
			l_code := c.code
			Result := (l_code >= 65 and l_code <= 90)
				or else (l_code >= 97 and l_code <= 122)
				or else (l_code >= 48 and l_code <= 57)
				or else l_code = 32
				or else l_code = 13
				or else l_code = 10
				or else l_code = 45
				or else l_code = 39
				or else l_code = 40
				or else l_code = 41
				or else l_code = 43
				or else l_code = 44
				or else l_code = 46
				or else l_code = 47
				or else l_code = 58
				or else l_code = 61
				or else l_code = 63
				or else l_code = 59
				or else l_code = 33
				or else l_code = 42
				or else l_code = 35
				or else l_code = 64
				or else l_code = 36
				or else l_code = 95
				or else l_code = 37
		end

	optional_string (a_text: READABLE_STRING_8): detachable READABLE_STRING_8
			-- `a_text' when not empty; otherwise Void.
		require
			text_attached: a_text /= Void
		do
			if not a_text.is_empty then
				Result := a_text
			end
		end

	is_xml_character_code (a_code: INTEGER): BOOLEAN
			-- Does `a_code' satisfy the XML 1.0 Char production?
		do
			Result := a_code = 9 or a_code = 10 or a_code = 13 or else (a_code >= 32 and a_code <= 55295) or else (a_code >= 57344 and a_code <= 65533) or else (a_code >= 65536 and a_code <= 1114111)
		end

	validate_xml_text (a_text: READABLE_STRING_8)
			-- Reject invalid XML characters in `a_text'.
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_text.count + 1
			until
				i > a_text.count or has_error
			loop
				if not is_xml_character_code (a_text.item (i).code) then
					set_error ("invalid XML character")
					i := a_text.count + 1
				else
					i := i + 1
				end
			variant
				a_text.count - i + 1
			end
		end

	append_character_reference (a_body: READABLE_STRING_8; a_text: STRING_8)
			-- Decode character reference body, excluding leading `&#' and trailing `;'.
		require
			body_attached: a_body /= Void
			text_attached: a_text /= Void
		local
			i: INTEGER
			l_base: INTEGER
			l_code: INTEGER
			l_digit: INTEGER
		do
			if a_body.is_empty then
				set_error ("invalid character reference syntax")
			else
				if a_body.count >= 2 and then a_body.item (1) = 'x' then
					l_base := 16
					i := 2
				else
					l_base := 10
					i := 1
				end
				if i > a_body.count then
					set_error ("invalid character reference syntax")
				end
				from
				invariant
					index_in_bounds: i >= 1 and i <= a_body.count + 1
					code_non_negative: l_code >= 0
				until
					i > a_body.count or has_error
				loop
					if l_base = 16 then
						l_digit := hex_digit_value (a_body.item (i))
					else
						l_digit := decimal_digit_value (a_body.item (i))
					end
					if l_digit < 0 then
						set_error ("invalid character reference digit")
					else
						l_code := l_code * l_base + l_digit
						if l_code > 1114111 then
							set_error ("invalid character reference")
						end
					end
					i := i + 1
				variant
					a_body.count - i + 1
				end
				if not has_error then
					if not is_xml_character_code (l_code) then
						set_error ("invalid character reference")
					else
						{UTF_CONVERTER}.utf_32_code_into_utf_8_string_8 (l_code.as_natural_32, a_text)
					end
				end
			end
		end

	decimal_digit_value (c: CHARACTER_8): INTEGER
			-- Decimal value of `c', or -1.
		do
			if c.is_digit then
				Result := c.code - ('0').code
			else
				Result := -1
			end
		end

	hex_digit_value (c: CHARACTER_8): INTEGER
			-- Hexadecimal value of `c', or -1.
		do
			if c.is_digit then
				Result := c.code - ('0').code
			elseif c.as_lower >= 'a' and c.as_lower <= 'f' then
				Result := c.as_lower.code - ('a').code + 10
			else
				Result := -1
			end
		end

	same_name_case_insensitive (a_name, a_other: READABLE_STRING_8): BOOLEAN
			-- Are `a_name' and `a_other' equal ignoring ASCII case?
		require
			name_attached: a_name /= Void
			other_attached: a_other /= Void
		local
			i: INTEGER
		do
			if a_name.count = a_other.count then
				from
					Result := True
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= a_name.count + 1
				until
					i > a_name.count or not Result
				loop
					Result := a_name.item (i).as_lower = a_other.item (i).as_lower
					i := i + 1
				variant
					a_name.count - i + 1
				end
			end
		end

	has_left_angle_in_range (a_text: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): BOOLEAN
			-- Does `a_text' contain `<` in the given range?
		require
			text_attached: a_text /= Void
			valid_range: a_start_index >= 1 and a_start_index <= a_end_index + 1 and a_end_index <= a_text.count
		local
			i: INTEGER
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				i > a_end_index or Result
			loop
				if a_text.item (i) = '<' then
					Result := True
					i := a_end_index + 1
				else
					i := i + 1
				end
			variant
				a_end_index - i + 1
			end
		end

feature {NONE} -- Entity tables

	initialize_predefined_entities
			-- Install XML predefined entities.
		do
			put_general_entity ("lt", "<")
			put_general_entity ("gt", ">")
			put_general_entity ("amp", "&")
			put_general_entity ("apos", "'")
			put_general_entity ("quot", "%"")
		end

	install_inherited_entity_context
			-- Install inherited DTD entity bindings into the current parse state.
		do
			dtd_declarations_disabled := dtd_declarations_disabled or else inherited_dtd_declarations_disabled
			dtd_has_parameter_entity_references := dtd_has_parameter_entity_references or else inherited_dtd_declarations_disabled
			if attached inherited_entity_table as l_entities then
				copy_string_table_into (l_entities, entity_table)
			end
			if attached inherited_parameter_entity_table as l_entities then
				copy_string_table_into (l_entities, parameter_entity_table)
			end
			if attached inherited_parameter_entity_accounting_table as l_counts then
				copy_integer_table_into (l_counts, parameter_entity_accounting_table)
			end
			if attached inherited_external_entity_table as l_entities then
				copy_external_entity_table_into (l_entities, external_entity_table)
			end
			if attached inherited_external_parameter_entity_table as l_entities then
				copy_external_entity_table_into (l_entities, external_parameter_entity_table)
			end
		end


	copy_string_entity_delta (a_source: HASH_TABLE [STRING_8, STRING_8]; a_inherited: detachable HASH_TABLE [STRING_8, STRING_8]; a_target: HASH_TABLE [STRING_8, STRING_8]; a_skip_predefined: BOOLEAN)
		local
			l_key, l_value: STRING_8
		do
			across a_source as c loop
				if (a_inherited = Void or else not a_inherited.has (c.key)) and then
					(not a_skip_predefined or else not is_predefined_entity (c.key))
				then
					l_key := c.key.twin
					l_value := c.item.twin
					a_target.put (l_value, l_key)
				end
			end
		end

	copy_integer_entity_delta (a_source: HASH_TABLE [INTEGER, STRING_8]; a_inherited: detachable HASH_TABLE [INTEGER, STRING_8]; a_target: HASH_TABLE [INTEGER, STRING_8])
		do
			across a_source as c loop
				if a_inherited = Void or else not a_inherited.has (c.key) then
					a_target.put (c.item, c.key.twin)
				end
			end
		end

	copy_external_entity_delta (a_source: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]; a_inherited: detachable HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]; a_target: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8])
		local
			l_value: XP_EXTERNAL_ENTITY
		do
			across a_source as c loop
				if a_inherited = Void or else not a_inherited.has (c.key) then
					create l_value.make (c.item.name, c.item.public_id, c.item.system_id, c.item.notation_name, c.item.is_parameter, c.item.is_unparsed)
					a_target.put (l_value, c.key.twin)
				end
			end
		end

	cloned_string_table (a_source: HASH_TABLE [STRING_8, STRING_8]): HASH_TABLE [STRING_8, STRING_8]
			-- Deep string copy of `a_source'.
		require
			source_attached: a_source /= Void
		do
			create Result.make (a_source.count + 1)
			copy_string_table_into (a_source, Result)
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = a_source.count
		end

	copy_string_table_into (a_source, a_target: HASH_TABLE [STRING_8, STRING_8])
			-- Copy string bindings from `a_source' into `a_target' without replacing existing bindings.
		require
			source_attached: a_source /= Void
			target_attached: a_target /= Void
		local
			l_key: STRING_8
			l_value: STRING_8
		do
			from
				a_source.start
			until
				a_source.after
			loop
				create l_key.make_from_string (a_source.key_for_iteration)
				if not a_target.has (l_key) then
					create l_value.make_from_string (a_source.item_for_iteration)
					a_target.put (l_value, l_key)
				end
				a_source.forth
			end
		end

	cloned_integer_table (a_source: HASH_TABLE [INTEGER, STRING_8]): HASH_TABLE [INTEGER, STRING_8]
			-- Copy of integer bindings in `a_source'.
		require
			source_attached: a_source /= Void
		do
			create Result.make (a_source.count + 1)
			copy_integer_table_into (a_source, Result)
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = a_source.count
		end

	copy_integer_table_into (a_source, a_target: HASH_TABLE [INTEGER, STRING_8])
			-- Copy integer bindings from `a_source' into `a_target' without replacing existing bindings.
		require
			source_attached: a_source /= Void
			target_attached: a_target /= Void
		local
			l_key: STRING_8
		do
			from
				a_source.start
			until
				a_source.after
			loop
				create l_key.make_from_string (a_source.key_for_iteration)
				if not a_target.has (l_key) then
					a_target.put (a_source.item_for_iteration, l_key)
				end
				a_source.forth
			end
		end

	cloned_external_entity_table (a_source: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]): HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- Copy of external entity metadata table `a_source'.
		require
			source_attached: a_source /= Void
		do
			create Result.make (a_source.count + 1)
			copy_external_entity_table_into (a_source, Result)
		ensure
			result_attached: Result /= Void
			count_preserved: Result.count = a_source.count
		end

	copy_external_entity_table_into (a_source, a_target: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8])
			-- Copy external entity bindings from `a_source' into `a_target' without replacing existing bindings.
		require
			source_attached: a_source /= Void
			target_attached: a_target /= Void
		local
			l_key: STRING_8
		do
			from
				a_source.start
			until
				a_source.after
			loop
				create l_key.make_from_string (a_source.key_for_iteration)
				if not a_target.has (l_key) then
					a_target.put (a_source.item_for_iteration, l_key)
				end
				a_source.forth
			end
		end

	put_general_entity (a_name, a_value: READABLE_STRING_8)
			-- Record general entity if not already bound.
		require
			valid_name: is_valid_name (a_name)
			value_attached: a_value /= Void
		local
			l_name: STRING_8
			l_value: STRING_8
		do
			create l_name.make_from_string (a_name)
			if not entity_table.has (l_name) then
				create l_value.make_from_string (a_value)
				entity_table.put (l_value, l_name)
			end
		end

	put_parameter_entity (a_name, a_value: READABLE_STRING_8; a_accounting_count: INTEGER)
			-- Record parameter entity if not already bound.
		require
			valid_name: is_valid_name (a_name)
			value_attached: a_value /= Void
			accounting_count_non_negative: a_accounting_count >= 0
		local
			l_name: STRING_8
			l_value: STRING_8
		do
			create l_name.make_from_string (a_name)
			if not parameter_entity_table.has (l_name) then
				create l_value.make_from_string (a_value)
				parameter_entity_table.put (l_value, l_name)
				parameter_entity_accounting_table.put (a_accounting_count, l_name)
			end
		end

	put_external_entity (a_name, a_public_id, a_system_id, a_notation_name: READABLE_STRING_8; a_is_parameter, a_is_unparsed: BOOLEAN)
			-- Record external entity metadata if not already bound.
		require
			valid_name: is_valid_name (a_name)
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
			notation_name_attached: a_notation_name /= Void
			unparsed_only_for_general: a_is_unparsed implies not a_is_parameter
		local
			l_name: STRING_8
			l_entity: XP_EXTERNAL_ENTITY
		do
			create l_name.make_from_string (a_name)
			if a_is_parameter then
				if not parameter_entity_table.has (l_name) and then not external_parameter_entity_table.has (l_name) then
					create l_entity.make (a_name, a_public_id, a_system_id, a_notation_name, True, False)
					external_parameter_entity_table.put (l_entity, l_name)
				end
			elseif not entity_table.has (l_name) and then not external_entity_table.has (l_name) then
				create l_entity.make (a_name, a_public_id, a_system_id, a_notation_name, False, a_is_unparsed)
				external_entity_table.put (l_entity, l_name)
			end
		end

	is_parameter_entity_declared (a_name: READABLE_STRING_8): BOOLEAN
			-- Is a parameter entity with `a_name' already bound?
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := parameter_entity_table.has (l_name) or else external_parameter_entity_table.has (l_name)
		end

	entity_value (a_name: READABLE_STRING_8): detachable STRING_8
			-- General entity value for `a_name', if declared.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := entity_table.item (l_name)
		end

	parameter_entity_value (a_name: READABLE_STRING_8): detachable STRING_8
			-- Parameter entity value for `a_name', if declared.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := parameter_entity_table.item (l_name)
		end

	parameter_entity_accounting_value (a_name: READABLE_STRING_8): INTEGER
			-- Logical replacement byte count for parameter entity `a_name'.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			if parameter_entity_accounting_table.has (l_name) then
				Result := parameter_entity_accounting_table.item (l_name)
			elseif attached parameter_entity_table.item (l_name) as l_value then
				Result := l_value.count
			end
		ensure
			non_negative: Result >= 0
		end

	external_entity (a_name: READABLE_STRING_8): detachable XP_EXTERNAL_ENTITY
			-- External general entity metadata for `a_name', if declared.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := external_entity_table.item (l_name)
		end

	external_parameter_entity (a_name: READABLE_STRING_8): detachable XP_EXTERNAL_ENTITY
			-- External parameter entity metadata for `a_name', if declared.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := external_parameter_entity_table.item (l_name)
		end

	is_predefined_entity (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' one of the XML predefined entities?
		require
			valid_name: is_valid_name (a_name)
		do
			Result := a_name.same_string ("lt") or a_name.same_string ("gt") or a_name.same_string ("amp") or a_name.same_string ("apos") or a_name.same_string ("quot")
		end

	append_predefined_entity (a_name: READABLE_STRING_8; a_text: STRING_8)
			-- Append predefined entity value.
		require
			predefined: is_predefined_entity (a_name)
			text_attached: a_text /= Void
		do
			if attached entity_value (a_name) as l_value then
				note_entity_expansion (l_value.count)
				a_text.append (l_value)
			end
		end

	note_entity_expansion (a_count: INTEGER)
			-- Account for entity replacement text.
		require
			non_negative: a_count >= 0
		do
			expanded_entity_bytes := expanded_entity_bytes + a_count
			if expanded_entity_bytes > Default_max_entity_expansion_bytes then
				set_error ("entity expansion limit exceeded")
			end
		end

	push_entity (a_name: READABLE_STRING_8)
			-- Mark `a_name' as active.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			entity_stack.extend (l_name)
		ensure
			one_more: entity_stack.count = old entity_stack.count + 1
		end

	pop_entity
			-- Unmark most recent active entity.
		require
			not_empty: entity_stack.count > 0
		do
			entity_stack.finish
			entity_stack.remove
		ensure
			one_less: entity_stack.count = old entity_stack.count - 1
		end

	is_entity_active (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' currently being expanded?
		require
			valid_name: is_valid_name (a_name)
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= entity_stack.count + 1
			until
				i > entity_stack.count or Result
			loop
				if entity_stack.i_th (i).same_string (a_name) then
					Result := True
					i := entity_stack.count + 1
				else
					i := i + 1
				end
			variant
				entity_stack.count - i + 1
			end
		end

	push_entity_reference_position (a_start_index, a_byte_count: INTEGER)
			-- Remember source range for callbacks emitted while expanding an entity reference.
		require
			valid_start: a_start_index >= 1
			positive_count: a_byte_count > 0
		local
			l_start: INTEGER
			l_count: INTEGER
		do
			if entity_reference_start_stack.count > 0 then
				l_start := entity_reference_start_stack.i_th (entity_reference_start_stack.count)
				l_count := entity_reference_count_stack.i_th (entity_reference_count_stack.count)
			else
				l_start := a_start_index
				l_count := a_byte_count
			end
			entity_reference_start_stack.extend (l_start)
			entity_reference_count_stack.extend (l_count)
		ensure
			one_more_start: entity_reference_start_stack.count = old entity_reference_start_stack.count + 1
			one_more_count: entity_reference_count_stack.count = old entity_reference_count_stack.count + 1
			stacks_aligned: entity_reference_start_stack.count = entity_reference_count_stack.count
		end

	pop_entity_reference_position
			-- Forget innermost entity reference source range.
		require
			start_stack_not_empty: entity_reference_start_stack.count > 0
			count_stack_not_empty: entity_reference_count_stack.count > 0
		do
			entity_reference_start_stack.finish
			entity_reference_start_stack.remove
			entity_reference_count_stack.finish
			entity_reference_count_stack.remove
		ensure
			one_less_start: entity_reference_start_stack.count = old entity_reference_start_stack.count - 1
			one_less_count: entity_reference_count_stack.count = old entity_reference_count_stack.count - 1
			stacks_aligned: entity_reference_start_stack.count = entity_reference_count_stack.count
		end

	note_current_entity_reference_position
			-- Move current position to the active document entity-reference token.
		do
			if entity_reference_start_stack.count > 0 then
				note_token_position (entity_reference_start_stack.i_th (entity_reference_start_stack.count), entity_reference_count_stack.i_th (entity_reference_count_stack.count))
			end
		end

feature {NONE} -- State


	reset_cached_doctype_body (a_prefix_count: INTEGER; a_doctype_name: STRING_8)
			-- Restore the completed DTD baseline, retaining all existing declaration tables.
		do
			has_error := False
			last_error.wipe_out
			is_suspended := False
			lazy_position_accounting := False
			current_position_index := a_prefix_count + 1
			current_line_number := cached_doctype_line
			current_column_number := cached_doctype_column
			current_byte_index := a_prefix_count
			current_byte_count := 0
			last_attribute_name_start := 0
			last_attribute_name_end := 0
			external_dtd_depth := 0
			entity_element_floor := 0
			element_stack.wipe_out
			element_slice_stack.wipe_out
			entity_stack.wipe_out
			entity_reference_start_stack.wipe_out
			entity_reference_count_stack.wipe_out
			document_element_count := 0
			expanded_entity_bytes := cached_doctype_entity_bytes
			current_entity_literal_accounting_adjustment := 0
			parameter_subset_expansion_depth := 0
			dtd_subset_position_offset := 0
			dtd_entity_reference_position := 0
			entity_literal_ended_by_undefined_parameter := False
			has_doctype := True
			doctype_name := a_doctype_name.twin
			document_has_external_subset := cached_doctype_has_external_subset
			dtd_has_parameter_entity_references := cached_doctype_has_parameter_references
			dtd_declarations_disabled := cached_doctype_declarations_disabled
			xml_standalone := cached_doctype_standalone
			foreign_dtd_loaded := cached_doctype_foreign_loaded
			not_standalone_checked := cached_doctype_not_standalone_checked
			reset_namespace_context
		end

	reset
			-- Reset parse state.
		do
			clear_cached_doctype
			has_error := False
			last_error.wipe_out
			create position_input.make_empty
			lazy_position_accounting := False
			last_attribute_name_start := 0
			last_attribute_name_end := 0
			external_dtd_depth := 0
			entity_element_floor := 0
			dtd_has_parameter_entity_references := False
			dtd_declarations_disabled := False
			entity_literal_ended_by_undefined_parameter := False
			current_position_index := 0
			current_line_number := 1
			current_column_number := 0
			current_byte_index := -1
			current_byte_count := 0
			doctype_name.wipe_out
			element_stack.wipe_out
			element_slice_stack.wipe_out
			entity_stack.wipe_out
			entity_reference_start_stack.wipe_out
			entity_reference_count_stack.wipe_out
			entity_table.wipe_out
			parameter_entity_table.wipe_out
			parameter_entity_accounting_table.wipe_out
			external_entity_table.wipe_out
			external_parameter_entity_table.wipe_out
			attribute_decl_table.wipe_out
			is_suspended := False
			document_element_count := 0
			expanded_entity_bytes := 0
			current_entity_literal_accounting_adjustment := 0
			parameter_subset_expansion_depth := 0
			dtd_subset_position_offset := 0
			dtd_entity_reference_position := 0
			has_doctype := False
			document_has_external_subset := False
			xml_standalone := -1
			foreign_dtd_loaded := False
			not_standalone_checked := False
			reset_namespace_context
			initialize_predefined_entities
			install_inherited_entity_context
		ensure
			no_error: not has_error
			no_message: last_error.is_empty
			no_open_elements: element_stack.count = 0
			one_predefined_entity: attached entity_value ("lt") as l_value and then l_value.same_string ("<")
		end

	check_handler_stop
			-- Honor a stop request raised from an application callback.
		do
			if not has_error and not is_suspended and then handler.stop_requested then
				if handler.stop_is_resumable then
					is_suspended := True
				else
					set_error ("parsing aborted")
				end
			end
		end

	note_position (a_index: INTEGER)
			-- Record the current parser position as a 1-based input index.
		local
			l_index: INTEGER
		do
			if not position_input.is_empty or else a_index > 0 then
				l_index := bounded_position_index (a_index)
				if lazy_position_accounting then
					current_position_index := l_index
				else
					if current_position_index <= 0 then
						recompute_position_from_start (l_index)
					elseif l_index < current_position_index then
						retreat_position_to (l_index)
					else
						advance_position_to (l_index)
					end
					current_position_index := l_index
				end
				current_byte_index := l_index - 1
				current_byte_count := 0
			end
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
			byte_count_non_negative: current_byte_count >= 0
		end

	note_token_position (a_index, a_byte_count: INTEGER)
			-- Record current parser position and token byte count.
		require
			non_negative_byte_count: a_byte_count >= 0
		do
			note_position (a_index)
			current_byte_count := a_byte_count
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
			byte_count_set: current_byte_count = a_byte_count
		end

	force_current_position
			-- Materialize deferred line and column counters for the current position.
		local
			l_index: INTEGER
		do
			if lazy_position_accounting and then current_position_index > 0 then
				l_index := bounded_position_index (current_position_index)
				recompute_position_from_start (l_index)
				current_position_index := l_index
				current_byte_index := l_index - 1
				current_byte_count := 0
				lazy_position_accounting := False
			end
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
			byte_count_non_negative: current_byte_count >= 0
		end

	advance_position_to (a_index: INTEGER)
			-- Advance line and column counters from current parser position to `a_index'.
		require
			index_in_bounds: a_index >= 1 and a_index <= position_input.count + 1
			forward: current_position_index >= 1 and current_position_index <= a_index
		local
			i: INTEGER
		do
			from
				i := current_position_index
			invariant
				index_in_bounds: i >= current_position_index and i <= a_index
				line_positive: current_line_number >= 1
				column_non_negative: current_column_number >= 0
			until
				i >= a_index
			loop
				if position_input.item (i) = '%N' then
					current_line_number := current_line_number + 1
					current_column_number := 0
				else
					current_column_number := current_column_number + 1
				end
				i := i + 1
			variant
				a_index - i
			end
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
		end

	retreat_position_to (a_index: INTEGER)
			-- Move line and column counters backwards without rescanning the document prefix.
		require
			index_in_bounds: a_index >= 1 and a_index <= position_input.count + 1
			backward: current_position_index > a_index
			current_index_in_bounds: current_position_index <= position_input.count + 1
			eager_positions: not lazy_position_accounting
		local
			i: INTEGER
			l_distance: INTEGER
			l_newlines: INTEGER
		do
			l_distance := current_position_index - a_index
			if l_distance <= current_column_number then
					-- The target is at or after the start of the current line.
				current_column_number := current_column_number - l_distance
			else
				from
					i := current_position_index - 1
				invariant
					index_in_bounds: i >= a_index - 1 and i < current_position_index
					newlines_non_negative: l_newlines >= 0
				until
					i < a_index
				loop
					if position_input.item (i) = '%N' then
						l_newlines := l_newlines + 1
					end
					i := i - 1
				variant
					i - a_index + 1
				end
				current_line_number := current_line_number - l_newlines
				if a_index = 1 then
					current_column_number := 0
				else
					current_column_number := a_index - 1 - position_input.last_index_of ('%N', a_index - 1)
				end
			end
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
		end

	recompute_position_from_start (a_index: INTEGER)
			-- Recompute line and column counters for `a_index' from the beginning.
		require
			index_in_bounds: a_index >= 1 and a_index <= position_input.count + 1
		local
			i: INTEGER
		do
			current_line_number := 1
			current_column_number := 0
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_index
				line_positive: current_line_number >= 1
				column_non_negative: current_column_number >= 0
			until
				i >= a_index
			loop
				if position_input.item (i) = '%N' then
					current_line_number := current_line_number + 1
					current_column_number := 0
				else
					current_column_number := current_column_number + 1
				end
				i := i + 1
			variant
				a_index - i
			end
		ensure
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
		end

	bounded_position_index (a_index: INTEGER): INTEGER
			-- `a_index' clamped to the current normalized input bounds.
		do
			if a_index < 1 then
				Result := 1
			elseif a_index > position_input.count + 1 then
				Result := position_input.count + 1
			else
				Result := a_index
			end
		ensure
			in_bounds: Result >= 1 and Result <= position_input.count + 1
		end

	line_number_at (a_index: INTEGER): INTEGER
			-- 1-based line number before character at `a_index'.
		require
			index_in_bounds: a_index >= 1 and a_index <= position_input.count + 1
		local
			i: INTEGER
		do
			from
				Result := 1
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_index
				line_positive: Result >= 1
			until
				i >= a_index
			loop
				if position_input.item (i) = '%N' then
					Result := Result + 1
				end
				i := i + 1
			variant
				a_index - i
			end
		ensure
			line_positive: Result >= 1
		end

	column_number_at (a_index: INTEGER): INTEGER
			-- 0-based column number before character at `a_index'.
		require
			index_in_bounds: a_index >= 1 and a_index <= position_input.count + 1
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_index
				column_non_negative: Result >= 0
			until
				i >= a_index
			loop
				if position_input.item (i) = '%N' then
					Result := 0
				else
					Result := Result + 1
				end
				i := i + 1
			variant
				a_index - i
			end
		ensure
			column_non_negative: Result >= 0
		end

	set_error (a_message: READABLE_STRING_8)
			-- Record first parse error.
		require
			message_attached: a_message /= Void
			message_not_empty: not a_message.is_empty
		do
			if not has_error then
				has_error := True
				last_error.wipe_out
				last_error.append (a_message)
				if current_position_index > 0 then
					if lazy_position_accounting then
						force_current_position
					else
						note_position (current_position_index)
					end
				end
			end
		ensure
			error_set: has_error
			message_set: not last_error.is_empty
		end

	element_stack: ARRAYED_STACK [STRING_8]
			-- Open element names.

	element_slice_stack: ARRAYED_STACK [XP_TOKEN_SLICE]
			-- Slice-backed open element names for the plain tokenizer path.

	element_stack_marker: STRING_8
			-- Non-mutated marker stored in `element_stack' when the real name is in `element_slice_stack'.

	entity_stack: ARRAYED_LIST [STRING_8]
			-- Active entity names for recursion detection.

	entity_reference_start_stack: ARRAYED_LIST [INTEGER]
			-- Original document start indexes for active entity references.

	entity_reference_count_stack: ARRAYED_LIST [INTEGER]
			-- Original document byte counts for active entity references.

	entity_table: HASH_TABLE [STRING_8, STRING_8]
			-- Internal and predefined general entities.

	parameter_entity_table: HASH_TABLE [STRING_8, STRING_8]
			-- Internal parameter entities.

	parameter_entity_accounting_table: HASH_TABLE [INTEGER, STRING_8]
			-- Logical replacement byte counts for internal parameter entities.

	external_entity_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- External general entities.

	external_parameter_entity_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- External parameter entities.

	attribute_decl_table: HASH_TABLE [ARRAYED_LIST [XP_ATTRIBUTE_DECL], STRING_8]
			-- Attribute declarations keyed by element name.

	namespace_context_stack: ARRAYED_STACK [HASH_TABLE [STRING_8, STRING_8]]
			-- Namespace scopes active at each element depth, plus one base scope.

	namespace_declaration_stack: ARRAYED_STACK [ARRAYED_LIST [STRING_8]]
			-- Namespace prefixes declared at each element depth.

	cached_doctype_prefix: detachable STRING_8
			-- Immutable validated UTF-8 prefix; absent when the optional cache is inactive.

	cached_doctype_name: detachable STRING_8
			-- Small immutable name snapshot paired with the retained source prefix.

	cached_doctype_line, cached_doctype_column, cached_doctype_entity_bytes: INTEGER
	cached_doctype_standalone: INTEGER
	cached_doctype_has_external_subset, cached_doctype_has_parameter_references: BOOLEAN
	cached_doctype_declarations_disabled, cached_doctype_foreign_loaded: BOOLEAN
	cached_doctype_not_standalone_checked: BOOLEAN

	inherited_dtd_declarations_disabled: BOOLEAN
			-- Declaration-processing snapshot supplied by an external-DTD parent.

	inherited_dtd_is_standalone: BOOLEAN
			-- Standalone snapshot supplied by an external-DTD parent.

	entity_literal_ended_by_undefined_parameter: BOOLEAN
			-- Stop collecting the current entity value after an unread parameter reference.

	inherited_entity_table: detachable HASH_TABLE [STRING_8, STRING_8]
			-- Parent general entity bindings for external entity child parsers.

	inherited_parameter_entity_table: detachable HASH_TABLE [STRING_8, STRING_8]
			-- Parent parameter entity bindings for external entity child parsers.

	inherited_parameter_entity_accounting_table: detachable HASH_TABLE [INTEGER, STRING_8]
			-- Parent parameter entity accounting bindings for external entity child parsers.

	inherited_external_entity_table: detachable HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- Parent external general entity bindings for external entity child parsers.

	inherited_external_parameter_entity_table: detachable HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- Parent external parameter entity bindings for external entity child parsers.

	document_element_count: INTEGER
			-- Number of root-level document elements seen.

	expanded_entity_bytes: INTEGER
			-- Total entity replacement bytes processed in current parse.

	current_entity_literal_accounting_adjustment: INTEGER
			-- Difference between stored and logical replacement bytes in current entity literal.

	parameter_subset_expansion_depth: INTEGER
			-- Number of parameter replacement fragments being interpreted as DTD content.

	dtd_subset_position_offset: INTEGER
			-- Raw document offset of the DTD substring currently being parsed.

	dtd_entity_reference_position: INTEGER
			-- Source position held during parameter entity replacement processing.

	has_doctype: BOOLEAN
			-- Has the document type declaration been parsed?

	document_has_external_subset: BOOLEAN
			-- Did the parsed doctype declare an external subset?

	xml_standalone: INTEGER
			-- XML declaration standalone value: 1 yes, 0 no, -1 absent.

	parameter_entities_unless_standalone: BOOLEAN
			-- Should external parameter entities be skipped when standalone='yes'?

	use_foreign_dtd: BOOLEAN
			-- Should a foreign DTD be loaded before the root element?

	input_is_utf8: BOOLEAN
			-- Do callers convert input to UTF-8 before parsing (see `set_input_is_utf8')?

	foreign_dtd_loaded: BOOLEAN
			-- Has the configured foreign DTD already been requested?

	not_standalone_checked: BOOLEAN
			-- Has the not-standalone handler already been consulted?

	doctype_name: STRING_8
			-- Declared document element name, if present.

	position_input: STRING_8
			-- Normalized document text used for position reporting.

	current_position_index: INTEGER
			-- Current 1-based position in `position_input'.

	lazy_position_accounting: BOOLEAN
			-- Are line and column counters deferred for the current no-callback parse?

	last_attribute_name_start: INTEGER
			-- Scratch start index for the most recent no-event attribute name.

	last_attribute_name_end: INTEGER
			-- Scratch end index for the most recent no-event attribute name.

	last_utf8_code: INTEGER
			-- Code point of the most recent sequence accepted by `utf8_character_length'.

	external_dtd_depth: INTEGER
			-- Number of external parameter entities currently being processed as DTD content.

	entity_element_floor: INTEGER
			-- Element depth at the start of the general entity whose content is being parsed;
			-- end tags may not close elements at or below it.

	dtd_has_parameter_entity_references: BOOLEAN
			-- Has the DTD referenced a parameter entity? Undeclared general entities
			-- are then not well-formedness errors unless the document is standalone.

	parsed_content_model: detachable XP_CONTENT_MODEL
			-- Scratch content model produced by recursive DTD parsing.

	is_initialized: BOOLEAN
			-- Has creation initialized invariant-protected fields?

invariant
	handler_attached: is_initialized implies handler /= Void
	last_error_attached: is_initialized implies last_error /= Void
	stack_attached: is_initialized implies element_stack /= Void
	element_slice_stack_attached: is_initialized implies element_slice_stack /= Void
	element_stack_marker_attached: is_initialized implies element_stack_marker /= Void
	element_slice_stack_not_above_stack: is_initialized implies element_slice_stack.count <= element_stack.count
	entity_stack_attached: is_initialized implies entity_stack /= Void
	entity_reference_start_stack_attached: is_initialized implies entity_reference_start_stack /= Void
	entity_reference_count_stack_attached: is_initialized implies entity_reference_count_stack /= Void
	entity_reference_stacks_aligned: is_initialized implies entity_reference_start_stack.count = entity_reference_count_stack.count
	entity_table_attached: is_initialized implies entity_table /= Void
	parameter_entity_table_attached: is_initialized implies parameter_entity_table /= Void
	parameter_entity_accounting_table_attached: is_initialized implies parameter_entity_accounting_table /= Void
	external_entity_table_attached: is_initialized implies external_entity_table /= Void
	external_parameter_entity_table_attached: is_initialized implies external_parameter_entity_table /= Void
	attribute_decl_table_attached: is_initialized implies attribute_decl_table /= Void
	namespace_context_stack_attached: is_initialized implies namespace_context_stack /= Void
	namespace_declaration_stack_attached: is_initialized implies namespace_declaration_stack /= Void
	namespace_context_available: is_initialized implies namespace_context_stack.count >= 1
	doctype_name_attached: is_initialized implies doctype_name /= Void
	valid_external_entity_policy: is_initialized implies is_valid_policy (external_entity_policy)
	input_limit_positive: is_initialized implies max_input_bytes > 0
	depth_limit_positive: is_initialized implies max_element_depth > 0
	name_limit_within_input_budget: is_initialized implies max_name_length > 0 and max_name_length <= max_input_bytes
	attribute_limit_positive: is_initialized implies max_attribute_count > 0
	token_limit_positive: is_initialized implies max_token_length > 0
	stack_within_depth_limit: is_initialized implies element_stack.count <= max_element_depth
	entity_stack_within_limit: is_initialized implies entity_stack.count <= Default_max_entity_depth
	document_element_count_bounded: is_initialized implies document_element_count >= 0 and document_element_count <= 1
	entity_expansion_non_negative: is_initialized implies expanded_entity_bytes >= 0
	valid_xml_standalone: is_initialized implies (xml_standalone = -1 or xml_standalone = 0 or xml_standalone = 1)
	error_has_message: is_initialized implies (has_error implies not last_error.is_empty)

end
