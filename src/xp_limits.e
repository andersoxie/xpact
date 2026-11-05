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

	Default_max_entity_expansion_bytes: INTEGER = 1073741824
			-- Hard cap on the total replacement text processed during one parse (1 GiB). Expat has
			-- no such cap; this one only keeps the 32-bit counter safe. The usual limit is the
			-- amplification rule below (mass-xpact #60).

	Default_amplification_threshold_bytes: INTEGER = 8388608
			-- Expat's billion-laughs activation threshold: output (direct + entity bytes) below this
			-- is never rejected (EXPAT_BILLION_LAUGHS_ATTACK_PROTECTION_ACTIVATION_THRESHOLD_DEFAULT).

	Default_maximum_amplification: REAL_32 = 100.0
			-- Expat's billion-laughs maximum amplification factor, output / direct bytes
			-- (EXPAT_BILLION_LAUGHS_ATTACK_PROTECTION_MAXIMUM_AMPLIFICATION_DEFAULT).

end
