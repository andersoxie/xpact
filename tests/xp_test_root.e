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
			test_xml_declaration_callbacks
			test_attlist_declaration_callbacks
			test_attlist_default_attributes
			test_element_declaration_callbacks
			test_notation_declaration_callbacks
			test_malformed_doctype_diagnostics
			test_entity_declaration_callbacks
			test_predefined_and_numeric_entities
			test_internal_entity_declarations
			test_parameter_entity_declarations
			test_entity_markup_expansion
			test_async_internal_entities_are_rejected
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
			test_position_accounting
			test_handler_position_accounting
			test_garbage_collection_suspension
			test_native_eiffel_bridge_parser
			test_native_bridge_installer
			test_expat_api_manifest
			test_libexpat_adapter_files
			test_benchmark_publication_files
			test_ci_test_matrix_files
			test_native_export_layer_files
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
			l_default_text: STRING_8
			i: INTEGER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<root><!-- comment --><![CDATA[raw < text]]></root>")
			assert ("CDATA document accepted", l_ok)
			assert ("comment emitted", l_handler.events.i_th (2).same_string ("comment: comment "))
			assert ("CDATA start emitted", l_handler.events.i_th (3).same_string ("start-cdata"))
			assert ("CDATA text emitted", l_handler.events.i_th (4).same_string ("text:raw < text"))
			assert ("CDATA end emitted", l_handler.events.i_th (5).same_string ("end-cdata"))

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<?work now?><root />")
			assert ("processing instruction document accepted", l_ok)
			assert ("processing instruction emitted", l_handler.events.i_th (1).same_string ("pi:work:now"))

			create l_handler.make
			l_handler.enable_doctype_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc PUBLIC 'pubname' 'test.dtd' [<!ENTITY foo 'bar'>]><doc>&foo;</doc>")
			assert ("doctype document accepted", l_ok)
			assert ("doctype start emitted", l_handler.events.i_th (1).same_string ("start-doctype:doc:test.dtd:pubname:1"))
			assert ("doctype end emitted", l_handler.events.i_th (2).same_string ("end-doctype"))

			create l_handler.make
			l_handler.enable_default_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [%N<!ENTITY e SYSTEM 'http://example.org/e'>%N<!NOTATION n SYSTEM 'http://example.org/n'>%N<!ELEMENT doc EMPTY>%N<!ATTLIST doc a CDATA #IMPLIED>%N<?pi in dtd?>%N<!--comment in dtd-->%N]><doc/>")
			assert ("DTD default document accepted", l_ok)
			create l_default_text.make_empty
			from
				i := 1
			until
				i > l_handler.events.count
			loop
				if l_handler.events.i_th (i).count >= 8 and then l_handler.events.i_th (i).substring (1, 8).same_string ("default:") then
					l_default_text.append (l_handler.events.i_th (i).substring (9, l_handler.events.i_th (i).count))
				end
				i := i + 1
			end
			assert ("DTD default tokens emitted", l_default_text.same_string ("<!DOCTYPE doc [%N<!ENTITY e SYSTEM 'http://example.org/e'>%N<!NOTATION n SYSTEM 'http://example.org/n'>%N<!ELEMENT doc EMPTY>%N<!ATTLIST doc a CDATA #IMPLIED>%N<?pi in dtd?>%N<!--comment in dtd-->%N]><doc/>"))
		end

	test_xml_declaration_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_native: XP_NATIVE_PARSER
			l_status: INTEGER
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("XML declaration document accepted", l_parser.parse ("<?xml version='1.0' encoding='us-ascii' standalone='no'?>%N<doc/>"))
			assert ("XML declaration callback emitted", l_handler.events.i_th (1).same_string ("xml-decl:1.0:us-ascii:0"))
			assert ("XML declaration is not a PI", not l_handler.events.i_th (1).has_substring ("pi:"))

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("XML declaration without optional attributes accepted", l_parser.parse ("<?xml version='1.0'?>%N<doc/>"))
			assert ("XML declaration optional values reported", l_handler.events.i_th (1).same_string ("xml-decl:1.0::-1"))

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("misplaced XML declaration rejected", not l_parser.parse ("%N<?xml version='1.0'?>%N<doc/>"))
			assert ("misplaced XML declaration diagnostic", l_parser.last_error.same_string ("misplaced xml declaration"))

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("invalid XML declaration rejected", not l_parser.parse ("<?xml version='1.0' standalone?>%N<doc/>"))
			assert ("invalid XML declaration diagnostic", l_parser.last_error.same_string ("invalid xml declaration"))

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("missing XML declaration attribute name rejected", not l_parser.parse ("<?xml ='1.0'?>%N<doc/>"))
			assert ("missing XML declaration attribute diagnostic", l_parser.last_error.same_string ("invalid xml declaration"))

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("unknown XML declaration attribute rejected", not l_parser.parse ("<?xml version='1.0' extra='x'?>%N<doc/>"))
			assert ("unknown XML declaration attribute diagnostic", l_parser.last_error.same_string ("invalid xml declaration"))

			create l_native.make
			l_status := l_native.parse ("<?xml version='1.0' encoding='us-ascii' standalone='yes'?>%N<doc/>", True)
			assert ("native Eiffel parser accepts XML declaration", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser emits XML declaration", l_native.handler.xml_decl_count = 1)
			assert ("native Eiffel XML declaration event recorded", l_native.handler.events.i_th (1).same_string ("xml-decl"))

			assert ("native Eiffel parser resets for XML declaration error", l_native.reset)
			l_status := l_native.parse ("%N<?xml version='1.0'?>%N<doc/>", True)
			assert ("native Eiffel parser rejects misplaced XML declaration", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser maps misplaced XML declaration", l_native.last_error_code = l_native.Xml_error_misplaced_xml_pi)

			assert ("native Eiffel parser resets for malformed XML declaration", l_native.reset)
			l_status := l_native.parse ("<?xml version='1.0' encoding='us-ascii' standalone?>%N<doc/>", True)
			assert ("native Eiffel parser rejects invalid XML declaration", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser maps invalid XML declaration", l_native.last_error_code = l_native.Xml_error_xml_decl)
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

	test_attlist_declaration_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			l_handler.enable_attlist_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!ELEMENT doc EMPTY><!ATTLIST doc a ( one | two | three ) #REQUIRED>]><doc a='two'/>")
			assert ("attlist enumeration document accepted", l_ok)
			if l_ok then
				assert ("attlist enumeration callback", l_handler.events.i_th (1).same_string ("attlist:doc:a:(one|two|three)::1"))
			else
				io.put_string ("attlist enumeration error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end

			create l_handler.make
			l_handler.enable_attlist_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!ELEMENT doc EMPTY><!ATTLIST doc a NOTATION (foo) 'bar'>]><doc/>")
			assert ("attlist notation document accepted", l_ok)
			if l_ok then
				assert ("attlist notation callback", l_handler.events.i_th (1).same_string ("attlist:doc:a:NOTATION(foo):bar:0"))
			else
				io.put_string ("attlist notation error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_attlist_default_attributes
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!ATTLIST doc a CDATA 'expected'><!ATTLIST doc a CDATA 'ignored'>]><doc/>")
			assert ("attlist default document accepted", l_ok)
			if l_ok then
				assert ("attlist default added", l_handler.last_attribute_value.same_string ("expected"))
				assert ("attlist default counted", l_handler.events.i_th (1).same_string ("start:doc:1"))
			else
				io.put_string ("attlist default error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!ATTLIST doc a CDATA 'default'>]><doc a='explicit'/>")
			assert ("explicit attribute with default accepted", l_ok)
			if l_ok then
				assert ("explicit attribute wins", l_handler.last_attribute_value.same_string ("explicit"))
				assert ("default not duplicated", l_handler.events.i_th (1).same_string ("start:doc:1"))
			else
				io.put_string ("attlist explicit error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE e:element [%N  <!ATTLIST e:element%N    xmlns:e CDATA 'http://example.org/'>%N      ]>%N<e:element/>")
			assert ("namespace-like default attribute without namespaces accepted", l_ok)
			if l_ok then
				assert ("namespace-like default attribute counted", l_handler.events.i_th (1).same_string ("start:e:element:1"))
			else
				io.put_string ("namespace-like default attribute error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_element_declaration_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			l_handler.enable_element_decl_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!ELEMENT doc (chapter)><!ELEMENT chapter (#PCDATA)>]><doc><chapter>Wombats are go</chapter></doc>")
			assert ("element declaration document accepted", l_ok)
			if l_ok then
				assert ("element declaration callback for doc", l_handler.events.i_th (1).same_string ("element-decl:doc:6:0:1"))
				assert ("element declaration callback for chapter", l_handler.events.i_th (2).same_string ("element-decl:chapter:3:0:0"))
			else
				io.put_string ("element declaration error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end

			create l_handler.make
			l_handler.enable_element_decl_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE foo [<!ELEMENT junk ((bar|foo|xyz+), zebra*)>]><foo/>")
			assert ("nested element declaration document accepted", l_ok)
			if l_ok then
				assert ("nested element declaration callback", l_handler.events.i_th (1).same_string ("element-decl:junk:6:0:2"))
			else
				io.put_string ("nested element declaration error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

	test_notation_declaration_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			l_handler.enable_notation_decl_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!NOTATION note PUBLIC 'pub'><!NOTATION img SYSTEM 'image/gif'><!ELEMENT doc EMPTY>]><doc/>")
			assert ("notation declaration document accepted", l_ok)
			if l_ok then
				assert ("public notation callback", l_handler.events.i_th (1).same_string ("notation:note::pub"))
				assert ("system notation callback", l_handler.events.i_th (2).same_string ("notation:img:image/gif:"))
			else
				io.put_string ("notation declaration error: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [<!NOTATION n SYSTEM>]><doc/>")
			assert ("bad notation rejected", not l_ok)
			if not l_ok then
				assert ("bad notation syntax error", l_parser.last_error.same_string ("missing notation system identifier"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<?xml version='1.0' encoding='utf-8'?>%N<!DOCTYPE doc PUBLIC '{BadName}' 'test'>%N<doc></doc>")
			assert ("bad public doctype rejected", not l_ok)
			if not l_ok then
				assert ("bad public doctype error", l_parser.last_error.same_string ("invalid public identifier"))
			end
		end

	test_malformed_doctype_diagnostics
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE 1+ [ <!ENTITY foo 'bar'> ]>%N<1+>&foo;</1+>")
			assert ("doctype plus rejected", not l_ok)
			if not l_ok then
				assert ("doctype plus invalid token", l_parser.last_error.same_string ("invalid doctype name"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE 1* [ <!ENTITY foo 'bar'> ]>%N<1*>&foo;</1*>")
			assert ("doctype star rejected", not l_ok)
			if not l_ok then
				assert ("doctype star invalid token", l_parser.last_error.same_string ("invalid doctype name"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE 1? [ <!ENTITY foo 'bar'> ]>%N<1?>&foo;</1?>")
			assert ("doctype query rejected", not l_ok)
			if not l_ok then
				assert ("doctype query invalid token", l_parser.last_error.same_string ("invalid doctype name"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc></doc>")
			assert ("short doctype rejected", not l_ok)
			if not l_ok then
				assert ("short doctype unexpected end tag", l_parser.last_error.same_string ("unexpected end tag"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc PUBLIC></doc>")
			assert ("doctype missing public id rejected", not l_ok)
			if not l_ok then
				assert ("doctype missing public id syntax", l_parser.last_error.same_string ("missing external public identifier"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc SYSTEM></doc>")
			assert ("doctype missing system id rejected", not l_ok)
			if not l_ok then
				assert ("doctype missing system id syntax", l_parser.last_error.same_string ("missing external system identifier"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc PUBLIC 'foo' 'bar' 'baz'></doc>")
			assert ("long doctype rejected", not l_ok)
			if not l_ok then
				assert ("long doctype syntax", l_parser.last_error.same_string ("unexpected doctype declaration content"))
			end

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE doc [ raw ]><doc/>")
			assert ("raw dtd content rejected", not l_ok)
			if not l_ok then
				assert ("raw dtd content syntax", l_parser.last_error.same_string ("unexpected DTD content"))
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

	test_entity_declaration_callbacks
		local
			l_handler: XP_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			l_handler.enable_entity_decl_events
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root [<!ENTITY e1 'v1'><!ENTITY e2 SYSTEM 'v2'><!NOTATION n SYSTEM 'n'><!ENTITY img SYSTEM 'image.gif' NDATA n>]><root/>")
			assert ("entity declaration document accepted", l_ok)
			if l_ok then
				assert ("internal entity declaration event", l_handler.events.i_th (1).same_string ("entity:e1:0:v1:"))
				assert ("external entity declaration event", l_handler.events.i_th (2).same_string ("entity:e2:0:(null):v2"))
				assert ("unparsed entity declaration event", l_handler.events.i_th (4).same_string ("unparsed:img:image.gif:n"))
			else
				io.put_string ("entity declaration error: ")
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

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE t0 [%N   <!ENTITY a '<t1></t1>'>%N   <!ENTITY b '<t2>two</t2>'>%N   <!ENTITY c '<t3>three<t4>four</t4>three</t3>'>%N   <!ENTITY d '<t5>&b;</t5>'>%N]>%N<t0>&a;&b;&c;&d;</t0>%N")
			assert ("synchronous nested entity markup accepted", l_ok)
			if l_ok then
				assert ("sync entity root start", l_handler.events.i_th (1).same_string ("start:t0:0"))
				assert ("sync entity nested t4 text", l_handler.events.i_th (10).same_string ("text:four"))
				assert ("sync entity final end", l_handler.events.i_th (l_handler.events.count).same_string ("end:t0"))
			else
				io.put_string ("sync entity error: ")
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

	test_async_internal_entities_are_rejected
		do
			assert_async_entity_rejected (
				"opened by one entity and closed by another",
				"<!DOCTYPE t0 [%N   <!ENTITY open '<t1>'>%N   <!ENTITY close '</t1>'>%N]>%N<t0>&open;&close;</t0>%N",
				5,
				4
			)
			assert_async_entity_rejected (
				"opened by tag and closed by entity",
				"<!DOCTYPE t0 [%N  <!ENTITY g0 ''>%N  <!ENTITY g1 '&g0;</t1>'>%N]>%N<t0><t1>&g1;</t0>%N",
				5,
				8
			)
			assert_async_entity_rejected (
				"root opened by tag and closed by entity",
				"<!DOCTYPE t0 [%N  <!ENTITY g0 ''>%N  <!ENTITY g1 '&g0;</t0>'>%N]>%N<t0>&g1;%N",
				5,
				4
			)
			assert_async_entity_rejected (
				"opened by entity and closed by tag",
				"<!DOCTYPE t0 [%N  <!ENTITY g0 ''>%N  <!ENTITY g1 '<t1>&g0;'>%N]>%N<t0>&g1;</t1></t0>%N",
				5,
				4
			)
			assert_async_entity_rejected (
				"closed by entity then opened by entity",
				"<!DOCTYPE t0 [%N  <!ENTITY open '<t1>'>%N  <!ENTITY close '</t1>'>%N]>%N<t0><t1>&close;&open;</t1></t0>%N",
				5,
				8
			)
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

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<!DOCTYPE root SYSTEM %"mem://subset%"><root>&possibly_external;</root>")
			assert ("undefined entity with unread external subset is skipped", l_ok)

			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<?xml version='1.0' standalone='yes'?>%N<!DOCTYPE root SYSTEM %"mem://subset%"><root>&possibly_external;</root>")
			assert ("standalone document rejects undefined external-subset entity", not l_ok)
			assert ("standalone undefined entity diagnostic", l_parser.last_error.same_string ("undefined entity"))
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

	test_position_accounting
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_error_text: STRING_8
		do
			create l_handler.make
			create l_parser.make (l_handler)
			assert ("position starts at line one", l_parser.current_line_number = 1)
			assert ("position starts at column zero", l_parser.current_column_number = 0)
			assert ("byte index starts before input", l_parser.current_byte_index = -1)
			assert ("byte count starts at zero", l_parser.current_byte_count = 0)

			assert ("line document parses", l_parser.parse ("<tag>%N%N%N</tag>"))
			assert ("line after parse matches Expat", l_parser.current_line_number = 4)
			assert ("byte count after parse is zero", l_parser.current_byte_count = 0)

			assert ("column document parses", l_parser.parse ("<tag></tag>"))
			assert ("column after parse matches Expat", l_parser.current_column_number = 11)
			assert ("byte index after parse is end", l_parser.current_byte_index = 11)
			assert ("byte count after second parse is zero", l_parser.current_byte_count = 0)

			l_error_text := "<a>%N  <b>%N  </a>"
			assert ("mismatch document rejected for position", not l_parser.parse (l_error_text))
			assert ("line after error matches Expat", l_parser.current_line_number = 3)
			assert ("column after error matches Expat", l_parser.current_column_number = 4)
			assert ("byte index after error matches Expat", l_parser.current_byte_index = 14)
			assert ("byte count after error is zero", l_parser.current_byte_count = 0)
		end

	test_handler_position_accounting
		local
			l_handler: XP_POSITION_COLLECTING_HANDLER
			l_parser: XP_PARSER
			l_input: STRING_8
			l_reference_input: STRING_8
			l_reference_index: INTEGER
			l_expected_event: STRING_8
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_handler.set_parser (l_parser)
			l_input := "<a>%N  <b>%R%N    <c/>%R  </b>%N  <d>%N    <f/>%N  </d>%N</a>"
			assert ("positioned handler document parses", l_parser.parse (l_input))
			assert ("start a handler position", l_handler.events.i_th (1).same_string ("start:a:1:0:0:0"))
			assert ("start b handler line and column", l_handler.events.i_th (2).has_substring (":2:2:"))
			assert ("empty c end handler line and column", l_handler.events.i_th (4).has_substring (":3:8:"))
			assert ("end b handler line and column", l_handler.events.i_th (5).has_substring (":4:2:"))
			assert ("end a handler line and column", l_handler.events.i_th (10).has_substring (":8:0:"))

			create l_handler.make
			create l_parser.make (l_handler)
			l_handler.set_parser (l_parser)
			assert ("byte handler document parses", l_parser.parse ("<e>Hello</e>"))
			assert ("text byte info inside handler", l_handler.events.i_th (2).same_string ("text:Hello:1:3:3:5"))

			create l_handler.make
			create l_parser.make (l_handler)
			l_handler.set_parser (l_parser)
			l_reference_input := "<!DOCTYPE day [%N  <!ENTITY draft.day '10'>%N]>%N<day>&draft.day;</day>%N"
			l_reference_index := l_reference_input.substring_index ("&draft.day;", 1) - 1
			create l_expected_event.make_from_string ("text:10:4:5:")
			l_expected_event.append_integer (l_reference_index)
			l_expected_event.append (":11")
			assert ("entity reference context document parses", l_parser.parse (l_reference_input))
			assert ("entity reference text byte info inside handler", l_handler.events.i_th (2).same_string (l_expected_event))
		end

	test_garbage_collection_suspension
		local
			l_memory: MEMORY
			l_original_collecting: BOOLEAN
			l_section: XP_GC_CRITICAL_SECTION
			l_seen_collecting: CELL [BOOLEAN]
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_native: XP_NATIVE_PARSER
			l_status: INTEGER
		do
			create l_memory
			l_original_collecting := l_memory.collecting
			l_memory.collection_on
			create l_section.make
			create l_seen_collecting.put (True)
			l_section.execute (agent record_garbage_collection_state (l_seen_collecting))
			assert ("GC disabled inside critical section", not l_seen_collecting.item)
			assert ("GC restored after critical section", l_memory.collecting)

			create l_handler.make
			create l_parser.make (l_handler)
			assert ("GC-suspended parser accepts document", l_parser.parse_without_garbage_collection ("<root/>"))
			assert ("GC restored after parser critical section", l_memory.collecting)

			l_memory.collection_off
			assert ("GC-suspended parser preserves disabled state", l_parser.parse_without_garbage_collection ("<root/>") and then not l_memory.collecting)

			l_memory.collection_on
			create l_native.make
			l_native.set_suspend_gc_during_parse (True)
			l_status := l_native.parse ("<root/>", True)
			assert ("native GC-suspended parser accepts document", l_status = l_native.Xml_status_ok)
			assert ("GC restored after native critical section", l_memory.collecting)

			if l_original_collecting then
				l_memory.collection_on
			else
				l_memory.collection_off
			end
		end

	test_native_eiffel_bridge_parser
		local
			l_attributes: XP_ATTRIBUTES
			l_native: XP_NATIVE_PARSER
			l_status: INTEGER
			l_hash_entropy: C_STRING
			l_utf8_encoding: C_STRING
			l_bad_encoding: C_STRING
			l_external_context: C_STRING
		do
			create l_attributes.make
			l_attributes.put ("first", "1")
			l_attributes.put ("second", "2")
			assert ("attribute insertion order first", l_attributes.i_th_name (1).same_string ("first"))
			assert ("attribute insertion order second", l_attributes.i_th_name (2).same_string ("second"))
			assert ("attribute insertion value first", l_attributes.i_th_value (1).same_string ("1"))
			assert ("attribute insertion value second", l_attributes.i_th_value (2).same_string ("2"))

			create l_native.make
			create l_utf8_encoding.make ("utf-8")
			create l_bad_encoding.make ("unknown-encoding")
			assert ("native Eiffel parser accepts null explicit encoding", l_native.set_encoding (default_pointer) = l_native.Xml_status_ok)
			assert ("native Eiffel parser accepts UTF-8 explicit encoding", l_native.set_encoding (l_utf8_encoding.item) = l_native.Xml_status_ok)
			l_status := l_native.parse ("<doc>Hello ", False)
			assert ("native Eiffel parser accepts non-final explicit encoding parse", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser rejects mid-parse encoding change", l_native.set_encoding (l_bad_encoding.item) = l_native.Xml_status_error)
			l_status := l_native.parse (" World</doc>", True)
			assert ("native Eiffel parser accepts final explicit encoding parse", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser accepts encoding unset after parse", l_native.set_encoding (default_pointer) = l_native.Xml_status_ok)
			assert ("native Eiffel parser resets before bad explicit encoding", l_native.reset)
			assert ("native Eiffel parser accepts bad explicit encoding before parse", l_native.set_encoding (l_bad_encoding.item) = l_native.Xml_status_ok)
			l_status := l_native.parse ("<doc>Hi</doc>", True)
			assert ("native Eiffel parser rejects bad explicit encoding during parse", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser maps bad explicit encoding", l_native.last_error_code = l_native.Xml_error_unknown_encoding)
			assert ("native Eiffel parser resets after bad explicit encoding", l_native.reset)
			create l_hash_entropy.make ("0123456789abcdef")
			assert ("native Eiffel parser accepts hash salt before parse", l_native.set_hash_salt (305419896))
			assert ("native Eiffel parser records hash salt", l_native.has_hash_salt and then l_native.hash_salt = 305419896)
			assert ("native Eiffel parser accepts 16-byte hash salt before parse", l_native.set_hash_salt_16_bytes (l_hash_entropy.item))
			assert ("native Eiffel parser records 16-byte hash salt", l_native.has_hash_salt_16_bytes and then l_native.hash_salt_16_bytes.same_string ("0123456789abcdef"))
			assert ("native Eiffel parser clears legacy salt after 16-byte salt", not l_native.has_hash_salt)
			l_status := l_native.parse ("", False)
			assert ("native Eiffel parser accepts empty non-final parse", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser rejects late hash salt", not l_native.set_hash_salt (1))
			assert ("native Eiffel parser rejects late 16-byte hash salt", not l_native.set_hash_salt_16_bytes (l_hash_entropy.item))
			assert ("native Eiffel parser reset clears hash salt", l_native.reset and then not l_native.has_hash_salt and then not l_native.has_hash_salt_16_bytes)
			l_status := l_native.parse ("<root><child a=%"1%">text</child></root>", True)
			assert ("native Eiffel parser accepts document", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser reports no error", l_native.last_error_code = l_native.Xml_error_none)
			assert ("native Eiffel parser reports end line", l_native.current_line_number = 1)
			assert ("native Eiffel parser reports end column", l_native.current_column_number = 38)
			assert ("native Eiffel parser reports end byte index", l_native.current_byte_index = 38)
			assert ("native Eiffel parser reports zero byte count", l_native.current_byte_count = 0)
			assert ("native Eiffel parser saw start callbacks", l_native.handler.start_element_count = 2)
			assert ("native Eiffel parser saw text callback", l_native.handler.character_data_count = 1)
			assert ("native Eiffel parser saw end callbacks", l_native.handler.end_element_count = 2)
			assert ("native Eiffel event log starts at root", l_native.handler.events.i_th (1).same_string ("start:root:0"))
			assert ("native Eiffel event log has text", l_native.handler.events.i_th (3).same_string ("text:text"))

			assert ("native Eiffel parser resets", l_native.reset)
			assert ("native Eiffel reset clears events", l_native.handler.events.count = 0)
			l_status := l_native.parse ("<root><child></root>", True)
			assert ("native Eiffel parser rejects mismatch", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser maps mismatch", l_native.last_error_code = l_native.Xml_error_tag_mismatch)
			assert ("native Eiffel parser reports mismatch line", l_native.current_line_number = 1)
			assert ("native Eiffel parser reports mismatch column", l_native.current_column_number = 15)
			assert ("native Eiffel parser reports mismatch byte index", l_native.current_byte_index = 15)

			assert ("native Eiffel parser resets for chunked input", l_native.reset)
			l_status := l_native.parse ("<root", False)
			assert ("native Eiffel parser accepts non-final chunk", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser keeps chunked parse open", l_native.parsing_status = l_native.Xml_parsing)
			assert ("native Eiffel parser reports no chunk error", l_native.last_error_code = l_native.Xml_error_none)
			l_status := l_native.parse (" />", True)
			assert ("native Eiffel parser accepts final chunk", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser finishes chunked parse", l_native.parsing_status = l_native.Xml_finished)
			assert ("native Eiffel parser emits chunked start", l_native.handler.start_element_count = 1)

			assert ("native Eiffel parser resets for extended callbacks", l_native.reset)
			l_status := l_native.parse ("<?work now?><root><!-- note --><![CDATA[payload]]></root>", True)
			assert ("native Eiffel parser accepts callback document", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser emits PI event", l_native.handler.processing_instruction_count = 1)
			assert ("native Eiffel parser emits comment event", l_native.handler.comment_count = 1)
			assert ("native Eiffel parser emits CDATA start event", l_native.handler.start_cdata_section_count = 1)
			assert ("native Eiffel parser emits CDATA end event", l_native.handler.end_cdata_section_count = 1)

			assert ("native Eiffel parser resets for doctype callbacks", l_native.reset)
			l_status := l_native.parse ("<!DOCTYPE doc PUBLIC 'pubname' 'test.dtd' [<!ENTITY foo 'bar'>]><doc>&foo;</doc>", True)
			assert ("native Eiffel parser accepts doctype callback document", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser emits doctype start event", l_native.handler.start_doctype_decl_count = 1)
			assert ("native Eiffel parser emits doctype end event", l_native.handler.end_doctype_decl_count = 1)

			assert ("native Eiffel parser resets for short doctype diagnostic", l_native.reset)
			l_status := l_native.parse ("<!DOCTYPE doc></doc>", True)
			assert ("native Eiffel parser rejects document-level end tag", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser maps document-level end tag", l_native.last_error_code = l_native.Xml_error_invalid_token)

			assert ("native Eiffel parser resets for unloaded external general entity", l_native.reset)
			l_status := l_native.parse ("<!DOCTYPE doc [<!ENTITY en SYSTEM %"http://example.org/dummy.ent%">]><doc>&en;</doc>", True)
			assert ("native Eiffel parser skips unloaded external general entity", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser reports skipped entity", l_native.handler.skipped_entity_count = 1)
			assert ("native Eiffel parser names skipped entity", across l_native.handler.events as l_event some l_event.item.same_string ("skipped:en:0") end)

			assert ("native Eiffel parser resets for external parsed entity", l_native.reset)
			assert ("native Eiffel parser marks external parsed entity", l_native.set_external_entity_context (default_pointer))
			l_status := l_native.parse ("external <![CDATA[cdata]]><leaf/> tail", True)
			assert ("native Eiffel parser accepts external parsed entity fragment", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel external fragment emits text", l_native.handler.character_data_count = 3)
			assert ("native Eiffel external fragment emits CDATA start", l_native.handler.start_cdata_section_count = 1)
			assert ("native Eiffel external fragment emits CDATA end", l_native.handler.end_cdata_section_count = 1)
			assert ("native Eiffel external fragment emits element", l_native.handler.start_element_count = 1 and then l_native.handler.end_element_count = 1)
			assert ("native Eiffel external fragment first text", l_native.handler.events.i_th (1).same_string ("text:external "))
			assert ("native Eiffel external fragment CDATA text", l_native.handler.events.i_th (3).same_string ("text:cdata"))
			assert ("native Eiffel external fragment trailing text", l_native.handler.events.i_th (7).same_string ("text: tail"))

			assert ("native Eiffel parser resets for external DTD subset", l_native.reset)
			create l_external_context.make ("external-subset")
			assert ("native Eiffel parser records external entity context", l_native.set_external_entity_context (l_external_context.item))
			l_status := l_native.parse ("<!-- external subset -->%N<!ELEMENT doc (#PCDATA)*>", True)
			assert ("native Eiffel parser accepts external DTD subset fragment", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel external DTD subset emits comment", l_native.handler.comment_count = 1)
			assert ("native Eiffel external DTD subset emits element declaration", l_native.handler.element_decl_count = 1)
			assert ("native Eiffel external context stored", attached l_native.external_entity_context as l_context and then l_context.same_string ("external-subset"))
			assert ("native Eiffel parser resets after external fragments", l_native.reset and then not l_native.is_external_entity_parser)
			assert ("native Eiffel parser rejects invalid parameter entity mode", not l_native.set_param_entity_parsing (99))
			assert ("native Eiffel parser accepts parameter entity parsing", l_native.set_param_entity_parsing (l_native.Xml_param_entity_parsing_always))
			assert ("native Eiffel parser broadens external entity policy", l_native.parser.external_entity_policy = {XP_EXTERNAL_ENTITY_POLICY}.All_external_entities)
		end

	test_native_bridge_installer
		local
			l_installer: XP_NATIVE_BRIDGE_INSTALLER
			l_handle: POINTER
			l_input: C_STRING
			l_buffer_input: C_STRING
			l_status_buffer: MANAGED_POINTER
			l_buffer: POINTER
			l_status: INTEGER
			l_error_input: C_STRING
			l_chunk_start: C_STRING
			l_chunk_end: C_STRING
			l_hash_entropy: C_STRING
			l_utf8_encoding: C_STRING
			l_bad_encoding: C_STRING
			l_external_context: C_STRING
		do
			create l_installer.make
			l_handle := l_installer.parser_create (default_pointer, default_pointer, default_pointer)
			assert ("native bridge installer returns parser handle", l_handle /= default_pointer)
			assert ("native bridge installer tracks parser", l_installer.active_parser_count = 1)
			assert ("native bridge installer resolves handle", attached l_installer.parser_for (l_handle))

			create l_utf8_encoding.make ("utf-8")
			create l_bad_encoding.make ("unknown-encoding")
			assert ("native bridge installer accepts null explicit encoding", l_installer.set_encoding (l_handle, default_pointer) = l_installer.Xml_status_ok)
			assert ("native bridge installer accepts UTF-8 explicit encoding", l_installer.set_encoding (l_handle, l_utf8_encoding.item) = l_installer.Xml_status_ok)
			create l_chunk_start.make ("<doc>Hello ")
			create l_chunk_end.make (" World</doc>")
			l_status := l_installer.parse (l_handle, l_chunk_start.item, l_chunk_start.count, False)
			assert ("native bridge installer accepts explicit encoding non-final parse", l_status = l_installer.Xml_status_ok)
			assert ("native bridge installer rejects mid-parse encoding change", l_installer.set_encoding (l_handle, l_bad_encoding.item) = l_installer.Xml_status_error)
			l_status := l_installer.parse (l_handle, l_chunk_end.item, l_chunk_end.count, True)
			assert ("native bridge installer accepts explicit encoding final parse", l_status = l_installer.Xml_status_ok)
			assert ("native bridge installer accepts encoding unset after parse", l_installer.set_encoding (l_handle, default_pointer) = l_installer.Xml_status_ok)
			assert ("native bridge installer resets after explicit encoding parse", l_installer.parser_reset (l_handle, default_pointer))
			assert ("native bridge installer accepts bad explicit encoding", l_installer.set_encoding (l_handle, l_bad_encoding.item) = l_installer.Xml_status_ok)
			create l_error_input.make ("<doc>Hi</doc>")
			l_status := l_installer.parse (l_handle, l_error_input.item, l_error_input.count, True)
			assert ("native bridge installer rejects bad explicit encoding during parse", l_status = l_installer.Xml_status_error)
			assert ("native bridge installer maps bad explicit encoding", l_installer.get_error_code (l_handle) = 18)
			assert ("native bridge installer resets after bad explicit encoding", l_installer.parser_reset (l_handle, default_pointer))

			create l_external_context.make ("external-subset")
			assert ("native bridge installer marks external parsed entity", l_installer.set_external_entity_context (l_handle, default_pointer))
			create l_input.make ("external <![CDATA[cdata]]><leaf/> tail")
			l_status := l_installer.parse (l_handle, l_input.item, l_input.count, True)
			assert ("native bridge installer accepts external parsed entity fragment", l_status = l_installer.Xml_status_ok)
			if attached l_installer.parser_for (l_handle) as l_external_parser then
				assert ("native bridge installer external fragment emits text", l_external_parser.handler.character_data_count = 3)
				assert ("native bridge installer external fragment emits CDATA", l_external_parser.handler.start_cdata_section_count = 1 and then l_external_parser.handler.end_cdata_section_count = 1)
				assert ("native bridge installer external fragment emits element", l_external_parser.handler.start_element_count = 1 and then l_external_parser.handler.end_element_count = 1)
			end
			assert ("native bridge installer resets before external DTD subset", l_installer.parser_reset (l_handle, default_pointer))
			assert ("native bridge installer records external context", l_installer.set_external_entity_context (l_handle, l_external_context.item))
			create l_input.make ("<!-- external subset -->%N<!ELEMENT doc (#PCDATA)*>")
			l_status := l_installer.parse (l_handle, l_input.item, l_input.count, True)
			assert ("native bridge installer accepts external DTD subset", l_status = l_installer.Xml_status_ok)
			if attached l_installer.parser_for (l_handle) as l_subset_parser then
				assert ("native bridge installer stores external context", attached l_subset_parser.external_entity_context as l_context and then l_context.same_string ("external-subset"))
				assert ("native bridge installer external DTD subset emits comment", l_subset_parser.handler.comment_count = 1)
				assert ("native bridge installer external DTD subset emits element decl", l_subset_parser.handler.element_decl_count = 1)
			end
			assert ("native bridge installer resets after external DTD subset", l_installer.parser_reset (l_handle, default_pointer))
			assert ("native bridge installer rejects invalid parameter entity mode", not l_installer.set_param_entity_parsing (l_handle, 99))
			assert ("native bridge installer accepts parameter entity parsing", l_installer.set_param_entity_parsing (l_handle, 2))

			create l_hash_entropy.make ("0123456789abcdef")
			assert ("native bridge installer sets hash salt", l_installer.set_hash_salt (l_handle, 305419896))
			assert ("native bridge installer sets 16-byte hash salt", l_installer.set_hash_salt_16_bytes (l_handle, l_hash_entropy.item))
			if attached l_installer.parser_for (l_handle) as l_hash_parser then
				assert ("native bridge installer stores 16-byte hash salt", l_hash_parser.has_hash_salt_16_bytes and then l_hash_parser.hash_salt_16_bytes.same_string ("0123456789abcdef"))
			end

			create l_input.make ("<root><child>text</child></root>")
			l_installer.set_user_data (l_handle, l_input.item)
			l_installer.set_element_handler (l_handle, default_pointer, default_pointer)
			l_installer.set_character_data_handler (l_handle, default_pointer)
			l_status := l_installer.parse (l_handle, l_input.item, l_input.count, True)
			assert ("native bridge installer parse succeeds", l_status = 1)
			assert ("native bridge installer rejects late hash salt", not l_installer.set_hash_salt (l_handle, 1))
			assert ("native bridge installer reports no error", l_installer.get_error_code (l_handle) = 0)
			if attached l_installer.parser_for (l_handle) as l_native then
				assert ("native bridge installer forwards user data", l_native.handler.user_data = l_input.item)
				assert ("native bridge installer emitted start events", l_native.handler.start_element_count = 2)
				assert ("native bridge installer emitted text event", l_native.handler.character_data_count = 1)
				assert ("native bridge installer emitted end events", l_native.handler.end_element_count = 2)
			end

			create l_status_buffer.make (8)
			l_installer.get_parsing_status (l_handle, l_status_buffer.item)
			assert ("native bridge installer reports end line", l_installer.get_current_line_number (l_handle) = 1)
			assert ("native bridge installer reports end column", l_installer.get_current_column_number (l_handle) = l_input.count)
			assert ("native bridge installer reports end byte index", l_installer.get_current_byte_index (l_handle) = l_input.count)
			assert ("native bridge installer reports zero byte count", l_installer.get_current_byte_count (l_handle) = 0)

			create l_error_input.make ("<a>%N  <b>%N  </a>")
			l_status := l_installer.parse (l_handle, l_error_input.item, l_error_input.count, True)
			assert ("native bridge installer parse rejects mismatch", l_status = l_installer.Xml_status_error)
			assert ("native bridge installer reports mismatch error", l_installer.get_error_code (l_handle) = 7)
			assert ("native bridge installer reports error line", l_installer.get_current_line_number (l_handle) = 3)
			assert ("native bridge installer reports error column", l_installer.get_current_column_number (l_handle) = 4)
			assert ("native bridge installer reports error byte index", l_installer.get_current_byte_index (l_handle) = 14)
			assert ("native bridge installer reports error byte count", l_installer.get_current_byte_count (l_handle) = 0)

			assert ("native bridge installer resets parser", l_installer.parser_reset (l_handle, default_pointer))
			create l_chunk_start.make ("<root")
			create l_chunk_end.make (" />")
			l_status := l_installer.parse (l_handle, l_chunk_start.item, l_chunk_start.count, False)
			assert ("native bridge installer accepts non-final chunk", l_status = 1)
			assert ("native bridge installer has no chunk error", l_installer.get_error_code (l_handle) = 0)
			l_status := l_installer.parse (l_handle, l_chunk_end.item, l_chunk_end.count, True)
			assert ("native bridge installer accepts final chunk", l_status = 1)
			assert ("native bridge installer reports chunked byte index", l_installer.get_current_byte_index (l_handle) = l_chunk_start.count + l_chunk_end.count)

			assert ("native bridge installer resets before parse buffer", l_installer.parser_reset (l_handle, default_pointer))
			create l_buffer_input.make ("<root />")
			l_buffer := l_installer.get_buffer (l_handle, l_buffer_input.count)
			assert ("native bridge installer allocates parse buffer", l_buffer /= default_pointer)
			l_buffer.memory_copy (l_buffer_input.item, l_buffer_input.count)
			l_status := l_installer.parse_buffer (l_handle, l_buffer_input.count, True)
			assert ("native bridge installer parse buffer succeeds", l_status = 1)

			l_installer.parser_free (l_handle)
			assert ("native bridge installer releases parser", l_installer.active_parser_count = 0)
			assert ("native bridge installer drops handle", not attached l_installer.parser_for (l_handle))
			l_status := l_installer.parse (l_handle, l_input.item, l_input.count, True)
			assert ("native bridge installer rejects freed handle", l_status = l_installer.Xml_status_error)
		end

	test_expat_api_manifest
		local
			l_api: XP_EXPAT_API
			l_header: STRING_8
		do
			create l_api
			assert ("Expat 2.8.1 major version tracked", l_api.Xml_major_version = 2)
			assert ("Expat 2.8.1 minor version tracked", l_api.Xml_minor_version = 8)
			assert ("Expat 2.8.1 micro version tracked", l_api.Xml_micro_version = 1)
			assert ("suspended status tracked", l_api.Xml_status_suspended = 2)
			assert ("latest error enum tracked", l_api.Xml_error_not_started = 44)
			assert ("full public API manifest count", l_api.public_function_count = 77)
			assert ("core parser creation API tracked", l_api.has_public_function ("XML_ParserCreate"))
			assert ("namespace parser creation API tracked", l_api.has_public_function ("XML_ParserCreateNS"))
			assert ("external entity parser API tracked", l_api.has_public_function ("XML_ExternalEntityParserCreate"))
			assert ("user data macro API tracked", l_api.has_public_function ("XML_GetUserData"))
			assert ("hash salt 16-byte API tracked", l_api.has_public_function ("XML_SetHashSalt16Bytes"))
			assert ("allocation tracker API tracked", l_api.has_public_function ("XML_SetAllocTrackerMaximumAmplification"))
			assert ("reparse deferral API tracked", l_api.has_public_function ("XML_SetReparseDeferralEnabled"))
			l_header := file_text ("include\xpact.h")
			assert ("public header loaded", not l_header.is_empty)
			assert ("public header has version macro", l_header.has_substring ("#define XML_MINOR_VERSION 8"))
			assert ("public header has status suspended", l_header.has_substring ("XML_STATUS_SUSPENDED"))
			assert ("public header has external entity declaration", l_header.has_substring ("XML_SetExternalEntityRefHandler"))
			assert ("public header has parser buffer declaration", l_header.has_substring ("XML_ParseBuffer"))
			assert ("public header has reparse deferral declaration", l_header.has_substring ("XML_SetReparseDeferralEnabled"))
		end

	test_libexpat_adapter_files
		local
			l_script: STRING_8
			l_cmake: STRING_8
			l_shim: STRING_8
			l_config: STRING_8
			l_notes: STRING_8
			l_expected: STRING_8
			l_parity: STRING_8
		do
			l_script := file_text ("scripts\run_libexpat_adapter.ps1")
			assert ("libexpat adapter script present", not l_script.is_empty)
			assert ("adapter extracts upstream START_TEST names", l_script.has_substring ("START_TEST"))
			assert ("adapter writes test manifest", l_script.has_substring ("libexpat-runtests-manifest.tsv"))
			assert ("adapter expands expected failures", l_script.has_substring ("libexpat-expected-failures-expanded.tsv"))
			assert ("adapter expands parity rows", l_script.has_substring ("libexpat-parity-expanded.tsv"))
			assert ("adapter rejects suite-wide expected failure", l_script.has_substring ("Suite-wide expected-failure wildcard is not allowed"))
			assert ("adapter can run native suite", l_script.has_substring ("NativeSuite"))
			assert ("adapter fails stale expected failures", l_script.has_substring ("passed while expected failures remain"))
			assert ("adapter drives xpact file parser", l_script.has_substring ("--parse-file"))
			assert ("adapter knows Expat split test sources", l_script.has_substring ("basic_tests.c") and l_script.has_substring ("nsalloc_tests.c"))

			l_cmake := file_text ("adapters\libexpat\CMakeLists.txt")
			assert ("libexpat CMake adapter present", not l_cmake.is_empty)
			assert ("CMake adapter imports xpact native library", l_cmake.has_substring ("XPACT_LIBRARY"))
			assert ("CMake adapter builds upstream runtests", l_cmake.has_substring ("xpact_libexpat_runtests"))
			assert ("CMake adapter enables DTD and general entities", l_cmake.has_substring ("XML_DTD=1") and l_cmake.has_substring ("XML_GE=1"))

			l_shim := file_text ("adapters\libexpat\include\expat.h")
			assert ("libexpat expat.h shim present", l_shim.has_substring ("xpact.h"))
			l_config := file_text ("adapters\libexpat\include\expat_config.h")
			assert ("libexpat expat_config.h shim present", l_config.has_substring ("XML_CONTEXT_BYTES") and l_config.has_substring ("BYTEORDER"))
			l_notes := file_text ("adapters\libexpat\README.md")
			assert ("libexpat adapter docs present", l_notes.has_substring ("R_2_8_1") and l_notes.has_substring ("ctest"))
			l_expected := file_text ("adapters\libexpat\expected-failures.tsv")
			assert ("expected-failure list keeps allocator rows", l_expected.has_substring ("test_alloc_*") and l_expected.has_substring ("test_nsalloc_*"))
			assert ("expected-failure list dropped reparse heuristic rows", not l_expected.has_substring ("test_bypass_heuristic_when_close_to_bufsize") and not l_expected.has_substring ("test_varying_buffer_fills"))
			assert ("expected-failure list dropped accounting row", not l_expected.has_substring ("test_accounting_precision"))
			assert ("expected-failure list has no suite-wide wildcard", not l_expected.has_substring ("*%T*%T"))
			assert ("expected-failure list narrowed stop rows", not l_expected.has_substring ("test_abort*") and not l_expected.has_substring ("test_*suspend*") and not l_expected.has_substring ("test_*resume*"))
			l_parity := file_text ("adapters\libexpat\parity.tsv")
			assert ("parity list has green rows", l_parity.has_substring ("green%Tlocal%TWindows DLL XML_Parse smoke"))
			assert ("namespace parity is green", l_parity.has_substring ("green%Tns_tests.c%Ttest_*"))
			assert ("namespace allocation parity remains red", l_parity.has_substring ("red%Tnsalloc_tests.c%Ttest_nsalloc_*"))
			assert ("parity list has no blocked native suite row", not l_parity.has_substring ("blocked%Tupstream-native-suite"))
			assert ("libexpat parity docs present", file_text ("docs\libexpat-parity.md").has_substring ("suite-wide expected failure"))
		end

	test_benchmark_publication_files
		local
			l_script: STRING_8
			l_python: STRING_8
			l_table: STRING_8
		do
			l_script := file_text ("scripts\run_benchmarks.ps1")
			assert ("benchmark publication script present", not l_script.is_empty)
			assert ("benchmark script runs xpact benchmark", l_script.has_substring ("xpact_benchmarks.exe"))
			assert ("benchmark script supports finalized assertion build", l_script.has_substring ("FinalizedAssertions") and l_script.has_substring ("xpact_benchmarks_assertions"))
			assert ("benchmark script records assertion build row", l_script.has_substring ("xpact Eiffel finalized, assertions enabled"))
			assert ("benchmark ECF has assertion target", file_text ("benchmarks\xpact_benchmarks.ecf").has_substring ("<target name=%"xpact_benchmarks_assertions%""))
			assert ("benchmark script records pyexpat baseline", l_script.has_substring ("pyexpat") and l_script.has_substring ("libexpat_py_benchmark.py"))
			assert ("benchmark script can record WSL C baseline", l_script.has_substring ("libexpat_c_benchmark.c") and l_script.has_substring ("WSL2 gcc"))
			assert ("benchmark script can record xpact native C ABI", l_script.has_substring ("xpact_native_c_benchmark.c"))
			assert ("benchmark script can record Windows Eiffel-backed native DLL", l_script.has_substring ("build_native_eiffel.ps1") and l_script.has_substring ("Windows MSVC DLL"))
			assert ("benchmark script distinguishes bridge-only WSL path", l_script.has_substring ("XML_ERROR_NOT_STARTED") and l_script.has_substring ("build\native\libxpact.so"))
			assert ("benchmark script writes docs table", l_script.has_substring ("docs\benchmarks.md"))
			assert ("large XML benchmark script present", file_text ("scripts\run_large_xml_benchmarks.ps1").has_substring ("pre-decompressed XML"))
			l_script := file_text ("scripts\run_chunked_crc_harness.ps1")
			assert ("chunked CRC harness script present", not l_script.is_empty and l_script.has_substring ("chunked-crc-results.tsv"))
			assert ("chunked CRC harness can target xpact and libexpat", l_script.has_substring ("Xpact") and l_script.has_substring ("LibexpatWsl"))
			assert ("chunked CRC harness supports diagnostic mismatches", l_script.has_substring ("AllowMismatches"))
			l_script := file_text ("scripts\run_chunked_crc_corpus.ps1")
			assert ("chunked CRC corpus script present", l_script.has_substring ("plain-text.xml") and l_script.has_substring ("large-catalog.xml"))
			assert ("chunked CRC corpus drives harness", l_script.has_substring ("run_chunked_crc_harness.ps1") and l_script.has_substring ("XmlFile"))
			assert ("chunked CRC corpus has stress size knob", l_script.has_substring ("CatalogItems"))
			l_python := file_text ("benchmarks\libexpat_py_benchmark.py")
			assert ("libexpat Python benchmark present", l_python.has_substring ("xml.parsers") and l_python.has_substring ("EXPAT_VERSION"))
			assert ("libexpat Python benchmark accepts files", l_python.has_substring ("--file"))
			assert ("libexpat C benchmark present", file_text ("benchmarks\libexpat_c_benchmark.c").has_substring ("XML_ExpatVersion"))
			assert ("libexpat C benchmark accepts files", file_text ("benchmarks\libexpat_c_benchmark.c").has_substring ("--file"))
			assert ("xpact native C benchmark present", file_text ("benchmarks\xpact_native_c_benchmark.c").has_substring ("XML_ERROR_NOT_STARTED"))
			assert ("xpact native C benchmark accepts files", file_text ("benchmarks\xpact_native_c_benchmark.c").has_substring ("--file"))
			assert ("chunked CRC C harness present", file_text ("tests\native\xpact_chunked_crc.c").has_substring ("semantic_crc") and file_text ("tests\native\xpact_chunked_crc.c").has_substring ("XPACT_USE_SYSTEM_EXPAT"))
			l_table := file_text ("docs\benchmarks.md")
			assert ("published benchmark table present", l_table.has_substring ("| Benchmark | Engine | Version | Iterations |"))
			assert ("published benchmark includes finalized xpact row", l_table.has_substring ("xpact Eiffel finalized, assertions discarded"))
			assert ("published benchmark includes libexpat row", l_table.has_substring ("libexpat via CPython pyexpat"))
			assert ("published benchmark documents optional WSL C rows", l_table.has_substring ("When present, WSL2 C rows"))
			assert ("published benchmark includes Windows native C ABI rows", l_table.has_substring ("xpact native C ABI callbacks via Windows MSVC DLL"))
			assert ("large XML benchmark docs present", file_text ("docs\large-xml-benchmarks.md").has_substring ("pre-decompressed"))
			assert ("chunked CRC docs present", file_text ("docs\chunked-parse-crc.md").has_substring ("semantic_crc") and file_text ("docs\chunked-parse-crc.md").has_substring ("chunk size 31"))
		end

	test_ci_test_matrix_files
		local
			l_ecf: STRING_8
			l_script: STRING_8
			l_jenkins: STRING_8
			l_notes: STRING_8
		do
			l_ecf := file_text ("tests\xpact_tests.ecf")
			assert ("test ECF has assertion-off target", l_ecf.has_substring ("<target name=%"xpact_tests%"") and l_ecf.has_substring ("precondition=%"false%""))
			assert ("test ECF has assertion-on target", l_ecf.has_substring ("<target name=%"xpact_tests_assertions%"") and l_ecf.has_substring ("precondition=%"true%""))
			l_script := file_text ("scripts\run_eiffel_test_matrix.ps1")
			assert ("Eiffel test matrix script present", l_script.has_substring ("AssertionMode") and l_script.has_substring ("BuildMode"))
			assert ("Eiffel test matrix covers finalized builds", l_script.has_substring ("finish_freezing") and l_script.has_substring ("Finalized"))
			l_jenkins := file_text ("ci\Jenkinsfile.all-tests")
			assert ("all-tests Jenkinsfile present", l_jenkins.has_substring ("Eiffel Regression Matrix"))
			assert ("all-tests Jenkinsfile has assertion axis", l_jenkins.has_substring ("ASSERTIONS") and l_jenkins.has_substring ("Off") and l_jenkins.has_substring ("On"))
			assert ("all-tests Jenkinsfile has build axis", l_jenkins.has_substring ("BUILD_MODE") and l_jenkins.has_substring ("Workbench") and l_jenkins.has_substring ("Finalized"))
			assert ("all-tests Jenkinsfile builds assertion native tier", l_jenkins.has_substring ("-BuildTier Assertions") and l_jenkins.has_substring ("xpact_assertions.dll"))
			assert ("all-tests Jenkinsfile benchmarks assertion tier", l_jenkins.has_substring ("FinalizedAssertions"))
			assert ("all-tests Jenkinsfile runs native tests", l_jenkins.has_substring ("run_native_runtime_smoke.ps1") and l_jenkins.has_substring ("run_native_abi_tests.ps1"))
			assert ("all-tests Jenkinsfile runs chunked CRC corpus", l_jenkins.has_substring ("run_chunked_crc_corpus.ps1") and l_jenkins.has_substring ("build/chunked-crc/*.tsv"))
			l_notes := file_text ("docs\test-matrix.md")
			assert ("test matrix docs present", l_notes.has_substring ("Assertions off") and l_notes.has_substring ("Assertions on"))
			assert ("test matrix docs include chunked CRC corpus", l_notes.has_substring ("chunked CRC corpus gate"))
			l_notes := file_text ("docs\platform-builds.md")
			assert ("platform build docs present", l_notes.has_substring ("Linux") and l_notes.has_substring ("Eiffel .NET"))
		end

	test_native_export_layer_files
		local
			l_source: STRING_8
			l_bridge: STRING_8
			l_runtime: STRING_8
			l_runtime_header: STRING_8
			l_script: STRING_8
			l_notes: STRING_8
		do
			l_source := file_text ("native\xpact_native.c")
			assert ("native export source present", not l_source.is_empty)
			assert ("native layer exports parser create", l_source.has_substring ("XML_ParserCreate"))
			assert ("native layer exports parse", l_source.has_substring ("XML_Parse"))
			assert ("native layer exports handler setters", l_source.has_substring ("XML_SetElementHandler"))
			assert ("native layer reports Eiffel bridge version", l_source.has_substring ("expat_2.8.1-xpact-eiffel-bridge"))
			assert ("native layer does not decode XML entities in C", not l_source.has_substring ("xp_decode_entity"))
			assert ("native layer does not parse XML names in C", not l_source.has_substring ("xp_parse_name"))
			l_bridge := file_text ("native\xpact_eiffel_bridge.h")
			assert ("Eiffel bridge header present", l_bridge.has_substring ("XPACT_EiffelBridge"))
			assert ("Eiffel bridge can be registered", l_bridge.has_substring ("XPACT_SetEiffelBridge"))
			assert ("Eiffel native parser target present", file_text ("src\xp_native_parser.e").has_substring ("XP_PARSER"))
			assert ("Eiffel native callback adapter present", file_text ("src\xp_native_callback_handler.e").has_substring ("XML_StartElementHandler"))
			assert ("Eiffel native callback replay tracks growing text", file_text ("src\xp_native_callback_handler.e").has_substring ("delivered_character_data_lengths"))
			assert ("Eiffel native bridge installer present", file_text ("src\xp_native_bridge_installer.e").has_substring ("XP_NATIVE_PARSER"))
			assert ("Eiffel native bridge installer uses runtime object ids", file_text ("src\xp_native_bridge_installer.e").has_substring ("eif_object_id"))
			assert ("Eiffel native bridge export present", file_text ("src\xp_native_bridge_export.e").has_substring ("XPACT_RegisterEiffelRuntimeBridgePointers"))
			assert ("Eiffel native library root installs bridge", file_text ("src\xp_native_library_root.e").has_substring ("XP_NATIVE_BRIDGE_EXPORT"))
			l_runtime_header := file_text ("native\xpact_eiffel_runtime_bridge.h")
			assert ("Eiffel runtime bridge header present", l_runtime_header.has_substring ("XPACT_RegisterEiffelRuntimeBridge"))
			assert ("Eiffel runtime bridge pointer wrapper present", l_runtime_header.has_substring ("XPACT_RegisterEiffelRuntimeBridgePointers"))
			assert ("Eiffel runtime bridge header accepts installer object", l_runtime_header.has_substring ("EIF_OBJECT installer"))
			l_runtime := file_text ("native\xpact_eiffel_runtime_bridge.c")
			assert ("Eiffel runtime bridge source present", l_runtime.has_substring ("XPACT_RegisterEiffelRuntimeBridge"))
			assert ("Eiffel runtime bridge adopts installer", l_runtime.has_substring ("eif_adopt"))
			assert ("Eiffel runtime bridge accesses installer", l_runtime.has_substring ("eif_access"))
			assert ("Eiffel runtime bridge releases installer", l_runtime.has_substring ("eif_wean"))
			assert ("Eiffel runtime bridge registers bridge table", l_runtime.has_substring ("XPACT_SetEiffelBridge"))
			assert ("Eiffel runtime bridge does not decode XML entities in C", not l_runtime.has_substring ("xp_decode_entity"))
			assert ("Eiffel runtime bridge does not parse XML names in C", not l_runtime.has_substring ("xp_parse_name"))
			l_runtime := file_text ("native\xpact_eiffel_dllmain.c")
			assert ("Eiffel DLL entry initializes runtime", l_runtime.has_substring ("DllMain") and l_runtime.has_substring ("emain"))
			assert ("Eiffel DLL entry does not decode XML entities in C", not l_runtime.has_substring ("xp_decode_entity"))
			assert ("Eiffel DLL entry does not parse XML names in C", not l_runtime.has_substring ("xp_parse_name"))
			l_script := file_text ("scripts\build_native.ps1")
			assert ("native build script present", not l_script.is_empty)
			assert ("native build script builds Windows DLL", l_script.has_substring ("xpact.dll"))
			assert ("native build script builds WSL shared object", l_script.has_substring ("libxpact.so"))
			l_script := file_text ("scripts\build_native_eiffel.ps1")
			assert ("Eiffel native DLL build script present", l_script.has_substring ("xpact_native_library.ecf"))
			assert ("Eiffel native DLL build script builds xpact DLL", l_script.has_substring ("xpact.dll"))
			assert ("Eiffel native DLL build script supports assertion tier", l_script.has_substring ("BuildTier") and l_script.has_substring ("xpact_assertions.dll"))
			assert ("Eiffel native DLL build script runs C smoke", l_script.has_substring ("xpact_eiffel_dll_smoke.c"))
			assert ("Eiffel native library ECF present", file_text ("tests\xpact_native_library.ecf").has_substring ("XP_NATIVE_LIBRARY_ROOT"))
			assert ("Eiffel native library ECF has assertion target", file_text ("tests\xpact_native_library.ecf").has_substring ("xpact_native_library_assertions"))
			assert ("Eiffel native DLL C smoke present", file_text ("tests\native\xpact_eiffel_dll_smoke.c").has_substring ("XML_STATUS_OK"))
			l_script := file_text ("scripts\run_native_runtime_smoke.ps1")
			assert ("native runtime smoke script present", l_script.has_substring ("xpact_native_runtime.ecf"))
			assert ("native runtime smoke compiles bridge objects", l_script.has_substring ("xpact_eiffel_runtime_bridge.c"))
			assert ("native runtime smoke covers assertion modes", l_script.has_substring ("AssertionMode") and l_script.has_substring ("xpact_native_runtime_no_assertions"))
			assert ("native runtime smoke runs Eiffel through C ABI", file_text ("tests\xp_native_runtime_smoke.e").has_substring ("XML_Parse"))
			assert ("native runtime ECF present", file_text ("tests\xpact_native_runtime.ecf").has_substring ("xpact_native_runtime"))
			l_script := file_text ("scripts\run_native_abi_tests.ps1")
			assert ("native ABI test script present", l_script.has_substring ("xpact_abi_smoke.c"))
			assert ("native bridge ABI test script present", l_script.has_substring ("xpact_bridge_smoke.c"))
			assert ("native ABI tests cover Windows and WSL", l_script.has_substring ("Build-WindowsTests") and l_script.has_substring ("Build-WslTests"))
			assert ("public native ABI smoke present", file_text ("tests\native\xpact_abi_smoke.c").has_substring ("XML_ERROR_NOT_STARTED"))
			assert ("bridge native ABI smoke present", file_text ("tests\native\xpact_bridge_smoke.c").has_substring ("XPACT_SetEiffelBridge"))
			l_notes := file_text ("native\README.md")
			assert ("native export notes present", l_notes.has_substring ("bridge-only"))
			assert ("native export notes keep parser semantics in Eiffel", l_notes.has_substring ("must not implement XML tokenization"))
			l_script := file_text ("scripts\package_windows_release.ps1")
			assert ("Windows release package script present", l_script.has_substring ("build_native_eiffel.ps1"))
			assert ("Windows release package script stages DLL", l_script.has_substring ("xpact.dll") and l_script.has_substring ("xpact.lib"))
			assert ("Windows release package script stages assertion DLL", l_script.has_substring ("xpact_assertions.dll") and l_script.has_substring ("xpact_assertions.lib"))
			assert ("Windows release package script stages public header", l_script.has_substring ("include\xpact.h"))
			assert ("Windows release package script stages parity doc", l_script.has_substring ("libexpat-parity.md"))
			assert ("Windows release package script writes archive", l_script.has_substring ("Compress-Archive") and l_script.has_substring ("windows-x64"))
			assert ("Windows release package script writes checksums", l_script.has_substring ("SHA256SUMS.txt"))
			l_notes := file_text ("docs\windows-release.md")
			assert ("Windows release notes present", l_notes.has_substring ("Windows x64 only"))
			assert ("Windows release notes exclude Linux package", l_notes.has_substring ("Out of scope") and l_notes.has_substring ("Linux/WSL `libxpact.so`"))
			assert ("Phase 1 documents Windows-only native release", file_text ("docs\phase-1.md").has_substring ("The first native-library package is Windows x64 only"))
		end

	assert_async_entity_rejected (a_label, a_input: READABLE_STRING_8; a_line, a_column: INTEGER)
			-- Assert Expat-compatible asynchronous entity rejection.
		require
			label_attached: a_label /= Void
			input_attached: a_input /= Void
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_assertion: STRING_8
		do
			create l_handler.make
			create l_parser.make (l_handler)
			create l_assertion.make_empty
			l_assertion.append (a_label)
			l_assertion.append (" rejected")
			assert (l_assertion, not l_parser.parse (a_input))
			create l_assertion.make_empty
			l_assertion.append (a_label)
			l_assertion.append (" async error")
			assert (l_assertion, l_parser.last_error.same_string ("asynchronous entity"))
			create l_assertion.make_empty
			l_assertion.append (a_label)
			l_assertion.append (" line")
			assert (l_assertion, l_parser.current_line_number = a_line)
			create l_assertion.make_empty
			l_assertion.append (a_label)
			l_assertion.append (" column")
			assert (l_assertion, l_parser.current_column_number = a_column)
		end

	record_garbage_collection_state (a_state: CELL [BOOLEAN])
			-- Store current Eiffel garbage-collection status in `a_state'.
		require
			state_attached: a_state /= Void
		local
			l_memory: MEMORY
		do
			create l_memory
			a_state.put (l_memory.collecting)
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

	file_text (a_path: READABLE_STRING_8): STRING_8
			-- Entire text of `a_path', or empty if it cannot be opened.
		require
			path_attached: a_path /= Void
			path_not_empty: not a_path.is_empty
		local
			l_file: PLAIN_TEXT_FILE
		do
			create Result.make_empty
			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				from
				invariant
					result_attached: Result /= Void
				until
					l_file.end_of_file
				loop
					l_file.read_line
					Result.append (l_file.last_string)
					Result.append_character ('%N')
				end
				l_file.close
			end
		ensure
			result_attached: Result /= Void
		end

	failed: BOOLEAN
			-- Has any test failed?

end
