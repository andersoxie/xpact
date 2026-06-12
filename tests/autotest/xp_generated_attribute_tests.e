note
	description: "AutoTest-generated cases for XP_ATTRIBUTES."
	testing: "type/generated"

class
	XP_GENERATED_ATTRIBUTE_TESTS

inherit
	EQA_GENERATED_TEST_SET

create
	default_create

feature -- Generated tests

	test_empty_attribute_collection
		local
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			assert ("count starts at zero", l_attributes.count = 0)
			assert ("specified count starts at zero", l_attributes.specified_attribute_count = 0)
			assert ("id index starts unset", l_attributes.id_attribute_index = -1)
			assert ("unknown attribute absent", not l_attributes.has ("missing"))
			assert ("unknown value is void", l_attributes.item ("missing") = Void)
		end

	test_attribute_insertion_lookup_and_order
		local
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			l_attributes.put ("id", "42")
			l_attributes.put ("kind", "primary")
			l_attributes.put_default ("lang", "en")

			assert ("three attributes recorded", l_attributes.count = 3)
			assert ("only explicit attributes are specified", l_attributes.specified_attribute_count = 2)
			assert ("id present", l_attributes.has ("id"))
			assert ("id value copied", attached l_attributes.item ("id") as l_id and then l_id.same_string ("42"))
			assert ("first insertion name", l_attributes.i_th_name (1).same_string ("id"))
			assert ("second insertion value", l_attributes.i_th_value (2).same_string ("primary"))
			assert ("default insertion follows explicit attributes", l_attributes.i_th_name (3).same_string ("lang"))
		end

	test_default_attributes_and_id_index
		local
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			l_attributes.put_default ("class", "generated")
			l_attributes.put ("id", "root")
			l_attributes.put ("role", "main")
			l_attributes.mark_id_attribute ("id")

			assert ("default does not count as specified", l_attributes.specified_attribute_count = 2)
			assert ("id index uses expat vector slot", l_attributes.id_attribute_index = 2)
			l_attributes.mark_id_attribute ("class")
			assert ("id index can move to first slot", l_attributes.id_attribute_index = 0)
		end

	test_xml_name_validation_edges
		local
			l_attributes: XP_ATTRIBUTES
		do
			create l_attributes.make
			assert ("plain name valid", l_attributes.is_valid_name ("root"))
			assert ("underscore name valid", l_attributes.is_valid_name ("_root"))
			assert ("colon name valid", l_attributes.is_valid_name ("p:root"))
			assert ("hyphen allowed after first character", l_attributes.is_valid_name ("root-node"))
			assert ("empty name invalid", not l_attributes.is_valid_name (""))
			assert ("digit cannot start name", not l_attributes.is_valid_name ("1root"))
			assert ("space invalid in name", not l_attributes.is_valid_name ("root node"))
		end

end
