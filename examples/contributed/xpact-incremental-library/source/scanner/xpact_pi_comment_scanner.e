note
	description: "[
					Scanners for processing instructions, comments, CDATA section openers,
					and declaration keywords (<!foo).
			
					Corresponds to scanComment, scanDecl, scanPi, checkPiTarget,
					scanCdataSection in xmltok_impl.c.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:45:44 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_PI_COMMENT_SCANNER

inherit XPACT_SCANNER_HELPERS

feature {NONE} -- PI and comment scanning

	scan_comment (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan comment after '<!-'.  Returns Tok_comment or error.
		require start_index <= a_end
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial
			elseif buf [index] /= '-' then
				next_token_index := index
				Result := Tok_invalid

			elseif attached byte_type_table as bt_table then
				index := advance (index)
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_minus then
							index := advance (index)
							if index >= a_end then
								Result := Tok_partial; done := True
							elseif buf [index] = '-' then
								index := advance (index)
								if index >= a_end then
									Result := Tok_partial; done := True
								elseif buf [index] = '>' then
									next_token_index := advance (index)
									Result := Tok_comment; done := True
								else
									next_token_index := index; Result := Tok_invalid; done := True
								end
							end
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
						when BT_lead_4_byte then
							if a_end - index < 4 then
								Result := Tok_partial_char; done := True
							elseif is_invalid_char_4 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 4
							end
					else
						index := advance (index)
					end
				end
				if not done then
					Result := Tok_partial
				end
			end
		end

	scan_pi (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan processing instruction after '<?'.
			-- Returns Tok_pi (or Tok_xml_decl if target is "xml").
		require
			valid_range: start_index <= a_end
		local
			index, tok: INTEGER; target_start: INTEGER; done: BOOLEAN
		do
			index := start_index
			target_start := index
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
						if a_end - index >= 3 and then not is_invalid_char_3 (buf, index)
							and then is_name_start_char_3 (buf, index)
						then index := index + 3
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
				else
					next_token_index := index; Result := Tok_invalid; done := True
				end
				if not done and then attached byte_type_table as bt_table then
					from until index >= a_end or done loop
						inspect bt_table [buf [index].code].to_integer_32
							when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
								index := advance (index)
							when BT_whitespace, BT_CR, BT_LF then
								tok := check_pi_target (buf, target_start, index)
								if tok = 0 then
									next_token_index := index; Result := Tok_invalid; done := True
								else
									index := advance (index)
									Result := scan_pi_content (buf, index, a_end, tok); done := True
								end
							when BT_question then
								tok := check_pi_target (buf, target_start, index)
								if tok = 0 then
									next_token_index := index; Result := Tok_invalid; done := True
								else
									index := advance (index)
									if index >= a_end then Result := Tok_partial; done := True
									elseif buf [index] = '>' then
										next_token_index := advance (index)
										Result := tok; done := True
									else
										next_token_index := index; Result := Tok_invalid; done := True
									end
								end
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
					end
					if not done then
					Result := Tok_partial
				end
				end
			end
		end

	scan_decl (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Scan declaration keyword after '<!'.  Returns Tok_decl_open or error.
		require start_index <= a_end
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= a_end then
				Result := Tok_partial

			elseif attached byte_type_table as bt_table then
				inspect bt_table [buf [index].code].to_integer_32
					when BT_minus then
						Result := scan_comment (buf, advance (index), a_end)

					when BT_left_square_bracket then
						next_token_index := advance (index)
						Result := Tok_cond_sect_open

					when BT_name_start, BT_hex_digit then
						index := advance (index)
						from until index >= a_end or done loop
							inspect bt_table [buf [index].code].to_integer_32
								when BT_name_start, BT_hex_digit then
									index := advance (index)
								when BT_whitespace, BT_CR, BT_LF, BT_percent then
									next_token_index := index; Result := Tok_decl_open; done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
						Result := Tok_partial
				end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_cdata_section_open (buf: SPECIAL [CHARACTER]; start_index, a_end: INTEGER): INTEGER
			-- Verify 'CDATA[' after '<!['.  Returns Tok_cdata_sect_open or error.
		require
			start_index <= a_end
		local
			index, i: INTEGER
		do
			index := start_index
			if a_end - index < 6 then
				Result := Tok_partial
			else
				from i := 0 until i >= 6 loop
					if buf [index + i] /= Cdata_lsqb [i] then
						next_token_index := index + i
						Result := Tok_invalid
						i := 6 -- exit
					else
						i := i + 1
					end
				end
				if Result = 0 then
					next_token_index := index + 6
					Result := Tok_cdata_sect_open
				end
			end
		end

feature {NONE} -- PI helpers

	check_pi_target (buf: SPECIAL [CHARACTER]; a_start, a_end: INTEGER): INTEGER
			-- Return Tok_xml_decl if target is exactly "xml" (case-sensitive),
			-- Tok_pi otherwise, or 0 if target is a case variation of "xml"
			-- (forbidden by XML spec: "<?XML" etc. are reserved).
		local
			len: INTEGER
		do
			len := a_end - a_start
			if len = 3 * min_bytes_per_char then
				if buf [a_start] = 'x'
					and buf [a_start + min_bytes_per_char] = 'm'
					and buf [a_start + 2 * min_bytes_per_char] = 'l'
				then
					Result := Tok_xml_decl
				elseif (buf [a_start] = 'x' or buf [a_start] = 'X')
					and (buf [a_start + min_bytes_per_char] = 'm' or buf [a_start + min_bytes_per_char] = 'M')
					and (buf [a_start + 2 * min_bytes_per_char] = 'l' or buf [a_start + 2 * min_bytes_per_char] = 'L')
				then
					Result := 0 -- reserved; caller treats as invalid
				else
					Result := Tok_pi
				end
			else
				Result := Tok_pi
			end
		end

	scan_pi_content (buf: SPECIAL [CHARACTER]; start_index, a_end, tok: INTEGER): INTEGER
			-- Scan PI content until '?>'.  Returns tok (Tok_pi or Tok_xml_decl).
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if attached byte_type_table as bt_table then
				from until index >= a_end or done loop
					inspect bt_table [buf [index].code].to_integer_32
						when BT_non_xml, BT_malform, BT_continuation_byte then
							next_token_index := index; Result := Tok_invalid; done := True
						when BT_lead_2_byte then
							if a_end - index < 2 then Result := Tok_partial_char; done := True
							elseif is_invalid_char_2 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 2
							end
						when BT_lead_3_byte then
							if a_end - index < 3 then Result := Tok_partial_char; done := True
							elseif is_invalid_char_3 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 3
							end
						when BT_lead_4_byte then
							if a_end - index < 4 then Result := Tok_partial_char; done := True
							elseif is_invalid_char_4 (buf, index) then
								next_token_index := index; Result := Tok_invalid; done := True
							else
								index := index + 4
							end
						when BT_question then
							index := advance (index)
							if index >= a_end then Result := Tok_partial; done := True
							elseif buf [index] = '>' then
								next_token_index := advance (index)
								Result := tok; done := True
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

feature {NONE} -- CDATA constant

	Cdata_lsqb: SPECIAL [CHARACTER]
			-- ASCII codes for "CDATA[" (C, D, A, T, A, [).
		once
			Result := ("CDATA[").area
		end

end
