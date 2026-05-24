note
	description: "DTD attribute-list declaration retained by the Eiffel parser."

class
	XP_ATTRIBUTE_DECL

create
	make

feature {NONE} -- Initialization

	make (a_name, a_type: READABLE_STRING_8; a_default_value: detachable READABLE_STRING_8; a_is_required: BOOLEAN)
			-- Create declaration for attribute `a_name'.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			type_attached: a_type /= Void
			type_not_empty: not a_type.is_empty
		do
			create name.make_from_string (a_name)
			create attribute_type.make_from_string (a_type)
			if attached a_default_value as l_default_value then
				create default_value.make_from_string (l_default_value)
			end
			is_required := a_is_required
		ensure
			name_set: name.same_string (a_name)
			type_set: attribute_type.same_string (a_type)
			required_set: is_required = a_is_required
		end

feature -- Access

	name: STRING_8
			-- Attribute name.

	attribute_type: STRING_8
			-- Attribute type spelling.

	default_value: detachable STRING_8
			-- Declared default value, if any.

	is_required: BOOLEAN
			-- Is this a `#REQUIRED' declaration?

	is_id: BOOLEAN
			-- Does this declaration define an ID attribute?
		do
			Result := attribute_type.same_string ("ID")
		end

invariant
	name_attached: name /= Void
	name_not_empty: not name.is_empty
	attribute_type_attached: attribute_type /= Void
	attribute_type_not_empty: not attribute_type.is_empty

end
