note
	description: "Phase 1 tests for xpact."

class
	XP_TEST_ROOT

create
	make

feature {NONE} -- Initialization

	make
		do
			test_well_formed_callbacks
			test_mismatched_tag_is_rejected
			test_depth_limit_is_enforced
			test_comments_and_cdata
			test_predefined_and_numeric_entities
			test_internal_entity_declarations
			test_parameter_entity_declarations
			test_entity_markup_expansion
			test_attribute_entity_expansion
			test_recursive_entity_is_rejected
			test_external_entity_is_rejected
			test_external_general_entity_resolver
			test_external_entity_resolver_denial
			test_external_parameter_entity_resolver
			test_external_subset_resolver
			test_external_policy_blocks_parameter_entities
			test_token_well_formedness_errors
			test_document_structure
			if failed then
				check tests_passed: False end
			else
				io.put_string ("xpact Phase 1 tests: ok%N")
			end
		end

feature {NONE} -- Tests

	test_well_formed_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<root><child id=%"1%">text</child><empty /></root>")
			assert ("well-formed document accepted", l_ok)
			assert ("seven events captured", l_handler.events.count = 7)
			assert ("root start", l_handler.events.i_th (1).same_string ("start:root:0"))
			assert ("child start with one attribute", l_handler.events.i_th (2).same_string ("start:child:1"))
			assert ("text callback", l_handler.events.i_th (3).same_string ("text:text"))
			assert ("child end", l_handler.events.i_th (4).same_string ("end:child"))
			assert ("empty start", l_handler.events.i_th (5).same_string ("start:empty:0"))
			assert ("empty end", l_handler.events.i_th (6).same_string ("end:empty"))
			assert ("root end", l_handler.events.i_th (7).same_string ("end:root"))
		end

	test_mismatched_tag_is_rejected
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<root><child></root>")
			assert ("mismatched document rejected", not l_ok)
			assert ("mismatch error reported", l_parser.last_error.same_string ("mismatched end tag"))
		end

	test_depth_limit_is_enforced
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make_with_limits (l_handler, 1024, 2, 16, 1024)
			l_ok := l_parser.parse ("<a><b><c /></b></a>")
			assert ("depth-limited document rejected", not l_ok)
			assert ("depth error reported", l_parser.last_error.same_string ("maximum element depth exceeded"))
		end

	test_comments_and_cdata
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<root><!-- comment --><![CDATA[raw < text]]></root>")
			assert ("CDATA document accepted", l_ok)
			assert ("CDATA emitted", l_handler.events.i_th (2).same_string ("text:raw < text"))
		end

	test_predefined_and_numeric_entities
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
			l_expected_text: STRING_8
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<root a=%"Tom &amp; &quot;A&quot; &#65; &lt;%">AT&amp;T &lt; &#x41;</root>")
			create l_expected_text.make_from_string ("text:AT&T < A")
			assert ("predefined and numeric references accepted", l_ok)
			if l_ok then
				assert ("content references expanded", l_handler.events.i_th (2).same_string (l_expected_text))
				assert ("attribute references expanded", l_handler.last_attribute_value.same_string ("Tom & %"A%" A <"))
			else
				io.put_string ("predefined error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_internal_entity_declarations
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY company %"AT&amp;T%"><!ENTITY phrase %"Hello &company;%">]><root>&phrase;</root>")
			assert ("internal entities accepted", l_ok)
			if l_ok then
				assert ("nested entity prefix expanded", l_handler.events.i_th (2).same_string ("text:Hello "))
				assert ("nested entity reference expanded", l_handler.events.i_th (3).same_string ("text:AT&T"))
			else
				io.put_string ("internal entity error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_entity_markup_expansion
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY item %"<item>ok</item>%">]><root>&item;</root>")
			assert ("entity replacement markup accepted", l_ok)
			if l_ok then
				assert ("expanded item start", l_handler.events.i_th (2).same_string ("start:item:0"))
				assert ("expanded item text", l_handler.events.i_th (3).same_string ("text:ok"))
				assert ("expanded item end", l_handler.events.i_th (4).same_string ("end:item"))
			else
				io.put_string ("markup entity error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_parameter_entity_declarations
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY %% p %"<!ENTITY who 'world'>%">%%p;]><root>Hello &who;</root>")
			assert ("parameter entity declaration accepted", l_ok)
			if l_ok then
				assert ("parameter entity introduced general entity", l_handler.events.i_th (2).same_string ("text:Hello "))
				assert ("parameter-introduced entity expanded", l_handler.events.i_th (3).same_string ("text:world"))
			else
				io.put_string ("parameter entity error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_attribute_entity_expansion
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY less %"&lt;%">]><root a=%"A &less; B%"/>")
			assert ("attribute entity accepted", l_ok)
			if l_ok then
				assert ("attribute entity expanded as literal", l_handler.last_attribute_value.same_string ("A < B"))
			else
				io.put_string ("attribute entity error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_recursive_entity_is_rejected
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY a %"&b;%"><!ENTITY b %"&a;%">]><root>&a;</root>")
			assert ("recursive entities rejected", not l_ok)
			assert ("recursive error reported", l_parser.last_error.same_string ("recursive entity reference"))
		end

	test_external_entity_is_rejected
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY ext SYSTEM %"file:///tmp/ext.xml%">]><root>&ext;</root>")
			assert ("external entity rejected", not l_ok)
			assert ("external entity error reported", l_parser.last_error.same_string ("external entity not loaded"))
		end

	test_external_general_entity_resolver
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_resolver: XP_TEST_EXTERNAL_ENTITY_RESOLVER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_resolver.make
			l_parser.set_external_entity_resolver (l_resolver)
			l_parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY ext SYSTEM %"mem://external-item%">]><root>&ext;</root>")
			assert ("external general entity accepted by resolver", l_ok)
			if l_ok then
				assert ("external entity produced markup", l_handler.events.i_th (2).same_string ("start:item:0"))
				assert ("external entity produced text", l_handler.events.i_th (3).same_string ("text:external"))
				assert ("resolver saw general entity", not l_resolver.last_is_parameter)
				assert ("resolver saw system id", l_resolver.last_system_id.same_string ("mem://external-item"))
			else
				io.put_string ("external general resolver error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_external_entity_resolver_denial
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_resolver: XP_TEST_EXTERNAL_ENTITY_RESOLVER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_resolver.make
			l_parser.set_external_entity_resolver (l_resolver)
			l_parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY ext SYSTEM %"mem://missing%">]><root>&ext;</root>")
			assert ("resolver denial rejected", not l_ok)
			assert ("resolver denial error", l_parser.last_error.same_string ("external entity not resolved"))
		end

	test_external_parameter_entity_resolver
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_resolver: XP_TEST_EXTERNAL_ENTITY_RESOLVER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_resolver.make
			l_parser.set_external_entity_resolver (l_resolver)
			l_parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY %% ext SYSTEM %"mem://parameter-declarations%">%%ext;]><root>&from_external;</root>")
			assert ("external parameter entity accepted by resolver", l_ok)
			if l_ok then
				assert ("external parameter entity introduced general entity", l_handler.events.i_th (2).same_string ("text:loaded"))
				assert ("resolver saw parameter entity", l_resolver.last_is_parameter)
			else
				io.put_string ("external parameter resolver error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_external_subset_resolver
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_resolver: XP_TEST_EXTERNAL_ENTITY_RESOLVER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_resolver.make
			l_parser.set_external_entity_resolver (l_resolver)
			l_parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_parameter_entities)
			l_ok := l_parser.parse ("<!DOCTYPE root SYSTEM %"mem://subset%"><root>&subset_entity;</root>")
			assert ("external subset accepted by resolver", l_ok)
			if l_ok then
				assert ("external subset introduced entity", l_handler.events.i_th (2).same_string ("text:subset loaded"))
				assert ("resolver saw subset as parameter-class load", l_resolver.last_is_parameter)
			else
				io.put_string ("external subset resolver error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_external_policy_blocks_parameter_entities
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_resolver: XP_TEST_EXTERNAL_ENTITY_RESOLVER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_resolver.make
			l_parser.set_external_entity_resolver (l_resolver)
			l_parser.set_external_entity_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY %% ext SYSTEM %"mem://parameter-declarations%">%%ext;]><root/>")
			assert ("general-only policy blocks parameter entity", not l_ok)
			assert ("policy block error", l_parser.last_error.same_string ("external entity not loaded"))
		end

	test_token_well_formedness_errors
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("raw ampersand rejected", not l_parser.parse ("<root>AT&T</root>"))
			assert ("ampersand error", l_parser.last_error.same_string ("unterminated reference"))
			assert ("double hyphen in comment rejected", not l_parser.parse ("<root><!-- bad -- comment --></root>"))
			assert ("comment error", l_parser.last_error.same_string ("double hyphen in comment"))
			assert ("CDATA close marker in text rejected", not l_parser.parse ("<root>bad ]]></root>"))
			assert ("CDATA marker error", l_parser.last_error.same_string ("CDATA close marker in character data"))
		end

	test_document_structure
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("multiple roots rejected", not l_parser.parse ("<a/><b/>"))
			assert ("multiple roots error", l_parser.last_error.same_string ("multiple document elements"))
			assert ("non-whitespace outside root rejected", not l_parser.parse ("text<a/>"))
			assert ("outside root error", l_parser.last_error.same_string ("character data outside document element"))
		end

feature {NONE} -- Assertions

	assert (a_label: READABLE_STRING_8; a_condition: BOOLEAN)
			-- Record test failure without hiding later failures.
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
			-- Has any test failed?

end
