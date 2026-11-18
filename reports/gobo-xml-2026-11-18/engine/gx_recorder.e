note
	description: "Records Gobo XML events as one JSON array (same shape as the AlotOfTests harness events)."

class
	GX_RECORDER

inherit
	XM_CALLBACKS_NULL
		rename
			make as make_callbacks_null,
			initialize as initialize_callbacks
		redefine
			on_error, on_processing_instruction, on_comment, on_start_tag, on_attribute,
			on_start_tag_finish, on_end_tag, on_content
		end

	XM_DTD_CALLBACKS_NULL
		rename
			make as make_dtd_null,
			initialize as initialize_dtd
		redefine
			on_doctype
		end

create
	make, make_null

feature {NONE} -- Initialization

	make
		do
			create json.make (4096)
			create tag.make (32)
			create attrs.make (64)
			create last_error.make_empty
			recording := True
		end

	make_null
			-- Count nothing, record nothing (speed runs).
		do
			make
			recording := False
		end

feature -- Access

	json: STRING_8
	last_error: STRING_8
	has_error: BOOLEAN
	recording: BOOLEAN
	event_count: INTEGER

	reset
		do
			json.wipe_out
			last_error.wipe_out
			has_error := False
			event_count := 0
		end

feature -- Callbacks

	on_error (a_message: STRING)
		do
			if not has_error then
				has_error := True
				last_error := utf8 (a_message)
			end
		end

	on_processing_instruction (a_name: STRING; a_content: STRING)
		do
			if recording then begin_event ("pi"); put_string (a_name); put_string (a_content); json.append_character (']') end
		end

	on_comment (a_content: STRING)
		do
			if recording then begin_event ("comment"); put_string (a_content); json.append_character (']') end
		end

	on_start_tag (a_namespace: detachable STRING; a_prefix: detachable STRING; a_local_part: STRING)
		do
			event_count := event_count + 1
			if recording then
				tag := qualified (a_namespace, a_prefix, a_local_part)
				attrs.wipe_out
				attr_count := 0
			end
		end

	on_attribute (a_namespace: detachable STRING; a_prefix: detachable STRING; a_local_part: STRING; a_value: STRING)
		do
			if recording then
				if is_xmlns (a_namespace, a_prefix, a_local_part) and namespaces then
						-- Expat (namespace mode) reports xmlns as namespace events, not attributes.
				else
					if attr_count > 0 then attrs.append_character (',') end
					attrs.append (quoted (qualified (a_namespace, a_prefix, a_local_part)))
					attrs.append_character (',')
					attrs.append (quoted (utf8 (a_value)))
					attr_count := attr_count + 1
				end
			end
		end

	on_start_tag_finish
		do
			if recording then
				begin_event ("start")
				json.append_character (',')
				json.append (quoted (tag))
				json.append (",[")
				json.append (attrs)
				json.append ("]]")
			end
		end

	on_end_tag (a_namespace: detachable STRING; a_prefix: detachable STRING; a_local_part: STRING)
		do
			if recording then
				begin_event ("end")
				json.append_character (',')
				json.append (quoted (qualified (a_namespace, a_prefix, a_local_part)))
				json.append_character (']')
			end
		end

	on_content (a_content: STRING)
		do
			if recording then begin_event ("chars"); put_string (a_content); json.append_character (']') end
		end

	on_doctype (a_name: STRING; an_id: detachable XM_DTD_EXTERNAL_ID; has_internal_subset: BOOLEAN)
		do
			saw_doctype := True
		end

feature -- Settings

	namespaces: BOOLEAN
	saw_doctype: BOOLEAN

	set_recording (b: BOOLEAN)
		do
			recording := b
		end

	set_namespaces (b: BOOLEAN)
		do
			namespaces := b
		end

feature -- Strings

	utf8 (s: READABLE_STRING_GENERAL): STRING_8
			-- UTF-8 bytes of `s'.
		do
			if attached {UC_STRING} s as u then
				Result := u.to_utf8
			else
				Result := {UTF_CONVERTER}.string_32_to_utf_8_string_8 (s.to_string_32)
			end
		end

	quoted (bytes: STRING_8): STRING_8
			-- JSON string literal; bytes >= 128 are passed through (UTF-8).
		local
			i, c: INTEGER
		do
			create Result.make (bytes.count + 2)
			Result.append_character ('"')
			from i := 1 until i > bytes.count loop
				c := bytes.item (i).code
				if c = 34 then Result.append ("\%"")
				elseif c = 92 then Result.append ("\\")
				elseif c < 32 or c = 127 then
					Result.append ("\u00")
					Result.append (c.to_hex_string.substring (7, 8))
				else
					Result.append_character (bytes.item (i))
				end
				i := i + 1
			end
			Result.append_character ('"')
		end

feature {NONE} -- Implementation

	tag: STRING_8
	attrs: STRING_8
	attr_count: INTEGER

	begin_event (kind: STRING_8)
		do
			if not json.is_empty then json.append_character (',') end
			json.append ("[%"")
			json.append (kind)
			json.append ("%"")
		end

	put_string (s: STRING)
		do
			json.append_character (',')
			json.append (quoted (utf8 (s)))
		end

	is_xmlns (a_namespace, a_prefix: detachable STRING; a_local_part: STRING): BOOLEAN
		do
			if attached a_prefix as p and then p.same_string ("xmlns") then
				Result := True
			elseif (a_prefix = Void or else a_prefix.is_empty) and a_local_part.same_string ("xmlns") then
				Result := True
			end
		end

	qualified (a_namespace, a_prefix: detachable STRING; a_local_part: STRING): STRING_8
			-- "uri|local" with namespaces (Expat ns-separator style), else "prefix:local".
		do
			if namespaces and attached a_namespace as ns and then not ns.is_empty then
				Result := utf8 (ns) + "|" + utf8 (a_local_part)
			elseif attached a_prefix as p and then not p.is_empty then
				Result := utf8 (p) + ":" + utf8 (a_local_part)
			else
				Result := utf8 (a_local_part)
			end
		end

end
