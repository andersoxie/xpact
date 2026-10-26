note
	description: "Direct xpact verdict adapter; receives original document bytes and fixes namespace policy at construction."

class
	DW_BACKEND

create
	make

feature {NONE} -- Initialization

	make (namespaces: BOOLEAN)
		local
			handler: XP_NULL_EVENT_HANDLER
		do
			create memory
			create last_error.make_empty
			create handler.make
			create parser.make (handler)
			if attached parser as p then
				p.set_external_entity_policy (p.No_external_entities)
				p.set_external_entity_resolver (Void)
				if namespaces then p.set_namespace_mode ('|') end
			end
		end

feature -- Whole-document boundary

	parse (document: STRING_8): BOOLEAN
		local
			was_collecting: BOOLEAN
		do
			was_collecting := memory.collecting
			if attached parser as p then
				Result := p.parse (document)
				last_error := p.last_error.twin
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
		end

	is_closed: BOOLEAN
		do
			Result := parser = Void
		end

	last_error: STRING_8

	gc_policy: STRING_8 = "normal"

feature {NONE} -- Owned references

	parser: detachable XP_PARSER

	memory: MEMORY

	restore_gc (collecting: BOOLEAN)
		do
			if memory.collecting /= collecting then
				if collecting then memory.collection_on else memory.collection_off end
			end
		end

end
