note
	description: "Prototype incremental parser session with explicit resumable state."

class
	XP_INCREMENTAL_PARSE_SESSION

create
	make

feature {NONE} -- Initialization

	make (a_handler: XP_EVENT_HANDLER)
			-- Create an isolated incremental parse session.
		require
			handler_attached: a_handler /= Void
		do
			handler := a_handler
			create buffer_window.make_empty
			create element_stack.make (16)
			create entity_stack.make (4)
			create namespace_context_stack.make (4)
			create last_error.make_empty
			current_processor_state := State_content
			current_line_number := 1
			current_column_number := 0
			current_byte_index := 0
		ensure
			handler_set: handler = a_handler
			empty_window: buffer_window.is_empty
			initial_position: current_line_number = 1 and current_column_number = 0 and current_byte_index = 0
		end

feature -- Status

	Status_event: INTEGER = 1
			-- One or more callbacks were emitted during the most recent advance.

	Status_need_more: INTEGER = 2
			-- More bytes are required to decide the next token.

	Status_finished: INTEGER = 3
			-- Final input was accepted and the document is complete.

	Status_error: INTEGER = 4
			-- Parsing failed.

	Status_suspended: INTEGER = 5
			-- A callback requested resumable suspension.

feature -- Access

	handler: XP_EVENT_HANDLER
			-- Event receiver.

	buffer_window: STRING_8
			-- Unconsumed input tail retained by this session.

	current_processor_state: INTEGER
			-- Current tokenizer/processor state.

	current_byte_index: INTEGER
			-- Byte index for the next unprocessed byte.

	current_line_number: INTEGER
			-- 1-based line for the next unprocessed byte.

	current_column_number: INTEGER
			-- 0-based column for the next unprocessed byte.

	current_byte_count: INTEGER
			-- Byte count of the most recently emitted token.

	element_stack: ARRAYED_LIST [STRING_8]
			-- Open element names.

	entity_stack: ARRAYED_LIST [STRING_8]
			-- Entity expansion stack reserved for the full prototype.

	namespace_context_stack: ARRAYED_LIST [STRING_8]
			-- Namespace context stack reserved for the full prototype.

	dtd_state: INTEGER
			-- DTD/prolog state reserved for the full prototype.

	encoding_decoder_state: INTEGER
			-- Encoding decoder state reserved for the full prototype.

	final_buffer: BOOLEAN
			-- Has the caller supplied the final input chunk?

	is_finished: BOOLEAN
			-- Has the session accepted a complete final document?

	is_suspended: BOOLEAN
			-- Did a callback request suspension?

	has_error: BOOLEAN
			-- Did the session reject input?

	last_error: STRING_8
			-- Last error message.

	document_element_count: INTEGER
			-- Number of top-level document elements emitted.

feature -- Parsing

	feed (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): INTEGER
			-- Append `a_input' and advance until blocked, finished, errored, or suspended.
		require
			input_attached: a_input /= Void
			not_finished: not is_finished
			not_suspended: not is_suspended
		do
			if not a_input.is_empty then
				buffer_window.append (a_input)
			end
			final_buffer := a_is_final
			Result := advance_available
		ensure
			valid_status: is_valid_status (Result)
			final_recorded: final_buffer = a_is_final
			error_matches_status: Result = Status_error implies has_error
			finished_matches_status: Result = Status_finished implies is_finished
		end

	resume: INTEGER
			-- Resume after a resumable callback stop.
		require
			suspended: is_suspended
		do
			is_suspended := False
			Result := advance_available
		ensure
			valid_status: is_valid_status (Result)
			not_suspended_if_not_reported: Result /= Status_suspended implies not is_suspended
		end

feature {NONE} -- Parsing implementation

	advance_available: INTEGER
			-- Advance through currently available complete tokens.
		local
			l_status: INTEGER
			l_emitted: BOOLEAN
			l_done: BOOLEAN
		do
			from
				Result := Status_need_more
			until
				l_done
			loop
				l_status := advance_one
				if l_status = Status_event then
					l_emitted := True
				else
					l_done := True
					Result := l_status
				end
			end
			if Result = Status_need_more and l_emitted then
				Result := Status_need_more
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	advance_one: INTEGER
			-- Advance by at most one complete token.
		local
			l_next_markup: INTEGER
			l_text: STRING_8
		do
			if has_error then
				Result := Status_error
			elseif is_suspended then
				Result := Status_suspended
			elseif buffer_window.is_empty then
				Result := finish_or_need_more
			elseif buffer_window.item (1) = '<' then
				Result := advance_markup
			else
				l_next_markup := buffer_window.index_of ('<', 1)
				if l_next_markup = 0 then
					if buffer_window.is_empty then
						Result := finish_or_need_more
					else
						create l_text.make_from_string (buffer_window)
						emit_character_data (l_text)
						consume_prefix (l_text.count)
						Result := event_or_suspended
					end
				elseif l_next_markup = 1 then
					Result := advance_markup
				else
					l_text := buffer_window.substring (1, l_next_markup - 1)
					emit_character_data (l_text)
					consume_prefix (l_text.count)
					Result := event_or_suspended
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	advance_markup: INTEGER
			-- Advance one markup token.
		local
			l_end: INTEGER
		do
			l_end := complete_markup_end
			if l_end = 0 then
				if final_buffer then
					set_error ("unclosed token")
					Result := Status_error
				else
					Result := Status_need_more
				end
			elseif buffer_window.count >= 2 and then buffer_window.item (2) = '/' then
				Result := advance_end_tag (l_end)
			elseif buffer_window.count >= 2 and then (buffer_window.item (2) = '!' or buffer_window.item (2) = '?') then
				set_error ("unsupported incremental markup")
				Result := Status_error
			else
				Result := advance_start_tag (l_end)
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	advance_start_tag (a_end_index: INTEGER): INTEGER
			-- Emit completed start tag ending at `a_end_index'.
		require
			valid_end: a_end_index >= 3 and a_end_index <= buffer_window.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
			l_empty_element: BOOLEAN
		do
			create l_attributes.make
			i := 2
			if i > a_end_index or else not l_attributes.is_name_start_character (buffer_window.item (i)) then
				set_error ("invalid start tag")
				Result := Status_error
			else
				l_name_start := i
				from
					i := i + 1
				until
					i >= a_end_index or else not l_attributes.is_name_character (buffer_window.item (i))
				loop
					i := i + 1
				variant
					a_end_index - i
				end
				l_name := buffer_window.substring (l_name_start, i - 1)
				i := parse_attributes (i, a_end_index, l_attributes)
				if not has_error then
					i := skip_spaces (i, a_end_index)
					if i < a_end_index and then buffer_window.item (i) = '/' then
						l_empty_element := True
						i := skip_spaces (i + 1, a_end_index)
					end
					if i /= a_end_index then
						set_error ("invalid start tag")
						Result := Status_error
					else
						if element_stack.is_empty then
							document_element_count := document_element_count + 1
						end
						handler.on_start_element (l_name, l_attributes)
						if not l_empty_element then
							element_stack.extend (l_name)
						else
							handler.on_end_element (l_name)
						end
						consume_prefix (a_end_index)
						Result := event_or_suspended
					end
				else
					Result := Status_error
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	advance_end_tag (a_end_index: INTEGER): INTEGER
			-- Emit completed end tag ending at `a_end_index'.
		require
			valid_end: a_end_index >= 4 and a_end_index <= buffer_window.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			i := 3
			if i >= a_end_index or else not l_attributes.is_name_start_character (buffer_window.item (i)) then
				set_error ("invalid end tag")
				Result := Status_error
			else
				l_name_start := i
				from
					i := i + 1
				until
					i >= a_end_index or else not l_attributes.is_name_character (buffer_window.item (i))
				loop
					i := i + 1
				variant
					a_end_index - i
				end
				l_name := buffer_window.substring (l_name_start, i - 1)
				i := skip_spaces (i, a_end_index)
				if i /= a_end_index then
					set_error ("invalid end tag")
					Result := Status_error
				elseif element_stack.is_empty or else not element_stack.i_th (element_stack.count).same_string (l_name) then
					set_error ("mismatched end tag")
					Result := Status_error
				else
					element_stack.finish
					element_stack.remove
					handler.on_end_element (l_name)
					consume_prefix (a_end_index)
					Result := event_or_suspended
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	parse_attributes (a_start_index, a_end_index: INTEGER; a_attributes: XP_ATTRIBUTES): INTEGER
			-- Parse attributes until `/` or `>` before `a_end_index'.
		require
			valid_start: a_start_index >= 2 and a_start_index <= a_end_index
			valid_end: a_end_index <= buffer_window.count
			attributes_attached: a_attributes /= Void
		local
			i: INTEGER
			l_name_start: INTEGER
			l_value_start: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_quote: CHARACTER_8
			l_done: BOOLEAN
		do
			from
				i := a_start_index
			until
				i >= a_end_index or has_error or l_done
			loop
				i := skip_spaces (i, a_end_index)
				if i < a_end_index and then buffer_window.item (i) = '/' then
					l_done := True
				elseif i < a_end_index then
					if not a_attributes.is_name_start_character (buffer_window.item (i)) then
						set_error ("invalid attribute")
					else
						l_name_start := i
						from
							i := i + 1
						until
							i >= a_end_index or else not a_attributes.is_name_character (buffer_window.item (i))
						loop
							i := i + 1
						variant
							a_end_index - i
						end
						l_name := buffer_window.substring (l_name_start, i - 1)
						i := skip_spaces (i, a_end_index)
						if i >= a_end_index or else buffer_window.item (i) /= '=' then
							set_error ("invalid attribute")
						else
							i := skip_spaces (i + 1, a_end_index)
							if i >= a_end_index or else not is_attribute_quote (buffer_window.item (i)) then
								set_error ("invalid attribute")
							else
								l_quote := buffer_window.item (i)
								l_value_start := i + 1
								from
									i := i + 1
								until
									i >= a_end_index or else buffer_window.item (i) = l_quote
								loop
									i := i + 1
								variant
									a_end_index - i
								end
								if i >= a_end_index then
									set_error ("invalid attribute")
								else
									l_value := buffer_window.substring (l_value_start, i - 1)
									if a_attributes.has (l_name) then
										set_error ("duplicate attribute")
									else
										a_attributes.put (l_name, l_value)
									end
									i := i + 1
								end
							end
						end
					end
				end
			variant
				a_end_index - i
			end
			Result := i
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index
		end

	finish_or_need_more: INTEGER
			-- Finish final input or wait for more.
		do
			if final_buffer then
				if document_element_count = 0 then
					set_error ("missing document element")
					Result := Status_error
				elseif not element_stack.is_empty then
					set_error ("unclosed token")
					Result := Status_error
				else
					is_finished := True
					current_processor_state := State_finished
					Result := Status_finished
				end
			else
				Result := Status_need_more
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	emit_character_data (a_text: READABLE_STRING_8)
			-- Emit character data.
		require
			text_attached: a_text /= Void
			text_not_empty: not a_text.is_empty
		do
			current_byte_count := a_text.count
			handler.on_character_data (a_text)
		end

	event_or_suspended: INTEGER
			-- Status after an emitted callback.
		do
			if handler.stop_requested then
				is_suspended := True
				Result := Status_suspended
			else
				Result := Status_event
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	consume_prefix (a_count: INTEGER)
			-- Consume `a_count' bytes from `buffer_window'.
		require
			positive_count: a_count > 0
			enough_bytes: a_count <= buffer_window.count
		local
			l_consumed: STRING_8
		do
			l_consumed := buffer_window.substring (1, a_count)
			update_position (l_consumed)
			if a_count = buffer_window.count then
				buffer_window.wipe_out
			else
				buffer_window := buffer_window.substring (a_count + 1, buffer_window.count)
			end
		ensure
			byte_index_advanced: current_byte_index = old current_byte_index + a_count
		end

	update_position (a_text: READABLE_STRING_8)
			-- Advance byte, line, and column counters by `a_text'.
		require
			text_attached: a_text /= Void
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > a_text.count
			loop
				if a_text.item (i) = '%N' then
					current_line_number := current_line_number + 1
					current_column_number := 0
				else
					current_column_number := current_column_number + 1
				end
				i := i + 1
			variant
				a_text.count - i + 1
			end
			current_byte_index := current_byte_index + a_text.count
		ensure
			byte_index_advanced: current_byte_index = old current_byte_index + a_text.count
			line_positive: current_line_number >= 1
			column_non_negative: current_column_number >= 0
		end

	complete_markup_end: INTEGER
			-- Index of the next markup `>' not inside an attribute quote, or zero.
		local
			i: INTEGER
			l_in_quote: BOOLEAN
			l_quote: CHARACTER_8
			c: CHARACTER_8
		do
			from
				i := 2
			until
				i > buffer_window.count or Result > 0
			loop
				c := buffer_window.item (i)
				if l_in_quote then
					if c = l_quote then
						l_in_quote := False
					end
				elseif is_attribute_quote (c) then
					l_in_quote := True
					l_quote := c
				elseif c = '>' then
					Result := i
				end
				i := i + 1
			variant
				buffer_window.count - i + 1
			end
		ensure
			result_in_bounds: Result >= 0 and Result <= buffer_window.count
		end

	skip_spaces (a_start_index, a_end_index: INTEGER): INTEGER
			-- First non-space index at or after `a_start_index', bounded by `a_end_index'.
		require
			valid_start: a_start_index >= 1 and a_start_index <= a_end_index
			valid_end: a_end_index <= buffer_window.count
		do
			from
				Result := a_start_index
			until
				Result >= a_end_index or else not is_xml_space (buffer_window.item (Result))
			loop
				Result := Result + 1
			variant
				a_end_index - Result
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index
		end

	set_error (a_message: READABLE_STRING_8)
			-- Record parse error.
		require
			message_attached: a_message /= Void
			message_not_empty: not a_message.is_empty
		do
			has_error := True
			last_error.wipe_out
			last_error.append (a_message)
		ensure
			error_set: has_error
			message_set: last_error.same_string (a_message)
		end

	is_valid_status (a_status: INTEGER): BOOLEAN
			-- Is `a_status' one of the session status constants?
		do
			Result :=
				a_status = Status_event
				or else a_status = Status_need_more
				or else a_status = Status_finished
				or else a_status = Status_error
				or else a_status = Status_suspended
		end

	is_attribute_quote (a_character: CHARACTER_8): BOOLEAN
			-- Is `a_character' an attribute quote?
		do
			Result := a_character = '%"' or else a_character = '%''
		end

	is_xml_space (a_character: CHARACTER_8): BOOLEAN
			-- Is `a_character' XML whitespace?
		do
			Result := a_character = ' ' or else a_character = '%T' or else a_character = '%N' or else a_character = '%R'
		end

	State_content: INTEGER = 1
			-- Parsing document content.

	State_finished: INTEGER = 2
			-- Final document accepted.

invariant
	handler_attached: handler /= Void
	buffer_window_attached: buffer_window /= Void
	element_stack_attached: element_stack /= Void
	entity_stack_attached: entity_stack /= Void
	namespace_context_stack_attached: namespace_context_stack /= Void
	last_error_attached: last_error /= Void
	byte_index_non_negative: current_byte_index >= 0
	line_positive: current_line_number >= 1
	column_non_negative: current_column_number >= 0
	error_has_message: has_error implies not last_error.is_empty
	finished_has_final_buffer: is_finished implies final_buffer

end
