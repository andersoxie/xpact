note
	description: "Root for EiffelStudio AutoTest-generated xpact tests."

class
	AUTOTEST

create
	make

feature {NONE} -- Initialization

	make
			-- Run generated tests when launched as a command-line executable.
			-- EiffelStudio AutoTest discovers the same test routines from the test cluster.
		local
			l_attributes: XP_GENERATED_ATTRIBUTE_TESTS
			l_models: XP_GENERATED_CONTENT_MODEL_TESTS
			l_entities: XP_GENERATED_EXTERNAL_ENTITY_TESTS
			l_parser: XP_GENERATED_PARSER_TESTS
		do
			create l_attributes
			l_attributes.test_empty_attribute_collection
			l_attributes.test_attribute_insertion_lookup_and_order
			l_attributes.test_default_attributes_and_id_index
			l_attributes.test_xml_name_validation_edges

			create l_models
			l_models.test_leaf_content_model
			l_models.test_nested_content_model_node_count
			l_models.test_content_model_validation_ranges

			create l_entities
			l_entities.test_external_entity_metadata_is_copied
			l_entities.test_external_entity_policy_matrix

			create l_parser
			l_parser.test_parser_configuration_and_reset
			l_parser.test_markup_prefix_boundaries
			l_parser.test_parse_prefix_accepts_incomplete_final_markup
			l_parser.test_namespace_expansion_and_errors

			io.put_string ("xpact AutoTest generated tests: ok%N")
		end

end
