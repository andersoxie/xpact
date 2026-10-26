note
	description: "Pinned raw core verdict adapter; keeps native encoding detection and restores caller GC state."

class
	DW_BACKEND

inherit
	XT_PARSE_CONSTANTS
	XT_PARSE_ERROR_CONSTANTS
	XT_NAMING_MODE_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make (namespaces: BOOLEAN)
		local
			data: XT_PARSER_DATA
		do
			create memory
			create last_error.make_empty
			if namespaces then
				create data.make (NM_uri_SEP_localname, '|')
			else
				create data.make_default
			end
				-- Naming mode determines cache classes in parser.make, so set it first.
			data.set_parameter_entity_parsing (PE_parsing_never)
			create parser.make (data)
		end

feature -- Whole-document boundary

	parse (document: STRING_8): BOOLEAN
		local
			was_collecting: BOOLEAN
			parse_status: INTEGER
		do
			was_collecting := memory.collecting
			last_error.wipe_out
			if attached parser as p then
				p.reset
					-- Copy bytes into core's own codec; its BOM/declaration detector selects encoding.
					-- No caller-side decoding, transcoding, newline replacement or BOM removal.
				create input.make_from_string (document)
				if attached input as bytes then
					parse_status := p.parse (bytes, True)
					Result := parse_status = Status_ok and p.error_code = Error_none
					if not Result then last_error := p.error_description.twin end
				end
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
		end

	is_closed: BOOLEAN
		do
			Result := parser = Void and input = Void
		end

	last_error: STRING_8

	gc_policy: STRING_8 = "core-managed-off-full-collect"

feature {NONE} -- Owned references

	parser: detachable DW_CORE_PARSER

	input: detachable XT_UTF_8_CODEC

	memory: MEMORY

	restore_gc (collecting: BOOLEAN)
		do
			if memory.collecting /= collecting then
				if collecting then memory.collection_on else memory.collection_off end
			end
		end

end
