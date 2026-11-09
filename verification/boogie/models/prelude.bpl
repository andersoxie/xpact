// Shared model of an Eiffel READABLE_STRING_8 and the character tests
// used by XP_NATIVE_PARSER (andersoxie/xpact incremental-test @ f067a9d).
//
// A string is a map s: [int]int (character codes) plus its count n.
// a_input.item (i) has the precondition valid_index: 1 <= i <= n,
// which every model checks with an explicit `assert`.

// XML whitespace in a start tag: ' ' %T %N %R  (is_reparse_tag_space)
function IsSpace(c: int): bool { c == 32 || c == 9 || c == 10 || c == 13 }

// Attribute quote: " or '  (is_reparse_tag_quote)
function IsQuote(c: int): bool { c == 34 || c == 39 }

// XP_ATTRIBUTES.is_name_start_character / is_name_character:
// left uninterpreted, so the proof holds for ANY definition of them.
function IsNameStart(c: int): bool;
function IsNameChar(c: int): bool;

const LT: int;    axiom LT == 60;     // '<'
const GT: int;    axiom GT == 62;     // '>'
const SLASH: int; axiom SLASH == 47;  // '/'
const EQ: int;    axiom EQ == 61;     // '='
