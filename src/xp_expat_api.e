note
	description: "libexpat public API compatibility manifest."

class
	XP_EXPAT_API

feature -- Version

	Xml_major_version: INTEGER = 2
			-- Expat major version tracked by `include/xpact.h'.

	Xml_minor_version: INTEGER = 8
			-- Expat minor version tracked by `include/xpact.h'.

	Xml_micro_version: INTEGER = 1
			-- Expat micro version tracked by `include/xpact.h'.

feature -- Status constants

	Xml_status_error: INTEGER = 0

	Xml_status_ok: INTEGER = 1

	Xml_status_suspended: INTEGER = 2

feature -- Error constants

	Xml_error_none: INTEGER = 0

	Xml_error_no_memory: INTEGER = 1

	Xml_error_syntax: INTEGER = 2

	Xml_error_no_elements: INTEGER = 3

	Xml_error_invalid_token: INTEGER = 4

	Xml_error_unclosed_token: INTEGER = 5

	Xml_error_not_started: INTEGER = 44

	Xml_error_count: INTEGER = 45
			-- Number of Expat 2.8.1 `enum XML_Error' values.

feature -- API manifest

	public_function_count: INTEGER
			-- Number of tracked public Expat API names, including macro APIs.
		do
			Result := public_functions.count
		ensure
			positive: Result > 0
		end

	has_public_function (a_name: READABLE_STRING_8): BOOLEAN
			-- Is `a_name' tracked in the public API surface?
		require
			name_attached: a_name /= Void
			name_not_empty: not a_name.is_empty
		local
			i: INTEGER
		do
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= public_functions.count + 1
			until
				i > public_functions.count or Result
			loop
				if public_functions.i_th (i).same_string (a_name) then
					Result := True
				end
				i := i + 1
			variant
				public_functions.count - i + 1
			end
		end

	public_functions: ARRAYED_LIST [STRING_8]
			-- Expat 2.8.1 public function and macro API names tracked by xpact.
		once
			create Result.make (80)
			Result.extend ("XML_SetElementDeclHandler")
			Result.extend ("XML_SetAttlistDeclHandler")
			Result.extend ("XML_SetXmlDeclHandler")
			Result.extend ("XML_ParserCreate")
			Result.extend ("XML_ParserCreateNS")
			Result.extend ("XML_ParserCreate_MM")
			Result.extend ("XML_ParserReset")
			Result.extend ("XML_SetEntityDeclHandler")
			Result.extend ("XML_SetElementHandler")
			Result.extend ("XML_SetStartElementHandler")
			Result.extend ("XML_SetEndElementHandler")
			Result.extend ("XML_SetCharacterDataHandler")
			Result.extend ("XML_SetProcessingInstructionHandler")
			Result.extend ("XML_SetCommentHandler")
			Result.extend ("XML_SetCdataSectionHandler")
			Result.extend ("XML_SetStartCdataSectionHandler")
			Result.extend ("XML_SetEndCdataSectionHandler")
			Result.extend ("XML_SetDefaultHandler")
			Result.extend ("XML_SetDefaultHandlerExpand")
			Result.extend ("XML_SetDoctypeDeclHandler")
			Result.extend ("XML_SetStartDoctypeDeclHandler")
			Result.extend ("XML_SetEndDoctypeDeclHandler")
			Result.extend ("XML_SetUnparsedEntityDeclHandler")
			Result.extend ("XML_SetNotationDeclHandler")
			Result.extend ("XML_SetNamespaceDeclHandler")
			Result.extend ("XML_SetStartNamespaceDeclHandler")
			Result.extend ("XML_SetEndNamespaceDeclHandler")
			Result.extend ("XML_SetNotStandaloneHandler")
			Result.extend ("XML_SetExternalEntityRefHandler")
			Result.extend ("XML_SetExternalEntityRefHandlerArg")
			Result.extend ("XML_SetSkippedEntityHandler")
			Result.extend ("XML_SetUnknownEncodingHandler")
			Result.extend ("XML_DefaultCurrent")
			Result.extend ("XML_SetReturnNSTriplet")
			Result.extend ("XML_SetUserData")
			Result.extend ("XML_GetUserData")
			Result.extend ("XML_SetEncoding")
			Result.extend ("XML_UseParserAsHandlerArg")
			Result.extend ("XML_UseForeignDTD")
			Result.extend ("XML_SetBase")
			Result.extend ("XML_GetBase")
			Result.extend ("XML_GetSpecifiedAttributeCount")
			Result.extend ("XML_GetIdAttributeIndex")
			Result.extend ("XML_GetAttributeInfo")
			Result.extend ("XML_Parse")
			Result.extend ("XML_GetBuffer")
			Result.extend ("XML_ParseBuffer")
			Result.extend ("XML_StopParser")
			Result.extend ("XML_ResumeParser")
			Result.extend ("XML_GetParsingStatus")
			Result.extend ("XML_ExternalEntityParserCreate")
			Result.extend ("XML_SetParamEntityParsing")
			Result.extend ("XML_SetHashSalt")
			Result.extend ("XML_SetHashSalt16Bytes")
			Result.extend ("XML_GetErrorCode")
			Result.extend ("XML_GetCurrentLineNumber")
			Result.extend ("XML_GetCurrentColumnNumber")
			Result.extend ("XML_GetCurrentByteIndex")
			Result.extend ("XML_GetCurrentByteCount")
			Result.extend ("XML_GetInputContext")
			Result.extend ("XML_GetErrorLineNumber")
			Result.extend ("XML_GetErrorColumnNumber")
			Result.extend ("XML_GetErrorByteIndex")
			Result.extend ("XML_FreeContentModel")
			Result.extend ("XML_MemMalloc")
			Result.extend ("XML_MemRealloc")
			Result.extend ("XML_MemFree")
			Result.extend ("XML_ParserFree")
			Result.extend ("XML_ErrorString")
			Result.extend ("XML_ExpatVersion")
			Result.extend ("XML_ExpatVersionInfo")
			Result.extend ("XML_GetFeatureList")
			Result.extend ("XML_SetBillionLaughsAttackProtectionMaximumAmplification")
			Result.extend ("XML_SetBillionLaughsAttackProtectionActivationThreshold")
			Result.extend ("XML_SetAllocTrackerMaximumAmplification")
			Result.extend ("XML_SetAllocTrackerActivationThreshold")
			Result.extend ("XML_SetReparseDeferralEnabled")
		ensure
			result_attached: Result /= Void
			complete_count: Result.count = 77
		end

end
