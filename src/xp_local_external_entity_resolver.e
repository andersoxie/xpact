note
	description: "Original-byte external resource loader confined to one local suite tree."

class
	XP_LOCAL_EXTERNAL_ENTITY_RESOLVER

inherit
	XP_EXTERNAL_ENTITY_RESOLVER
		redefine
			resolve_external_entity_from_base,
			last_resolved_resource
		end
	XP_LIMITS

create
	make

feature {NONE} -- Initialization

	make (a_suite_root: PATH)
		local
			l_root: RAW_FILE
		do
			suite_root := a_suite_root.canonical_path
			create last_error.make_empty
				-- Decide from the path/drive type before any file metadata query can touch a share.
			if is_local_root (suite_root) and then not has_link_component (suite_root) then
				create l_root.make_with_path (suite_root)
				suite_is_usable := l_root.exists and then l_root.is_directory and then l_root.is_readable
			end
			reset
		end

feature -- Access

	suite_root: PATH

	last_error: STRING_8
			-- Resource failures are infrastructure errors, never XML rejection evidence.

	last_resolved_resource: detachable STRING_8

	resolution_count: INTEGER
			-- Requests since `reset', including denied/missing resources.

	reset
			-- Release prior outcome before parsing a new document with the same loader.
		do
			last_resolved_resource := Void
			last_error.wipe_out
			resolution_count := 0
			if not suite_is_usable then
				last_error := "suite root must be a readable ordinary local directory without links/reparse points"
			end
		end

	is_allowed_document (a_path: PATH): BOOLEAN
			-- Is the document itself inside the same ordinary local directory tree?
		do
			Result := suite_is_usable and then is_contained (a_path.canonical_path) and then not has_link_component (a_path.canonical_path)
		end

feature -- Resolution

	resolve_external_entity (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN): detachable STRING_8
		do
			last_resolved_resource := Void
			last_error := "external resource declaration has no document base"
		end

	resolve_external_entity_from_base (a_name, a_public_id, a_system_id: READABLE_STRING_8; a_is_parameter: BOOLEAN; a_base: detachable READABLE_STRING_8): detachable STRING_8
		local
			l_base, l_relative, l_resource: PATH
			l_identifier: STRING_8
		do
			last_resolved_resource := Void
			last_error.wipe_out
			resolution_count := resolution_count + 1
			if not suite_is_usable then
				last_error := "suite root must be a readable ordinary local directory without links/reparse points"
			elseif a_base = Void or else a_base.is_empty or else not {UTF_CONVERTER}.is_valid_utf_8_string_8 (a_base) then
				last_error := "external resource declaration has no valid document base"
			elseif attached decoded_identifier (a_system_id) as l_decoded then
				l_identifier := l_decoded
				create l_relative.make_from_string ({UTF_CONVERTER}.utf_8_string_8_to_string_32 (l_identifier))
				create l_base.make_from_string ({UTF_CONVERTER}.utf_8_string_8_to_string_32 (a_base))
				if l_relative.has_root or else l_identifier.has (':') or else l_identifier.has ('?') or else l_identifier.has ('#') or else not is_safe_relative_name (l_identifier) then
					last_error := "only relative local external resource identifiers are allowed"
				elseif not is_allowed_document (l_base) then
					last_error := "external resource declaration base is outside the suite or contains a link"
				else
					l_resource := l_base.parent.extended_path (l_relative).canonical_path
					if not is_contained (l_resource) or else has_link_component (l_resource) then
						last_error := "external resource escapes the suite or contains a symbolic link/reparse point"
					else
						Result := read_resource (l_resource)
						if Result /= Void then
							last_resolved_resource := {UTF_CONVERTER}.utf_32_string_to_utf_8_string_8 (l_resource.name)
						end
					end
				end
			else
				last_error := "invalid or empty external resource identifier"
			end
		end

feature {NONE} -- Local file boundary

	suite_is_usable: BOOLEAN

	is_local_root (a_root: PATH): BOOLEAN
			-- UNC and mapped network roots are rejected before checking file existence.
		local
			l_native: NATIVE_STRING
		do
			if {PLATFORM}.is_windows then
				if not a_root.name.starts_with ("\\") and then not a_root.name.starts_with ("//") and then attached a_root.root as l_volume then
					create l_native.make (l_volume.name)
					Result := is_local_drive (l_native.item)
				end
			else
				Result := not a_root.name.starts_with ("//")
			end
		end

	is_local_drive (a_root: POINTER): BOOLEAN
		external
			"C inline use %"eif_misc.h%""
		alias
			"[
#ifdef EIF_WINDOWS
	UINT kind = GetDriveTypeW ((LPCWSTR) $a_root);
	return kind == DRIVE_FIXED || kind == DRIVE_REMOVABLE || kind == DRIVE_CDROM || kind == DRIVE_RAMDISK;
#else
	return 1;
#endif
			]"
		end

	is_contained (a_path: PATH): BOOLEAN
		local
			l_root, l_name: STRING_32
			l_separator: CHARACTER_32
		do
			l_root := suite_root.name.twin
			l_name := a_path.name.twin
			if {PLATFORM}.is_windows then
				l_root.to_lower
				l_name.to_lower
				l_separator := '\'
			else
				l_separator := '/'
			end
			if not l_root.is_empty and then l_root.item (l_root.count) /= l_separator then
				l_root.append_character (l_separator)
			end
			Result := l_name.starts_with (l_root)
		end

	has_link_component (a_path: PATH): BOOLEAN
			-- Walk from root to leaf and stop at a link before querying any descendant.
		local
			l_components: ARRAYED_LIST [PATH]
			l_path: PATH
			l_native: NATIVE_STRING
			i: INTEGER
		do
			l_components := a_path.components
			if not l_components.is_empty then
				l_path := l_components.first
				from i := 1 until i > l_components.count or Result loop
					if i > 1 then l_path := l_path.extended_path (l_components.i_th (i)) end
					create l_native.make (l_path.name)
					Result := is_link_path (l_native.item)
					i := i + 1
				end
			end
		end

	is_link_path (a_path: POINTER): BOOLEAN
		external
			"C inline use %"eif_misc.h%", <sys/stat.h>"
		alias
			"[
#ifdef EIF_WINDOWS
	DWORD attributes = GetFileAttributesW ((LPCWSTR) $a_path);
	return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
#else
	struct stat information;
	return lstat ((const char *) $a_path, &information) == 0 && S_ISLNK (information.st_mode);
#endif
			]"
		end

	read_resource (a_path: PATH): detachable STRING_8
		local
			l_file: RAW_FILE
			l_size: INTEGER
		do
			create l_file.make_with_path (a_path)
			if has_link_component (a_path) then
				last_error := "external resource contains a symbolic link/reparse point"
			elseif not l_file.exists or else not l_file.is_plain or else not l_file.is_readable then
				last_error := "external resource is missing, unreadable or not a regular file"
			elseif l_file.count > Default_max_input_bytes then
				last_error := "external resource exceeds the input limit"
			else
				l_file.open_read
				l_size := l_file.count
				if has_link_component (a_path) then
					last_error := "external resource changed to a symbolic link/reparse point"
				else
					create Result.make (l_size)
					from until Result.count >= l_size or else l_file.end_of_file loop
						l_file.read_stream ((l_size - Result.count).min (65536))
						Result.append (l_file.last_string)
					end
					if Result.count /= l_size or else l_file.count /= l_size then
						last_error := "external resource changed while being read"
						Result := Void
					end
				end
				l_file.close
			end
		rescue
			if l_file /= Void and then not l_file.is_closed then l_file.close end
			last_resolved_resource := Void
			last_error := "external resource read failed"
		end

	is_safe_relative_name (a_identifier: STRING_8): BOOLEAN
			-- Win32 trims trailing dots/spaces and recognizes device names before extension.
			-- Reject those aliases before lexical containment can be bypassed.
		local
			l_normalized, l_component, l_stem: STRING_8
			l_dot: INTEGER
		do
			Result := True
			if {PLATFORM}.is_windows then
				l_normalized := a_identifier.twin
				l_normalized.replace_substring_all ("\", "/")
				across l_normalized.split ('/') as part loop
					l_component := part.item
					if not l_component.is_empty and then not l_component.same_string (".") and then not l_component.same_string ("..") then
						if l_component.item (l_component.count) = '.' or l_component.item (l_component.count) = ' ' then Result := False end
						l_dot := l_component.index_of ('.', 1)
						if l_dot > 0 then l_stem := l_component.substring (1, l_dot - 1) else l_stem := l_component.twin end
						l_stem.to_upper
						if l_stem.same_string ("CON") or l_stem.same_string ("PRN") or l_stem.same_string ("AUX") or l_stem.same_string ("NUL") or
							(l_stem.count = 4 and then (l_stem.starts_with ("COM") or l_stem.starts_with ("LPT")) and then l_stem.item (4) >= '1' and then l_stem.item (4) <= '9')
						then Result := False end
					end
				end
			end
		end

	decoded_identifier (a_identifier: READABLE_STRING_8): detachable STRING_8
		local
			i, l_high, l_low, l_code: INTEGER
			l_valid: BOOLEAN
		do
			create Result.make (a_identifier.count)
			l_valid := not a_identifier.is_empty
			from i := 1 until i > a_identifier.count or not l_valid loop
				if a_identifier.item (i).code = 37 then
					if i + 2 <= a_identifier.count then
						l_high := hex_value (a_identifier.item (i + 1))
						l_low := hex_value (a_identifier.item (i + 2))
						l_valid := l_high >= 0 and l_low >= 0
						l_code := l_high * 16 + l_low
						i := i + 3
					else
						l_valid := False
					end
				else
					l_code := a_identifier.item (i).code
					i := i + 1
				end
				if l_code < 32 or l_code = 127 then l_valid := False end
				if l_valid then Result.append_code (l_code.to_natural_32) end
			end
			if not l_valid or else not {UTF_CONVERTER}.is_valid_utf_8_string_8 (Result) then Result := Void end
		end

	hex_value (a_character: CHARACTER_8): INTEGER
		do
			if a_character >= '0' and a_character <= '9' then
				Result := a_character.code - ('0').code
			elseif a_character.as_lower >= 'a' and a_character.as_lower <= 'f' then
				Result := a_character.as_lower.code - ('a').code + 10
			else
				Result := -1
			end
		end

end
