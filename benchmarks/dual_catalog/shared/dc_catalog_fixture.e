note
	description: "Fixed input and independent event oracle for the first dual-implementation lane."

class
	DC_CATALOG_FIXTURE

feature -- Fixed workload

	catalog: STRING_8
		local
			i: INTEGER
		once
			create Result.make (2611)
			Result.append ("<catalog>")
			from i := 1 until i > 100 loop
				Result.append ("<item id=%"")
				Result.append_integer (i)
				Result.append ("%">value</item>")
				i := i + 1
			end
			Result.append ("</catalog>")
		end

	expected_trace: STRING_8
			-- Expected names, attribute values, text and event order; not parser-derived.
		local
			i: INTEGER
		once
			create Result.make (6000)
			Result.append ("S|catalog|0|=%N")
			from i := 1 until i > 100 loop
				Result.append ("S|item|1|id=")
				Result.append_integer (i)
				Result.append ("%NT|value%NE|item%N")
				i := i + 1
			end
			Result.append ("E|catalog%N")
		end

	malformed: STRING_8 = "<catalog><item></catalog>"

end
