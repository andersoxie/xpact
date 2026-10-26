note
	description: "Raw core parser with no-op data events and no external resource loader."

class
	DW_CORE_PARSER

inherit
	XT_XML_PARSER_BASE

	XT_DEFAULT_PARSE_EVENTS
		rename
			on_attribute_list_declaration_ as on_attribute_list_declaration,
			on_cdata_section_start_ as on_cdata_section_start,
			on_cdata_section_end_ as on_cdata_section_end,
			on_comment_ as on_comment,
			on_content_ as on_content,
			on_default_ as on_default,
			on_doctype_declaration_start_ as on_doctype_declaration_start,
			on_element_declaration_ as on_element_declaration,
			on_element_start_ as on_element_start,
			on_element_end_ as on_element_end,
			on_entity_declaration_ as on_entity_declaration,
			on_external_entity_reference_ as on_external_entity_reference,
			on_namespace_declaration_end_ as on_namespace_declaration_end,
			on_namespace_declaration_start_ as on_namespace_declaration_start,
			on_not_standalone_ as on_not_standalone,
			on_notation_declaration_ as on_notation_declaration,
			on_processing_instruction_ as on_processing_instruction,
			on_skipped_entity_ as on_skipped_entity,
			on_unknown_encoding_ as on_unknown_encoding,
			on_unparsed_entity_declaration_ as on_unparsed_entity_declaration,
			on_xml_declaration_ as on_xml_declaration
		end

create
	make

end
