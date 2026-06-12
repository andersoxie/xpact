note
	description: "AutoTest-generated cases for XP_CONTENT_MODEL."
	testing: "type/generated"

class
	XP_GENERATED_CONTENT_MODEL_TESTS

inherit
	EQA_GENERATED_TEST_SET

create
	default_create

feature -- Generated tests

	test_leaf_content_model
		local
			l_model: XP_CONTENT_MODEL
		do
			create l_model.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_none, "item")
			assert ("type set", l_model.content_type = {XP_CONTENT_MODEL}.Type_name)
			assert ("quantifier set", l_model.quantifier = {XP_CONTENT_MODEL}.Quant_none)
			assert ("name copied", attached l_model.name as l_name and then l_name.same_string ("item"))
			assert ("leaf has one node", l_model.node_count = 1)
			assert ("leaf has no children", l_model.children.count = 0)
		end

	test_nested_content_model_node_count
		local
			l_root: XP_CONTENT_MODEL
			l_choice: XP_CONTENT_MODEL
			l_name: XP_CONTENT_MODEL
		do
			create l_root.make ({XP_CONTENT_MODEL}.Type_sequence, {XP_CONTENT_MODEL}.Quant_none, Void)
			create l_choice.make ({XP_CONTENT_MODEL}.Type_choice, {XP_CONTENT_MODEL}.Quant_optional, Void)
			create l_name.make ({XP_CONTENT_MODEL}.Type_name, {XP_CONTENT_MODEL}.Quant_plus, "chapter")

			l_choice.add_child (l_name)
			l_root.add_child (l_choice)
			l_root.add_child (create {XP_CONTENT_MODEL}.make ({XP_CONTENT_MODEL}.Type_empty, {XP_CONTENT_MODEL}.Quant_none, Void))

			assert ("root child count", l_root.children.count = 2)
			assert ("nested node count includes descendants", l_root.node_count = 4)
			assert ("child name preserved", attached l_choice.children.i_th (1).name as l_child_name and then l_child_name.same_string ("chapter"))

			l_choice.set_quantifier ({XP_CONTENT_MODEL}.Quant_repetition)
			assert ("quantifier updated", l_choice.quantifier = {XP_CONTENT_MODEL}.Quant_repetition)
		end

	test_content_model_validation_ranges
		local
			l_model: XP_CONTENT_MODEL
		do
			create l_model.make ({XP_CONTENT_MODEL}.Type_any, {XP_CONTENT_MODEL}.Quant_none, Void)
			assert ("lowest type valid", l_model.is_valid_type ({XP_CONTENT_MODEL}.Type_empty))
			assert ("highest type valid", l_model.is_valid_type ({XP_CONTENT_MODEL}.Type_sequence))
			assert ("type below range invalid", not l_model.is_valid_type ({XP_CONTENT_MODEL}.Type_empty - 1))
			assert ("type above range invalid", not l_model.is_valid_type ({XP_CONTENT_MODEL}.Type_sequence + 1))
			assert ("lowest quant valid", l_model.is_valid_quant ({XP_CONTENT_MODEL}.Quant_none))
			assert ("highest quant valid", l_model.is_valid_quant ({XP_CONTENT_MODEL}.Quant_plus))
			assert ("quant below range invalid", not l_model.is_valid_quant ({XP_CONTENT_MODEL}.Quant_none - 1))
			assert ("quant above range invalid", not l_model.is_valid_quant ({XP_CONTENT_MODEL}.Quant_plus + 1))
		end

end
