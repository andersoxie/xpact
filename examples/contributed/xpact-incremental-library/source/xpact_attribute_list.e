note
	description: "Parsed attribute name value pairs"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 19:49:24 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XPACT_ATTRIBUTE_LIST

inherit
	EL_ARRAYED_INTERVAL_LIST
		rename
			extend as extend_interval_list,
			isfirst as is_first
		export
			{NONE} all
			{ANY} is_first, forth
		redefine
			make, wipe_out
		end

create
	make

feature {NONE} -- Initialization

	make (n: INTEGER)
		do
			Precursor (n)
			create name_area.make_empty (n)
		end

feature -- Access

	name_item: STRING
		require
			not_off: not off
		do
			Result := name_area [index - 1]
		end

feature -- Element change

	extend (name: STRING; a_lower, a_upper: INTEGER)
		local
			i: INTEGER; l_area: like area_v2
		do
			i := count * 2 + 2
			l_area := area_v2
			if i > l_area.capacity then
				l_area := l_area.aliased_resized_area (i + additional_space)
				area_v2 := l_area
				name_area := name_area.aliased_resized_area (l_area.capacity + 1 // 2)
			end
			l_area.extend (a_lower); l_area.extend (a_upper); name_area.extend (name)
		end

feature -- Removal

	wipe_out
			-- Remove all items.
		do
			Precursor
			name_area.wipe_out
		end

feature {NONE} -- Internal attributes

	name_area: SPECIAL [STRING]
end