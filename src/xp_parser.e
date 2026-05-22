note
	description: "Phase 1 xpact streaming XML parser with explicit resource contracts."

class
	XP_PARSER

inherit
	XP_LIMITS

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
			create last_error.make_empty
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

feature -- Parsing

	parse (a_input: READABLE_STRING_8): BOOLEAN
			-- Parse complete XML document `a_input'.
		require
			input_attached: a_input /= Void
			input_within_limit: a_input.count <= max_input_bytes
		local
			i: INTEGER
			text_start: INTEGER
		do
			reset
			from
				i := 1
				text_start := 1
			invariant
				index_in_bounds: i >= 1 and i <= a_input.count + 1
				text_start_in_bounds: text_start >= 1 and text_start <= a_input.count + 1
				depth_within_limit: element_stack.count <= max_element_depth
			until
				i > a_input.count or has_error
			loop
				if a_input.item (i) = '<' then
					if text_start < i then
						emit_text (a_input.substring (text_start, i - 1))
					end
					if not has_error then
						i := parse_markup (a_input, i)
						text_start := i
					end
				else
					i := i + 1
				end
			variant
				a_input.count - i + 1
			end
			if not has_error and text_start <= a_input.count then
				emit_text (a_input.substring (text_start, a_input.count))
			end
			if not has_error and element_stack.count /= 0 then
				set_error ("unclosed element")
			end
			Result := not has_error
		ensure
			result_matches_error: Result = not has_error
			success_is_balanced: Result implies element_stack.count = 0
		end

feature {NONE} -- Markup parsing

	parse_markup (a_input: READABLE_STRING_8; a_start_index: INTEGER): INTEGER
			-- Parse markup beginning at `a_start_index'.
		require
			input_attached: a_input /= Void
			valid_start: a_start_index >= 1 and a_start_index <= a_input.count
			starts_markup: a_input.item (a_start_index) = '<'
		local
			l_end: INTEGER
		do
			if has_at (a_input, a_start_index, "</") then
				Result := parse_end_tag (a_input, a_start_index)
			elseif has_at (a_input, a_start_index, "<!--") then
				l_end := find_sequence (a_input, "-->", a_start_index + 4)
				if l_end = 0 then
					set_error ("unterminated comment")
					Result := a_input.count + 1
				elseif l_end - a_start_index > max_token_length then
					set_error ("comment token exceeds limit")
					Result := a_input.count + 1
				else
					Result := l_end + 3
				end
			elseif has_at (a_input, a_start_index, "<![CDATA[") then
				l_end := find_sequence (a_input, "]]>", a_start_index + 9)
				if l_end = 0 then
					set_error ("unterminated CDATA section")
					Result := a_input.count + 1
				elseif l_end - (a_start_index + 9) > max_token_length then
					set_error ("CDATA token exceeds limit")
					Result := a_input.count + 1
				else
					if l_end > a_start_index + 9 then
						emit_text (a_input.substring (a_start_index + 9, l_end - 1))
					end
					Result := l_end + 3
				end
			elseif has_at (a_input, a_start_index, "<?") then
				l_end := find_sequence (a_input, "?>", a_start_index + 2)
				if l_end = 0 then
					set_error ("unterminated processing instruction")
					Result := a_input.count + 1
				elseif l_end - a_start_index > max_token_length then
					set_error ("processing instruction exceeds limit")
					Result := a_input.count + 1
				else
					Result := l_end + 2
				end
			elseif has_at (a_input, a_start_index, "<!") then
				l_end := find_character (a_input, '>', a_start_index + 2)
				if l_end = 0 then
					set_error ("unterminated declaration")
					Result := a_input.count + 1
				elseif l_end - a_start_index > max_token_length then
					set_error ("declaration token exceeds limit")
					Result := a_input.count + 1
				else
					Result := l_end + 1
				end
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
						i := parse_attribute (a_input, i, l_attributes)
						if not has_error then
							i := skip_spaces (a_input, i)
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
						open_element (l_name, l_attributes)
						if l_empty_element and not has_error then
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
						close_element (l_name)
						Result := i + 1
					else
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
			value_start: INTEGER
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
					if i > a_input.count or else not (a_input.item (i).code = 34 or a_input.item (i).code = 39) then
						set_error ("missing attribute quote")
						Result := a_input.count + 1
					else
						l_quote := a_input.item (i)
						value_start := i + 1
						i := find_character (a_input, l_quote, value_start)
						if i = 0 then
							set_error ("unterminated attribute value")
							Result := a_input.count + 1
						elseif i - value_start > max_token_length then
							set_error ("attribute value exceeds limit")
							Result := a_input.count + 1
						elseif a_attributes.has (l_name) then
							set_error ("duplicate attribute")
							Result := a_input.count + 1
						else
							if value_start <= i - 1 then
								create l_value.make_from_string (a_input.substring (value_start, i - 1))
							else
								create l_value.make_empty
							end
							a_attributes.put (l_name, l_value)
							Result := i + 1
						end
					end
				end
			end
		ensure
			progress_or_error: Result > a_start_index or has_error
			result_in_bounds: Result <= a_input.count + 1
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
			else
				create l_name.make_from_string (a_name)
				element_stack.extend (l_name)
				handler.on_start_element (a_name, a_attributes)
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

feature {NONE} -- Scanning

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

	is_xml_space (c: CHARACTER_8): BOOLEAN
			-- Is `c' XML whitespace?
		do
			Result := c = ' ' or c = '%T' or c = '%N' or c = '%R'
		end

feature {NONE} -- State

	reset
			-- Reset parse state.
		do
			has_error := False
			last_error.wipe_out
			element_stack.wipe_out
		ensure
			no_error: not has_error
			no_message: last_error.is_empty
			no_open_elements: element_stack.count = 0
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
			end
		ensure
			error_set: has_error
			message_set: not last_error.is_empty
		end

	element_stack: ARRAYED_STACK [STRING_8]
			-- Open element names.

invariant
	handler_attached: handler /= Void
	last_error_attached: last_error /= Void
	stack_attached: element_stack /= Void
	input_limit_positive: max_input_bytes > 0
	depth_limit_positive: max_element_depth > 0
	attribute_limit_positive: max_attribute_count > 0
	token_limit_positive: max_token_length > 0
	stack_within_depth_limit: element_stack.count <= max_element_depth
	error_has_message: has_error implies not last_error.is_empty

end
