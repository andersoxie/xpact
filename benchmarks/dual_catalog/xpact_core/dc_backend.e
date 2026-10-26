note
	description: "Pinned raw core adapter; resets one parser and restores incoming GC policy per document."

class
	DC_BACKEND

inherit
	XT_PARSE_CONSTANTS
	XT_PARSE_ERROR_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make (observing: BOOLEAN)
		local
			data: XT_PARSER_DATA
			p: DC_CORE_PARSER
		do
			create observer.make
			create memory
			create last_error.make_empty
			create data.make_default
			create p.make (data)
			if observing then p.set_observer (observer) end
			parser := p
		end

feature -- Whole-document boundary

	parse (document: STRING_8): BOOLEAN
		local
			was_collecting: BOOLEAN
			parse_status: INTEGER
		do
			was_collecting := memory.collecting
			observer.reset
			last_error.wipe_out
			if attached parser as p then
				if cached_document /= document then
					create input.make_from_string (document)
					cached_document := document
				end
				p.reset
				if attached input as bytes then
					parse_status := p.parse (bytes, True)
					Result := parse_status = Status_ok and p.error_code = Error_none
					if not Result then last_error := p.error_description.twin end
				end
				observer.finish
			else
				last_error := "backend closed"
			end
			restore_gc (was_collecting)
		rescue
			restore_gc (was_collecting)
		end

	close
		do
			parser := Void
			input := Void
			cached_document := Void
			observer.reset
		end

	is_closed: BOOLEAN
		do
			Result := parser = Void and input = Void and cached_document = Void
		end

	observer: DC_CATALOG_OBSERVER

	last_error: STRING_8

	gc_policy: STRING_8 = "core-managed-off-full-collect"

feature {NONE} -- Owned input and parser references

	parser: detachable DC_CORE_PARSER

	input: detachable XT_UTF_8_CODEC

	cached_document: detachable STRING_8
			-- Harness input is immutable; the timed catalog is prepared once per process.

	memory: MEMORY

	restore_gc (collecting: BOOLEAN)
		do
			if memory.collecting /= collecting then
				if collecting then memory.collection_on else memory.collection_off end
			end
		end

end
