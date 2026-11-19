note
	description: "[
		Gobo XML (XM_EIFFEL_PARSER) test engine, for comparing with xpact.
		  --conformance-file F [--suite-root R] [--namespaces]   W3C runner protocol (XPACT_CONFORMANCE line, exit 0/1)
		  --server                                               one job per stdin line: PATH<TAB>FLAGS<TAB>SPLIT<TAB>ENTITY_ROOT
		                                                         one JSON result per stdout line
		  --bench F N [--events]                                 parse F N times, print milliseconds
		Gobo gets its strongest checking: end-tag checker, Unicode validation, namespace resolver (namespace mode),
		parser stop-on-error; string mode mixed (full Unicode).
	]"

class
	GX_ENGINE

inherit
	XM_CALLBACKS_FILTER_FACTORY
		export {NONE} all end

	XM_RESOLVER_FACTORY
		export {NONE} all end

	UT_SHARED_FILE_URI_ROUTINES
		export {NONE} all end

	KL_SHARED_STANDARD_FILES
		export {NONE} all end

	KL_SHARED_EXCEPTIONS
		export {NONE} all end

create
	make

feature {NONE} -- Initialization

	make
		local
			args: ARGUMENTS_32
			i: INTEGER
			file, root: detachable STRING_8
			ns, events: BOOLEAN
		do
			create args
				-- A copy named gx_engine_nouf.exe runs without Gobo's optional Unicode validation filter.
			no_unicode_filter := args.command_name.as_lower.has_substring ("nouf")
			create recorder.make
			create last_message.make_empty
			if args.argument_count >= 1 and then args.argument (1).same_string ("--server") then
				server
			elseif args.argument_count >= 3 and then args.argument (1).same_string ("--bench") then
				events := args.argument_count >= 4 and then args.argument (4).same_string ("--events")
				bench (args.argument (2).to_string_8, args.argument (3).to_integer, events)
			else
				from i := 1 until i > args.argument_count loop
					if args.argument (i).same_string ("--conformance-file") and i < args.argument_count then
						file := args.argument (i + 1).to_string_8; i := i + 2
					elseif (args.argument (i).same_string ("--suite-root") or args.argument (i).same_string ("--entity-root")) and i < args.argument_count then
						root := args.argument (i + 1).to_string_8; i := i + 2
					elseif args.argument (i).same_string ("--namespaces") then
						ns := True; i := i + 1
					else
						i := i + 1
					end
				end
				if attached file as f then
					conformance (f, root, ns)
				else
					std.error.put_string ("usage: gx_engine --conformance-file F [--suite-root R] [--namespaces] | --server | --bench F N [--events]%N")
					exceptions.die (2)
				end
			end
		end

feature -- Modes

	conformance (path: STRING_8; root: detachable STRING_8; ns: BOOLEAN)
		local
			bytes: detachable STRING_8
			ok: BOOLEAN
		do
			bytes := read_bytes (path)
			if bytes = Void then
				std.error.put_string ("cannot read " + path + "%N")
				exceptions.die (2)
			else
				recorder.set_recording (False)
				ok := parse (bytes, ns, "", if root /= Void then path else Void end)
				if ok then
					std.output.put_string ("XPACT_CONFORMANCE%TACCEPT%N")
				else
					std.output.put_string ("XPACT_CONFORMANCE%TREJECT%N")
					std.error.put_string (last_message + "%N")
					std.output.flush
					exceptions.die (1)
				end
			end
		end

	server
			-- PATH<TAB>FLAGS<TAB>SPLIT<TAB>ENTITY_ROOT; FLAGS contains 'n' for namespaces, 'q' for no events.
		local
			line: STRING_8
			fields: LIST [STRING_8]
			bytes: detachable STRING_8
			ok, ns: BOOLEAN
			base: detachable STRING_8
		do
			from std.input.read_line until std.input.end_of_file loop
				line := std.input.last_string.twin
				line.prune_all ('%R')
				fields := line.split ('%T')
				if fields.count >= 4 then
					ns := fields [2].has ('n')
					if fields [2].has ('q') then recorder.set_recording (False) else recorder.set_recording (True) end
					if fields [4].is_empty then base := Void else base := fields [1] end
					recorder.reset
					bytes := read_bytes (fields [1])
					if bytes = Void then
						reply ("ERROR", "cannot read input")
					else
						ok := parse (bytes, ns, fields [3], base)
						if ok then reply ("ACCEPT", "") else reply ("REJECT", last_message) end
					end
				else
					reply ("ERROR", "bad job line")
				end
				std.input.read_line
			end
		end

	bench (path: STRING_8; n: INTEGER; events: BOOLEAN)
		local
			bytes: detachable STRING_8
			i, accepted: INTEGER
			t0, t1: INTEGER_64
		do
			bytes := read_bytes (path)
			if attached bytes as b then
				if events then recorder.set_recording (True) else recorder.set_recording (False) end
				if parse (b, False, "", Void) then accepted := 1 end -- warm-up
				t0 := ticks_us
				from i := 1 until i > n loop
					recorder.reset
					if parse (b, False, "", Void) then accepted := accepted + 1 end
					i := i + 1
				end
				t1 := ticks_us
				std.output.put_string ("GOBO_BENCH%T" + n.out + "%T" + ((t1 - t0) // 1000).out + "%T" + accepted.out + "%N")
			end
		end

feature -- Parsing

	parse (bytes: STRING_8; ns: BOOLEAN; split: STRING_8; document_path: detachable STRING_8): BOOLEAN
			-- Parse `bytes' (whole, or in pieces per `split': "", "byte", "every:N", "K").
			-- With `document_path', external entities are loaded from files (relative to the document).
		local
			parser: XM_EIFFEL_PARSER
			pipe: XM_CALLBACKS
			stop: XM_PARSER_STOP_ON_ERROR_FILTER
			end_tags: XM_END_TAG_CHECKER
			unicode: XM_UNICODE_VALIDATION_FILTER
			resolver_ns: XM_NAMESPACE_RESOLVER
			pieces: ARRAYED_LIST [STRING_8]
			uri: UT_URI
			failed: BOOLEAN
		do
			if failed then
				Result := False
			else
				recorder.reset
				recorder.set_namespaces (ns)
				create parser.make
				parser.set_string_mode_mixed
				create stop.make_next (parser, recorder)
				end_tags := new_end_tag_checker
				end_tags.set_next (stop)
				unicode := new_unicode_validation
				unicode.set_next (end_tags)
				if ns then
					resolver_ns := new_namespace_resolver
					if no_unicode_filter then resolver_ns.set_next (end_tags) else resolver_ns.set_next (unicode) end
					pipe := resolver_ns
				else
					parser.disable_namespaces
					if no_unicode_filter then pipe := end_tags else pipe := unicode end
				end
				parser.set_callbacks (pipe)
				parser.set_dtd_callbacks (recorder)
				if attached document_path as p then
					uri := File_uri.filename_to_uri (p)
					parser.set_resolver (new_file_resolver_with_uri (uri))
					parser.parse_from_system (uri.full_reference)
				elseif split.is_empty or not parser.is_incremental then
						-- XM_EIFFEL_PARSER is not incremental: pieces cannot be fed, the caller must buffer the whole document.
					parser.parse_from_stream (create {KL_STRING_INPUT_STREAM}.make (bytes))
				else
					pieces := chunks (bytes, split)
					across pieces as c loop
						if parser.is_correct and not recorder.has_error then
							parser.parse_incremental_from_stream (create {KL_STRING_INPUT_STREAM}.make (c))
						end
					end
					parser.finish_incremental
				end
				Result := parser.is_correct and not recorder.has_error
				if not parser.is_correct then
					last_message := recorder.utf8 (parser.last_error_extended_description)
				elseif recorder.has_error then
					last_message := recorder.last_error
				else
					last_message := ""
				end
			end
		rescue
			failed := True
			last_message := "EIFFEL EXCEPTION: " + "see engine"
			exception_seen := True
			retry
		end

	chunks (bytes: STRING_8; split: STRING_8): ARRAYED_LIST [STRING_8]
		local
			i, n: INTEGER
		do
			create Result.make (8)
			if split.same_string ("byte") then
				n := 1
			elseif split.starts_with ("every:") then
				n := split.substring (7, split.count).to_integer.max (1)
			end
			if n > 0 then
				from i := 1 until i > bytes.count loop
					Result.extend (bytes.substring (i, (i + n - 1).min (bytes.count)))
					i := i + n
				end
			else
				n := split.to_integer.max (0).min (bytes.count)
				Result.extend (bytes.substring (1, n))
				Result.extend (bytes.substring (n + 1, bytes.count))
			end
			if Result.is_empty then Result.extend ("") end
		end

feature {NONE} -- Implementation

	ticks_us: INTEGER_64
			-- Microseconds from the Windows performance counter.
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER c, f; QueryPerformanceCounter(&c); QueryPerformanceFrequency(&f); return (EIF_INTEGER_64)(c.QuadPart / (f.QuadPart / 1000000));"
		end

	recorder: GX_RECORDER
	no_unicode_filter: BOOLEAN
	last_message: STRING_8
	exception_seen: BOOLEAN

	reply (verdict, message: STRING_8)
		local
			s: STRING_8
		do
			create s.make (recorder.json.count + message.count + 64)
			s.append ("{%"verdict%":%"")
			if exception_seen then s.append ("EXCEPTION") else s.append (verdict) end
			s.append ("%",%"message%":")
			s.append (recorder.quoted (message))
			s.append (",%"event_count%":")
			s.append (recorder.event_count.out)
			s.append (",%"events%":[")
			s.append (recorder.json)
			s.append ("]}%N")
			std.output.put_string (s)
			std.output.flush
			exception_seen := False
		end

	read_bytes (path: STRING_8): detachable STRING_8
		local
			f: KL_BINARY_INPUT_FILE
		do
			create f.make (path)
			f.open_read
			if f.is_open_read then
				create Result.make (f.count.max (16))
				from until f.end_of_input loop
					f.read_string (65536)
					Result.append (f.last_string)
				end
				f.close
			end
		end

end
