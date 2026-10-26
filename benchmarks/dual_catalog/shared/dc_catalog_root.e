note
	description: "One catalog lane, with explicit qualification independent of Eiffel assertions."

class
	DC_CATALOG_ROOT

inherit
	XP_BUILD_IDENTITY
	DC_CATALOG_FIXTURE

create
	make

feature {NONE} -- Initialization

	make
		local
			arguments: ARGUMENTS_32
			iterations: INTEGER
		do
			create arguments
			if arguments.argument_count = 1 and then arguments.argument (1).same_string ("--identity") then
				put_identity
			elseif arguments.argument_count = 1 and then arguments.argument (1).same_string ("--qualify") then
				qualify
			elseif arguments.argument_count = 2 and then arguments.argument (1).same_string ("--iterations")
				and then arguments.argument (2).is_integer
			then
				iterations := arguments.argument (2).to_integer
				if iterations > 0 then
					benchmark (iterations)
				else
					usage_error
				end
			else
				usage_error
			end
		end

	put_identity
		local
			backend: DC_BACKEND
		do
			create backend.make (False)
			io.put_string ("XPACT_CATALOG_IDENTITY%T" + implementation_id + "%T" + source_revision + "%T" + build_configuration + "%T" + backend.gc_policy + "%N")
			backend.close
		end

	benchmark (iterations: INTEGER)
		local
			backend: DC_BACKEND
			i: INTEGER
			ok: BOOLEAN
		do
			create backend.make (False)
			from i := 0; ok := catalog.count = 2611 until i = iterations or not ok loop
				ok := backend.parse (catalog)
				if ok then i := i + 1 end
			end
			if ok and i = iterations then
				backend.close
				io.put_string ("xpact benchmark harness parsed " + i.out + " documents.%N")
			else
				io.error.put_string ("catalog benchmark failed after " + i.out + " documents: " + backend.last_error + "%N")
				backend.close
				exit_with_code (1)
			end
		end

feature {NONE} -- Untimed qualification

	qualify
		local
			ok, all_ok: BOOLEAN
		do
			put_identity
			ok := catalog_check (True)
			emit_case ("catalog_observed", ok, "2611 bytes; ordered root/item events, id=1..100 attributes and exact text value")
			all_ok := ok
			ok := catalog_check (False)
			emit_case ("catalog_noop", ok, "same catalog accepted through the timed no-op handler path")
			all_ok := all_ok and ok
			ok := reuse_check (True)
			emit_case ("observed_reuse_recovery", ok, "same parser: catalog twice, malformed, catalog, malformed; clean errors/events and closed references")
			all_ok := all_ok and ok
			ok := reuse_check (False)
			emit_case ("noop_reuse_recovery", ok, "same no-op parser: catalog twice, malformed, catalog, malformed; clean errors and closed references")
			all_ok := all_ok and ok
			ok := gc_check
			emit_case ("gc_restoration", ok, "incoming GC on/off restored after valid, mismatched and empty final inputs")
			all_ok := all_ok and ok
			if not all_ok then exit_with_code (1) end
		end

	catalog_check (observing: BOOLEAN): BOOLEAN
		local
			backend: DC_BACKEND
		do
			create backend.make (observing)
			Result := catalog.count = 2611 and then backend.parse (catalog) and then backend.last_error.is_empty
			if observing then
				Result := Result and backend.observer.trace.same_string (expected_trace)
			end
			if not Result then
				io.error.put_string ("catalog qualification: " + backend.last_error + "%N" + backend.observer.trace)
			end
			backend.close
			Result := Result and backend.is_closed and backend.observer.trace.is_empty
		end

	reuse_check (observing: BOOLEAN): BOOLEAN
		local
			backend: DC_BACKEND
			ok: BOOLEAN
		do
			create backend.make (observing)
			Result := backend.parse (catalog) and then backend.last_error.is_empty
			if observing then Result := Result and backend.observer.trace.same_string (expected_trace) end
			ok := backend.parse (catalog)
			Result := Result and ok and backend.last_error.is_empty
			if observing then Result := Result and backend.observer.trace.same_string (expected_trace) end
			ok := backend.parse (malformed)
			Result := Result and not ok and not backend.last_error.is_empty
			ok := backend.parse (catalog)
			Result := Result and ok and backend.last_error.is_empty
			if observing then Result := Result and backend.observer.trace.same_string (expected_trace) end
			ok := backend.parse (malformed)
			Result := Result and not ok and not backend.last_error.is_empty
			backend.close
			Result := Result and backend.is_closed and backend.observer.trace.is_empty
		end

	gc_check: BOOLEAN
		local
			memory: MEMORY
			backend: DC_BACKEND
			was_collecting, ignored: BOOLEAN
		do
			create memory
			was_collecting := memory.collecting
			create backend.make (False)
			memory.collection_on
			ignored := backend.parse (catalog)
			Result := ignored and memory.collecting
			ignored := backend.parse (malformed)
			Result := Result and not ignored and memory.collecting
			ignored := backend.parse ("")
			Result := Result and not ignored and memory.collecting
			memory.collection_off
			ignored := backend.parse (catalog)
			Result := Result and ignored and not memory.collecting
			ignored := backend.parse (malformed)
			Result := Result and not ignored and not memory.collecting
			ignored := backend.parse ("")
			Result := Result and not ignored and not memory.collecting
			backend.close
			Result := Result and backend.is_closed
			restore_gc (memory, was_collecting)
		rescue
			if memory /= Void then restore_gc (memory, was_collecting) end
		end

	restore_gc (memory: MEMORY; collecting: BOOLEAN)
		do
			if collecting then memory.collection_on else memory.collection_off end
		end

	emit_case (id: STRING_8; ok: BOOLEAN; detail: STRING_8)
		do
			io.put_string ("XPACT_CATALOG_CASE%T" + id + "%T")
			if ok then io.put_string ("PASS") else io.put_string ("FAIL") end
			io.put_string ("%T" + detail + "%N")
		end

	usage_error
		do
			io.error.put_string ("usage: --identity | --qualify | --iterations POSITIVE_INTEGER%N")
			exit_with_code (2)
		end

	exit_with_code (code: INTEGER)
		local
			exceptions: EXCEPTIONS
		do
			create exceptions
			exceptions.die (code)
		end

end
