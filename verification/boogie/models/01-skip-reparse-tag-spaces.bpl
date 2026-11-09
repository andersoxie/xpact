// XP_NATIVE_PARSER.skip_reparse_tag_spaces (src/xp_native_parser.e:2072, f067a9d)
//
//   require valid_start: a_start_index >= 1 and a_start_index <= a_end_index
//           valid_end:   a_end_index <= a_input.count
//   from Result := a_start_index
//   until Result >= a_end_index or else not is_reparse_tag_space (a_input.item (Result))
//   loop Result := Result + 1
//   variant a_end_index - Result end
//   ensure result_in_bounds: Result >= a_start_index and Result <= a_end_index
//
// Checks: every item (Result) is in bounds, the variant is >= 0 and
// decreases on every iteration, and the postcondition holds.

procedure skip_reparse_tag_spaces(s: [int]int, n: int, a_start_index: int, a_end_index: int)
  returns (Result: int)
  requires a_start_index >= 1 && a_start_index <= a_end_index;   // valid_start
  requires a_end_index <= n;                                      // valid_end
  ensures  Result >= a_start_index && Result <= a_end_index;      // result_in_bounds
{
  var v_old: int;
  Result := a_start_index;
  while (true)
    invariant a_start_index <= Result && Result <= a_end_index;
    invariant a_end_index - Result >= 0;                          // variant non-negative
  {
    // until-condition, with Eiffel's short-circuit `or else`
    if (Result >= a_end_index) { break; }
    assert 1 <= Result && Result <= n;                            // item (Result): valid_index
    if (!IsSpace(s[Result])) { break; }
    v_old := a_end_index - Result;
    Result := Result + 1;
    assert a_end_index - Result < v_old;                          // variant decreases
  }
}
