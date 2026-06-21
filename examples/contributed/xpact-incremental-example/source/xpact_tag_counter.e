note
	description: "Count occurrences of tags in a document and display in order of highest count to lowest"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:21:11 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XPACT_TAG_COUNTER

inherit
	XPACT_INCREMENTAL_PARSER
		redefine
			make_default
		end

	XPACT_DEFAULT_PARSE_EVENTS
		rename
			on_comment_ as on_comment,
			on_content_ as on_content,
			on_tag_attributes_ as on_tag_attributes,
			on_tag_end_ as on_tag_end
		end

create
	make

feature {NONE} -- Initialisation

	make_default
		do
			Precursor
			create tag_occurrence_table.make (100)
		end

feature -- Basic operations

	print_stats
		local
			array: SORTABLE_ARRAY [TAG_OCCURRENCE_COUNT]
		do
			if attached tag_occurrence_table.linear_representation as count_list then
				io.put_string ("Tags sorted in order of occurrence count (Highest first)")
				io.put_new_line
				io.put_new_line
				create array.make_from_array (count_list.to_array)
				array.sort
				across array.new_cursor.reversed as tag_count loop
					tag_count.io_print
				end
			end
		end

feature {NONE} -- Event handlers

	on_tag_start (name: STRING_8; is_empty: BOOLEAN)
		do
			if attached tag_occurrence_table as table then
				if not table.has_key (name) then
					table.put (create {TAG_OCCURRENCE_COUNT}.make (name), name)
				end
				table.found_item.increment
			end
		end

feature {NONE} -- Internal attributes

	tag_occurrence_table: HASH_TABLE [TAG_OCCURRENCE_COUNT, STRING]

end
