note
	description: "AutoTest-generated cases for XP_EXTERNAL_ENTITY and XP_EXTERNAL_ENTITY_POLICY."
	testing: "type/generated"

class
	XP_GENERATED_EXTERNAL_ENTITY_TESTS

inherit
	EQA_GENERATED_TEST_SET

create
	default_create

feature -- Generated tests

	test_external_entity_metadata_is_copied
		local
			l_name: STRING_8
			l_public: STRING_8
			l_system: STRING_8
			l_notation: STRING_8
			l_entity: XP_EXTERNAL_ENTITY
		do
			create l_name.make_from_string ("logo")
			create l_public.make_from_string ("public-id")
			create l_system.make_from_string ("logo.svg")
			create l_notation.make_from_string ("svg")
			create l_entity.make (l_name, l_public, l_system, l_notation, False, True)

			l_name.append ("-changed")
			l_public.append ("-changed")
			l_system.append ("-changed")
			l_notation.append ("-changed")

			assert ("name copied", l_entity.name.same_string ("logo"))
			assert ("public id copied", l_entity.public_id.same_string ("public-id"))
			assert ("system id copied", l_entity.system_id.same_string ("logo.svg"))
			assert ("notation copied", l_entity.notation_name.same_string ("svg"))
			assert ("unparsed general entity", l_entity.is_unparsed and not l_entity.is_parameter)
		end

	test_external_entity_policy_matrix
		local
			l_policy: XP_EXTERNAL_ENTITY_POLICY
		do
			create l_policy
			assert ("no external entities valid", l_policy.is_valid_policy ({XP_EXTERNAL_ENTITY_POLICY}.No_external_entities))
			assert ("general policy valid", l_policy.is_valid_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities))
			assert ("parameter policy valid", l_policy.is_valid_policy ({XP_EXTERNAL_ENTITY_POLICY}.External_parameter_entities))
			assert ("all policy valid", l_policy.is_valid_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities))
			assert ("negative policy invalid", not l_policy.is_valid_policy (-1))
			assert ("above range policy invalid", not l_policy.is_valid_policy ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities + 1))

			assert ("none blocks general", not l_policy.allows_general_entities ({XP_EXTERNAL_ENTITY_POLICY}.No_external_entities))
			assert ("none blocks parameter", not l_policy.allows_parameter_entities ({XP_EXTERNAL_ENTITY_POLICY}.No_external_entities))
			assert ("general allows general only", l_policy.allows_general_entities ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities) and not l_policy.allows_parameter_entities ({XP_EXTERNAL_ENTITY_POLICY}.External_general_entities))
			assert ("parameter allows parameter only", not l_policy.allows_general_entities ({XP_EXTERNAL_ENTITY_POLICY}.External_parameter_entities) and l_policy.allows_parameter_entities ({XP_EXTERNAL_ENTITY_POLICY}.External_parameter_entities))
			assert ("all allows both", l_policy.allows_general_entities ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities) and l_policy.allows_parameter_entities ({XP_EXTERNAL_ENTITY_POLICY}.All_external_entities))
		end

end
