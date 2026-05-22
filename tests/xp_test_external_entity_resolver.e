note
	description: "Deterministic in-memory external entity resolver for tests."

class
	XP_TEST_EXTERNAL_ENTITY_RESOLVER

inherit
	XP_EXTERNAL_ENTITY_RESOLVER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_name.make_empty
			create last_public_id.make_empty
			create last_system_id.make_empty
		end

feature -- Access

	call_count: INTEGER
			-- Number of resolver calls.

	last_name: STRING_8
			-- Last requested entity name.

	last_public_id: STRING_8
			-- Last requested public identifier.

	last_system_id: STRING_8
			-- Last requested system identifier.

	last_is_parameter: BOOLEAN
			-- Was the last request for a parameter entity or external subset?

feature -- Resolution

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
		do
			call_count := call_count + 1
			last_name.wipe_out
			last_name.append (a_name)
			last_public_id.wipe_out
			last_public_id.append (a_public_id)
			last_system_id.wipe_out
			last_system_id.append (a_system_id)
			last_is_parameter := a_is_parameter
			if a_system_id.same_string ("mem://external-item") then
				create Result.make_from_string ("<item>external</item>")
			elseif a_system_id.same_string ("mem://parameter-declarations") then
				create Result.make_from_string ("<!ENTITY from_external 'loaded'>")
			elseif a_system_id.same_string ("mem://subset") then
				create Result.make_from_string ("<!ENTITY subset_entity 'subset loaded'>")
			end
		end

invariant
	last_name_attached: last_name /= Void
	last_public_id_attached: last_public_id /= Void
	last_system_id_attached: last_system_id /= Void
	call_count_non_negative: call_count >= 0

end

