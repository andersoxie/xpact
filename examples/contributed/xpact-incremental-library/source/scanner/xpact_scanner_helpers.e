note
	description: "[
		Primitive byte-level operations shared by all scanner mixin classes.

		Scanner mixins inherit this class to obtain `byte_type', `char_at',
		`next_token_index', and the multi-byte name-character checks.  The
		concrete encoding provides effective implementations.

		The C macros this replaces:
		  BYTE_TYPE(enc, p)         -> byte_type (buf, index)
		  BYTE_TO_ASCII(enc, p)     -> char_at (buf, index)
		  CHAR_MATCHES(enc, p, c)   -> char_at (buf, index) = c
		  MINBPC(enc)               -> min_bytes_per_char
		  HAS_CHAR(enc, p, end)     -> index < a_end   (written inline)
		  HAS_CHARS(enc, p, end, n) -> a_end - index >= n * min_bytes_per_char
		  IS_NAME_CHAR(enc, p, n)   -> is_name_char_n (buf, index)
		  IS_NMSTRT_CHAR(enc, p, n) -> is_name_start_char_n (buf, index)
		  IS_INVALID_CHAR(enc, p, n)-> is_invalid_char_n (buf, index)
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:20:51 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XPACT_SCANNER_HELPERS

inherit
	XPACT_BYTE_TYPE_CONSTANTS
	XPACT_TOKEN_CONSTANTS

feature -- Output of the last scan (shared with XPACT_ENCODING via join)

	next_token_index: INTEGER

feature -- Primitive queries (deferred; provided by XPACT_NORMAL_ENCODING)

	min_bytes_per_char: INTEGER
		deferred
		ensure positive: Result >= 1
		end

	byte_type (buf: SPECIAL [CHARACTER]; index: INTEGER): INTEGER
			-- Byte-type category of the byte at buf[index].
		require
			valid_index: index >= 0 and index < buf.count
		deferred
		end

feature -- Multi-byte name-character checks

-- UTF-8; deferred for UTF-16/etc.
-- never called for single-byte encoding

	is_name_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True when the 2-byte UTF-8 sequence at index is an XML name character.
		require
			valid_index: index + 1 < buf.count
		do
			Result := False
		end

	is_name_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True when the 3-byte UTF-8 sequence at index is an XML name character.
		require
			valid_index: index + 2 < buf.count
		do
			Result := False
		end

	is_name_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True when the 4-byte UTF-8 sequence at index is an XML name character.
		require
			valid_index: index + 3 < buf.count
		do
			Result := False
		end

	is_name_start_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True when the 2-byte UTF-8 sequence at index can start an XML name.
		require
			valid_index: index + 1 < buf.count
		do
			Result := False
		end

	is_name_start_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 2 < buf.count
		do
			Result := False
		end

	is_name_start_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 3 < buf.count
		do
			Result := False
		end

	is_invalid_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True when the 2-byte sequence at index is not a valid Unicode scalar.
		require
			valid_index: index + 1 < buf.count
		do
			Result := False
		end

	is_invalid_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 2 < buf.count
		do
			Result := False
		end

	is_invalid_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 3 < buf.count
		do
			Result := False
		end

feature {NONE} -- Inline helpers (correspond to C macros)

	advance (index: INTEGER): INTEGER
			-- index + min_bytes_per_char  (replaces index += MINBPC)
		do
			Result := index + min_bytes_per_char
		end

	has_chars (a_end, index, count: INTEGER): BOOLEAN
			-- a_end - index >= count * min_bytes_per_char  (HAS_CHARS macro)
		do
			Result := a_end - index >= count * min_bytes_per_char
		end

feature {XPACT_INCREMENTAL_PARSER} -- Deferred

	byte_type_table: SPECIAL [NATURAL_8]
			-- 256-entry table mapping each byte value to its BT_* type.
		deferred
		end
end
