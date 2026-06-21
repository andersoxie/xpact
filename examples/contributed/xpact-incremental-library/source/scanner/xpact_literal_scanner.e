note
	description: "[
		Second-level tokenizers for the content of quoted literals already
		returned by prolog_tok or content_tok.

		Corresponds to attributeValueTok and entityValueTok in xmltok_impl.c.
		These are called after the outer token has already been identified.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:47:58 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_LITERAL_SCANNER

inherit
	XPACT_SCANNER_HELPERS
	XPACT_REF_SCANNER

feature -- Literal content tokenization

	attribute_value_tok (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Tokenize inside an already-identified attribute value literal.
			-- Corresponds to attributeValueTok() in xmltok_impl.c.
		require start_index <= a_end and a_end <= buf.count
		local
			index, start: INTEGER; done: BOOLEAN
		do
			index := start_index; start := index
			if index >= a_end then
				Result := Tok_none

			elseif attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_lead_2_byte then
							index := index + 2
						when BT_lead_3_byte then
							index := index + 3
						when BT_lead_4_byte then
							index := index + 4
						when BT_ampersand then
							if index = start then
								Result := scan_ref (buf, advance (index), a_end)
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_lt then
							next_token_index := index; Result := Tok_invalid; done := True
						when BT_LF then
							if index = start then
								next_token_index := advance (index); Result := Tok_data_newline
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_CR then
							if index = start then
								index := advance (index)
								if index >= a_end then
									Result := Tok_trailing_cr
								else
									if bt_table [buf [index].code].to_integer_32 = BT_LF then index := advance (index) end
									next_token_index := index; Result := Tok_data_newline
								end
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_whitespace then
							if index = start then
								next_token_index := advance (index); Result := Tok_attribute_value_s
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
					else
						index := advance (index)
					end
				end
				if not done then
					next_token_index := index; Result := Tok_data_chars
				end
			end
		end

	entity_value_tok (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Tokenize inside an entity value literal.
			-- Corresponds to entityValueTok() in xmltok_impl.c.
		require start_index <= a_end and a_end <= buf.count
		local
			index, start: INTEGER; done: BOOLEAN
		do
			index := start_index; start := index
			if index >= a_end then
				Result := Tok_none

			elseif attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_lead_2_byte then
							index := index + 2
						when BT_lead_3_byte then
							index := index + 3
						when BT_lead_4_byte then
							index := index + 4
						when BT_ampersand then
							if index = start then
								Result := scan_ref (buf, advance (index), a_end)
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_percent then
							if index = start then
								-- % starts a parameter entity reference inside entity values
								-- treat as invalid here (caller
								-- (should use prolog scanner)
								next_token_index := index; Result := Tok_invalid
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_LF then
							if index = start then
								next_token_index := advance (index); Result := Tok_data_newline
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
						when BT_CR then
							if index = start then
								index := advance (index)
								if index >= a_end then
									Result := Tok_trailing_cr
								else
									if bt_table [buf [index].code].to_integer_32 = BT_LF then index := advance (index) end
									next_token_index := index; Result := Tok_data_newline
								end
							else
								next_token_index := index; Result := Tok_data_chars
							end
							done := True
					else
						index := advance (index)
					end
				end
				if not done then
					next_token_index := index; Result := Tok_data_chars
				end
			end
		end

end
