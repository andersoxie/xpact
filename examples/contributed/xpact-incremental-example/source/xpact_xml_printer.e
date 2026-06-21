note
	description: "[
		Concrete incremental XML parser that prints element names, attribute
		name/value pairs, and character data to standard output.
	]"
	notes: "[
		**EXAMPLE OUTPUT**
		
			Parsing: data/sample.xml
			bookstore:
			COMMENT: Test data for the billion-user project xpact
			book:
			   ATTRIBUTES: {category : "cooking"}
			title:
			   ATTRIBUTES: {lang : "en"}
			   "Everyday Italian"
			author:
			   "Giada De Laurentiis"
			price:
			   30.00
			book:
			   ATTRIBUTES: {category : "children"}
			title:
			   ATTRIBUTES: {lang : "en"}
			COMMENT: Test leading/trailing space adjust
			   "Harry Potter"
			author:
			   "J K. Rowling"
			price:
			   29.99
			dvd:
			   ATTRIBUTES: {region : "2", format : "PAL"}

	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 18:21:11 GMT (Saturday 20th June 2026)"
	revision: "1"

class XPACT_XML_PRINTER

inherit
	XPACT_INCREMENTAL_PARSER

create make

feature {NONE} -- Event handlers

	on_comment (text: C_STRING_8)
		do
			io.put_string ("COMMENT: ")
			io.put_string (text.to_string)
			io.put_new_line
		end

	on_content (text_intervals: EL_ARRAYED_INTERVAL_LIST)
		local
			is_double: BOOLEAN
		do
			if attached adjusted_concatenation (text_intervals) as str and then str.count > 0 then
				is_double := str.is_double
				io.put_string (Tab_string)
				if cdata_pending then
					io.put_string ("CDATA: ")
				end
				if not is_double then
					io.put_character ('"')
				end
				io.put_string (str)
				if not is_double then
					io.put_character ('"')
				end
				io.put_new_line
			end
		end

	on_tag_attributes (list: XPACT_ATTRIBUTE_LIST)
		do
			from list.start until list.after loop
				if list.is_first then
					io.put_string (Tab_string)
					io.put_string ("ATTRIBUTES: {")
				else
					io.put_string (", ")
				end
				io.put_string (list.name_item)
				io.put_string (" : %"")
				io.put_string (buffer_substring (list.item_lower, list.item_upper))
				io.put_character ('"')
				list.forth
			end
			io.put_character ('}')
			io.put_new_line
		end

	on_tag_end (name: STRING_8)
		do
		end

	on_tag_start (name: STRING_8; is_empty: BOOLEAN)
		do
			io.put_string (name)
			io.put_character (':')
			io.put_new_line
		end

feature {NONE} -- Constants

	Tab_string: STRING
		once
			create Result.make_filled (' ', 3)
		end

end
