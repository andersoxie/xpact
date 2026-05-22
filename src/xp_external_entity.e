note
	description: "External entity declaration captured from a DTD."

class
	XP_EXTERNAL_ENTITY

create
	make

feature {NONE} -- Initialization

	make (a_name, a_public_id, a_system_id, a_notation_name: READABLE_STRING_8; a_is_parameter, a_is_unparsed: BOOLEAN)
			-- Create external entity metadata.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
			system_id_not_empty: not a_system_id.is_empty
			notation_name_attached: a_notation_name /= Void
			unparsed_only_for_general: a_is_unparsed implies not a_is_parameter
		do
			create name.make_from_string (a_name)
			create public_id.make_from_string (a_public_id)
			create system_id.make_from_string (a_system_id)
			create notation_name.make_from_string (a_notation_name)
			is_parameter := a_is_parameter
			is_unparsed := a_is_unparsed
		ensure
			name_set: name.same_string (a_name)
			public_id_set: public_id.same_string (a_public_id)
			system_id_set: system_id.same_string (a_system_id)
			notation_name_set: notation_name.same_string (a_notation_name)
			parameter_set: is_parameter = a_is_parameter
			unparsed_set: is_unparsed = a_is_unparsed
		end

feature -- Access

	name: STRING_8
			-- Entity name.

	public_id: STRING_8
			-- Public identifier, or empty string.

	system_id: STRING_8
			-- System identifier.

	notation_name: STRING_8
			-- Notation name for unparsed entities, or empty string.

	is_parameter: BOOLEAN
			-- Is this a parameter entity?

	is_unparsed: BOOLEAN
			-- Is this an unparsed external general entity?

invariant
	name_attached: name /= Void
	name_not_empty: not name.is_empty
	public_id_attached: public_id /= Void
	system_id_attached: system_id /= Void
	system_id_not_empty: not system_id.is_empty
	notation_name_attached: notation_name /= Void
	unparsed_only_for_general: is_unparsed implies not is_parameter

end

