note
	description: "Local parser adapter; parse resets its document state implicitly."

class
	DC_BACKEND

create
	make

feature {NONE} -- Initialization

	make (observing: BOOLEAN)
		local
			handler: XP_EVENT_HANDLER
		do
			create observer.make
			create memory
			create last_error.make_empty
			if observing then
				create {DC_XPACT_HANDLER} handler.make (observer)
			else
				create {XP_NULL_EVENT_HANDLER} handler.make
			end
			create parser.make (handler)
		end

feature -- Whole-document boundary

	parse (document: STRING_8): BOOLEAN
		local
			was_collecting: BOOLEAN
		do
			was_collecting := memory.collecting
			observer.reset
			if attached parser as p then
				Result := p.parse (document)
				last_error := p.last_error.twin
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
			observer.reset
		end

	is_closed: BOOLEAN
		do
			Result := parser = Void
		end

	observer: DC_CATALOG_OBSERVER

	last_error: STRING_8

	gc_policy: STRING_8 = "normal"

feature {NONE} -- Owned parser reference

	parser: detachable XP_PARSER

	memory: MEMORY

	restore_gc (collecting: BOOLEAN)
		do
			if memory.collecting /= collecting then
				if collecting then memory.collection_on else memory.collection_off end
			end
		end

end
