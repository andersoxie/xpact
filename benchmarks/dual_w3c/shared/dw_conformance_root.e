note
	description: "Original-byte W3C binary-verdict CLI and directed observations for one implementation."

class
	DW_CONFORMANCE_ROOT

inherit
	XP_BUILD_IDENTITY

create
	make

feature {NONE} -- Initialization

	make
		local
			arguments: ARGUMENTS_32
			path: PATH
			namespaces: BOOLEAN
		do
			create arguments
			if arguments.argument_count = 1 and then arguments.argument (1).same_string ("--identity") then
				put_identity
			elseif arguments.argument_count = 1 and then arguments.argument (1).same_string ("--qualify") then
				qualify
			elseif (arguments.argument_count = 2 or arguments.argument_count = 3)
				and then arguments.argument (1).same_string ("--conformance-file")
				and then not arguments.argument (2).is_empty
			then
				namespaces := arguments.argument_count = 3
				if not namespaces or else arguments.argument (3).same_string ("--namespaces") then
					create path.make_from_string (arguments.argument (2))
					conformance (path, namespaces)
				else
					usage_error
				end
			else
				usage_error
			end
		end

	put_identity
		local
			backend: DW_BACKEND
		do
			create backend.make (False)
			io.put_string ("XPACT_W3C_IDENTITY%T" + implementation_id + "%T" + source_revision + "%T" + build_configuration + "%T" + backend.gc_policy + "%N")
			backend.close
		end

	conformance (path: PATH; namespaces: BOOLEAN)
		local
			backend: DW_BACKEND
			accepted: BOOLEAN
		do
			if attached raw_file_bytes (path) as bytes then
				create backend.make (namespaces)
				accepted := backend.parse (bytes)
				if accepted then
					backend.close
					io.put_string ("XPACT_CONFORMANCE%TACCEPT%N")
				else
					io.put_string ("XPACT_CONFORMANCE%TREJECT%N")
					io.error.put_string (backend.last_error + "%N")
					backend.close
					exit_with_code (1)
				end
			else
				io.error.put_string ("Cannot read conformance input as original bytes%N")
				exit_with_code (2)
			end
		end

	raw_file_bytes (path: PATH): detachable STRING_8
		local
			file: RAW_FILE
		do
			create file.make_with_path (path)
			if file.exists and then file.is_readable then
				create Result.make (file.count)
				file.open_read
				from until file.end_of_file loop
					file.read_stream (65536)
					Result.append (file.last_string)
				end
				file.close
			end
		rescue
			if file /= Void and then not file.is_closed then file.close end
		end

feature {NONE} -- Directed observations; semantic failures do not alter full-suite expectations

	qualify
		local
			ok, all_ok: BOOLEAN
		do
			put_identity
			ok := utf8_check
			emit_case ("raw_utf8", ok, "UTF-8 non-ASCII bytes with and without BOM; malformed final input rejected")
			all_ok := ok
			ok := utf16_check
			emit_case ("raw_utf16", ok, "Original UTF-16 little- and big-endian BOM control bytes accepted")
			all_ok := all_ok and ok
			ok := namespace_check
			emit_case ("namespace_switch", ok, "Bound prefix accepted; unbound and multi-colon names rejected with namespaces, accepted when disabled")
			all_ok := all_ok and ok
			ok := reuse_check
			emit_case ("reuse_recovery", ok, "Same parser reuses original bytes, rejects mismatch/unbound prefix after reset, then accepts valid input")
			all_ok := all_ok and ok
			ok := gc_check
			emit_case ("gc_restoration", ok, "Incoming GC on/off restored after valid, mismatched and empty final input; closed references released")
			all_ok := all_ok and ok
			if not all_ok then exit_with_code (1) end
		end

	utf8_check: BOOLEAN
		local
			backend: DW_BACKEND
			ok: BOOLEAN
		do
			create backend.make (False)
			Result := backend.parse (utf8_document)
			ok := backend.parse ("%/239/%/187/%/191/" + utf8_document)
			Result := Result and ok
			ok := backend.parse ("<r>")
			Result := Result and not ok and not backend.last_error.is_empty
			backend.close
			Result := Result and backend.is_closed
		end

	utf16_check: BOOLEAN
		local
			backend: DW_BACKEND
			ok: BOOLEAN
		do
			create backend.make (False)
			Result := backend.parse (utf16_document (True))
			ok := backend.parse (utf16_document (False))
			Result := Result and ok
			backend.close
			Result := Result and backend.is_closed
		end

	namespace_check: BOOLEAN
		local
			aware, plain: DW_BACKEND
			ok: BOOLEAN
		do
			create aware.make (True)
			create plain.make (False)
			Result := aware.parse ("<p:r xmlns:p='urn:p'/>")
			ok := aware.parse ("<p:r/>")
			Result := Result and not ok
			ok := plain.parse ("<p:r/>")
			Result := Result and ok
			ok := aware.parse ("<a:b:c/>")
			Result := Result and not ok
			ok := plain.parse ("<a:b:c/>")
			Result := Result and ok
			aware.close
			plain.close
			Result := Result and aware.is_closed and plain.is_closed
		end

	reuse_check: BOOLEAN
		local
			backend: DW_BACKEND
			ok: BOOLEAN
		do
			create backend.make (True)
			Result := backend.parse ("<p:r xmlns:p='urn:p'/>")
			ok := backend.parse ("<p:r xmlns:p='urn:p'/>")
			Result := Result and ok and backend.last_error.is_empty
			ok := backend.parse ("<r><s></r>")
			Result := Result and not ok and not backend.last_error.is_empty
			ok := backend.parse ("<p:r/>")
			Result := Result and not ok and not backend.last_error.is_empty
			ok := backend.parse (utf8_document)
			Result := Result and ok and backend.last_error.is_empty
			backend.close
			Result := Result and backend.is_closed
		end

	gc_check: BOOLEAN
		local
			backend: DW_BACKEND
			memory: MEMORY
			was_collecting, accepted: BOOLEAN
		do
			create memory
			was_collecting := memory.collecting
			create backend.make (False)
			memory.collection_on
			accepted := backend.parse (utf8_document)
			Result := accepted and memory.collecting
			accepted := backend.parse ("<r><s></r>")
			Result := Result and not accepted and memory.collecting
			accepted := backend.parse ("")
			Result := Result and not accepted and memory.collecting
			memory.collection_off
			accepted := backend.parse (utf8_document)
			Result := Result and accepted and not memory.collecting
			accepted := backend.parse ("<r><s></r>")
			Result := Result and not accepted and not memory.collecting
			accepted := backend.parse ("")
			Result := Result and not accepted and not memory.collecting
			backend.close
			Result := Result and backend.is_closed
			restore_gc (memory, was_collecting)
		rescue
			if memory /= Void then restore_gc (memory, was_collecting) end
		end

	utf8_document: STRING_8 = "<r>%/195/%/169/</r>"

	utf16_document (little_endian: BOOLEAN): STRING_8
		local
			text: STRING_8
		do
			text := "<r>%/233/</r>"
			create Result.make (text.count * 2 + 2)
			if little_endian then Result.append ("%/255/%/254/") else Result.append ("%/254/%/255/") end
			across text as c loop
				if little_endian then
					Result.append_character (c.item)
					Result.append_character ('%U')
				else
					Result.append_character ('%U')
					Result.append_character (c.item)
				end
			end
		end

	restore_gc (memory: MEMORY; collecting: BOOLEAN)
		do
			if collecting then memory.collection_on else memory.collection_off end
		end

	emit_case (id: STRING_8; ok: BOOLEAN; detail: STRING_8)
		do
			io.put_string ("XPACT_W3C_CASE%T" + id + "%T")
			if ok then io.put_string ("PASS") else io.put_string ("FAIL") end
			io.put_string ("%T" + detail + "%N")
		end

	usage_error
		do
			io.error.put_string ("usage: --identity | --qualify | --conformance-file PATH [--namespaces]%N")
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
