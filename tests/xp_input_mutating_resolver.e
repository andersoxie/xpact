note
	description: "External resolver that edits an already consumed opening tag in the caller's input."

class
	XP_INPUT_MUTATING_RESOLVER

inherit
	XP_EXTERNAL_ENTITY_RESOLVER

create
	make

feature {NONE} -- Initialization

	make (a_input: STRING_8)
		do
			input := a_input
		end

feature -- Access

	call_count: INTEGER

feature -- Resolution

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
		local
			l_index: INTEGER
		do
			call_count := call_count + 1
			if a_system_id.same_string ("mem://mutate") and then not a_is_parameter then
				l_index := input.substring_index ("<r>", 1)
				if l_index > 0 then
					input.put ('s', l_index + 1)
				end
				create Result.make_empty
			end
		end

feature {NONE} -- State

	input: STRING_8

end
