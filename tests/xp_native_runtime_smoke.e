note
	description: "Smoke test for the native C ABI calling into the Eiffel parser runtime."

class
	XP_NATIVE_RUNTIME_SMOKE

create
	make

feature {NONE} -- Initialization

	make
		local
			l_bridge: XP_NATIVE_BRIDGE_EXPORT
			l_parser: POINTER
			l_encoding: C_STRING
			l_input: C_STRING
			l_status: INTEGER
		do
			create l_bridge.make
			assert ("runtime bridge installs", l_bridge.install)
			create l_encoding.make ("UTF-8")
			l_parser := xml_parser_create (l_encoding.item)
			assert ("C ABI parser created", l_parser /= default_pointer)
			create l_input.make ("<root><child>text</child></root>")
			l_status := xml_parse (l_parser, l_input.item, l_input.count, 1)
			assert ("C ABI parse reached Eiffel parser", l_status = Xml_status_ok)
			assert ("C ABI error code delegated", xml_get_error_code (l_parser) = Xml_error_none)
			xml_parser_free (l_parser)
			assert ("Eiffel bridge released parser handle", l_bridge.active_parser_count = 0)
			l_bridge.uninstall
			if failed then
				check smoke_passed: False end
			else
				io.put_string ("xpact native runtime smoke: ok%N")
			end
		end

feature {NONE} -- Constants

	Xml_status_ok: INTEGER = 1

	Xml_error_none: INTEGER = 0

feature {NONE} -- Assertions

	assert (a_label: READABLE_STRING_8; a_condition: BOOLEAN)
			-- Record failure without hiding later checks.
		require
			label_attached: a_label /= Void
			label_not_empty: not a_label.is_empty
		do
			if not a_condition then
				failed := True
				io.put_string ("FAIL: ")
				io.put_string (a_label)
				io.put_new_line
			end
		end

	failed: BOOLEAN
			-- Has any smoke check failed?

feature {NONE} -- Native C ABI calls

	xml_parser_create (a_encoding: POINTER): POINTER
			-- `XML_ParserCreate'.
		external
			"C signature (const XML_Char *): EIF_POINTER use %"xpact.h%""
		alias
			"XML_ParserCreate"
		end

	xml_parse (a_parser, a_bytes: POINTER; a_length, a_is_final: INTEGER): INTEGER
			-- `XML_Parse'.
		external
			"C signature (XML_Parser, const char *, int, int): EIF_INTEGER use %"xpact.h%""
		alias
			"XML_Parse"
		end

	xml_get_error_code (a_parser: POINTER): INTEGER
			-- `XML_GetErrorCode'.
		external
			"C signature (XML_Parser): EIF_INTEGER use %"xpact.h%""
		alias
			"XML_GetErrorCode"
		end

	xml_parser_free (a_parser: POINTER)
			-- `XML_ParserFree'.
		external
			"C signature (XML_Parser) use %"xpact.h%""
		alias
			"XML_ParserFree"
		end

end
