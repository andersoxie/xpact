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
			make_with_limits (a_handler, Default_max_input_bytes, Default_max_element_depth, Default_max_attribute_count, Default_max_token_length)
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
			handler := a_handler
			max_input_bytes := a_max_input_bytes
			max_element_depth := a_max_element_depth
			max_attribute_count := a_max_attribute_count
			max_token_length := a_max_token_length
			create element_stack.make (32)
			create entity_stack.make (8)
			create entity_table.make (8)
			create parameter_entity_table.make (4)
			create external_entity_table.make (4)
			create external_parameter_entity_table.make (4)
			create attribute_decl_table.make (4)
			create last_error.make_empty
			create doctype_name.make_empty
			create position_input.make_empty
			external_entity_policy := No_external_entities
			reset
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

	max_attribute_count: INTEGER
			-- Maximum attributes accepted on a single element.

	max_token_length: INTEGER
			-- Maximum accepted non-markup token length.

	last_error: STRING_8
			-- Last parse error.

	has_error: BOOLEAN
			-- Did the last parse fail?

	current_line_number: INTEGER
			-- Current 1-based XML line number.

	current_column_number: INTEGER
			-- Current 0-based XML column number.

	current_byte_index: INTEGER
			-- Current 0-based byte index, or -1 before parsing starts.

	current_byte_count: INTEGER
			-- Current token byte count, or zero at parse end and errors.

	external_entity_policy: INTEGER
			-- Current external entity loading policy.

	external_entity_resolver: detachable XP_EXTERNAL_ENTITY_RESOLVER
			-- Application-provided external entity resolver.

feature -- Configuration

	set_external_entity_policy (a_policy: INTEGER)
			-- Set external entity loading policy.
		require
			valid_policy: is_valid_policy (a_policy)
		do
			external_entity_policy := a_policy
		ensure
			policy_set: external_entity_policy = a_policy
		end

	set_external_entity_resolver (a_resolver: detachable XP_EXTERNAL_ENTITY_RESOLVER)
			-- Set resolver used when `external_entity_policy' permits loading.
		do
			external_entity_resolver := a_resolver
		ensure
			resolver_set: external_entity_resolver = a_resolver
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
		do
			reset
			l_input := normalized_input (a_input)
			position_input.wipe_out
			position_input.append (l_input)
			note_position (1)
			if not has_error then
				from
					i := 1
				invariant
					index_in_bounds: i >= 1 and i <= l_input.count + 1
					depth_within_limit: element_stack.count <= max_element_depth
				until
					i > l_input.count or has_error
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
			if not has_error and element_stack.count /= 0 then
				note_position (l_input.count + 1)
				set_error ("unclosed element")
			end
			if not has_error and document_element_count = 0 then
				note_position (l_input.count + 1)
				set_error ("missing document element")
			end
			if not has_error then
				note_position (l_input.count + 1)
			end
			Result := not has_error
		ensure
			result_matches_error: Result = not has_error
			success_is_balanced: Result implies element_stack.count = 0
			success_has_root: Result implies document_element_count = 1
		end

feature {NONE} -- Markup parsing

	parse_markup (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse markup beginning at `a_start_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		do
			if has_at (a_input, a_start_index, "</") then
				Result := parse_end_tag (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<!--") then
				Result := parse_comment (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<![CDATA[") then
				Result := parse_cdata (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<?") then
				Result := parse_processing_instruction (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<!DOCTYPE") then
				Result := parse_doctype (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<!") then
				set_error ("unsupported declaration")
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
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
			l_empty_element: BOOLEAN
		do
			create l_attributes.make
			i := a_start_index + 1
			if i > a_input.count or else not l_attributes.is_name_start_character (a_input.item (i)) then
				set_error ("invalid start tag name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				if i - name_start > Default_max_name_length then
					set_error ("element name exceeds limit")
					Result := a_input.count + 1
				else
					create l_name.make_from_string (a_input.substring (name_start, i - 1))
					i := skip_spaces (a_input, i)
					from
					invariant
						index_in_bounds: i >= 1 and i <= a_input.count + 1
						attributes_within_limit: l_attributes.count <= max_attribute_count
					until
						has_error or i > a_input.count or else a_input.item (i) = '>' or else a_input.item (i) = '/'
					loop
						if l_attributes.count >= max_attribute_count then
							set_error ("attribute count exceeds limit")
							i := a_input.count + 1
						else
							i := parse_attribute (a_input, i, l_attributes)
							if not has_error then
								i := skip_spaces (a_input, i)
							end
						end
					variant
						a_input.count - i + 1
					end
					if not has_error then
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
					if not has_error then
						emit_default (a_input.substring (a_start_index, Result - 1))
						note_position (a_start_index)
						open_element (l_name, l_attributes)
						if l_empty_element and not has_error then
							note_position (Result)
							close_element (l_name)
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
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			i := a_start_index + 2
			note_position (i)
			if i > a_input.count or else not l_attributes.is_name_start_character (a_input.item (i)) then
				set_error ("invalid end tag name")
				Result := a_input.count + 1
			else
				name_start := i
				i := scan_name (a_input, i)
				if i - name_start > Default_max_name_length then
					set_error ("end tag name exceeds limit")
					Result := a_input.count + 1
				else
					create l_name.make_from_string (a_input.substring (name_start, i - 1))
					i := skip_spaces (a_input, i)
					if i <= a_input.count and then a_input.item (i) = '>' then
						if element_stack.count > 0 and then element_stack.item.same_string (l_name) then
							note_position (a_start_index)
						else
							note_position (name_start)
						end
						emit_default (a_input.substring (a_start_index, i))
						close_element (l_name)
						Result := i + 1
					else
						note_position (i)
						set_error ("unterminated end tag")
						Result := a_input.count + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
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
							if a_attributes.has (l_name) then
								set_error ("duplicate attribute")
								Result := a_input.count + 1
							else
								a_attributes.put (l_name, l_value)
								Result := i + 1
							end
						else
							Result := a_input.count + 1
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
					i >= l_end - 1 or has_error
				loop
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
					emit_default (a_input.substring (a_start_index, l_end + 2))
					note_token_position (a_start_index, l_end + 3 - a_start_index)
					handler.on_comment (l_text)
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
			if element_stack.count = 0 then
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
					emit_default (a_input.substring (a_start_index, l_end + 2))
					note_position (a_start_index)
					handler.on_start_cdata_section
					if l_end > a_start_index + 9 then
						create l_text.make_from_string (a_input.substring (a_start_index + 9, l_end - 1))
						validate_xml_text (l_text)
						if not has_error then
							note_token_position (a_start_index + 9, l_text.count)
							emit_text (l_text)
						end
					end
					if not has_error then
						note_position (l_end + 3)
						handler.on_end_cdata_section
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
					if same_name_case_insensitive (l_target, "xml") and then a_start_index /= 1 then
						set_error ("xml declaration must be first")
						Result := a_input.count + 1
					else
						create l_data.make_empty
						if not same_name_case_insensitive (l_target, "xml") then
							if i < l_end and then is_xml_space (a_input.item (i)) then
								i := skip_spaces (a_input, i)
							end
							if i <= l_end - 1 then
								l_data.append (a_input.substring (i, l_end - 1))
							end
							emit_default (a_input.substring (a_start_index, l_end + 1))
							note_token_position (a_start_index, l_end + 2 - a_start_index)
							handler.on_processing_instruction (l_target, l_data)
						end
						Result := l_end + 2
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
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
			l_public_literal_start: INTEGER
			l_public_literal_end: INTEGER
			l_system_literal_start: INTEGER
			l_system_literal_end: INTEGER
			l_attributes: XP_ATTRIBUTES
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
					set_error ("unterminated doctype")
					Result := a_input.count + 1
				elseif l_end - a_start_index > max_token_length then
					set_error ("doctype token exceeds limit")
					Result := a_input.count + 1
				else
					i := skip_spaces (a_input, a_start_index + 9)
					if i > a_input.count or else not l_attributes.is_name_start_character (a_input.item (i)) then
						set_error ("invalid doctype name")
						Result := a_input.count + 1
					else
						name_start := i
						i := scan_name (a_input, i)
						doctype_name.wipe_out
						doctype_name.append (a_input.substring (name_start, i - 1))
						has_doctype := True
						l_subset_start := find_unquoted_character (a_input, '[', i, l_end)
						if l_subset_start > 0 then
							l_external_end := l_subset_start
						else
							l_external_end := l_end
						end
						i := skip_spaces (a_input, i)
						if i < l_external_end then
							if has_keyword_at (a_input, i, "SYSTEM") then
								l_has_external_subset := True
								i := skip_spaces (a_input, i + 6)
								if i < l_external_end and then is_quote (a_input.item (i)) then
									l_system_literal_start := i
									i := read_quoted_literal (a_input, i, l_external_end, l_system_id)
									l_system_literal_end := i - 1
								else
									set_error ("missing external system identifier")
								end
							elseif has_keyword_at (a_input, i, "PUBLIC") then
								l_has_external_subset := True
								i := skip_spaces (a_input, i + 6)
								if i < l_external_end and then is_quote (a_input.item (i)) then
									l_public_literal_start := i
									i := read_public_id_literal (a_input, i, l_external_end, l_public_id)
									l_public_literal_end := i - 1
									if not has_error then
										i := skip_spaces (a_input, i)
										if i < l_external_end and then is_quote (a_input.item (i)) then
											l_system_literal_start := i
											i := read_quoted_literal (a_input, i, l_external_end, l_system_id)
											l_system_literal_end := i - 1
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
						if not has_error then
							if l_public_literal_start > 0 then
								emit_default (a_input.substring (l_public_literal_start, l_public_literal_end))
							end
							if l_system_literal_start > 0 then
								emit_default (a_input.substring (l_system_literal_start, l_system_literal_end))
							end
							if not l_public_id.is_empty then
								l_event_public_id := l_public_id
							end
							if not l_system_id.is_empty then
								l_event_system_id := l_system_id
							end
							handler.on_start_doctype_decl (doctype_name, l_event_system_id, l_event_public_id, l_has_internal_subset)
						end
						if l_subset_start > 0 then
							l_subset_end := find_subset_end (a_input, l_subset_start + 1, l_end)
							if l_subset_end = 0 then
								set_error ("unterminated internal subset")
							else
								create l_subset.make_from_string (a_input.substring (l_subset_start + 1, l_subset_end - 1))
								process_internal_subset (l_subset)
							end
						end
						if not has_error and l_has_external_subset then
							include_external_subset (l_public_id, l_system_id)
						end
						if has_error then
							Result := a_input.count + 1
						else
							handler.on_end_doctype_decl
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

	parse_character_data (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse character data until next markup delimiter.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			not_markup: a_input.item (a_start_index) /= '<'
		local
			i: INTEGER
			c: CHARACTER_8
			l_text: STRING_8
		do
			create l_text.make_empty
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or has_error or else a_input.item (i) = '<'
			loop
				note_position (i)
				c := a_input.item (i)
				if has_at (a_input, i, "]]>") then
					set_error ("CDATA close marker in character data")
					i := a_input.count + 1
				elseif c = '&' then
					if element_stack.count = 0 then
						set_error ("entity reference outside document element")
						i := a_input.count + 1
					else
						i := append_reference_in_content (a_input, i, l_text)
					end
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					l_text.append_character (c)
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
			if not has_error then
				if element_stack.count = 0 then
					if not is_all_xml_space (l_text) then
						set_error ("character data outside document element")
						Result := a_input.count + 1
					else
						emit_default (l_text)
						Result := i
					end
				else
					emit_default (l_text)
					note_token_position (a_start_index, l_text.count)
					emit_text (l_text)
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
					include_general_entity_in_content (l_name)
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

	include_general_entity_in_content (a_name: READABLE_STRING_8)
			-- Include general entity `a_name' as parsed content.
		require
			valid_name: is_valid_name (a_name)
		do
			if is_entity_active (a_name) then
				set_error ("recursive entity reference")
			elseif entity_stack.count >= Default_max_entity_depth then
				set_error ("entity expansion depth exceeded")
			elseif attached entity_value (a_name) as l_value then
				note_entity_expansion (l_value.count)
				if not has_error then
					push_entity (a_name)
					parse_entity_content (l_value)
					pop_entity
				end
			elseif attached external_entity (a_name) as l_external then
				include_external_entity_in_content (l_external)
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
		do
			if is_entity_active (a_name) then
				set_error ("recursive entity reference")
			elseif entity_stack.count >= Default_max_entity_depth then
				set_error ("entity expansion depth exceeded")
			elseif attached entity_value (a_name) as l_value then
				note_entity_expansion (l_value.count)
				if not has_error then
					push_entity (a_name)
					expand_literal_text (l_value, a_text)
					pop_entity
				end
			elseif attached external_entity (a_name) as l_external then
				include_external_entity_in_literal (l_external, a_text)
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
			if not allows_parameter_entities (external_entity_policy) then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif external_entity_resolver /= Void and then attached external_entity_resolver as l_resolver then
				if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, True) as l_value then
					note_entity_expansion (l_value.count)
					if not has_error then
						process_internal_subset (l_value)
					end
				else
					set_error ("external entity not resolved")
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
			if not allows_parameter_entities (external_entity_policy) then
				set_error ("external entity not loaded")
			elseif external_entity_resolver = Void then
				set_error ("external entity resolver missing")
			elseif external_entity_resolver /= Void and then attached external_entity_resolver as l_resolver then
				if attached l_resolver.resolve_external_entity (a_entity.name, a_entity.public_id, a_entity.system_id, True) as l_value then
					note_entity_expansion (l_value.count)
					if not has_error then
						a_text.append (l_value)
					end
				else
					set_error ("external entity not resolved")
				end
			end
		end

	include_external_subset (a_public_id, a_system_id: READABLE_STRING_8)
			-- Resolve and process external DTD subset if policy permits it.
		require
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
			system_id_not_empty: not a_system_id.is_empty
		do
			if allows_parameter_entities (external_entity_policy) then
				if external_entity_resolver = Void then
					set_error ("external entity resolver missing")
				elseif attached external_entity_resolver as l_resolver then
					if attached l_resolver.resolve_external_entity (doctype_name, a_public_id, a_system_id, True) as l_value then
						note_entity_expansion (l_value.count)
						if not has_error then
							process_internal_subset (l_value)
						end
					else
						set_error ("external entity not resolved")
					end
				end
			end
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
				i > a_content.count or has_error
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
				i > a_content.count or has_error
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

	process_internal_subset (a_subset: READABLE_STRING_8)
			-- Process entity declarations and parameter entity references in an internal subset.
		require
			subset_attached: a_subset /= Void
		local
			i: INTEGER
			l_end: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_subset.count + 1
			until
				i > a_subset.count or has_error
			loop
				if has_at (a_subset, i, "<!ENTITY") then
					i := parse_entity_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!ATTLIST") then
					i := parse_attlist_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!ELEMENT") then
					i := parse_element_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!NOTATION") then
					i := parse_notation_declaration (a_subset, i)
				elseif has_at (a_subset, i, "<!--") then
					l_end := find_sequence (a_subset, "-->", i + 4)
					if l_end = 0 then
						set_error ("unterminated comment")
						i := a_subset.count + 1
					else
						i := l_end + 3
					end
				elseif has_at (a_subset, i, "<?") then
					l_end := find_sequence (a_subset, "?>", i + 2)
					if l_end = 0 then
						set_error ("unterminated processing instruction")
						i := a_subset.count + 1
					else
						i := l_end + 2
					end
				elseif a_subset.item (i).code = 37 then
					i := include_parameter_entity_in_subset (a_subset, i)
				else
					if is_xml_space (a_subset.item (i)) then
						emit_default (a_subset.substring (i, i))
					end
					i := i + 1
				end
			variant
				a_subset.count - i + 1
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
				i := skip_spaces (a_subset, a_start_index + 9)
				if i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid element declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					i := skip_spaces (a_subset, i)
					parsed_content_model := Void
					if has_keyword_at (a_subset, i, "EMPTY") then
						create l_model.make ({XP_CONTENT_MODEL}.Type_empty, {XP_CONTENT_MODEL}.Quant_none, Void)
						i := i + 5
					elseif has_keyword_at (a_subset, i, "ANY") then
						create l_model.make ({XP_CONTENT_MODEL}.Type_any, {XP_CONTENT_MODEL}.Quant_none, Void)
						i := i + 3
					elseif i <= l_end - 1 and then a_subset.item (i) = '(' then
						i := parse_content_particle (a_subset, i, l_end - 1)
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
							handler.on_element_decl (l_name, l_attached_model)
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

	parse_content_particle (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER): INTEGER
			-- Parse one element-content particle and store it in `parsed_content_model'.
		require
			subset_attached: a_subset /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_subset.count
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
		do
			create l_attributes.make
			i := a_start_index
			parsed_content_model := Void
			if i <= a_end_index and then a_subset.item (i) = '(' then
				i := skip_spaces (a_subset, i + 1)
				if has_at (a_subset, i, "#PCDATA") then
					create l_node.make ({XP_CONTENT_MODEL}.Type_mixed, {XP_CONTENT_MODEL}.Quant_none, Void)
					i := skip_spaces (a_subset, i + 7)
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
							i := skip_spaces (a_subset, i + 1)
							if i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
								name_start := i
								i := scan_name (a_subset, i)
								create l_name.make_from_string (a_subset.substring (name_start, i - 1))
								create l_child.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, l_name)
								l_node.add_child (l_child)
								i := skip_spaces (a_subset, i)
							else
								set_error ("invalid mixed content model")
							end
						else
							set_error ("invalid mixed content model")
						end
					variant
						a_end_index - i + 2
					end
					if not has_error then
						i := apply_content_quantifier (l_node, a_subset, i, a_end_index)
						parsed_content_model := l_node
						Result := i
					else
						Result := a_subset.count + 1
					end
				else
					i := parse_content_particle (a_subset, i, a_end_index)
					if not has_error and then attached parsed_content_model as l_first_child then
						i := skip_spaces (a_subset, i)
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
								i := skip_spaces (a_subset, i + 1)
								i := parse_content_particle (a_subset, i, a_end_index)
								if not has_error and then attached parsed_content_model as l_next_child then
									l_node.add_child (l_next_child)
									i := skip_spaces (a_subset, i)
									if i <= a_end_index and then a_subset.item (i) = l_separator then
									elseif i <= a_end_index and then a_subset.item (i) = ')' then
										i := i + 1
										l_done := True
									else
										set_error ("invalid element content separator")
									end
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
							Result := i
						else
							Result := a_subset.count + 1
						end
					else
						Result := a_subset.count + 1
					end
				end
			elseif i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
				name_start := i
				i := scan_name (a_subset, i)
				create l_name.make_from_string (a_subset.substring (name_start, i - 1))
				create l_node.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, l_name)
				i := apply_content_quantifier (l_node, a_subset, i, a_end_index)
				parsed_content_model := l_node
				Result := i
			else
				set_error ("invalid element content particle")
				Result := a_subset.count + 1
			end
		ensure
			result_in_bounds: Result <= a_subset.count + 1
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
				i := skip_spaces (a_subset, a_start_index + 10)
				if i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid notation declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					create l_public_id.make_empty
					create l_system_id.make_empty
					i := skip_spaces (a_subset, i)
					if has_keyword_at (a_subset, i, "SYSTEM") then
						i := skip_spaces (a_subset, i + 6)
						if i <= l_end - 1 and then is_quote (a_subset.item (i)) then
							i := read_quoted_literal (a_subset, i, l_end - 1, l_system_id)
							l_system := l_system_id
						else
							set_error ("missing notation system identifier")
						end
					elseif has_keyword_at (a_subset, i, "PUBLIC") then
						i := skip_spaces (a_subset, i + 6)
						if i <= l_end - 1 and then is_quote (a_subset.item (i)) then
							i := read_public_id_literal (a_subset, i, l_end - 1, l_public_id)
							l_public := l_public_id
							if not has_error then
								i := skip_spaces (a_subset, i)
								if i <= l_end - 1 and then is_quote (a_subset.item (i)) then
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
							handler.on_notation_decl (l_name, Void, l_system, l_public)
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
		do
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated attlist declaration")
				Result := a_subset.count + 1
			else
				i := skip_spaces (a_subset, a_start_index + 9)
				if i >= l_end or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid attlist element name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_element_name.make_from_string (a_subset.substring (name_start, i - 1))
					i := skip_spaces (a_subset, i)
					from
					invariant
						index_in_bounds: i >= 1 and i <= l_end
						element_name_attached: l_element_name /= Void
					until
						has_error or i >= l_end
					loop
						if not l_attributes.is_name_start_character (a_subset.item (i)) then
							set_error ("invalid attlist attribute name")
						else
							name_start := i
							i := scan_name (a_subset, i)
							create l_attribute_name.make_from_string (a_subset.substring (name_start, i - 1))
							i := skip_spaces (a_subset, i)
							create l_attribute_type.make_empty
							if i <= l_end - 1 then
								i := parse_attlist_type (a_subset, i, l_end - 1, l_attribute_type)
							else
								set_error ("missing attlist type")
							end
							if not has_error then
								i := skip_spaces (a_subset, i)
								l_default_value := Void
								l_is_required := False
								if has_at (a_subset, i, "#REQUIRED") then
									l_is_required := True
									i := i + 9
								elseif has_at (a_subset, i, "#IMPLIED") then
									i := i + 8
								elseif has_at (a_subset, i, "#FIXED") then
									i := skip_spaces (a_subset, i + 6)
									if i <= l_end - 1 and then is_quote (a_subset.item (i)) then
										create l_new_default_value.make_empty
										i := parse_attlist_default_value (a_subset, i, l_end - 1, l_new_default_value)
										l_default_value := l_new_default_value
									else
										set_error ("missing fixed attlist default")
									end
								elseif i <= l_end - 1 and then is_quote (a_subset.item (i)) then
									create l_new_default_value.make_empty
									i := parse_attlist_default_value (a_subset, i, l_end - 1, l_new_default_value)
									l_default_value := l_new_default_value
								else
									set_error ("missing attlist default declaration")
								end
								if not has_error then
									record_attribute_decl (l_element_name, l_attribute_name, l_attribute_type, l_default_value, l_is_required)
									handler.on_attlist_decl (l_element_name, l_attribute_name, l_attribute_type, l_default_value, l_is_required)
									i := skip_spaces (a_subset, i)
								end
							end
						end
					variant
						l_end - i
					end
					if has_error then
						Result := a_subset.count + 1
					else
						Result := l_end + 1
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

	parse_attlist_type (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_type: STRING_8): INTEGER
			-- Parse an attribute type and append Expat-compatible spelling to `a_type'.
		require
			subset_attached: a_subset /= Void
			type_attached: a_type /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_subset.count
		local
			i: INTEGER
			name_start: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			i := a_start_index
			if has_keyword_at (a_subset, i, "NOTATION") then
				a_type.append ("NOTATION")
				i := skip_spaces (a_subset, i + 8)
				if i <= a_end_index and then a_subset.item (i) = '(' then
					Result := append_attlist_group (a_subset, i, a_end_index, a_type)
				else
					set_error ("missing notation attlist group")
					Result := a_subset.count + 1
				end
			elseif i <= a_end_index and then a_subset.item (i) = '(' then
				Result := append_attlist_group (a_subset, i, a_end_index, a_type)
			elseif i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
				name_start := i
				i := scan_name (a_subset, i)
				a_type.append (a_subset.substring (name_start, i - 1))
				Result := i
			else
				set_error ("invalid attlist type")
				Result := a_subset.count + 1
			end
		ensure
			result_in_bounds: Result <= a_subset.count + 1
		end

	append_attlist_group (a_subset: READABLE_STRING_8; a_start_index, a_end_index: INTEGER; a_type: STRING_8): INTEGER
			-- Append an enumeration/notation group with XML whitespace removed.
		require
			subset_attached: a_subset /= Void
			type_attached: a_type /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_subset.count
			starts_group: a_subset.item (a_start_index) = '('
		local
			i: INTEGER
			c: CHARACTER_8
			l_done: BOOLEAN
		do
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_end_index + 1
			until
				i > a_end_index or has_error or l_done
			loop
				c := a_subset.item (i)
				if not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
				elseif not is_xml_space (c) then
					a_type.append_character (c)
				end
				if c = ')' then
					l_done := True
					Result := i + 1
				end
				i := i + 1
			variant
				a_end_index - i + 1
			end
			if not has_error and not l_done then
				set_error ("unterminated attlist type")
				Result := a_subset.count + 1
			end
		ensure
			result_in_bounds: Result <= a_subset.count + 1
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
						set_error ("unterminated reference")
					else
						i := append_reference_in_literal (a_subset, i, a_value)
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
			variant
				a_end_index - i + 1
			end
			if not has_error then
				if i > a_end_index then
					set_error ("unterminated attlist default")
					Result := a_subset.count + 1
				else
					Result := i + 1
				end
			else
				Result := a_subset.count + 1
			end
		ensure
			result_in_bounds: Result <= a_subset.count + 1
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
		do
			create l_attributes.make
			l_end := find_markup_declaration_end (a_subset, a_start_index)
			if l_end = 0 then
				set_error ("unterminated entity declaration")
				Result := a_subset.count + 1
			else
				i := skip_spaces (a_subset, a_start_index + 8)
				if i <= a_subset.count and then a_subset.item (i).code = 37 then
					l_is_parameter := True
					i := skip_spaces (a_subset, i + 1)
				end
				if i > a_subset.count or else not l_attributes.is_name_start_character (a_subset.item (i)) then
					set_error ("invalid entity declaration name")
					Result := a_subset.count + 1
				else
					name_start := i
					i := scan_name (a_subset, i)
					create l_name.make_from_string (a_subset.substring (name_start, i - 1))
					i := skip_spaces (a_subset, i)
					if i <= a_subset.count and then is_quote (a_subset.item (i)) then
						l_quote := a_subset.item (i)
						create l_value.make_empty
						i := parse_entity_literal (a_subset, i + 1, l_quote, l_value)
						if not has_error then
							if l_is_parameter then
								put_parameter_entity (l_name, l_value)
							else
								put_general_entity (l_name, l_value)
							end
							Result := l_end + 1
						else
							Result := a_subset.count + 1
						end
					else
						Result := parse_external_entity_declaration (a_subset, i, l_end, l_name, l_is_parameter)
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
				i := skip_spaces (a_subset, i + 6)
				if i <= a_end_index and then is_quote (a_subset.item (i)) then
					i := read_quoted_literal (a_subset, i, a_end_index, l_system_id)
				else
					set_error ("missing external system identifier")
				end
			elseif has_keyword_at (a_subset, i, "PUBLIC") then
				i := skip_spaces (a_subset, i + 6)
				if i <= a_end_index and then is_quote (a_subset.item (i)) then
					i := read_public_id_literal (a_subset, i, a_end_index, l_public_id)
					if not has_error then
						i := skip_spaces (a_subset, i)
						if i <= a_end_index and then is_quote (a_subset.item (i)) then
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
			if not has_error then
				i := skip_spaces (a_subset, i)
				if not a_is_parameter and then i < a_end_index and then has_keyword_at (a_subset, i, "NDATA") then
					l_is_unparsed := True
					i := skip_spaces (a_subset, i + 5)
					if i <= a_end_index and then l_attributes.is_name_start_character (a_subset.item (i)) then
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
					put_external_entity (a_name, l_public_id, l_system_id, l_notation_name, a_is_parameter, l_is_unparsed)
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
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or has_error or else a_input.item (i) = a_quote
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
				elseif attached parameter_entity_value (l_name) as l_value then
					a_text.append (l_value)
					Result := l_end + 1
				elseif attached external_parameter_entity (l_name) as l_external then
					append_external_parameter_entity_in_literal (l_external, a_text)
					if has_error then
						Result := a_input.count + 1
					else
						Result := l_end + 1
					end
				else
					set_error ("undefined parameter entity")
					Result := a_input.count + 1
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
		end

	include_parameter_entity_in_subset (a_subset: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Include a parameter entity reference in the internal subset.
		require
			subset_attached: a_subset /= Void
			starts_reference: a_subset.item (a_start_index).code = 37
		local
			l_end: INTEGER
			l_name: STRING_8
		do
			l_end := find_character (a_subset, ';', a_start_index + 1)
			if l_end = 0 then
				set_error ("unterminated parameter entity reference")
				Result := a_subset.count + 1
			else
				create l_name.make_from_string (a_subset.substring (a_start_index + 1, l_end - 1))
				if not is_valid_name (l_name) then
					set_error ("invalid parameter entity name")
					Result := a_subset.count + 1
				elseif is_entity_active (l_name) then
					set_error ("recursive entity reference")
					Result := a_subset.count + 1
				elseif attached parameter_entity_value (l_name) as l_value then
					push_entity (l_name)
					process_internal_subset (l_value)
					pop_entity
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
					set_error ("undefined parameter entity")
					Result := a_subset.count + 1
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_subset.count + 1
		end

feature {NONE} -- Event dispatch

	open_element (a_name: READABLE_STRING_8; a_attributes: XP_ATTRIBUTES)
			-- Push `a_name' and emit start-element event.
		require
			name_attached: a_name /= Void
			attributes_attached: a_attributes /= Void
			valid_name: a_attributes.is_valid_name (a_name)
			attributes_bounded: a_attributes.count <= max_attribute_count
		local
			l_name: STRING_8
		do
			if element_stack.count >= max_element_depth then
				set_error ("maximum element depth exceeded")
			elseif element_stack.count = 0 and then document_element_count > 0 then
				set_error ("multiple document elements")
			elseif element_stack.count = 0 and then not doctype_name.is_empty and then not doctype_name.same_string (a_name) then
				set_error ("document element does not match doctype")
			else
				if element_stack.count = 0 then
					document_element_count := document_element_count + 1
				end
				apply_default_attributes (a_name, a_attributes)
				if not has_error then
					create l_name.make_from_string (a_name)
					element_stack.extend (l_name)
					handler.on_start_element (a_name, a_attributes)
				end
			end
		ensure
			pushed_or_error: (not has_error) implies element_stack.count = old element_stack.count + 1
			depth_bounded: element_stack.count <= max_element_depth
		end

	close_element (a_name: READABLE_STRING_8)
			-- Pop `a_name' and emit end-element event.
		require
			name_attached: a_name /= Void
		do
			if element_stack.count = 0 then
				set_error ("unexpected end tag")
			elseif not element_stack.item.same_string (a_name) then
				set_error ("mismatched end tag")
			else
				element_stack.remove
				handler.on_end_element (a_name)
			end
		ensure
			popped_or_error: (not has_error) implies element_stack.count = old element_stack.count - 1
		end

	emit_text (a_text: READABLE_STRING_8)
			-- Emit character data.
		require
			text_attached: a_text /= Void
			text_within_limit: a_text.count <= max_token_length
		do
			if a_text.count > 0 then
				handler.on_character_data (a_text)
			end
		end

	emit_default (a_text: READABLE_STRING_8)
			-- Emit raw default-handler text.
		require
			text_attached: a_text /= Void
		do
			if not a_text.is_empty then
				handler.on_default (a_text)
			end
		end

feature {NONE} -- Scanning

	normalized_input (a_input: READABLE_STRING_8): STRING_8
			-- XML line-end normalized input.
		require
			input_attached: a_input /= Void
		local
			i: INTEGER
			c: CHARACTER_8
		do
			create Result.make (a_input.count)
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
			until
				i > a_input.count or has_error
			loop
				c := a_input.item (i)
				if c = '%R' then
					Result.append_character ('%N')
					if i + 1 <= a_input.count and then a_input.item (i + 1) = '%N' then
						i := i + 2
					else
						i := i + 1
					end
				elseif not is_xml_character_code (c.code) then
					set_error ("invalid XML character")
					i := a_input.count + 1
				else
					Result.append_character (c)
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
		ensure
			result_attached: Result /= Void
		end

	scan_name (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Index immediately after the XML name beginning at `a_start_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
		local
			i: INTEGER
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			from
				i := a_start_index
			invariant
				index_in_bounds: i >= a_start_index and i <= a_input.count + 1
			until
				i > a_input.count or else not l_attributes.is_name_character (a_input.item (i))
			loop
				i := i + 1
			variant
				a_input.count - i + 1
			end
			Result := i
		ensure
			progress: Result > a_start_index
			result_in_bounds: Result <= a_input.count + 1
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
				i := a_start_index + 2
			invariant
				index_in_bounds: i >= a_start_index + 2 and i <= a_input.count + 1
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
			-- Matching unquoted `]' before `a_end_index', or 0.
		require
			input_attached: a_input /= Void
			valid_bounds: a_start_index >= 1 and a_start_index <= a_end_index and a_end_index <= a_input.count
		do
			Result := find_unquoted_character (a_input, ']', a_start_index, a_end_index)
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
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			Result := l_attributes.is_valid_name (a_name)
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
				set_error ("invalid character reference")
			else
				if a_body.count >= 2 and then a_body.item (1).as_lower = 'x' then
					l_base := 16
					i := 2
				else
					l_base := 10
					i := 1
				end
				if i > a_body.count then
					set_error ("invalid character reference")
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
						set_error ("invalid character reference")
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

	put_parameter_entity (a_name, a_value: READABLE_STRING_8)
			-- Record parameter entity if not already bound.
		require
			valid_name: is_valid_name (a_name)
			value_attached: a_value /= Void
		local
			l_name: STRING_8
			l_value: STRING_8
		do
			create l_name.make_from_string (a_name)
			if not parameter_entity_table.has (l_name) then
				create l_value.make_from_string (a_value)
				parameter_entity_table.put (l_value, l_name)
			end
		end

	put_external_entity (a_name, a_public_id, a_system_id, a_notation_name: READABLE_STRING_8; a_is_parameter, a_is_unparsed: BOOLEAN)
			-- Record external entity metadata if not already bound.
		require
			valid_name: is_valid_name (a_name)
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
			system_id_not_empty: not a_system_id.is_empty
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

feature {NONE} -- State

	reset
			-- Reset parse state.
		do
			has_error := False
			last_error.wipe_out
			position_input.wipe_out
			current_position_index := 0
			current_line_number := 1
			current_column_number := 0
			current_byte_index := -1
			current_byte_count := 0
			doctype_name.wipe_out
			element_stack.wipe_out
			entity_stack.wipe_out
			entity_table.wipe_out
			parameter_entity_table.wipe_out
			external_entity_table.wipe_out
			external_parameter_entity_table.wipe_out
			attribute_decl_table.wipe_out
			document_element_count := 0
			expanded_entity_bytes := 0
			has_doctype := False
			initialize_predefined_entities
		ensure
			no_error: not has_error
			no_message: last_error.is_empty
			no_open_elements: element_stack.count = 0
			one_predefined_entity: attached entity_value ("lt") as l_value and then l_value.same_string ("<")
		end

	note_position (a_index: INTEGER)
			-- Record the current parser position as a 1-based input index.
		local
			l_index: INTEGER
		do
			if not position_input.is_empty or else a_index > 0 then
				l_index := bounded_position_index (a_index)
				current_position_index := l_index
				current_line_number := line_number_at (l_index)
				current_column_number := column_number_at (l_index)
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
					note_position (current_position_index)
				end
			end
		ensure
			error_set: has_error
			message_set: not last_error.is_empty
		end

	element_stack: ARRAYED_STACK [STRING_8]
			-- Open element names.

	entity_stack: ARRAYED_LIST [STRING_8]
			-- Active entity names for recursion detection.

	entity_table: HASH_TABLE [STRING_8, STRING_8]
			-- Internal and predefined general entities.

	parameter_entity_table: HASH_TABLE [STRING_8, STRING_8]
			-- Internal parameter entities.

	external_entity_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- External general entities.

	external_parameter_entity_table: HASH_TABLE [XP_EXTERNAL_ENTITY, STRING_8]
			-- External parameter entities.

	attribute_decl_table: HASH_TABLE [ARRAYED_LIST [XP_ATTRIBUTE_DECL], STRING_8]
			-- Attribute declarations keyed by element name.

	document_element_count: INTEGER
			-- Number of root-level document elements seen.

	expanded_entity_bytes: INTEGER
			-- Total entity replacement bytes processed in current parse.

	has_doctype: BOOLEAN
			-- Has the document type declaration been parsed?

	doctype_name: STRING_8
			-- Declared document element name, if present.

	position_input: STRING_8
			-- Normalized document text used for position reporting.

	current_position_index: INTEGER
			-- Current 1-based position in `position_input'.

	parsed_content_model: detachable XP_CONTENT_MODEL
			-- Scratch content model produced by recursive DTD parsing.

invariant
	handler_attached: handler /= Void
	last_error_attached: last_error /= Void
	stack_attached: element_stack /= Void
	entity_stack_attached: entity_stack /= Void
	entity_table_attached: entity_table /= Void
	parameter_entity_table_attached: parameter_entity_table /= Void
	external_entity_table_attached: external_entity_table /= Void
	external_parameter_entity_table_attached: external_parameter_entity_table /= Void
	attribute_decl_table_attached: attribute_decl_table /= Void
	doctype_name_attached: doctype_name /= Void
	valid_external_entity_policy: is_valid_policy (external_entity_policy)
	input_limit_positive: max_input_bytes > 0
	depth_limit_positive: max_element_depth > 0
	attribute_limit_positive: max_attribute_count > 0
	token_limit_positive: max_token_length > 0
	stack_within_depth_limit: element_stack.count <= max_element_depth
	entity_stack_within_limit: entity_stack.count <= Default_max_entity_depth
	document_element_count_bounded: document_element_count >= 0 and document_element_count <= 1
	entity_expansion_non_negative: expanded_entity_bytes >= 0
	error_has_message: has_error implies not last_error.is_empty

end
