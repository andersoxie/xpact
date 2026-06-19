note
	description: "Isolated Expat-processor-style incremental parser spike."
	legal: "Architecture spike modelled on Expat 2.8.1 xmlparse.c processor dispatch. No production dependency."

class
	XP_EXPAT_PORT_PARSE_SESSION

create
	make

feature {NONE} -- Initialization

	make (a_handler: XP_EVENT_HANDLER)
			-- Create Expat-port experiment session.
		require
			handler_attached: a_handler /= Void
		do
			handler := a_handler
			create buffer.make_empty
			create element_stack.make (16)
			create last_error.make_empty
			processor := Processor_prolog_init
			parsing_status := Parsing_initialized
			current_line_number := 1
			current_column_number := 0
		ensure
			handler_set: handler = a_handler
			initial_processor: processor = Processor_prolog_init
			initialized: parsing_status = Parsing_initialized
		end

feature -- Source attribution

	expat_source_reference: STRING_8 = "libexpat R_2_8_1 expat/lib/xmlparse.c"
			-- Source used to shape this spike.

	expat_license_reference: STRING_8 = "MIT; see build/libexpat-R_2_8_1/libexpat-R_2_8_1/expat/COPYING"
			-- License reference for the upstream source studied by this spike.

feature -- Result statuses

	Status_event: INTEGER = 1
	Status_need_more: INTEGER = 2
	Status_finished: INTEGER = 3
	Status_error: INTEGER = 4
	Status_suspended: INTEGER = 5

feature -- Processor states

	Processor_prolog_init: INTEGER = 1
	Processor_prolog: INTEGER = 2
	Processor_content: INTEGER = 3
	Processor_epilog: INTEGER = 4
	Processor_error: INTEGER = 5

feature -- Parsing states

	Parsing_initialized: INTEGER = 0
	Parsing_parsing: INTEGER = 1
	Parsing_finished: INTEGER = 2
	Parsing_suspended: INTEGER = 3

feature -- Access

	handler: XP_EVENT_HANDLER
			-- Event receiver.

	buffer: STRING_8
			-- Unconsumed bytes.

	processor: INTEGER
			-- Active Expat-style processor.

	parsing_status: INTEGER
			-- Expat-style parse status.

	final_buffer: BOOLEAN
			-- Did the caller mark the latest input as final?

	last_error: STRING_8
			-- Last spike error.

	current_byte_index: INTEGER
			-- Number of bytes consumed.

	current_line_number: INTEGER
			-- 1-based line for next input.

	current_column_number: INTEGER
			-- 0-based column for next input.

	current_byte_count: INTEGER
			-- Byte count of the last emitted token.

	processor_transition_count: INTEGER
			-- Number of explicit processor changes.

	document_element_count: INTEGER
			-- Number of document-level start elements.

	element_stack: ARRAYED_LIST [STRING_8]
			-- Open element names.

feature -- Parsing

	parse (a_input: READABLE_STRING_8; a_is_final: BOOLEAN): INTEGER
			-- Append input and run the active processor loop.
		require
			input_attached: a_input /= Void
			not_finished: parsing_status /= Parsing_finished
			not_suspended: parsing_status /= Parsing_suspended
		do
			if not a_input.is_empty then
				buffer.append (a_input)
			end
			final_buffer := a_is_final
			parsing_status := Parsing_parsing
			Result := call_processor
			if Result = Status_finished then
				parsing_status := Parsing_finished
			elseif Result = Status_suspended then
				parsing_status := Parsing_suspended
			elseif Result = Status_error then
				parsing_status := Parsing_finished
				set_processor (Processor_error)
			else
				parsing_status := Parsing_parsing
			end
		ensure
			valid_status: is_valid_status (Result)
			final_recorded: final_buffer = a_is_final
		end

	resume: INTEGER
			-- Resume after a callback stop.
		require
			suspended: parsing_status = Parsing_suspended
		do
			parsing_status := Parsing_parsing
			Result := call_processor
			if Result = Status_finished then
				parsing_status := Parsing_finished
			elseif Result = Status_suspended then
				parsing_status := Parsing_suspended
			elseif Result = Status_error then
				parsing_status := Parsing_finished
				set_processor (Processor_error)
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	processor_name: STRING_8
			-- Human-readable active processor name.
		do
			inspect processor
			when Processor_prolog_init then
				Result := "prologInitProcessor"
			when Processor_prolog then
				Result := "prologProcessor"
			when Processor_content then
				Result := "contentProcessor"
			when Processor_epilog then
				Result := "epilogProcessor"
			else
				Result := "errorProcessor"
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Processor dispatch

	call_processor: INTEGER
			-- Repeatedly call the active processor until it blocks or stops.
		local
			l_done: BOOLEAN
			l_status: INTEGER
		do
			from
				Result := Status_need_more
			until
				l_done
			loop
				inspect processor
				when Processor_prolog_init then
					l_status := prolog_init_processor
				when Processor_prolog then
					l_status := prolog_processor
				when Processor_content then
					l_status := content_processor
				when Processor_epilog then
					l_status := epilog_processor
				else
					l_status := Status_error
				end
				if l_status = Status_event then
					Result := Status_event
				else
					Result := l_status
					l_done := True
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	prolog_init_processor: INTEGER
			-- Initialize encoding/prolog state, then enter prolog processor.
		do
			set_processor (Processor_prolog)
			Result := Status_event
		ensure
			valid_status: is_valid_status (Result)
		end

	prolog_processor: INTEGER
			-- Process document prolog until root content starts.
		do
			if buffer.is_empty then
				Result := finish_or_need_more
			elseif starts_with ("<?xml") then
				Result := consume_processing_instruction_like_markup
			elseif starts_with ("<!--") or else starts_with ("<!DOCTYPE") then
				set_error ("unsupported prolog markup")
				Result := Status_error
			elseif buffer.item (1) = '<' then
				set_processor (Processor_content)
				Result := Status_event
			elseif is_xml_space (buffer.item (1)) then
				consume_prefix (1)
				Result := Status_event
			else
				set_error ("character data outside document element")
				Result := Status_error
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	content_processor: INTEGER
			-- Process document content.
		local
			l_markup_end: INTEGER
			l_text_end: INTEGER
			l_text: STRING_8
		do
			if buffer.is_empty then
				Result := finish_or_need_more
			elseif buffer.item (1) = '<' then
				l_markup_end := complete_markup_end
				if l_markup_end = 0 then
					if final_buffer then
						set_error ("unclosed token")
						Result := Status_error
					else
						Result := Status_need_more
					end
				elseif buffer.count >= 2 and then buffer.item (2) = '/' then
					Result := process_end_tag (l_markup_end)
				elseif buffer.count >= 2 and then (buffer.item (2) = '!' or buffer.item (2) = '?') then
					set_error ("unsupported content markup")
					Result := Status_error
				else
					Result := process_start_tag (l_markup_end)
				end
			elseif element_stack.is_empty then
				if is_xml_space (buffer.item (1)) then
					consume_prefix (1)
					Result := Status_event
				else
					set_error ("character data outside document element")
					Result := Status_error
				end
			else
				l_text_end := buffer.index_of ('<', 1)
				if l_text_end = 0 then
					l_text := buffer.twin
				else
					l_text := buffer.substring (1, l_text_end - 1)
				end
				handler.on_character_data (l_text)
				current_byte_count := l_text.count
				consume_prefix (l_text.count)
				Result := event_or_suspended
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	epilog_processor: INTEGER
			-- Process epilog whitespace and final completion.
		do
			if buffer.is_empty then
				Result := finish_or_need_more
			elseif is_xml_space (buffer.item (1)) then
				consume_prefix (1)
				Result := Status_event
			else
				set_error ("junk after document element")
				Result := Status_error
			end
		ensure
			valid_status: is_valid_status (Result)
		end

feature {NONE} -- Token handling

	process_start_tag (a_end_index: INTEGER): INTEGER
			-- Emit one start tag.
		require
			valid_end: a_end_index >= 3 and a_end_index <= buffer.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
			l_empty: BOOLEAN
		do
			create l_attributes.make
			i := 2
			if not l_attributes.is_name_start_character (buffer.item (i)) then
				set_error ("invalid start tag")
				Result := Status_error
			else
				l_name_start := i
				from
					i := i + 1
				until
					i >= a_end_index or else not l_attributes.is_name_character (buffer.item (i))
				loop
					i := i + 1
				variant
					a_end_index - i
				end
				l_name := buffer.substring (l_name_start, i - 1)
				i := parse_attributes (i, a_end_index, l_attributes)
				if not last_error.is_empty then
					Result := Status_error
				else
					i := skip_spaces (i, a_end_index)
					if i < a_end_index and then buffer.item (i) = '/' then
						l_empty := True
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
						if l_empty then
							handler.on_end_element (l_name)
							if element_stack.is_empty then
								set_processor (Processor_epilog)
							end
						else
							element_stack.extend (l_name)
						end
						current_byte_count := a_end_index
						consume_prefix (a_end_index)
						Result := event_or_suspended
					end
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	process_end_tag (a_end_index: INTEGER): INTEGER
			-- Emit one end tag.
		require
			valid_end: a_end_index >= 4 and a_end_index <= buffer.count
		local
			i: INTEGER
			l_name_start: INTEGER
			l_name: STRING_8
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			i := 3
			if i >= a_end_index or else not l_attributes.is_name_start_character (buffer.item (i)) then
				set_error ("invalid end tag")
				Result := Status_error
			else
				l_name_start := i
				from
					i := i + 1
				until
					i >= a_end_index or else not l_attributes.is_name_character (buffer.item (i))
				loop
					i := i + 1
				variant
					a_end_index - i
				end
				l_name := buffer.substring (l_name_start, i - 1)
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
					current_byte_count := a_end_index
					consume_prefix (a_end_index)
					if element_stack.is_empty then
						set_processor (Processor_epilog)
					end
					Result := event_or_suspended
				end
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	parse_attributes (a_start_index, a_end_index: INTEGER; a_attributes: XP_ATTRIBUTES): INTEGER
			-- Parse attributes before `a_end_index'.
		require
			valid_start: a_start_index >= 2 and a_start_index <= a_end_index
			attributes_attached: a_attributes /= Void
		local
			i: INTEGER
			l_name_start: INTEGER
			l_value_start: INTEGER
			l_name: STRING_8
			l_value: STRING_8
			l_quote: CHARACTER_8
			l_done: BOOLEAN
			l_done_index: INTEGER
		do
			from
				i := a_start_index
			until
				i >= a_end_index or else not last_error.is_empty or l_done
			loop
				i := skip_spaces (i, a_end_index)
				if i < a_end_index and then buffer.item (i) = '/' then
					l_done_index := i
					l_done := True
					i := a_end_index
				elseif i < a_end_index then
					if not a_attributes.is_name_start_character (buffer.item (i)) then
						set_error ("invalid attribute")
					else
						l_name_start := i
						from
							i := i + 1
						until
							i >= a_end_index or else not a_attributes.is_name_character (buffer.item (i))
						loop
							i := i + 1
						variant
							a_end_index - i
						end
						l_name := buffer.substring (l_name_start, i - 1)
						i := skip_spaces (i, a_end_index)
						if i >= a_end_index or else buffer.item (i) /= '=' then
							set_error ("invalid attribute")
						else
							i := skip_spaces (i + 1, a_end_index)
							if i >= a_end_index or else not is_attribute_quote (buffer.item (i)) then
								set_error ("invalid attribute")
							else
								l_quote := buffer.item (i)
								l_value_start := i + 1
								from
									i := i + 1
								until
									i >= a_end_index or else buffer.item (i) = l_quote
								loop
									i := i + 1
								variant
									a_end_index - i
								end
								if i >= a_end_index then
									set_error ("invalid attribute")
								else
									l_value := buffer.substring (l_value_start, i - 1)
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
			if l_done_index > 0 then
				Result := l_done_index
			else
				Result := i
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index
		end

	consume_processing_instruction_like_markup: INTEGER
			-- Consume an XML declaration or PI-like prolog token.
		local
			l_end: INTEGER
		do
			l_end := buffer.substring_index ("?>", 1)
			if l_end = 0 then
				if final_buffer then
					set_error ("unclosed token")
					Result := Status_error
				else
					Result := Status_need_more
				end
			else
				consume_prefix (l_end + 1)
				Result := Status_event
			end
		ensure
			valid_status: is_valid_status (Result)
		end

feature {NONE} -- Shared mechanics

	finish_or_need_more: INTEGER
			-- Complete final input or wait for more.
		do
			if final_buffer then
				if document_element_count = 0 then
					set_error ("missing document element")
					Result := Status_error
				elseif not element_stack.is_empty then
					set_error ("unclosed token")
					Result := Status_error
				elseif buffer.is_empty then
					Result := Status_finished
				else
					Result := Status_need_more
				end
			else
				Result := Status_need_more
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	event_or_suspended: INTEGER
			-- Return event or suspension status after callback dispatch.
		do
			if handler.stop_requested then
				Result := Status_suspended
			else
				Result := Status_event
			end
		ensure
			valid_status: is_valid_status (Result)
		end

	set_processor (a_processor: INTEGER)
			-- Switch active processor.
		require
			valid_processor: is_valid_processor (a_processor)
		do
			if processor /= a_processor then
				processor := a_processor
				processor_transition_count := processor_transition_count + 1
			end
		ensure
			processor_set: processor = a_processor
		end

	set_error (a_message: READABLE_STRING_8)
			-- Record error and switch to error processor.
		require
			message_attached: a_message /= Void
			message_not_empty: not a_message.is_empty
		do
			last_error.wipe_out
			last_error.append (a_message)
			set_processor (Processor_error)
		ensure
			message_set: last_error.same_string (a_message)
			error_processor: processor = Processor_error
		end

	consume_prefix (a_count: INTEGER)
			-- Consume prefix bytes.
		require
			positive_count: a_count > 0
			enough: a_count <= buffer.count
		local
			l_consumed: STRING_8
		do
			l_consumed := buffer.substring (1, a_count)
			update_position (l_consumed)
			if a_count = buffer.count then
				buffer.wipe_out
			else
				buffer := buffer.substring (a_count + 1, buffer.count)
			end
		ensure
			byte_index_advanced: current_byte_index = old current_byte_index + a_count
		end

	update_position (a_text: READABLE_STRING_8)
			-- Advance position counters.
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
		end

	complete_markup_end: INTEGER
			-- First `>' not inside quotes, or zero.
		local
			i: INTEGER
			l_quote: CHARACTER_8
			l_in_quote: BOOLEAN
			c: CHARACTER_8
		do
			from
				i := 2
			until
				i > buffer.count or Result > 0
			loop
				c := buffer.item (i)
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
				buffer.count - i + 1
			end
		end

	skip_spaces (a_start_index, a_end_index: INTEGER): INTEGER
			-- First non-space index.
		require
			valid_start: a_start_index >= 1 and a_start_index <= a_end_index
		do
			from
				Result := a_start_index
			until
				Result >= a_end_index or else not is_xml_space (buffer.item (Result))
			loop
				Result := Result + 1
			variant
				a_end_index - Result
			end
		ensure
			result_in_bounds: Result >= a_start_index and Result <= a_end_index
		end

	starts_with (a_prefix: READABLE_STRING_8): BOOLEAN
			-- Does `buffer' start with `a_prefix'?
		require
			prefix_attached: a_prefix /= Void
		do
			Result := buffer.count >= a_prefix.count and then buffer.substring (1, a_prefix.count).same_string (a_prefix)
		end

	is_valid_status (a_status: INTEGER): BOOLEAN
			-- Is `a_status' a result status?
		do
			Result := a_status = Status_event or else a_status = Status_need_more or else a_status = Status_finished or else a_status = Status_error or else a_status = Status_suspended
		end

	is_valid_processor (a_processor: INTEGER): BOOLEAN
			-- Is `a_processor' known?
		do
			Result := a_processor = Processor_prolog_init or else a_processor = Processor_prolog or else a_processor = Processor_content or else a_processor = Processor_epilog or else a_processor = Processor_error
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

invariant
	handler_attached: handler /= Void
	buffer_attached: buffer /= Void
	last_error_attached: last_error /= Void
	element_stack_attached: element_stack /= Void
	valid_processor_state: is_valid_processor (processor)
	byte_index_non_negative: current_byte_index >= 0
	line_positive: current_line_number >= 1
	column_non_negative: current_column_number >= 0

end
