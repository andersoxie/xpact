// XP_NATIVE_PARSER.direct_start_tag_attributes (src/xp_native_parser.e:1975, f067a9d)
// The routine where issue #3 ("Non-decreasing loop variant") happened.
//
// Two switches, set by one of the config-*.bpl files:
//   FIXED      true  = outer variant after the #3 fix (d9f662f):  a_end_index - i + l_valid.to_integer
//              false = outer variant before the fix:               a_end_index - i
//   NAME_POST  true  = the call to direct_start_tag_name may use its proposed postcondition
//              false = only the Eiffel contract as written today (no postcondition)
//
// Checks: every a_input.item (i) is in bounds, every call meets the callee's
// precondition, and every loop variant is >= 0 and decreases each iteration.
// skip_reparse_tag_spaces is used only through its contract (01-*.bpl).
// l_value.has ('&') or else l_attributes.has (l_name) is unknown (havoc).

const FIXED: bool;
const NAME_POST: bool;

function OuterVariant(end_: int, i: int, valid: bool): int
{ if FIXED then end_ - i + (if valid then 1 else 0) else end_ - i }

procedure direct_start_tag_attributes(s: [int]int, n: int, a_start_index: int, a_end_index: int)
  returns (has_result: bool)
  requires a_start_index >= 1 && a_start_index <= n;                  // valid_start
  requires a_end_index >= a_start_index && a_end_index <= n;          // valid_end
{
  var attached, l_valid, l_done, rejected: bool;
  var i, l_name_start, l_value_start, l_quote, v_old, w_old: int;

  has_result := false;
  if (NAME_POST) {
    call attached := direct_start_tag_name(s, n, a_start_index, a_end_index);
  } else {
    call attached := direct_start_tag_name_as_written(s, n, a_start_index, a_end_index);
  }
  if (!attached) { return; }

  l_valid := true;
  l_done := false;
  i := a_start_index + 2;

  // Loop 1: skip the rest of the element name.
  while (true)
    invariant a_end_index - i >= 0;                                   // variant non-negative
    invariant a_start_index + 2 <= i;
  {
    if (i >= a_end_index) { break; }
    assert 1 <= i && i <= n;                                          // item (i)
    if (!IsNameChar(s[i])) { break; }
    v_old := a_end_index - i;
    i := i + 1;
    assert a_end_index - i < v_old;                                   // variant decreases
  }

  // Loop 2: the attributes.
  while (true)
    invariant OuterVariant(a_end_index, i, l_valid) >= 0;             // variant non-negative
    invariant a_start_index + 2 <= i && i <= a_end_index;
  {
    if (i >= a_end_index || !l_valid || l_done) { break; }
    v_old := OuterVariant(a_end_index, i, l_valid);

    call i := skip_reparse_tag_spaces(s, n, i, a_end_index);
    if (i >= a_end_index) {
      l_done := true;
    } else {
      assert 1 <= i && i <= n;
      if (s[i] == SLASH) {
        l_valid := false;
      } else if (!IsNameStart(s[i])) {
        l_valid := false;
      } else {
        l_name_start := i;
        i := i + 1;
        // Loop 3: the attribute name.
        while (true)
          invariant a_end_index - i >= 0;
          invariant l_name_start < i;
        {
          if (i >= a_end_index) { break; }
          assert 1 <= i && i <= n;
          if (!IsNameChar(s[i])) { break; }
          w_old := a_end_index - i;
          i := i + 1;
          assert a_end_index - i < w_old;
        }
        call i := skip_reparse_tag_spaces(s, n, i, a_end_index);
        if (i >= a_end_index) {
          l_valid := false;
        } else {
          assert 1 <= i && i <= n;
          if (s[i] != EQ) {
            l_valid := false;
          } else {
            call i := skip_reparse_tag_spaces(s, n, i + 1, a_end_index);
            if (i >= a_end_index) {
              l_valid := false;
            } else {
              assert 1 <= i && i <= n;
              if (!IsQuote(s[i])) {
                l_valid := false;
              } else {
                l_quote := s[i];
                l_value_start := i + 1;
                i := i + 1;
                // Loop 4: the attribute value.
                while (true)
                  invariant a_end_index - i >= 0;
                  invariant l_value_start <= i;
                {
                  if (i >= a_end_index) { break; }
                  assert 1 <= i && i <= n;
                  if (s[i] == l_quote) { break; }
                  w_old := a_end_index - i;
                  i := i + 1;
                  assert a_end_index - i < w_old;
                }
                if (i >= a_end_index) {
                  l_valid := false;
                } else {
                  havoc rejected;                                     // has '&' or duplicate name
                  if (rejected) {
                    l_valid := false;
                  } else {
                    i := i + 1;
                  }
                }
              }
            }
          }
        }
      }
    }
    assert OuterVariant(a_end_index, i, l_valid) < v_old;             // variant decreases
  }
  if (l_valid && i == a_end_index) { has_result := true; }
}
