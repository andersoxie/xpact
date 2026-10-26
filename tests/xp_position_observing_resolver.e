note
	description: "External entity resolver that captures public parser positions at the call boundary."

class
	XP_POSITION_OBSERVING_RESOLVER

inherit
	XP_EXTERNAL_ENTITY_RESOLVER

create
	make

feature {NONE} -- Initialization

	make (a_parser: XP_PARSER; a_replacement: READABLE_STRING_8)
		do
			parser := a_parser
			create replacement.make_from_string (a_replacement)
		end

feature -- Observations

	call_count: INTEGER

	line_number: INTEGER

	column_number: INTEGER

	byte_index: INTEGER

	byte_count: INTEGER

feature -- Configuration

	set_replacement (a_replacement: READABLE_STRING_8)
		do
			replacement.wipe_out
			replacement.append (a_replacement)
		end

feature -- Resolution

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
		do
			call_count := call_count + 1
			line_number := parser.current_line_number
			column_number := parser.current_column_number
			byte_index := parser.current_byte_index
			byte_count := parser.current_byte_count
			if a_system_id.same_string ("mem://positioned") and then not a_is_parameter then
				Result := replacement.twin
			end
		end

feature {NONE} -- State

	parser: XP_PARSER

	replacement: STRING_8

end
