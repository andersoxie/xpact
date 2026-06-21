note
	description: "[
		Top-level tokenizers for element content and CDATA section content.

		Corresponds to contentTok and cdataSectionTok in xmltok_impl.c.
		These are the entry points called by the content processor.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:34:05 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_CONTENT_SCANNER

inherit
	XPACT_TAG_SCANNER
	XPACT_PI_COMMENT_SCANNER

feature -- Content tokenization

	content_tok (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Return the token type for the next token in element content.
			-- Sets next_token_ptr.  Corresponds to contentTok() in xmltok_impl.c.
		require
			valid_start_index: start_index <= a_end and a_end <= buf.count
		local
			index, a_end_adj: INTEGER
		do
			index := start_index
			a_end_adj := a_end
			if index >= a_end_adj then
				Result := Tok_none
			else
				inspect byte_type (buf, index)
					when BT_lt then
						Result := scan_lt (buf, advance (index), a_end_adj)
					when BT_ampersand then
						Result := scan_ref (buf, advance (index), a_end_adj)
					when BT_CR then
						index := advance (index)
						if index >= a_end_adj then
							Result := Tok_trailing_cr
						else
							if byte_type (buf, index) = BT_LF then
								index := advance (index)
							end
							next_token_index := index
							Result := Tok_data_newline
						end
					when BT_LF then
						next_token_index := advance (index)
						Result := Tok_data_newline
					when BT_right_square_bracket then
						index := advance (index)
						if index >= a_end_adj then
							Result := Tok_trailing_rsqb
						elseif buf [index] /= ']' then
							-- lone ']', fall through to data chars
							Result := scan_data_chars (buf, index, a_end_adj)
						else
							index := advance (index)
							if index >= a_end_adj then
								Result := Tok_trailing_rsqb
							elseif buf [index] = '>' then
								-- illegal ']]>' in content
								next_token_index := index
								Result := Tok_invalid
							else
								index := advance (index)
								Result := scan_data_chars (buf, index, a_end_adj)
							end
						end
					when BT_non_xml, BT_malform, BT_continuation_byte then
						next_token_index := index
						Result := Tok_invalid
					when BT_lead_2_byte then
						if a_end_adj - index < 2 then
							Result := Tok_partial_char
						elseif is_invalid_char_2 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 2
							Result := scan_data_chars (buf, index, a_end_adj)
						end
					when BT_lead_3_byte then
						if a_end_adj - index < 3 then
							Result := Tok_partial_char
						elseif is_invalid_char_3 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 3
							Result := scan_data_chars (buf, index, a_end_adj)
						end
					when BT_lead_4_byte then
						if a_end_adj - index < 4 then
							Result := Tok_partial_char
						elseif is_invalid_char_4 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 4
							Result := scan_data_chars (buf, index, a_end_adj)
						end
				else
					index := advance (index)
					Result := scan_data_chars (buf, index, a_end_adj)
				end
			end
		end

	cdata_section_tok (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Return the next token inside a CDATA section.
			-- Sets next_token_ptr.  Corresponds to cdataSectionTok() in xmltok_impl.c.
		require
			valid_range: start_index <= a_end and a_end <= buf.count
		local
			index: INTEGER
		do
			index := start_index
			if index >= a_end then
				Result := Tok_none
			else
				inspect byte_type (buf, index)
					when BT_right_square_bracket then
						index := advance (index)
						if index >= a_end then
							Result := Tok_partial
						elseif buf [index] /= ']' then
							-- lone ']'
							Result := scan_cdata_data_chars (buf, index, a_end)
						else
							index := advance (index)
							if index >= a_end then
								Result := Tok_partial
							elseif buf [index] = '>' then
								next_token_index := advance (index)
								Result := Tok_cdata_sect_close
							else
								index := advance (index)
								Result := scan_cdata_data_chars (buf, index, a_end)
							end
						end
					when BT_CR then
						index := advance (index)
						if index >= a_end then
							Result := Tok_partial
						else
							if byte_type (buf, index) = BT_LF then
								index := advance (index)
							end
							next_token_index := index
							Result := Tok_data_newline
						end
					when BT_LF then
						next_token_index := advance (index)
						Result := Tok_data_newline
					when BT_non_xml, BT_malform, BT_continuation_byte then
						next_token_index := index; Result := Tok_invalid
					when BT_lead_2_byte then
						if a_end - index < 2 then
							Result := Tok_partial_char
						elseif is_invalid_char_2 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 2
							Result := scan_cdata_data_chars (buf, index, a_end)
						end
					when BT_lead_3_byte then
						if a_end - index < 3 then
							Result := Tok_partial_char
						elseif is_invalid_char_3 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 3
							Result := scan_cdata_data_chars (buf, index, a_end)
						end
					when BT_lead_4_byte then
						if a_end - index < 4 then
							Result := Tok_partial_char
						elseif is_invalid_char_4 (buf, index) then
							next_token_index := index; Result := Tok_invalid
						else
							index := index + 4
							Result := scan_cdata_data_chars (buf, index, a_end)
						end
				else
					index := advance (index)
					Result := scan_cdata_data_chars (buf, index, a_end)
				end
			end
		end

feature {NONE} -- Data character accumulation

	scan_data_chars (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
		-- Accumulate data characters in content context until a delimiter.
		-- Returns Tok_data_chars.
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if attached byte_type_table as BT_table then
				from until index >= a_end or done loop
					inspect BT_table [buf [index].code].to_integer_32
						when BT_lead_2_byte then
							if a_end - index < 2 or else is_invalid_char_2 (buf, index) then
								next_token_index := index; Result := Tok_data_chars; done := True
							else
								index := index + 2
							end
						when BT_lead_3_byte then
							if a_end - index < 3 or else is_invalid_char_3 (buf, index) then
								next_token_index := index; Result := Tok_data_chars; done := True
							else
								index := index + 3
							end
						when BT_lead_4_byte then
							if a_end - index < 4 or else is_invalid_char_4 (buf, index) then
								next_token_index := index; Result := Tok_data_chars; done := True
							else
								index := index + 4
							end
						when BT_right_square_bracket, BT_ampersand, BT_lt, BT_non_xml, BT_malform, BT_continuation_byte,
						     BT_CR, BT_LF then
							next_token_index := index; Result := Tok_data_chars; done := True
					else
						index := advance (index)
					end
				end
			end
			if not done then
				next_token_index := index; Result := Tok_data_chars
			end
		end

	scan_cdata_data_chars (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Accumulate data characters inside a CDATA section.
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_lead_2_byte then
							if a_end - index < 2 or else is_invalid_char_2 (buf, index) then
								next_token_index := index; Result := Tok_data_chars; done := True
							else
								index := index + 2
							end
						when BT_lead_3_byte then
							if a_end - index < 3 or else is_invalid_char_3 (buf, index) then
								next_token_index := index; Result := Tok_data_chars; done := True
							else
								index := index + 3
							end
						when BT_non_xml, BT_malform, BT_continuation_byte, BT_CR, BT_LF, BT_right_square_bracket then
							next_token_index := index; Result := Tok_data_chars; done := True
					else
						index := advance (index)
					end
				end
			end
			if not done then
				next_token_index := index; Result := Tok_data_chars
			end
		end

end
