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
			create names.make (8)
			id_attribute_index := -1
		ensure
			empty: count = 0
			no_specified_attributes: specified_attribute_count = 0
			no_id_attribute: id_attribute_index = -1
		end

feature -- Access

	count: INTEGER
			-- Number of attributes.
		do
			Result := table.count
		ensure
			non_negative: Result >= 0
		end

	specified_attribute_count: INTEGER
			-- Number of attributes explicitly present in the document.

	id_attribute_index: INTEGER
			-- Zero-based name slot in an Expat-style attribute vector, or -1.

	has (a_name: READABLE_STRING_8): BOOLEAN
			-- Does `a_name' exist?
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := table.has (l_name)
		end

	item (a_name: READABLE_STRING_8): detachable STRING_8
			-- Value for `a_name', if present.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		local
			l_name: STRING_8
		do
			create l_name.make_from_string (a_name)
			Result := table.item (l_name)
		end

	i_th_name (i: INTEGER): STRING_8
			-- Attribute name at insertion index `i'.
		require
			valid_index: i >= 1 and i <= count
		do
			Result := names.i_th (i)
		ensure
			result_attached: Result /= Void
			name_not_empty: not Result.is_empty
		end

	i_th_value (i: INTEGER): STRING_8
			-- Attribute value at insertion index `i'.
		require
			valid_index: i >= 1 and i <= count
		do
			check attached table.item (i_th_name (i)) as l_value then
				Result := l_value
			end
		ensure
			result_attached: Result /= Void
		end

feature {XP_PARSER} -- Parser insertion

	has_string (a_name: STRING_8): BOOLEAN
			-- Does `a_name' exist?
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		do
			Result := table.has (a_name)
		end

	put_owned (a_name, a_value: STRING_8)
			-- Add explicit parser-owned attribute strings without cloning them.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			value_attached: a_value /= Void
			not_full: count < Default_max_attribute_count
			not_duplicate: not has_string (a_name)
		do
			table.put (a_value, a_name)
			names.extend (a_name)
			specified_attribute_count := specified_attribute_count + 1
		ensure
			one_more: count = old count + 1
			one_more_specified: specified_attribute_count = old specified_attribute_count + 1
			inserted: has_string (a_name)
		end

feature -- Element change

	put (a_name, a_value: READABLE_STRING_8)
			-- Add explicit attribute `a_name' with `a_value'.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
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
			names.extend (l_name)
			specified_attribute_count := specified_attribute_count + 1
		ensure
			one_more: count = old count + 1
			one_more_specified: specified_attribute_count = old specified_attribute_count + 1
			inserted: has (a_name)
		end

	put_default (a_name, a_value: READABLE_STRING_8)
			-- Add DTD default attribute `a_name' with `a_value'.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
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
			names.extend (l_name)
		ensure
			one_more: count = old count + 1
			specified_unchanged: specified_attribute_count = old specified_attribute_count
			inserted: has (a_name)
		end

	mark_id_attribute (a_name: READABLE_STRING_8)
			-- Mark `a_name' as the ID attribute in the Expat-style vector.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			present: has (a_name)
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= count + 1
			until
				i > count
			loop
				if i_th_name (i).same_string (a_name) then
					id_attribute_index := (i - 1) * 2
					i := count + 1
				else
					i := i + 1
				end
			variant
				count - i + 1
			end
		ensure
			id_attribute_found: id_attribute_index >= 0
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
			Result := is_name_start_character (c) or c.is_digit or c = '-' or c = '.' or l_code = 183 or else (l_code >= 128 and l_code <= 191)
		end

feature {NONE} -- Implementation

	table: HASH_TABLE [STRING_8, STRING_8]
			-- Values keyed by attribute name.

	names: ARRAYED_LIST [STRING_8]
			-- Attribute names in parser insertion order.

invariant
	table_attached: table /= Void
	names_attached: names /= Void
	count_within_limit: count <= Default_max_attribute_count
	specified_count_valid: specified_attribute_count >= 0 and specified_attribute_count <= count
	id_attribute_index_valid: id_attribute_index = -1 or else (id_attribute_index >= 0 and id_attribute_index \\ 2 = 0 and id_attribute_index < count * 2)
	table_names_count_match: table.count = names.count

end
