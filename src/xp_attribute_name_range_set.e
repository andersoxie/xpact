note
	description: "Per-start-tag duplicate-name index storing only integer ranges and hashes."

class
	XP_ATTRIBUTE_NAME_RANGE_SET

create {XP_PARSER}
	make

feature {NONE} -- Initialization

	make (a_input: READABLE_STRING_8; a_first_start, a_first_end: INTEGER; a_starts, a_ends: ARRAYED_LIST [INTEGER])
			-- Seed with the distinct names already accepted in this start tag.
		require
			input_attached: a_input /= Void
			first_in_bounds: a_first_start >= 1 and a_first_start <= a_first_end and a_first_end <= a_input.count
			later_names_aligned: a_starts.count = a_ends.count
		local
			i: INTEGER
			l_capacity: INTEGER
			l_duplicate: BOOLEAN
		do
			from l_capacity := 32 until l_capacity // 2 > a_starts.count + 1 loop
				l_capacity := l_capacity * 2
			end
			create starts.make_filled (0, l_capacity)
			create ends.make_filled (0, l_capacity)
			create hashes.make_filled (0, l_capacity)
			l_duplicate := has_or_insert (a_input, a_first_start, a_first_end)
			from i := 1 until i > a_starts.count loop
				l_duplicate := has_or_insert (a_input, a_starts.i_th (i), a_ends.i_th (i))
				i := i + 1
			end
		ensure
			seeded_names: count = a_starts.count + 1
		end

feature {XP_PARSER} -- Duplicate detection

	has_or_insert (a_input: READABLE_STRING_8; a_start, a_end: INTEGER): BOOLEAN
			-- Is this name already present? Otherwise insert its integer range.
			-- `a_input' is used only for this call and is never retained.
		require
			input_attached: a_input /= Void
			range_in_bounds: a_start >= 1 and a_start <= a_end and a_end <= a_input.count
		local
			l_hash: NATURAL_32
			l_slot, l_mask, l_probes: INTEGER
		do
			if count >= starts.count // 2 then
				grow
			end
			l_hash := range_hash (a_input, a_start, a_end)
			l_mask := starts.count - 1
			l_slot := l_hash.bit_and (l_mask.to_natural_32).to_integer_32
			from
			until
				starts.item (l_slot) = 0 or Result
			loop
				if hashes.item (l_slot) = l_hash and then same_range (a_input, a_start, a_end, starts.item (l_slot), ends.item (l_slot)) then
					Result := True
				else
					l_slot := (l_slot + 1).bit_and (l_mask)
				end
				l_probes := l_probes + 1
			variant
				starts.count - l_probes
			end
			if not Result then
				starts.put (a_start, l_slot)
				ends.put (a_end, l_slot)
				hashes.put (l_hash, l_slot)
				count := count + 1
			end
		ensure
			count_changes_only_for_new_name: (Result and count = old count) or else (not Result and count = old count + 1)
		end

	count: INTEGER

feature {NONE} -- Integer metadata

	starts: SPECIAL [INTEGER]
			-- Zero marks an empty slot; XML indices start at one.

	ends: SPECIAL [INTEGER]

	hashes: SPECIAL [NATURAL_32]

	grow
			-- Reinsert cached integer metadata; no input bytes are needed.
		local
			l_old_starts, l_old_ends: SPECIAL [INTEGER]
			l_old_hashes: SPECIAL [NATURAL_32]
			l_capacity, l_mask, l_slot, i, l_probes: INTEGER
		do
			l_old_starts := starts
			l_old_ends := ends
			l_old_hashes := hashes
			l_capacity := starts.count * 2
			create starts.make_filled (0, l_capacity)
			create ends.make_filled (0, l_capacity)
			create hashes.make_filled (0, l_capacity)
			l_mask := l_capacity - 1
			from i := 0 until i = l_old_starts.count loop
				if l_old_starts.item (i) /= 0 then
					l_slot := l_old_hashes.item (i).bit_and (l_mask.to_natural_32).to_integer_32
					from l_probes := 0 until starts.item (l_slot) = 0 loop
						l_slot := (l_slot + 1).bit_and (l_mask)
						l_probes := l_probes + 1
					variant
						l_capacity - l_probes
					end
					starts.put (l_old_starts.item (i), l_slot)
					ends.put (l_old_ends.item (i), l_slot)
					hashes.put (l_old_hashes.item (i), l_slot)
				end
				i := i + 1
			end
		ensure
			same_names: count = old count
			doubled_capacity: starts.count = old starts.count * 2
		end

	range_hash (a_input: READABLE_STRING_8; a_start, a_end: INTEGER): NATURAL_32
			-- FNV-1a over the original UTF-8 name bytes.
			-- A 64-bit intermediate and explicit 32-bit mask avoid arithmetic overflow.
		local
			i: INTEGER
			l_hash: NATURAL_64
		do
			l_hash := Hash_offset
			from i := a_start until i > a_end loop
				l_hash := (l_hash.bit_xor (a_input.item (i).code.to_natural_64) * Hash_prime).bit_and (Hash_mask)
				i := i + 1
			end
			Result := l_hash.to_natural_32
		end

	same_range (a_input: READABLE_STRING_8; a_start, a_end, a_other_start, a_other_end: INTEGER): BOOLEAN
			-- Exact comparison makes full-hash collisions harmless.
		local
			i, j: INTEGER
		do
			if a_end - a_start = a_other_end - a_other_start then
				from Result := True; i := a_start; j := a_other_start until i > a_end or not Result loop
					Result := a_input.item (i) = a_input.item (j)
					i := i + 1
					j := j + 1
				end
			end
		end

	Hash_offset: NATURAL_64 = 2166136261

	Hash_prime: NATURAL_64 = 16777619

	Hash_mask: NATURAL_64 = 0xFFFFFFFF

invariant
	metadata_aligned: starts.count = ends.count and starts.count = hashes.count
	power_of_two: starts.count >= 32 and then starts.count.bit_and (starts.count - 1) = 0
	count_in_bounds: count >= 0 and count <= starts.count // 2

end
