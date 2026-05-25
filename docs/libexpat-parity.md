# libexpat Parity Status

Windows Phase 1 no longer uses a suite-wide expected failure for the upstream
libexpat adapter. The broad `*/*` row has been replaced by:

- `adapters/libexpat/expected-failures.tsv`: explicit red expected-failure
  patterns tied to upstream Expat 2.8.1 source files and `START_TEST(...)`
  names.
- `adapters/libexpat/parity.tsv`: green, red, and blocked parity rows for the
  Windows-only native release scope.

The adapter expands those rows against an upstream Expat 2.8.1 checkout:

```powershell
.\scripts\run_libexpat_adapter.ps1 `
  -ExpatSourceDir C:\src\libexpat `
  -Mode Manifest
```

The current upstream manifest has 399 `START_TEST(...)` entries. The explicit
expected-failure patterns expand to 179 named upstream tests in the downloaded
R_2_8_1 sources used for this checkpoint.

## Green Rows

The Windows release has green evidence for:

- loading the Eiffel-backed `xpact.dll` through the public `include/xpact.h`
  ABI;
- `XML_Parse` reaching the Eiffel parser;
- native C callbacks through the Windows MSVC DLL benchmark;
- basic entity, attribute, duplicate-attribute, empty-document, and
  `XML_GetBuffer` / `XML_ParseBuffer` coverage in the Eiffel/native bridge
  path;
- Expat-compatible line, column, and byte index/count reporting after complete
  parses and parse errors;
- non-final native `XML_Parse` chunks accumulated in Eiffel until the final
  chunk, covering upstream single-byte feed helpers for supported syntax;
- native callback forwarding for Eiffel-tokenized comments, processing
  instructions, and CDATA section boundaries;
- handler-time line and column positions during start/end element callbacks;
- handler-time byte index/count and `XML_GetInputContext` windows during
  character-data callbacks;
- default-handler delivery for raw processing-instruction, comment, and CDATA
  section tokens in the Eiffel-backed Windows DLL path;
- doctype start/end callbacks and default-handler replay for public/system
  identifiers;
- internal-subset default-handler whitespace for handled DTD declarations;
- `XML_AttlistDeclHandler` callbacks for ATTLIST enumeration, NOTATION, CDATA,
  and default-value declarations;
- ATTLIST default-attribute merging, first-declaration-wins behavior,
  explicit-attribute counts, and ID attribute indexes for the covered native
  callback path;
- namespace-like default attributes such as `xmlns:e` are kept as ordinary
  attributes when namespace mode is not enabled;
- `XML_SetElementDeclHandler` callbacks with freeable `XML_Content` content
  models for simple and nested sequence/choice/name quantifier declarations;
- `XML_SetNotationDeclHandler` callbacks for `SYSTEM` notation declarations
  and `PUBLIC` notation declarations without system identifiers;
- XML public identifier validation for doctype `PUBLIC` IDs, including
  `XML_ERROR_PUBLICID` mapping through the native C ABI;
- malformed doctype diagnostics for invalid names, malformed UTF-8 byte
  sequences, prefix-conv internal-subset syntax, missing `PUBLIC`/`SYSTEM`
  literals, extra external identifier content, and document-level end tags
  after short doctypes.
- entity declaration callbacks and external general entity callback delegation
  for the native general-entity support path.
- synchronous internal entity replacement text that contributes nested markup
  in content, including the upstream `test_misc_sync_entity_tolerated` shape.
- callback-time `XML_GetInputContext` and `XML_GetCurrentByteCount` values for
  character data emitted from internal entity references, covering upstream
  `test_misc_expected_event_ptr_issue_980`.
- `XML_ERROR_ASYNC_ENTITY` detection for internal parsed entities whose markup
  crosses entity boundaries, covering upstream
  `test_misc_async_entity_rejected`.
- `XML_GetFeatureList` size feature entries for `XML_Char` and `XML_LChar`,
  covering upstream `test_misc_features`.
- Eiffel-owned hash-salt setter contract checks, including null-argument
  rejection, successful repeated pre-parse calls, post-parse rejection, and
  collision-heavy document parsing through the native ABI.
- Eiffel-owned explicit encoding state for `XML_SetEncoding`, covering
  pre-parse UTF-8 configuration, mid-parse change rejection, post-parse unset,
  and unsupported explicit encoding names mapping to
  `XML_ERROR_UNKNOWN_ENCODING`.
- unloaded external general entities are skipped in the Windows native bridge
  when no external entity handler is registered, with
  `XML_SkippedEntityHandler` callback delivery.
- `XML_ExternalEntityParserCreate` accepts a null context, creates
  Eiffel-backed child parsers, and frees those child parsers through the native
  ABI.
- loaded external parsed entity fragments are parsed by Eiffel child parsers
  that inherit element, character-data, and CDATA callbacks from the parent
  parser, covering the upstream `test_ext_entity_good_cdata` shape.
- external entity reference handler arguments now follow Expat's null-argument
  fallback to the public C `XML_Parser` pointer in the Windows native bridge.
- XML declaration parsing is owned by `XP_PARSER`, emits
  `XML_SetXmlDeclHandler` callbacks through the Windows DLL, and maps malformed
  or misplaced declarations to `XML_ERROR_XML_DECL` and
  `XML_ERROR_MISPLACED_XML_PI`.
- the upstream `test_user_parameters` shape now passes through the Windows DLL
  smoke: parser-as-handler-argument callbacks, XML declaration callbacks,
  external subset loading, comments, and skipped entities all receive the
  expected public C parser argument.
- the upstream `test_ext_entity_ref_parameter` shape now passes through the
  Windows DLL smoke for both explicit `XML_SetExternalEntityRefHandlerArg`
  values and the `NULL` fallback to the parser.
- undeclared general entities are skipped or rejected according to Expat's
  external-subset and standalone rules for the covered
  `test_wfc_undeclared_entity_*` cases.
- `XML_NotStandaloneHandler`,
  `XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE`, and the covered
  `XML_UseForeignDTD` cases now pass through the Windows DLL smoke, including
  late-setting rejection, foreign DTD plus internal subset handling, and empty
  foreign DTD undefined-entity rejection.
- parser-create allocator failure/success edges for `XML_ParserCreate_MM`,
  external DTD subset child parsing, external parameter entity
  not-standalone rejection, and invalid tags inside DTD parameter entity
  children now pass through the Windows DLL smoke.
- recursive external parameter entities, undefined external parameter entity
  skipping, DTD stop-after-undefined-parameter-entity behavior, and UTF-8 BOM
  consumption before external subset tokenization now pass through the Windows
  DLL smoke.
- the upstream `test_external_entity_values` shape now passes through the
  Windows DLL smoke, including child text-declaration diagnostics,
  unterminated literal errors, partial UTF-8 tails, BOM-prefixed ATTLIST
  content, and recursive parameter entity context.
- the upstream `test_ext_entity_trailing_*` shapes now pass through the Windows
  DLL smoke: trailing CR and right-square-bracket character data are delivered,
  while incomplete external parsed entity fragments report
  `XML_ERROR_ASYNC_ENTITY`.
- the upstream `test_ext_entity_invalid_parse` shape now passes through the
  Windows DLL smoke: bare external markup reports `XML_ERROR_UNCLOSED_TOKEN`,
  and incomplete UTF-8 in tag-name or character-data positions reports
  `XML_ERROR_PARTIAL_CHAR`.
- the upstream `test_ext_entity_set_*` and `test_ext_entity_bad_encoding*`
  shapes now pass through the Windows DLL smoke: external text declarations can
  use encoding-only form when `XML_SetEncoding` supplies UTF-8, BOM-prefixed
  external input is consumed, and unsupported explicit child encodings map to
  `XML_ERROR_UNKNOWN_ENCODING`.
- UTF-16 byte input is decoded in the Eiffel native parser boundary before the
  existing UTF-8 tokenizer runs. The Windows DLL smoke covers UTF-16BE/LE BOM
  detection, no-BOM UTF-16LE detection, explicit `UTF-16LE` parser creation,
  BMP and surrogate-pair character data, CDATA, malformed surrogate rejection,
  incorrect `encoding='utf-16'` declarations in UTF-8 input, and decoded
  non-ASCII attribute names.
- explicit ISO-8859-1 and UTF-16 external parsed entity child inputs now pass
  through the Eiffel native decoder, including UTF-16-looking BOM bytes under
  Latin-1, explicit endian overrides, invalid no-signal UTF-16-looking bytes,
  and the not-quite UTF-8 BOM character-data case.
- DTD conditional `IGNORE` sections and UTF-16 DTD diagnostics now pass through
  the Eiffel subset parser for the covered upstream UTF-16 cases: conditional
  ignore default text, parameter entity declaration callbacks, invalid ATTLIST
  default keywords, and invalid internal-subset content.
- malformed UTF-16 CDATA prefixes now map to the same
  `XML_ERROR_UNCLOSED_TOKEN`, `XML_ERROR_UNCLOSED_CDATA_SECTION`, and
  `XML_ERROR_PARTIAL_CHAR` diagnostics as upstream Expat's bad CDATA matrix.
- the upstream `test_misc_no_infinite_loop_issue_1161` external-DTD regression
  now passes through the Windows DLL smoke by propagating the nested external
  parameter entity failure to the parent as `XML_ERROR_EXTERNAL_ENTITY_HANDLING`.
- the upstream `test_renter_loop_finite_content` external parsed-entity
  regression now passes through the Windows DLL smoke; child parsers import the
  parent DTD entity context before expanding nested internal entities.
- the upstream `test_entity_public_utf16_*` cases now pass through the Windows
  DLL smoke; UTF-16BE/LE external parameter entity child parsers merge parsed
  general entity declarations back into the parent DTD context.

## Red Rows

The red rows are specific remaining parity gaps, not a suite-wide failure:

- namespace parsing and namespace callback semantics;
- allocation-failure injection and allocation accounting tests;
- remaining external entity abort/suspend semantics;
- remaining external DTD encoding diagnostics and default-handler edge cases;
- DTD default-handler replay and default-current edge cases;
- stop/suspend/resume/abort parser state;
- Expat siphash/reparse-deferral/accounting semantics.

## Blocked Row

The upstream native C suite was not executed in this Windows verification
environment because `cmake` was not on `PATH`. The adapter still generates the
manifest, expected-failure expansion, and parity expansion. Running the native
suite is a toolchain verification step, while the Windows Phase 1 release scope
is now explicit about the green and red parity rows it claims.
