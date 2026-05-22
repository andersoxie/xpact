note
	description: "External entity loading policy constants for xpact."

class
	XP_EXTERNAL_ENTITY_POLICY

feature -- Policies

	No_external_entities: INTEGER = 0
			-- Do not resolve any external entity.

	External_general_entities: INTEGER = 1
			-- Resolve external general entities only.

	External_parameter_entities: INTEGER = 2
			-- Resolve external parameter entities and external DTD subsets only.

	All_external_entities: INTEGER = 3
			-- Resolve external general and parameter entities.

feature -- Status

	is_valid_policy (a_policy: INTEGER): BOOLEAN
			-- Is `a_policy' one of the supported constants?
		do
			Result := a_policy = No_external_entities or a_policy = External_general_entities or a_policy = External_parameter_entities or a_policy = All_external_entities
		end

	allows_general_entities (a_policy: INTEGER): BOOLEAN
			-- Does `a_policy' allow external general entity resolution?
		require
			valid_policy: is_valid_policy (a_policy)
		do
			Result := a_policy = External_general_entities or a_policy = All_external_entities
		end

	allows_parameter_entities (a_policy: INTEGER): BOOLEAN
			-- Does `a_policy' allow external parameter entity and DTD subset resolution?
		require
			valid_policy: is_valid_policy (a_policy)
		do
			Result := a_policy = External_parameter_entities or a_policy = All_external_entities
		end

end

