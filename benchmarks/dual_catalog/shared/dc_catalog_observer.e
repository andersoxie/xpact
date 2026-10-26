note
	description: "Owns copied raw event observations, coalescing only adjacent text callbacks."

class
	DC_CATALOG_OBSERVER

create
	make

feature {NONE} -- Initialization

	make
		do
			create trace.make (6000)
			create pending_text.make (500)
		end

feature -- Observations

	trace: STRING_8

	on_start (name: READABLE_STRING_8; attribute_count: INTEGER; attribute_name, attribute_value: READABLE_STRING_8)
		do
			flush_text
			trace.append ("S|")
			trace.append (name)
			trace.append_character ('|')
			trace.append_integer (attribute_count)
			trace.append_character ('|')
			trace.append (attribute_name)
			trace.append_character ('=')
			trace.append (attribute_value)
			trace.append_character ('%N')
		end

	on_end (name: READABLE_STRING_8)
		do
			flush_text
			trace.append ("E|")
			trace.append (name)
			trace.append_character ('%N')
		end

	on_text (text: READABLE_STRING_8)
		do
			pending_text.append (text)
		end

	on_text_character (c: CHARACTER_8)
		do
			pending_text.append_character (c)
		end

	finish
		do
			flush_text
		end

	reset
		do
			trace.wipe_out
			pending_text.wipe_out
		end

feature {NONE} -- Implementation

	pending_text: STRING_8

	flush_text
		do
			if not pending_text.is_empty then
				trace.append ("T|")
				trace.append (pending_text)
				trace.append_character ('%N')
				pending_text.wipe_out
			end
		end

end
