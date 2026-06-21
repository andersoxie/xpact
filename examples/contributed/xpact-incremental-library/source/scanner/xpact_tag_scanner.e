note
	description: "[
		Scanner for start tags, empty-element tags, end tags, and attribute lists.

		Corresponds to scanLt, scanEndTag, scanAtts in xmltok_impl.c.
		Entry points are positioned one byte past the sigil already consumed:
		  scan_lt      : past '<'
		  scan_end_tag : past '</'
		  scan_atts    : past first character of the first attribute name
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:32:53 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_TAG_SCANNER

inherit
	XPACT_SCANNER_HELPERS
	XPACT_REF_SCANNER

feature {NONE} -- Tag scanning

	scan_lt (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Dispatch on the character after '<'.
			-- Returns the appropriate XML_TOK_* code; sets next_token_ptr.
		require start_index <= a_end
		local
			index: INTEGER
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial
			else
				inspect byte_type (buf, index)
					when BT_exclamation then
						index := advance (index)
						if index >= a_end then
							Result := Tok_partial
						else
							inspect byte_type (buf, index)
								when BT_minus then
									Result := scan_comment (buf, advance (index), a_end)
								when BT_left_square_bracket then
									Result := scan_cdata_section_open (buf, advance (index), a_end)
							else
								next_token_index := index
								Result := Tok_invalid
							end
						end
					when BT_question then
						Result := scan_pi (buf, advance (index), a_end)
					when BT_forward_slash then
						Result := scan_end_tag (buf, advance (index), a_end)
					when BT_name_start, BT_hex_digit then
						index := advance (index)
						Result := scan_start_tag_name (byte_type_table, buf, index, a_end)
					when BT_lead_2_byte then
						if a_end - index >= 2 and then not is_invalid_char_2 (buf, index)
							and then is_name_start_char_2 (buf, index)
						then
							index := index + 2
							Result := scan_start_tag_name (byte_type_table, buf, index, a_end)
						else
							next_token_index := index
							Result := Tok_invalid
						end
					when BT_lead_3_byte then
						if a_end - index >= 3 and then not is_invalid_char_3 (buf, index)
							and then is_name_start_char_3 (buf, index)
						then
							index := index + 3
							Result := scan_start_tag_name (byte_type_table, buf, index, a_end)
						else
							next_token_index := index
							Result := Tok_invalid
						end
				else
					next_token_index := index
					Result := Tok_invalid
				end
			end
		end

	scan_end_tag (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan end tag after '</'.  Returns Tok_end_tag or error.
		require start_index <= a_end
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial
			else
				inspect byte_type (buf, index)
					when BT_name_start, BT_hex_digit then
						index := advance (index)
					when BT_lead_2_byte then
						if a_end - index >= 2 and then not is_invalid_char_2 (buf, index)
							and then is_name_start_char_2 (buf, index)
						then
							index := index + 2
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
					when BT_lead_3_byte then
						if a_end - index >= 3  and then not is_invalid_char_3 (buf, index)
							and then is_name_start_char_3 (buf, index)
						then
							index := index + 3
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
				else
					next_token_index := index; Result := Tok_invalid; done := True
				end
				if not done and then attached byte_type_table as bt_table then
					from until index >= a_end or done loop
						inspect bt_table [buf [index].code].to_integer_32
							when BT_name_start, BT_hex_digit, BT_digit, BT_name_only,
							     BT_minus, BT_colon then
								index := advance (index)
							when BT_whitespace, BT_CR, BT_LF then
								index := advance (index)
								from until index >= a_end or done loop
									inspect bt_table [buf [index].code].to_integer_32
										when BT_whitespace, BT_CR, BT_LF then
											index := advance (index)
										when BT_gt then
											next_token_index := advance (index)
											Result := Tok_end_tag
											done := True
									else
										next_token_index := index
										Result := Tok_invalid
										done := True
									end
								end
								if not done then
									Result := Tok_partial; done := True
								end
							when BT_gt then
								next_token_index := advance (index)
								Result := Tok_end_tag
								done := True
						else
							next_token_index := index
							Result := Tok_invalid
							done := True
						end
					end
					if not done then
						Result := Tok_partial
					end
				end
			end
		end

	scan_atts (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan attribute list starting at the first attribute name character.
			-- Returns Tok_start_tag_with_atts, Tok_empty_element_with_atts, or error.
		require start_index <= a_end
		local
			index, open: INTEGER; done: BOOLEAN
		do
			index := start_index
			if attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_name_start, BT_hex_digit, BT_digit, BT_name_only,
						     BT_minus, BT_colon, BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
							index := advance (index)
						when BT_whitespace, BT_CR, BT_LF then
							-- Skip one whitespace byte; outer loop handles subsequent chars naturally.
							-- Whitespace may separate a name from '=' or one attribute from the next.
							index := advance (index)
						when BT_equals then
							index := advance (index)
							Result := scan_att_value (buf, index, a_end, open)
							if Result /= 0 then
								done := True
							else
								index := next_token_index
							end
						when BT_gt then
							next_token_index := advance (index)
							Result := Tok_start_tag_with_atts
							done := True
						when BT_forward_slash then
							index := advance (index)
							if index >= a_end then
								Result := Tok_partial; done := True
							elseif buf [index] = '>' then
								next_token_index := advance (index)
								Result := Tok_empty_element_with_atts
								done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
					else
						next_token_index := index; Result := Tok_invalid; done := True
					end
				end
			end
			if not done then
				Result := Tok_partial
			end
		end

feature {NONE} -- Tag sub-helpers

	scan_start_tag_name (bt_table: SPECIAL [NATURAL_8]; buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- After consuming name-start char(s); scan rest of start tag name.
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			from until index >= a_end or done loop
				inspect bt_table [buf [index].code].to_integer_32
					when BT_name_start, BT_hex_digit, BT_digit, BT_name_only,
					     BT_minus, BT_colon, BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						index := advance (index)
					when BT_whitespace, BT_CR, BT_LF then
						index := advance (index)
						from until index >= a_end or done loop
							inspect bt_table [buf [index].code].to_integer_32
								when BT_name_start, BT_hex_digit then
									Result := scan_atts (buf, index, a_end); done := True
								when BT_gt then
									next_token_index := advance (index)
									Result := Tok_start_tag_no_atts; done := True
								when BT_forward_slash then
									index := advance (index)
									if index >= a_end then Result := Tok_partial; done := True
									elseif buf [index] = '>' then
										next_token_index := advance (index)
										Result := Tok_empty_element_no_atts; done := True
									else
										next_token_index := index; Result := Tok_invalid; done := True
									end
								when BT_whitespace, BT_CR, BT_LF then
									index := advance (index)
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
							Result := Tok_partial; done := True
						end
					when BT_gt then
						next_token_index := advance (index)
						Result := Tok_start_tag_no_atts; done := True
					when BT_forward_slash then
						index := advance (index)
						if index >= a_end then
							Result := Tok_partial; done := True
						elseif buf [index] = '>' then
							next_token_index := advance (index)
							Result := Tok_empty_element_no_atts; done := True
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
				else
					next_token_index := index; Result := Tok_invalid; done := True
				end
			end
			if not done then
				Result := Tok_partial
			end
		end

	scan_att_value (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER;
	                open: INTEGER): INTEGER
			-- Scan past whitespace to the opening quote, then the value up to matching
			-- close quote.  Sets next_token_ptr past the closing quote.
			-- Returns 0 (caller should continue) or a non-zero error/end token code.
		local
			index, opening_quote: INTEGER
			done, closed: BOOLEAN
		do
			index := start_index
			-- skip to opening quote
			if attached byte_type_table as bt_table  then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_quote then
							opening_quote := BT_quote; done := True
						when BT_apostrophe then
							opening_quote := BT_apostrophe; done := True
						when BT_whitespace, BT_LF, BT_CR then
							index := advance (index)
					else
						next_token_index := index; Result := Tok_invalid; done := True
					end
				end
			end
			if done and Result = 0 and then attached byte_type_table as bt_table then
				-- scan value content up to matching closing quote
				index := advance (index)  -- skip opening quote
				from until index >= a_end or closed loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_quote then
							if opening_quote = BT_quote then
								next_token_index := advance (index); closed := True
							else
								index := advance (index)
							end
						when BT_apostrophe then
							if opening_quote = BT_apostrophe then
								next_token_index := advance (index); closed := True
							else
								index := advance (index)
							end
						when BT_ampersand then
							Result := scan_ref (buf, advance (index), a_end)
							if Result > 0 then
								index := next_token_index; Result := 0
							else
								closed := True  -- partial or invalid; exit
							end
						when BT_lt then
							next_token_index := index; Result := Tok_invalid; closed := True
					else
						index := advance (index)
					end
				end
				if not closed and Result = 0 then
					Result := Tok_partial
				end
			elseif not done then
				Result := Tok_partial
			end
		end

	scan_comment (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Deferred: implemented in XPACT_PI_COMMENT_SCANNER.
		require start_index <= a_end
		deferred
		end

	scan_pi (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Deferred: implemented in XPACT_PI_COMMENT_SCANNER.
		require start_index <= a_end
		deferred
		end

	scan_cdata_section_open (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Deferred: implemented in XPACT_PI_COMMENT_SCANNER.
		require start_index <= a_end
		deferred
		end

end
