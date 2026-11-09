// Smoke test: max is correct (should verify); bad_max is wrong (should fail).
procedure max(a: int, b: int) returns (r: int)
  ensures r >= a && r >= b && (r == a || r == b);
{ if (a >= b) { r := a; } else { r := b; } }

procedure bad_max(a: int, b: int) returns (r: int)
  ensures r >= a && r >= b;
{ r := a; }
