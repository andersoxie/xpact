note
	description: "Raw core event observer/no-op sink; avoids the text-normalizing convenience parser."

class
	DC_CORE_PARSER

inherit
	XT_XML_PARSER_BASE

	XT_DEFAULT_PARSE_EVENTS
		rename
			on_attribute_list_declaration_ as on_attribute_list_declaration,
			on_cdata_section_start_ as on_cdata_section_start,
			on_cdata_section_end_ as on_cdata_section_end,
			on_comment_ as on_comment,
			on_default_ as on_default,
			on_doctype_declaration_start_ as on_doctype_declaration_start,
			on_element_declaration_ as on_element_declaration,
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

feature -- Observation selection

	set_observer (a_observer: DC_CATALOG_OBSERVER)
		do
			observer := a_observer
		end

feature {NONE} -- Raw events

	on_element_start (buf: like buffer; context: XT_ELEMENT_CONTEXT; attributes: XT_ATTRIBUTE_LIST; token: INTEGER; parse_data: POINTER)
		do
			if attached observer as o then
				if attributes.count = 1 then
					o.on_start (context.name, attributes.count, attributes.first_name, attributes.first_value (buf))
				else
					o.on_start (context.name, attributes.count, "", "")
				end
			end
		end

	on_element_end (name: STRING_8; parse_data: POINTER)
		do
			if attached observer as o then o.on_end (name) end
		end

	on_content (buf: like buffer; start_index, end_index: INTEGER; parse_data: POINTER)
		local
			i: INTEGER
		do
			if attached observer as o then
				from i := start_index until i > end_index loop
					o.on_text_character (buf [i])
					i := i + 1
				end
			end
		end

feature {NONE} -- Observer is absent in the timed path

	observer: detachable DC_CATALOG_OBSERVER

end
