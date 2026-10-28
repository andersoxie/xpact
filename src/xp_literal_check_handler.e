note
	description: "[
		Event sink for checking an external parameter entity that is included in an entity literal:
		declarations and content found while checking are dropped, but the text declaration still
		reaches the application, and a stop requested from that callback is honoured (as in Expat).
	]"

class
	XP_LITERAL_CHECK_HANDLER

inherit
	XP_NULL_EVENT_HANDLER
		rename
			make as make_null
		redefine
			stop_requested,
			stop_is_resumable,
			on_xml_declaration
		end

create
	make

feature {NONE} -- Initialization

	make (a_application: XP_EVENT_HANDLER)
			-- Forward the text declaration and stop requests to `a_application'.
		require
			application_attached: a_application /= Void
		do
			make_null
			application := a_application
		ensure
			application_set: application = a_application
		end

feature -- Access

	application: XP_EVENT_HANDLER
			-- Handler of the parse that includes the entity.

feature -- Status report

	stop_requested: BOOLEAN
			-- Did the application request parsing to stop from inside a callback?
		do
			Result := application.stop_requested
		end

	stop_is_resumable: BOOLEAN
			-- Is the current stop request resumable?
		do
			Result := application.stop_is_resumable
		end

feature -- Events

	on_xml_declaration (a_version, a_encoding: READABLE_STRING_8; a_standalone: INTEGER)
			-- Pass the text declaration on to `application'.
		do
			application.on_xml_declaration (a_version, a_encoding, a_standalone)
		end

end
