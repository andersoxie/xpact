note
	description: "Attribute collection delivered with an xpact start-element event."

class
	XP_ATTRIBUTES

inherit
	XP_LIMITS

create
	make

feature {NONE} -- Initialization

	make
		do
			create table.make (8)
		ensure
			empty: count = 0
		end

feature -- Access

	count: INTEGER
			-- Number of attributes.
		do
			Result := table.count
		ensure
			non_negative: Result >= 0
		end

	has (a_name: READABLE_STRING_8): BOOLEAN
			-- Does `a_name' exist?
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := table.has (l_name)
		end

	item (a_name: READABLE_STRING_8): detachable STRING_8
			-- Value for `a_name', if present.
		require
			valid_name: is_valid_name (a_name)
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := table.item (l_name)
		end

feature -- Element change

	put (a_name, a_value: READABLE_STRING_8)
			-- Add attribute `a_name' with `a_value'.
		require
			valid_name: is_valid_name (a_name)
			value_attached: a_value /= Void
			not_full: count < Default_max_attribute_count
			not_duplicate: not has (a_name)
		local
			l_name: STRING_8
			l_value: STRING_8
		do
			create l_name.make_from_string (a_name)
			create l_value.make_from_string (a_value)
			table.put (l_value, l_name)
		ensure
			one_more: count = old count + 1
			inserted: has (a_name)
		end

feature -- Validation

	is_valid_name (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' an XML 1.0 name in the current UTF-8/8-bit token model?
		require
			name_attached: a_name /= Void
		local
			i: INTEGER
		do
			if a_name.count > 0 and then a_name.count <= Default_max_name_length and then is_name_start_character (a_name.item (1)) then
				from
					Result := True
					i := 2
				invariant
					valid_index: i >= 2 and i <= a_name.count + 1
				until
					i > a_name.count or not Result
				loop
					Result := is_name_character (a_name.item (i))
					i := i + 1
				variant
					a_name.count - i + 1
				end
			end
		end

	is_name_start_character (c: CHARACTER_8): BOOLEAN
			-- Is `c' an XML 1.0 name-start character representable in CHARACTER_8?
		local
			l_code: INTEGER
		do
			l_code := c.code
			Result := c.is_alpha or c = '_' or c = ':' or else (l_code >= 192 and l_code <= 255)
		end

	is_name_character (c: CHARACTER_8): BOOLEAN
			-- Is `c' an XML 1.0 name character representable in CHARACTER_8?
		local
			l_code: INTEGER
		do
			l_code := c.code
			Result := is_name_start_character (c) or c.is_digit or c = '-' or c = '.' or l_code = 183
		end

feature {NONE} -- Implementation

	table: HASH_TABLE [STRING_8, STRING_8]
			-- Values keyed by attribute name.

invariant
	table_attached: table /= Void
	count_within_limit: count <= Default_max_attribute_count

end
