note
	description: "Tests that a handler can edit namespace callback strings without changing parser bindings."

class
	XP_MUTATING_NAMESPACE_HANDLER

inherit
	XP_COLLECTING_HANDLER
		redefine
			on_start_namespace_decl, on_end_namespace_decl
		end

create
	make

feature -- Events

	on_start_namespace_decl (a_prefix: detachable READABLE_STRING_8; a_uri: READABLE_STRING_8)
		do
			if attached {STRING_8} a_uri as l_uri then
				l_uri.append_character ('!')
			end
			if attached {STRING_8} a_prefix as l_prefix then
				l_prefix.append_character ('!')
			end
		end

	on_end_namespace_decl (a_prefix: detachable READABLE_STRING_8)
		do
			if attached a_prefix as l_prefix then
				events.extend ("ns-end:" + l_prefix.to_string_8)
			end
			if attached {STRING_8} a_prefix as l_mutable then
				l_mutable.wipe_out
			end
		end

end
