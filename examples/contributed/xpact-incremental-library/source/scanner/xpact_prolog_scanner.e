note
	description: "[
		Tokenizer for the XML prolog and DTD subset.

		Corresponds to prologTok, scanPercent, scanPoundName, scanLit
		in xmltok_impl.c.

		prologTok handles all tokens that appear before and inside the DTD:
		quoted literals, '<'-prefixed markup, whitespace, punctuation, and
		name/nmtoken tokens.  Negative return values signal partial tokens
		where the caller needs more data before deciding the token type:
		  -Tok_prolog_s          : CR at end of buffer (might be part of CRLF)
		  -Tok_close_bracket     : ']' at end of buffer
		  -Tok_close_paren       : ')' at end of buffer
		  -Tok_pound_name        : partial #name
		  -Tok_name / -Tok_nmtoken : partial name/nmtoken
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:36:24 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_PROLOG_SCANNER

inherit
	XPACT_SCANNER_HELPERS
	XPACT_REF_SCANNER
	XPACT_PI_COMMENT_SCANNER

feature -- Prolog tokenization

	prolog_tok (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Return the next prolog/DTD token.  Sets next_token_ptr.
		require start_index <= a_end and a_end <= buf.count
		local
			index, tok: INTEGER
		do
			index := start_index
			if index >= a_end then
				Result := Tok_none
			else
				inspect byte_type (buf, index)
					when BT_quote then
						Result := scan_lit (BT_quote, buf, advance (index), a_end)
					when BT_apostrophe then
						Result := scan_lit (BT_apostrophe, buf, advance (index), a_end)
					when BT_lt then
						index := advance (index)
						if index >= a_end then
							Result := Tok_partial
						else
							inspect byte_type (buf, index)
								when BT_exclamation then
									Result := scan_decl (buf, advance (index), a_end)
								when BT_question then
									Result := scan_pi (buf, advance (index), a_end)
								when BT_name_start, BT_hex_digit, BT_non_ascii, BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
									next_token_index := index - min_bytes_per_char
									Result := Tok_instance_start
							else
								next_token_index := index; Result := Tok_invalid
							end
						end
					when BT_CR then
						if advance (index) = a_end then
							next_token_index := a_end
							Result := -Tok_prolog_s
						else
							Result := scan_prolog_s (buf, index, a_end)
						end
					when BT_whitespace, BT_LF then
						Result := scan_prolog_s (buf, index, a_end)
					when BT_percent then
						Result := scan_percent (buf, advance (index), a_end)
					when BT_comma then
						next_token_index := advance (index); Result := Tok_comma

					when BT_left_square_bracket then
						next_token_index := advance (index); Result := Tok_open_bracket

					when BT_right_square_bracket then
						index := advance (index)
						if index >= a_end then
							next_token_index := index; Result := -Tok_close_bracket
						elseif buf [index] = ']' then
							if a_end - index < 2 * min_bytes_per_char then
								next_token_index := index; Result := Tok_partial
							elseif buf [index + min_bytes_per_char] = '>' then
								next_token_index := index + 2 * min_bytes_per_char
								Result := Tok_cond_sect_close
							else
								next_token_index := index; Result := Tok_close_bracket
							end
						else
							next_token_index := index; Result := Tok_close_bracket
						end
					when BT_left_parenthesis then
						next_token_index := advance (index); Result := Tok_open_paren
					when BT_right_parenthesis then
						index := advance (index)
						if index >= a_end then
							next_token_index := index; Result := -Tok_close_paren
						else
							inspect byte_type (buf, index)
								when BT_asterisk then
									next_token_index := advance (index); Result := Tok_close_paren_asterisk
								when BT_question then
									next_token_index := advance (index); Result := Tok_close_paren_question
								when BT_plus then
									next_token_index := advance (index); Result := Tok_close_paren_plus
								when BT_CR, BT_LF, BT_whitespace, BT_gt, BT_comma, BT_pipe_symbol, BT_right_parenthesis then
									next_token_index := index; Result := Tok_close_paren
							else
								next_token_index := index; Result := Tok_invalid
							end
						end
					when BT_pipe_symbol then
						next_token_index := advance (index); Result := Tok_or
					when BT_gt then
						next_token_index := advance (index); Result := Tok_decl_close
					when BT_hash then
						Result := scan_pound_name (buf, advance (index), a_end)
					when BT_name_start, BT_hex_digit then
						tok := Tok_name
						index := advance (index)
						Result := scan_name_or_nmtoken (buf, index, a_end, tok)
					when BT_digit, BT_name_only, BT_minus then
						tok := Tok_nmtoken
						index := advance (index)
						Result := scan_name_or_nmtoken (buf, index, a_end, tok)

					when BT_lead_2_byte then
						if a_end - index < 2 then
							Result := Tok_partial_char
						elseif is_invalid_char_2 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						elseif is_name_start_char_2 (buf, index) then
							tok := Tok_name; index := index + 2
							Result := scan_name_or_nmtoken (buf, index, a_end, tok)
						elseif is_name_char_2 (buf, index) then
							tok := Tok_nmtoken; index := index + 2
							Result := scan_name_or_nmtoken (buf, index, a_end, tok)
						else
							next_token_index := index; Result := Tok_invalid
						end
					when BT_lead_3_byte then
						if a_end - index < 3 then
							Result := Tok_partial_char
						elseif is_invalid_char_3 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						elseif is_name_start_char_3 (buf, index) then
							tok := Tok_name; index := index + 3
							Result := scan_name_or_nmtoken (buf, index, a_end, tok)
						elseif is_name_char_3 (buf, index) then
							tok := Tok_nmtoken; index := index + 3
							Result := scan_name_or_nmtoken (buf, index, a_end, tok)
						else
							next_token_index := index; Result := Tok_invalid
						end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

feature {NONE} -- Prolog sub-scanners

	scan_percent (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan parameter entity reference after '%'.
		require start_index <= a_end
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial

			elseif attached byte_type_table as bt_table then
				inspect bt_table [buf [index].code].to_integer_32
					when BT_name_start, BT_hex_digit then
						index := advance (index)
						from until index >= a_end or done loop
							inspect bt_table [buf [index].code].to_integer_32
								when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
									index := advance (index)
								when BT_semicolon then
									next_token_index := advance (index)
									Result := Tok_param_entity_ref; done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
							Result := Tok_partial
						end
					when BT_whitespace, BT_LF, BT_CR, BT_percent then
						next_token_index := index; Result := Tok_percent
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_pound_name (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan #name after '#'.  Negative result means partial token.
		require start_index <= a_end
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial

			elseif attached byte_type_table as bt_table then
				inspect bt_table [buf [index].code].to_integer_32
					when BT_name_start, BT_hex_digit then
						index := advance (index)
						from until index >= a_end or done loop
							inspect bt_table [buf [index].code].to_integer_32
								when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
									index := advance (index)
								when BT_CR, BT_LF, BT_whitespace, BT_right_parenthesis, BT_gt, BT_percent, BT_pipe_symbol then
									next_token_index := index; Result := Tok_pound_name; done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
							next_token_index := index; Result := -Tok_pound_name
						end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_lit (a_open: INTEGER; buf: SPECIAL [CHARACTER];
	           start_index, a_end: INTEGER): INTEGER
			-- Scan quoted literal (attribute or entity value delimited by
			-- a_open quote type BT_quote or BT_apostrophe).
			-- Returns Tok_literal or negative (partial) or Tok_invalid.
		require start_index <= a_end
		local
			index, t: INTEGER; done: BOOLEAN
		do
			index := start_index
			if attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					t := bt_table [buf [index].code].to_integer_32
					inspect t
						when BT_non_xml, BT_malform, BT_continuation_byte then
							next_token_index := index; Result := Tok_invalid; done := True
						when BT_lead_2_byte then
							if a_end - index < 2 then
								Result := Tok_partial_char; done := True
							elseif is_invalid_char_2 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 2
							end
						when BT_lead_3_byte then
							if a_end - index < 3 then
								Result := Tok_partial_char; done := True
							elseif is_invalid_char_3 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 3
							end
						when BT_quote, BT_apostrophe then
							index := advance (index)
							if t = a_open then
								if index >= a_end then
									Result := -Tok_literal; done := True
								else
									next_token_index := index
									inspect bt_table [buf [index].code].to_integer_32
										when BT_whitespace, BT_CR, BT_LF, BT_gt, BT_percent, BT_left_square_bracket then
											Result := Tok_literal
									else
										Result := Tok_invalid
									end
									done := True
								end
							end
					else
						index := advance (index)
					end
			end
			end
			if not done then
				Result := Tok_partial
			end
		end

	scan_prolog_s (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Collect whitespace run and return Tok_prolog_s.
		local
			index: INTEGER
		do
			index := start_index
			if attached byte_type_table as bt_table then
				from index := advance (index) until index >= a_end loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_whitespace, BT_LF then
							index := advance (index)
						when BT_CR then
							if advance (index) = a_end then index := a_end  -- exit; might be CRLF
							else
								index := advance (index)
							end
					else
						next_token_index := index; Result := Tok_prolog_s; index := a_end
					end
				end
			end
			if Result = 0 then
				next_token_index := index; Result := Tok_prolog_s
			end
		end

	scan_name_or_nmtoken (buf: SPECIAL [CHARACTER]; start_index, a_end, a_tok: INTEGER): INTEGER
			-- Continue scanning a name or nmtoken started by caller.
			-- a_tok is Tok_name or Tok_nmtoken from the first character.
			-- Returns the token (possibly with suffix +, *, ?) or negative if partial.
		local
			index, tok: INTEGER; done: BOOLEAN
		do
			tok := a_tok; index := start_index
			if attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus, BT_colon then
							index := advance (index)
						when BT_gt, BT_right_parenthesis, BT_comma, BT_pipe_symbol, BT_left_square_bracket,
						     BT_percent, BT_whitespace, BT_CR, BT_LF then
							next_token_index := index; Result := tok; done := True
						when BT_plus then
							if tok = Tok_nmtoken then
								next_token_index := index; Result := Tok_invalid
							else
								next_token_index := advance (index); Result := Tok_name_plus
							end
							done := True
						when BT_asterisk then
							if tok = Tok_nmtoken then
								next_token_index := index; Result := Tok_invalid
							else
								next_token_index := advance (index); Result := Tok_name_asterisk
							end
							done := True
						when BT_question then
							if tok = Tok_nmtoken then
								next_token_index := index; Result := Tok_invalid
							else
								next_token_index := advance (index); Result := Tok_name_question
							end
							done := True
					else
						next_token_index := index; Result := Tok_invalid; done := True
					end
				end
			end
			if not done then
				next_token_index := index; Result := -tok
			end
		end

end
