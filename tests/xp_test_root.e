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
