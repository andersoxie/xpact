note
	description: "No-event handler descendant that edits consumed input from a comment callback."

class
	XP_INPUT_MUTATING_NULL_HANDLER

inherit
	XP_NULL_EVENT_HANDLER
		redefine
			on_comment
		end

create
	make

feature -- Configuration

	set_input (a_input: detachable STRING_8)
		do
			input := a_input
		end

feature -- Events

	on_comment (a_text: READABLE_STRING_8)
		local
			l_index: INTEGER
		do
			if attached input as l_input then
				l_index := l_input.substring_index ("<r>", 1)
				if l_index > 0 then
					l_input.put ('s', l_index + 1)
				end
			end
		end

feature {NONE} -- State

	input: detachable STRING_8

end
