note
	description: "AutoTest-generated parser helper cases."
	testing: "type/generated"

class
	XP_GENERATED_PARSER_TESTS

inherit
	EQA_GENERATED_TEST_SET

create
	default_create

feature -- Generated tests

	test_parser_configuration_and_reset
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make_with_limits (l_handler, 128, 8, 4, 64)
			assert ("input limit set", l_parser.max_input_bytes = 128)
			assert ("depth limit set", l_parser.max_element_depth = 8)
			assert ("attribute limit set", l_parser.max_attribute_count = 4)
			assert ("token limit set", l_parser.max_token_length = 64)

			l_parser.set_namespace_mode ('|')
			l_parser.set_return_ns_triplet (True)
			assert ("namespace mode enabled", l_parser.namespace_mode)
			assert ("namespace separator set", l_parser.namespace_separator = '|')
			assert ("namespace triplet enabled", l_parser.return_ns_triplet)

			assert ("broken document rejected", not l_parser.parse ("<root>"))
			assert ("error recorded", l_parser.has_error and not l_parser.last_error.is_empty)
			assert ("next parse resets previous error", l_parser.parse ("<root/>"))
			assert ("successful parse clears error", not l_parser.has_error)
			assert ("successful parse clears message", l_parser.last_error.is_empty)
			assert ("reset keeps namespace mode", l_parser.namespace_mode and l_parser.namespace_separator = '|')
		end

	test_markup_prefix_boundaries
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("complete start tag end", l_parser.markup_prefix_end ("<root a='1'>", 1) = 12)
			assert ("complete empty element end", l_parser.markup_prefix_end ("<empty/>", 1) = 8)
			assert ("complete comment end", l_parser.markup_prefix_end ("<!--x-->", 1) = 8)
			assert ("complete cdata end", l_parser.markup_prefix_end ("<![CDATA[x]]>", 1) = 13)
			assert ("complete processing instruction end", l_parser.markup_prefix_end ("<?x y?>", 1) = 7)
			assert ("incomplete start tag has no end", l_parser.markup_prefix_end ("<root", 1) = 0)
			assert ("first incomplete markup found", l_parser.incomplete_markup_prefix_start ("<root><child") = 7)
			assert ("complete document has no incomplete markup", l_parser.incomplete_markup_prefix_start ("<root><child /></root>") = 0)
		end

	test_parse_prefix_accepts_incomplete_final_markup
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("incomplete final start tag accepted as prefix", l_parser.parse_prefix ("<root><child"))
			assert ("prefix parse has no error", not l_parser.has_error)

			create l_parser.make (l_handler)
			assert ("incomplete final comment accepted as prefix", l_parser.parse_prefix ("<root><!-- open"))
			assert ("comment prefix parse has no error", not l_parser.has_error)

			create l_parser.make (l_handler)
			assert ("final parse still rejects incomplete document", not l_parser.parse ("<root><child"))
			assert ("final parse reports unclosed token or element", not l_parser.last_error.is_empty)
		end

	test_namespace_expansion_and_errors
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_parser.set_namespace_mode ('|')
			assert ("namespace document accepted", l_parser.parse ("<p:root xmlns:p='urn:x' p:a='1'/>"))
			assert ("namespace-expanded start name", l_handler.events.i_th (1).same_string ("start:urn:x|root:1"))
			assert ("namespace-expanded end name", l_handler.events.i_th (2).same_string ("end:urn:x|root"))

			create l_handler.make
			create l_parser.make (l_handler)
			l_parser.set_namespace_mode ('|')
			l_parser.set_return_ns_triplet (True)
			assert ("triplet namespace document accepted", l_parser.parse ("<p:root xmlns:p='urn:x'/>"))
			assert ("namespace triplet start name", l_handler.events.i_th (1).same_string ("start:urn:x|root|p:0"))

			create l_handler.make
			create l_parser.make (l_handler)
			l_parser.set_namespace_mode ('|')
			assert ("unbound namespace prefix rejected", not l_parser.parse ("<p:root/>"))
			assert ("unbound namespace error", l_parser.last_error.same_string ("unbound namespace prefix"))
		end

end
