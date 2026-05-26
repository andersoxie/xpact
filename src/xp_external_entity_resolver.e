note
	description: "Application-provided resolver for xpact external entities."

deferred class
	XP_EXTERNAL_ENTITY_RESOLVER

feature -- Resolution

	last_resolution_is_external_child_parse: BOOLEAN
			-- Did the last resolution return parser-control text after
			-- delegating the entity body to an external child parser?
		do
		end

	last_resolution_replacement_byte_count: INTEGER
			-- Logical replacement byte count from the last resolution.
		do
		ensure
			non_negative: Result >= 0
		end

	set_next_resolution_is_parameter_literal (a_enabled: BOOLEAN)
			-- Mark whether the next parameter entity resolution is inside an entity literal.
		do
		ensure
			accepted: True
		end

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
			-- Replacement text for external entity, or Void to deny/not-found.
			--
			-- xpact never opens files or network resources itself. Implementations decide
			-- which system identifiers are allowed and return the already-loaded text.
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
			public_id_attached: a_public_id /= Void
			system_id_attached: a_system_id /= Void
			system_id_not_empty: not a_system_id.is_empty
		deferred
		end

end
