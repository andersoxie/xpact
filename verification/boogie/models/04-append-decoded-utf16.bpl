// XP_NATIVE_PARSER.append_decoded_utf16 (src/xp_native_parser.e:1616, f067a9d)
// The loop of mass-xpact issue #12 ("loop variant violation on an invalid
// UTF-16 surrogate", fixed in 19ba873).
//
// Switches, set by one of the config-U*.bpl files:
//   U_FIXED  true  = after 19ba873: until i > l_end; on failure  i := l_end + 1
//            false = before:        until i > l_end or not Result; i stays put
//   U_FACTS  true  = assume l_end <= input_buffer.count and decoded_raw_count <= l_end
//                    (true of the code's intent, but stated by NO contract)
//            false = only what the contracts say today
//
// Checks: invariant index_in_bounds, the variant (l_end - i + 1), the
// precondition of every utf16_unit_at call, and the postcondition
// unchanged_on_failure. A UTF-16 unit is any value 0..65535 (havoc).

const U_FIXED: bool;
const U_FACTS: bool;

procedure utf16_unit_at(count: int, a_index: int) returns (unit: int);
  requires a_index >= 1 && a_index + 1 <= count;                     // valid_index
  ensures  0 <= unit && unit <= 65535;

procedure append_decoded_utf16(count: int, l_end: int, decoded_raw_count: int)
  returns (Result: bool, new_raw_count: int)
  requires count >= 0;
  requires decoded_raw_count >= 0;
  requires U_FACTS ==> l_end <= count && decoded_raw_count <= l_end;
  ensures  !Result ==> new_raw_count == decoded_raw_count;           // unchanged_on_failure
{
  var i, l_unit, l_low, v_old: int;
  Result := false;
  new_raw_count := decoded_raw_count;
  // (l_end - decoded_raw_count) \\ 2 = 0  and then  decoded_raw_count >= 2
  if (!((l_end - decoded_raw_count) mod 2 == 0 && decoded_raw_count >= 2)) { return; }

  Result := true;
  i := decoded_raw_count + 1;
  while (true)
    invariant i >= decoded_raw_count + 1 && i <= l_end + 1;          // index_in_bounds (Eiffel)
    invariant l_end - i + 1 >= 0;                                    // variant non-negative
    invariant (i - decoded_raw_count - 1) mod 2 == 0;                // helper: i keeps the parity
    invariant Result || i == l_end + 1 || !U_FIXED;                  // helper
  {
    if (i > l_end) { break; }
    if (!U_FIXED && !Result) { break; }
    v_old := l_end - i + 1;

    call l_unit := utf16_unit_at(count, i);
    if (l_unit >= 55296 && l_unit <= 56319) {
      if (i + 3 > l_end) {
        Result := false;
      } else {
        call l_low := utf16_unit_at(count, i + 2);
        if (l_low < 56320 || l_low > 57343) {
          Result := false;
        } else {
          i := i + 4;
        }
      }
    } else if (l_unit >= 56320 && l_unit <= 57343) {
      Result := false;
    } else {
      i := i + 2;
    }
    if (U_FIXED && !Result) {
      i := l_end + 1;
    }
    assert l_end - i + 1 < v_old;                                    // variant decreases
  }
  if (Result) { new_raw_count := l_end; }
}
