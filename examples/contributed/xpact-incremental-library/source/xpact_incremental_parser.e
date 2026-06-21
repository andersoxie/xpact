note
	description: "[
		Incremental XML parser: state machine and buffer manager.

		Ports XML_Parse(), XML_ParseBuffer(), XML_GetBuffer(), and callProcessor()
		from xmlparse.c (libexpat 2.x) to Eiffel with Design by Contract.

		Pointer arithmetic from the C source is replaced by integer indices
		into `buffer: SPECIAL [CHARACTER]'.  The correspondences are:

		  C field              Eiffel attribute
		  -----------------------------------------------------------------------
		  m_buffer[0]          buffer [0]
		  m_bufferPtr          buffer_ptr        (index)
		  m_bufferEnd          buffer_end        (index)
		  m_bufferLim          buffer_lim        (capacity)
		  m_parseEndPtr        parse_end_ptr     (index, snapshot at parse entry)
		  m_positionPtr        position_ptr      (index for line/col tracking)
		  m_parseEndByteIndex  parse_end_byte_index
		  m_handlerCallDepth   handler_call_depth
		  m_partialTokenBytesBefore  partial_token_bytes_before
		  m_lastBufferRequestSize    last_buffer_request_size
		  m_reparseDeferralEnabled   reparse_deferral_enabled
		  m_parsingStatus.parsing    parsing_state
		  m_parsingStatus.finalBuffer  is_final_buffer
		  m_errorCode          error_code

		Deferred features that concrete subclasses must supply:
		  on_start_parsing     -- initialise hash salt, namespace context (startParsing)
		  do_process_bytes     -- one-shot processor call (m_processor)
		  processor_wants_reenter  -- whether to loop again (m_reenter flag)
		  on_clear_reenter     -- clear the reenter flag
		  on_set_error_processor  -- switch to errorProcessor sink
		  on_update_position   -- run XmlUpdatePosition over consumed bytes
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:30:52 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_INCREMENTAL_PARSER

inherit
	XPACT_BYTE_TYPE_CONSTANTS

	XPACT_TOKEN_CONSTANTS

	XPACT_PARSE_CONSTANTS

	XPACT_STRING_BUFFERS
		rename
			make as make_default
		end

feature {NONE} -- Initialisation

	make
			-- Set up in State_initialized with an empty buffer.
		do
			make_default
			create {XPACT_UTF8_ENCODING} encoding.make

			parsing_state              := State_initialized
			error_code                 := Error_none
			is_final_buffer            := False
			in_prolog						:= True
			in_cdata_section           := False
			handler_call_depth         := 0
			reparse_deferral_enabled   := True
			last_buffer_request_size   := 0
			partial_token_bytes_before := 0
			parse_end_byte_index       := 0
			parse_end_index            := 0

			buffer_end := 0
			buffer_lim := Default_buffer_size
		ensure then
			initialized:    parsing_state = State_initialized
			no_error:       error_code = Error_none
			handler_clean:  handler_call_depth = 0
		end

feature -- Access

	handler_call_depth: INTEGER

	buffer_lim: INTEGER
			-- Total usable capacity of `buffer'.

feature -- Status

	parsing_state: INTEGER
			-- Current state: one of the State_* constants.

	error_code: INTEGER
			-- Most recent error (Error_none if none).

	is_final_buffer: BOOLEAN
			-- Was the current parse call marked as the last chunk?

	in_prolog: BOOLEAN

	in_cdata_section: BOOLEAN

	parse_end_byte_index: INTEGER_64
			-- Cumulative count of bytes committed to the parser.

feature -- Element change

	set_encoding (a_encoding: XPACT_NORMAL_ENCODING)
		do
			encoding := a_encoding
		end

feature -- Basic operations

	parse (s: SPECIAL [CHARACTER]; a_offset, a_count: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Accept `a_count' bytes from `s[a_offset]' as the next chunk.
			-- Returns Status_ok, Status_suspended, or Status_error.
			-- Corresponds to XML_Parse() in xmlparse.c.
		require
			non_negative_count: a_count >= 0
			valid_source_range: a_count = 0 or else (a_offset >= 0 and then a_offset + a_count <= s.count)
			not_in_handler: handler_call_depth = 0
		local
			write_start: INTEGER
		do
			inspect parsing_state
				when State_suspended then
					error_code := Error_suspended
					Result := Status_error
				when State_finished then
					error_code := Error_finished
					Result := Status_error
			else
				-- State_initialized or State_parsing
				parsing_state := State_parsing
				if not on_start_parsing_if_needed then
					Result := Status_error
				elseif not prepare_buffer (a_count) then
					Result := Status_error
				else
					write_start := buffer_end
					if a_count > 0 then
						-- Copy caller's bytes into the internal buffer.
						-- Destination index < source index is impossible here
						-- (write_start is past all existing data), so copy_data is safe.
						buffer.copy_data (s, a_offset, write_start, a_count)
					end
					Result := parse_buffer (a_count, a_is_final)
				end
			end
		ensure
			valid_result: Result = Status_ok or Result = Status_error or Result = Status_suspended
			finished_when_final_ok:
				(Result = Status_ok and a_is_final) implies parsing_state = State_finished
			error_code_set_on_error:
				Result = Status_error implies error_code /= Error_none
		end

feature -- Handler depth tracking

	increment_handler_depth
			-- Signal entry into a parse-event callback.
		require
			parsing_active: parsing_state = State_parsing
		do
			handler_call_depth := handler_call_depth + 1
		ensure
			depth_increased: handler_call_depth = old handler_call_depth + 1
		end

	decrement_handler_depth
			-- Signal exit from a parse-event callback.
		require
			in_handler: handler_call_depth > 0
		do
			handler_call_depth := handler_call_depth - 1
		ensure
			depth_decreased: handler_call_depth = old handler_call_depth - 1
		end

feature {NONE} -- Buffer implementation

	parse_buffer (a_count: INTEGER; a_is_final: BOOLEAN): INTEGER
			-- Parse `a_count' bytes that the caller has already written into
			-- `buffer' starting at the old `buffer_end'.
			-- Returns Status_ok, Status_suspended, or Status_error.
			--
			-- Corresponds to XML_ParseBuffer() in xmlparse.c.
		require
			non_negative_count: a_count >= 0
			not_in_handler:     handler_call_depth = 0
			buffer_allocated:   buffer_lim > 0
			data_fits:          buffer_end + a_count <= buffer_lim
		local
			start: INTEGER
		do
			inspect parsing_state
				when State_suspended then
					error_code := Error_suspended
					Result := Status_error
				when State_finished then
					error_code := Error_finished
					Result := Status_error
			else
				if not on_start_parsing_if_needed then
					Result := Status_error
				else
					parsing_state        := State_parsing
					start                := buffer_index
					position_index       := start
					buffer_end           := buffer_end + a_count
					parse_end_index      := buffer_end
					parse_end_byte_index := parse_end_byte_index + a_count
					is_final_buffer      := a_is_final

					error_code := call_processor (start, parse_end_index)

					if error_code /= Error_none then
						on_set_error_processor
						Result := Status_error
					else
						inspect parsing_state
							when State_suspended then
								Result := Status_suspended
						else
							if a_is_final then
								parsing_state := State_finished
								on_finish (Status_ok)
							end
							Result := Status_ok
						end
						on_update_position (position_index, buffer_index)
						position_index := buffer_index
					end
				end
			end
		ensure
			valid_result:
				Result = Status_ok or Result = Status_error or Result = Status_suspended
			finished_when_final_ok:
				(Result = Status_ok and a_is_final) implies parsing_state = State_finished
			error_code_set_on_error:
				Result = Status_error implies error_code /= Error_none
			byte_index_advanced:
				Result /= Status_error implies
					parse_end_byte_index = old parse_end_byte_index + a_count
		end

	get_buffer (a_count: INTEGER): BOOLEAN
			-- Prepare the internal buffer to accept `a_count' more bytes.
			-- On success the caller may write directly into
			-- `buffer [buffer_end .. buffer_end + a_count)'.
			-- Returns False and sets `error_code' on failure.
			--
			-- Corresponds to XML_GetBuffer() in xmlparse.c.
		require
			non_negative_count: a_count >= 0
			not_in_handler:     handler_call_depth = 0
			not_suspended:      parsing_state /= State_suspended
			not_finished:       parsing_state /= State_finished
		do
			last_buffer_request_size := a_count
			Result := prepare_buffer (a_count)
		ensure
			space_when_ok:        Result implies buffer_end + a_count <= buffer_lim
			error_set_on_failure: not Result implies error_code /= Error_none
			request_size_saved:   last_buffer_request_size = a_count
		end

	prepare_buffer (a_count: INTEGER): BOOLEAN
			-- Ensure `buffer' has room for `a_count' more bytes
			-- after `buffer_end'.  Compacts or reallocates as needed,
			-- preserving up to `Context_bytes' before `buffer_index' for
			-- error reporting.  Returns False and sets `error_code' on
			-- failure; buffer indices are adjusted consistently on success.
			--
			-- Corresponds to the resize/compact logic in XML_GetBuffer().
		local
			needed, parsed, keep, offset, new_size: INTEGER
		do
			if a_count <= buffer_lim - buffer_end then
				-- Enough free space after buffer_end already.
				Result := True
			else
				parsed := buffer_index                 -- bytes before buffer_ptr
				keep   := parsed.min (Context_bytes)   -- context bytes to retain
				needed := keep + a_count + (buffer_end - buffer_index)

				if needed < 0 then
					-- Integer overflow: the request is impossibly large.
					error_code := Error_no_memory

				elseif needed <= buffer_lim then
					-- Existing allocation fits once we compact.
					offset := parsed - keep
					if offset > 0 then
						shift_buffer_left (offset)
					end
					Result := True

				else
					-- Must grow. Double from current capacity until large enough.
					new_size := buffer_lim.max (Default_buffer_size)
					from until new_size >= needed or new_size <= 0 loop
						if new_size > {INTEGER}.max_value // 2 then
							new_size := -1   -- overflow sentinel
						else
							new_size := new_size * 2
						end
					end
					if new_size <= 0 then
						error_code := Error_no_memory
					elseif attached new_buffer_area (new_size) as new_buffer then
						new_buffer.copy_data (buffer, 0, 0, buffer_lim)
						buffer := new_buffer
						buffer_lim := new_size
						offset := parsed - keep
						if offset > 0 then
							shift_buffer_left (offset)
						end
						Result := True
					end
				end
			end
		ensure
			space_when_ok:       Result implies buffer_end + a_count <= buffer_lim
			error_when_not_ok:   not Result implies error_code /= Error_none
			ptr_within_end:      buffer_index <= buffer_end
			end_within_lim:      buffer_end <= buffer_lim
			ptr_non_negative:    buffer_index >= 0
		end

	shift_buffer_left (a_offset: INTEGER)
			-- Slide all live content left by `a_offset' bytes and adjust
			-- every index that points into `buffer'.
			-- Safe for a forward (left) copy because destination < source.
		require
			positive_offset: a_offset > 0
			offset_leq_ptr: a_offset <= buffer_index
		do
			buffer.copy_data (buffer, a_offset, 0, buffer_end - a_offset)
			buffer_end := buffer_end - a_offset
			buffer_index := buffer_index - a_offset
			position_index := (position_index - a_offset).max (0)
			parse_end_index := (parse_end_index - a_offset).max (0)
		ensure
			buffer_ptr_reduced:  buffer_index  = old buffer_index  - a_offset
			buffer_end_reduced:  buffer_end  = old buffer_end  - a_offset
			ptr_non_negative:    buffer_index >= 0
			end_non_negative:    buffer_end >= 0
		end

feature {NONE} -- Processor dispatch

	call_processor (a_start, a_end_index: INTEGER): INTEGER
			-- Drive the current processor over `buffer[a_start .. a_end_index)'.
			-- Implements the reparse-deferral heuristic and the re-enter loop
			-- from callProcessor() in xmlparse.c.
			-- Updates `buffer_index' to the furthest position reached.
			-- Returns Error_none on success or an Error_* code on failure.
		require
			valid_range:  a_start >= 0 and then a_start <= a_end_index
			end_in_buf:   a_end_index <= buffer_end
			ptr_at_start: buffer_index = a_start
		local
			have_now, had_before, available: INTEGER
			enough, done: BOOLEAN
			err: INTEGER
		do
			have_now := a_end_index - a_start

			-- Reparse-deferral heuristic (m_reparseDeferralEnabled in xmlparse.c):
			-- avoid re-scanning a partial token until we have significantly more data
			-- or the buffer is nearly full.
			if reparse_deferral_enabled and then not is_final_buffer then
				had_before := partial_token_bytes_before
				available  := (buffer_index - buffer_index.min (Context_bytes)) + (buffer_lim - buffer_end)
				enough := have_now >= 2 * had_before
					or else last_buffer_request_size > available
				if not enough then
					-- Leave buffer_ptr at a_start; nothing consumed this call.
					Result := Error_none
				end
			else
				enough := True
			end

			if enough and then attached buffer as buf then
				-- Re-enter loop: drives the processor repeatedly when it sets
				-- the reenter flag (avoids deep C-style recursion).
				from done := False until done loop
					err := do_process_bytes (buf, buffer_index, a_end_index)

					-- Suspended state overrides the reenter request.
					if parsing_state /= State_parsing then
						on_clear_reenter
					end

					if not processor_wants_reenter then
						done := True
					else
						on_clear_reenter
						if err /= Error_none then
							Result := err
							done   := True
						end
					end
				end
				Result := err
			end

			-- Track how many bytes were available but not consumed,
			-- so the deferral heuristic can judge the next call.
			if Result = Error_none then
				if buffer_index = a_start then
					partial_token_bytes_before := have_now
				else
					partial_token_bytes_before := 0
				end
			end
		ensure
			buffer_ptr_in_range: buffer_index >= a_start and buffer_index <= a_end_index
			error_code_unchanged_on_success: Result = Error_none
				implies error_code = old error_code
		end

	do_process_bytes (buf: like buffer; a_start, a_end_index: INTEGER): INTEGER
		-- Scan tokens from `buf' `a_start .. a_end_index` and
		-- triggers relevant XML events.  Advances `buffer_ptr'.
		-- Execute one pass of the current processor over
		-- `buf [a_start .. a_end_index)'.
		-- Must update `buffer_index' to the first unconsumed byte.
		-- Returns Error_none on success or an Error_* code on failure.
		-- Corresponds to a single call of `m_processor' in xmlparse.c.
		require
			valid_range:    a_start >= 0 and then a_start <= a_end_index
			end_in_buf:     a_end_index <= buffer_end
			ptr_at_start:   buffer_index = a_start
		local
			index, tok: INTEGER; done: BOOLEAN
		do
			index := a_start
			from until index >= a_end_index or done loop
				if in_prolog then
					tok := encoding.scan_prolog (buf, index, a_end_index)
					if tok = Tok_instance_start then
						in_prolog := False
						index := encoding.next_token_index
					elseif tok = Tok_invalid then
						Result := Error_invalid_token; done := True
					elseif tok <= 0 then
						done := True  -- partial; wait for more data
					else
						index := encoding.next_token_index  -- skip prolog token
					end
				elseif in_cdata_section then
					tok := encoding.scan_cdata_section (buf, index, a_end_index)
					if tok = Tok_cdata_sect_close then
						in_cdata_section := False; cdata_pending := True
						index := encoding.next_token_index
					elseif tok = Tok_data_chars or tok = Tok_data_newline then
						text_data_intervals.extend (index, encoding.next_token_index - 1)
						index := encoding.next_token_index
					elseif tok = Tok_invalid then
						Result := Error_invalid_token; done := True
					else
						done := True  -- partial; wait for more data
					end
				else
					tok := encoding.scan_content (buf, index, a_end_index)
					if tok = Tok_cdata_sect_open then
						in_cdata_section := True
						index := encoding.next_token_index
					elseif tok > 0 then
						process_token (buf, tok, index)
						index := encoding.next_token_index
					elseif tok = Tok_invalid then
						Result := Error_invalid_token; done := True
					else
						done := True  -- partial; wait for more data
					end
				end
			end
			buffer_index := index
		ensure
			buffer_ptr_advanced: buffer_index >= a_start and buffer_index <= a_end_index
		end

	process_attributes (attributes: XPACT_ATTRIBUTE_LIST; buf: like buffer; start_index, a_end: INTEGER)
		-- Scan attributes in buf [start_index .. a_end) and print them on one line
		-- as:  key: "value"; key: "value"
		-- Stops when '>' or '/' is reached (end-of-tag punctuation).
		local
			index, name_start, name_end, val_start, val_end, bt: INTEGER
			q: CHARACTER; done: BOOLEAN
		do
			index := start_index
			if attached encoding.byte_type_table as bt_table then
				from until index >= a_end or done loop
					bt := bt_table [buf [index].code].to_integer_32
					inspect bt
						when BT_whitespace, BT_CR, BT_LF then
							index := index + 1

						when BT_gt, BT_forward_slash then
							done := True

					else
						name_start := index  -- collect attribute name
						from until index >= a_end or else not_name_character (bt) loop
							index := index + 1
							if index < a_end then
								bt := bt_table [buf [index].code].to_integer_32
							end
						end
						name_end := index - 1

						from until index >= a_end or bt = BT_equals loop  -- skip to '='
							index := index + 1
							if index < a_end then
								bt := bt_table [buf [index].code].to_integer_32
							end
						end
						if index < a_end then
							index := index + 1     -- consume '='
						end
						if index < a_end then
							bt := bt_table [buf [index].code].to_integer_32
						end
						from until index >= a_end or is_quote_or_apostrophe (bt) loop -- skip whitespace to quote
							index := index + 1
							if index < a_end then
								bt := bt_table [buf [index].code].to_integer_32
							end
						end
						if index < a_end then
							q := buf [index]  -- remember opening quote byte
							index := index + 1   -- skip opening quote
							val_start := index
							from until index >= a_end or buf [index] = q loop
								index := index + 1
							end
							val_end := index
							if index < a_end then
								index := index + 1
							end  -- skip closing quote
							attributes.extend (name_cache.item (buf, name_start, name_end), val_start, val_end - 1)
						end
					end
				end
			end
			if attribute_list.count > 0 then
				on_tag_attributes (attribute_list)
				attribute_list.wipe_out
			end
		end

	process_token (buf: like buffer; tok, tok_start: INTEGER)
			-- Print the XML event for a complete token at tok_start.
			-- encoding.next_token_ptr is the first byte after the token.
		local
			tok_end, null_index, lower, upper: INTEGER
			c, null: CHARACTER
		do
			tok_end := encoding.next_token_index
			inspect tok
				when Tok_data_chars then
					do_nothing
			else
				if text_data_intervals.count > 0 then
					on_content (text_data_intervals)
					if cdata_pending then
						cdata_pending := False
					end
					text_data_intervals.wipe_out
				end
			end
			inspect tok
				when Tok_start_tag_no_atts, Tok_start_tag_with_atts then
					if attached buffer_name (buf, tok_start, 1) as tag_name then
						on_tag_start (tag_name, False)
						inspect tok when Tok_start_tag_with_atts then
							process_attributes (attribute_list, buf, tok_start + tag_name.count + 1, tok_end)
						else
						end
					end

				when Tok_empty_element_no_atts then
					on_tag_start (buffer_name (buf, tok_start, 1), True)

				when Tok_empty_element_with_atts then
					if attached buffer_name (buf, tok_start, 1) as tag_name then
						on_tag_start (tag_name, False)
						process_attributes (attribute_list, buf, tok_start + tag_name.count + 1, tok_end)
						on_tag_end (tag_name)
					end

				when Tok_end_tag then
					on_tag_end (buffer_name (buf, tok_start, 2))  -- skip '</'

				when Tok_comment then
					lower := tok_start + 4; upper := tok_end - 4
					comment_string.make_shared (buf.item_address (lower), upper - lower + 1)
					null_index := upper + 1
					c := buf [null_index]; buf [null_index] := null
					on_comment (comment_string) -- null terminated temporarily for C strlen
					buf [null_index] := c

				when Tok_data_chars then
					text_data_intervals.extend (tok_start, tok_end - 1)

			else
				-- PIs, BOM, xml declaration, CDATA open: skip
			end
		end

feature {NONE} -- Implementation

	is_quote_or_apostrophe (bt: INTEGER): BOOLEAN
		do
			inspect bt
				when BT_quote, BT_apostrophe then
					Result := True
			else
			end
		end

	not_name_character (bt: INTEGER): BOOLEAN
		do
			inspect bt
				when BT_CR, BT_LF, BT_gt, BT_equals, BT_forward_slash, BT_whitespace then
					Result := True
			else
			end
		end

	processor_wants_reenter: BOOLEAN
		-- True when the processor has set its reenter flag, requesting
		-- another pass through `do_process_bytes' to avoid stack overflow.
		-- Corresponds to `m_reenter' in xmlparse.c.
		do
			Result := False
		end

feature {NONE} -- Event handlers

	on_finish (status: INTEGER)
		do
		end

	on_set_error_processor
		-- Switch the active processor to the error sink so that any
		-- further parse calls immediately fail.
		-- Corresponds to `m_processor = errorProcessor' in xmlparse.c.
		do
		end

	on_start_parsing_if_needed: BOOLEAN
			-- If currently in State_initialized, call `on_start_parsing' for a
			-- root parser; always succeeds for child/entity parsers.
			-- Returns False only when `on_start_parsing' fails.
		do
			if parsing_state = State_initialized then
				if not on_start_parsing then
					error_code := Error_no_memory
				else
					Result := True
				end
			else
				Result := True
			end
		ensure
			error_set_on_failure: not Result implies error_code /= Error_none
		end

	on_clear_reenter
			-- Clear the reenter flag after each loop iteration.
		do
		ensure
			cleared: not processor_wants_reenter
		end

	on_start_parsing: BOOLEAN
			-- Called once when a root parser leaves State_initialized.
			-- Initialise hash salt and any implicit namespace context here.
			-- Return True on success; False causes the parse to abort with
			-- Error_no_memory (matching startParsing() in xmlparse.c).
		do
			Result := True
		end

	on_update_position (start_index, end_index: INTEGER)
			-- Update line/column counters by scanning
			-- `buffer [start_index .. end_index)'.
			-- Corresponds to XmlUpdatePosition() calls in xmlparse.c.
		require
			valid_range: start_index >= 0 and then start_index <= end_index
			to_in_buf: end_index <= buffer_end
		do
		end

feature {NONE} -- Deferred event handlers

	on_comment (text: C_STRING_8)
		require
			null_terminated: is_null_terminated (text)
		deferred
		end

	on_content (text_intervals: EL_ARRAYED_INTERVAL_LIST)
		deferred
		end

	on_tag_attributes (list: XPACT_ATTRIBUTE_LIST)
		deferred
		end

	on_tag_end (name: STRING_8)
		deferred
		end

	on_tag_start (name: STRING_8; is_empty: BOOLEAN)
		deferred
		end

feature {NONE} -- Internal attributes

	cdata_pending: BOOLEAN
		-- `True' if accumulated text in `text_data_list' CDATA

	encoding: XPACT_NORMAL_ENCODING

	position_index: INTEGER
		-- Start index for the next line/column position update.

	last_buffer_request_size: INTEGER

	partial_token_bytes_before: INTEGER

	reparse_deferral_enabled: BOOLEAN

invariant
	room_for_null_terminator: buffer.capacity = buffer_lim + 1
	valid_state:
		parsing_state = State_initialized or parsing_state = State_parsing
		or parsing_state = State_finished or parsing_state = State_suspended

	buffer_indices_consistent:
		buffer_index >= 0 and then buffer_index <= buffer_end and then buffer_end <= buffer_lim

	position_ptr_non_negative: position_index >= 0
	non_negative_handler_depth: handler_call_depth >= 0
	non_negative_byte_index: parse_end_byte_index >= 0
	partial_token_non_negative: partial_token_bytes_before >= 0

end
