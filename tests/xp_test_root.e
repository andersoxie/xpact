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
			test_native_eiffel_bridge_parser
			test_native_bridge_installer
			test_expat_api_manifest
			test_libexpat_adapter_files
			test_benchmark_publication_files
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

	test_native_eiffel_bridge_parser
		local
			l_attributes: XP_ATTRIBUTES
			l_native: XP_NATIVE_PARSER
			l_status: INTEGER
		do
			create l_attributes.make
			l_attributes.put ("first", "1")
			l_attributes.put ("second", "2")
			assert ("attribute insertion order first", l_attributes.i_th_name (1).same_string ("first"))
			assert ("attribute insertion order second", l_attributes.i_th_name (2).same_string ("second"))
			assert ("attribute insertion value first", l_attributes.i_th_value (1).same_string ("1"))
			assert ("attribute insertion value second", l_attributes.i_th_value (2).same_string ("2"))

			create l_native.make
			l_status := l_native.parse ("<root><child a=%"1%">text</child></root>", True)
			assert ("native Eiffel parser accepts document", l_status = l_native.Xml_status_ok)
			assert ("native Eiffel parser reports no error", l_native.last_error_code = l_native.Xml_error_none)
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
			l_status := l_native.parse ("<root />", False)
			assert ("native Eiffel parser rejects non-final parse", l_status = l_native.Xml_status_error)
			assert ("native Eiffel parser marks non-final unsupported", l_native.last_error_code = l_native.Xml_error_not_started)
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
		do
			create l_installer.make
			l_handle := l_installer.parser_create (default_pointer, default_pointer, default_pointer)
			assert ("native bridge installer returns parser handle", l_handle /= default_pointer)
			assert ("native bridge installer tracks parser", l_installer.active_parser_count = 1)
			assert ("native bridge installer resolves handle", attached l_installer.parser_for (l_handle))

			create l_input.make ("<root><child>text</child></root>")
			l_installer.set_user_data (l_handle, l_input.item)
			l_installer.set_element_handler (l_handle, default_pointer, default_pointer)
			l_installer.set_character_data_handler (l_handle, default_pointer)
			l_status := l_installer.parse (l_handle, l_input.item, l_input.count, True)
			assert ("native bridge installer parse succeeds", l_status = 1)
			assert ("native bridge installer reports no error", l_installer.get_error_code (l_handle) = 0)
			if attached l_installer.parser_for (l_handle) as l_native then
				assert ("native bridge installer forwards user data", l_native.handler.user_data = l_input.item)
				assert ("native bridge installer emitted start events", l_native.handler.start_element_count = 2)
				assert ("native bridge installer emitted text event", l_native.handler.character_data_count = 1)
				assert ("native bridge installer emitted end events", l_native.handler.end_element_count = 2)
			end

			create l_status_buffer.make (8)
			l_installer.get_parsing_status (l_handle, l_status_buffer.item)
			assert ("native bridge installer has line default", l_installer.get_current_line_number (l_handle) = 1)
			assert ("native bridge installer has column default", l_installer.get_current_column_number (l_handle) = 0)
			assert ("native bridge installer has byte index default", l_installer.get_current_byte_index (l_handle) = -1)
			assert ("native bridge installer has byte count default", l_installer.get_current_byte_count (l_handle) = 0)

			assert ("native bridge installer resets parser", l_installer.parser_reset (l_handle, default_pointer))
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
		do
			l_script := file_text ("scripts\run_libexpat_adapter.ps1")
			assert ("libexpat adapter script present", not l_script.is_empty)
			assert ("adapter extracts upstream START_TEST names", l_script.has_substring ("START_TEST"))
			assert ("adapter writes test manifest", l_script.has_substring ("libexpat-runtests-manifest.tsv"))
			assert ("adapter expands expected failures", l_script.has_substring ("libexpat-expected-failures-expanded.tsv"))
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
			assert ("expected-failure list present", file_text ("adapters\libexpat\expected-failures.tsv").has_substring ("XML_ERROR_NOT_STARTED"))
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
			assert ("benchmark script records pyexpat baseline", l_script.has_substring ("pyexpat") and l_script.has_substring ("libexpat_py_benchmark.py"))
			assert ("benchmark script can record WSL C baseline", l_script.has_substring ("libexpat_c_benchmark.c") and l_script.has_substring ("WSL2 gcc"))
			assert ("benchmark script can record xpact native C ABI", l_script.has_substring ("xpact_native_c_benchmark.c"))
			assert ("benchmark script reports unconnected Eiffel bridge", l_script.has_substring ("XML_ERROR_NOT_STARTED"))
			assert ("benchmark script writes docs table", l_script.has_substring ("docs\benchmarks.md"))
			l_python := file_text ("benchmarks\libexpat_py_benchmark.py")
			assert ("libexpat Python benchmark present", l_python.has_substring ("xml.parsers") and l_python.has_substring ("EXPAT_VERSION"))
			assert ("libexpat C benchmark present", file_text ("benchmarks\libexpat_c_benchmark.c").has_substring ("XML_ExpatVersion"))
			assert ("xpact native C benchmark present", file_text ("benchmarks\xpact_native_c_benchmark.c").has_substring ("XML_ERROR_NOT_STARTED"))
			l_table := file_text ("docs\benchmarks.md")
			assert ("published benchmark table present", l_table.has_substring ("| Benchmark | Engine | Version | Iterations |"))
			assert ("published benchmark includes finalized xpact row", l_table.has_substring ("xpact Eiffel finalized, assertions discarded"))
			assert ("published benchmark includes libexpat row", l_table.has_substring ("libexpat via CPython pyexpat"))
			assert ("published benchmark includes WSL C libexpat row", l_table.has_substring ("libexpat C callbacks via WSL2 gcc"))
			assert ("published benchmark includes native C ABI status", l_table.has_substring ("xpact native C ABI"))
		end

	test_native_export_layer_files
		local
			l_source: STRING_8
			l_bridge: STRING_8
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
			assert ("Eiffel native bridge installer present", file_text ("src\xp_native_bridge_installer.e").has_substring ("XP_NATIVE_PARSER"))
			assert ("Eiffel native bridge installer uses runtime object ids", file_text ("src\xp_native_bridge_installer.e").has_substring ("eif_object_id"))
			l_script := file_text ("scripts\build_native.ps1")
			assert ("native build script present", not l_script.is_empty)
			assert ("native build script builds Windows DLL", l_script.has_substring ("xpact.dll"))
			assert ("native build script builds WSL shared object", l_script.has_substring ("libxpact.so"))
			l_script := file_text ("scripts\run_native_abi_tests.ps1")
			assert ("native ABI test script present", l_script.has_substring ("xpact_abi_smoke.c"))
			assert ("native bridge ABI test script present", l_script.has_substring ("xpact_bridge_smoke.c"))
			assert ("native ABI tests cover Windows and WSL", l_script.has_substring ("Build-WindowsTests") and l_script.has_substring ("Build-WslTests"))
			assert ("public native ABI smoke present", file_text ("tests\native\xpact_abi_smoke.c").has_substring ("XML_ERROR_NOT_STARTED"))
			assert ("bridge native ABI smoke present", file_text ("tests\native\xpact_bridge_smoke.c").has_substring ("XPACT_SetEiffelBridge"))
			l_notes := file_text ("native\README.md")
			assert ("native export notes present", l_notes.has_substring ("bridge-only"))
			assert ("native export notes keep parser semantics in Eiffel", l_notes.has_substring ("must not implement XML tokenization"))
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
