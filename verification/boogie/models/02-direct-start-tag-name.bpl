// XP_NATIVE_PARSER.direct_start_tag_name (src/xp_native_parser.e:1936, f067a9d)
//
// Two declarations:
//  1. direct_start_tag_name: the body, checked against a postcondition that
//     the Eiffel code does NOT state today:
//        ensure short_token_gives_void: Result /= Void implies a_start_index + 1 < a_end_index
//     (plus the facts about '<', '>' and the name start that the body checks).
//  2. direct_start_tag_name_as_written: no body, only the Eiffel contract
//     as it is today (require only, no ensure). A modular verifier such as
//     AutoProof knows nothing more than this at a call site.
//
// Result /= Void is modelled as the boolean `attached`. The name-length
// check against parser.max_name_length is unknown here (havoc).

procedure direct_start_tag_name(s: [int]int, n: int, a_start_index: int, a_end_index: int)
  returns (attached: bool)
  requires a_start_index >= 1 && a_start_index <= n;                  // valid_start
  requires a_end_index >= a_start_index && a_end_index <= n;          // valid_end
  ensures  attached ==> a_start_index + 1 < a_end_index;              // proposed
  ensures  attached ==> s[a_start_index] == LT && s[a_end_index] == GT
                        && IsNameStart(s[a_start_index + 1]);
{
  var i, l_name_start, v_old: int;
  var short_enough: bool;
  attached := false;
  // The `and then' chain: each item call is checked in order.
  assert 1 <= a_start_index && a_start_index <= n;
  if (s[a_start_index] != LT) { return; }
  if (!(a_start_index + 1 < a_end_index)) { return; }
  assert 1 <= a_end_index && a_end_index <= n;
  if (s[a_end_index] != GT) { return; }
  assert 1 <= a_start_index + 1 && a_start_index + 1 <= n;
  if (s[a_start_index + 1] == SLASH || s[a_start_index + 1] == 33 || s[a_start_index + 1] == 63) { return; }

  i := a_start_index + 1;
  assert 1 <= i && i <= n;
  if (IsNameStart(s[i])) {
    l_name_start := i;
    i := i + 1;
    while (true)
      invariant l_name_start < i && i <= a_end_index;
      invariant a_end_index - i >= 0;                                 // variant non-negative
    {
      if (i >= a_end_index) { break; }
      assert 1 <= i && i <= n;
      if (!IsNameChar(s[i])) { break; }
      v_old := a_end_index - i;
      i := i + 1;
      assert a_end_index - i < v_old;                                 // variant decreases
    }
    havoc short_enough;                                               // i - l_name_start <= max_name_length
    if (short_enough) { attached := true; }
  }
}

procedure direct_start_tag_name_as_written(s: [int]int, n: int, a_start_index: int, a_end_index: int)
  returns (attached: bool);
  requires a_start_index >= 1 && a_start_index <= n;
  requires a_end_index >= a_start_index && a_end_index <= n;
