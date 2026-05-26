note
	description: "Security and resource limits for xpact parsing."

class
	XP_LIMITS

feature -- Defaults

	Default_max_input_bytes: INTEGER = 10485760
			-- 10 MiB default input ceiling for development builds.

	Default_max_element_depth: INTEGER = 256
			-- Maximum nested element depth before parsing is rejected.

	Default_max_attribute_count: INTEGER = 1024
			-- Maximum attributes accepted on a single start tag.

	Default_max_name_length: INTEGER = 4096
			-- Maximum XML name length accepted by the Phase 1 parser.

	Default_max_token_length: INTEGER = 1048576
			-- Maximum text, comment, CDATA, or declaration token length.

	Default_max_entity_depth: INTEGER = 32
			-- Maximum recursive general/parameter entity expansion depth.

	Default_max_entity_expansion_bytes: INTEGER = 8388608
			-- Maximum total replacement text processed during one parse.

end
