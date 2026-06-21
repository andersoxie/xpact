note
	description: "[
		A fast lookup cache of name strings that will enable fast C strlen in library client
		due to L1/L2 caching on CPU.
	]"
	notes: "[
		Largest vocabularies:  100 to 500 names

		XHTML/HTML5 as XML, around 120 element types
		TEI (Text Encoding Initiative): a scholarly text markup standard with over 500 element types, widely used in digital humanities
		DITA (Darwin Information Typing Architecture): technical documentation format with 200+ element types
		UBL (Universal Business Language): XML standard for business documents with hundreds of element types across many schemas
		HL7 FHIR XML:  healthcare data interchange with hundreds of resource types

		The maths for 512 buckets

		10 names across 512 buckets: average 0.02 per bucket, virtually every lookup hits an empty bucket immediately
		50 names across 512 buckets:  average 0.1 per bucket, collisions extremely rare
		200 names across 512 buckets:  average 0.4 per bucket, most buckets still empty or single entry
		500 names across 512 buckets: average 1.0 per bucket, linear search of 1-2 entries is essentially free

		At 512 buckets long linear searchs essentially never triggers, even for the largest realistic vocabularies every bucket
		has 0, 1, or occasionally 2 entries. The Linear_search_count threshold of 10 becomes largely irrelevant because no
		bucket ever gets close to it. The memory cost is genuinely negligible
	]"
	author: "Finnian Reilly`"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-06-20 6:31:14 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XPACT_NAME_CACHE

inherit
	ARRAY [ARRAYED_LIST [STRING]]
		rename
			make as make_array,
			item as cache_item,
			count as array_count
		export
			{NONE} all
		end

	STRING_HANDLER
		undefine
			copy, is_equal
		end

create
	make

feature {NONE} -- Initialization

	make
			-- Allocate empty array starting at `1'.
		do
			make_filled (Default_list, 1, Size)
		end

feature -- Access

	item (buffer: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): STRING
		local
			i, bucket_count, count: INTEGER; bucket_list: like cache_item; found: BOOLEAN
		do
			i := bucket_hash (buffer, start_index, end_index)
			bucket_list := area [i]
			if bucket_list.is_empty then
				create bucket_list.make (2)
				area [i] := bucket_list

				Result := buffer_string_8 (buffer, start_index, end_index)
				bucket_list.extend (Result)

			elseif attached bucket_list.area as l_area then
			-- search for match
				bucket_count := bucket_list.count
				from i := 0 until i = bucket_count or found loop
					count := end_index - start_index + 1
					if attached l_area [i] as name and then name.count = count
						and then same_string (buffer, start_index, count, name)
					then
						Result := name; found := True
					else
						i := i + 1
					end
				end
			-- Add to bucket if not found
				if not found then
					Result := buffer_string_8 (buffer, start_index, end_index)
					bucket_list.extend (Result)
				end
			end
		end

feature {XPACT_STRING_BUFFERS} -- Implementation

	buffer_string_8 (buffer: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): STRING_8
			-- Buffer bytes [start_index .. end_index) as a STRING_8.
			-- UTF-8 bytes are copied as-is; correct on UTF-8 terminals.
		local
			count: INTEGER
		do
			count := end_index - start_index + 1
			create Result.make (count)
			Result.area.copy_data (buffer, start_index, 0, count)
			Result.set_count (count)
		end

feature {NONE} -- Implementation

	bucket_hash (buffer: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
		-- very fast well distributed hash with only 3 components
		local
			first, last, count: INTEGER
		do
			first := buffer [start_index].code
			last := buffer [end_index].code
			count := end_index - start_index + 1
			Result := (first |<< 4).bit_xor ((last |<< 1).bit_xor (count)) \\ Size
		end

	same_string (buffer: SPECIAL [CHARACTER]; start_index, count: INTEGER; name: STRING_8): BOOLEAN
		require
			same_size: count = name.count
		local
			i: INTEGER
		do
			if attached name.area as l_area then
				Result := True
				from i := 0 until i = count or not Result loop
					if l_area [i] = buffer [start_index + i] then
						i := i + 1
					else
						Result := False
					end
				end
			end
		end

feature {NONE} -- Constants

	Size: INTEGER = 512

	Default_list: ARRAYED_LIST [STRING]
		once ("PROCESS")
			create Result.make (0)
		end
end
