#include "xpact.h"

#include <stdio.h>
#include <string.h>

static int XMLCALL
not_standalone_callback(void *userData) {
	(void)userData;
	return 1;
}

static void XMLCALL
start_callback(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)name;
	(void)atts;
}

static void XMLCALL
end_callback(void *userData, const XML_Char *name) {
	(void)userData;
	(void)name;
}

static void XMLCALL
text_callback(void *userData, const XML_Char *s, int len) {
	(void)userData;
	(void)s;
	(void)len;
}

static int
check(int condition, const char *label) {
	if (!condition) {
		fprintf(stderr, "FAIL: %s\n", label);
		return 0;
	}
	return 1;
}

int
main(void) {
	int marker = 0x584d4c;
	XML_Expat_Version version = XML_ExpatVersionInfo();
	XML_ParsingStatus parsing_status;
	const XML_LChar *version_text = XML_ExpatVersion();
	XML_Parser parser;
	enum XML_Status status;

	if (!check(version.major == XML_MAJOR_VERSION, "major version matches header")) return 1;
	if (!check(version.minor == XML_MINOR_VERSION, "minor version matches header")) return 1;
	if (!check(version.micro == XML_MICRO_VERSION, "micro version matches header")) return 1;
	if (!check(version_text != NULL, "version string returned")) return 1;
	if (!check(strstr(version_text, "xpact-eiffel-bridge") != NULL, "bridge version reported")) return 1;

	parser = XML_ParserCreate(NULL);
	if (!check(parser != NULL, "parser created without installed bridge")) return 1;

	XML_SetUserData(parser, &marker);
	if (!check(XML_GetUserData(parser) == &marker, "user data macro reads first parser field")) return 1;

	XML_SetElementHandler(parser, start_callback, end_callback);
	XML_SetCharacterDataHandler(parser, text_callback);
	XML_SetNotStandaloneHandler(parser, not_standalone_callback);

	status = XML_SetBase(parser, "mem://xpact");
	if (!check(status == XML_STATUS_OK, "base setter succeeds")) return 1;
	if (!check(strcmp(XML_GetBase(parser), "mem://xpact") == 0, "base getter returns copied base")) return 1;

	XML_GetParsingStatus(parser, &parsing_status);
	if (!check(parsing_status.parsing == XML_INITIALIZED, "parser starts initialized")) return 1;
	if (!check(parsing_status.finalBuffer == XML_FALSE, "parser starts without final buffer")) return 1;

	status = XML_Parse(parser, "<root/>", 7, XML_TRUE);
	if (!check(status == XML_STATUS_ERROR, "parse fails before Eiffel bridge is installed")) return 1;
	if (!check(XML_GetErrorCode(parser) == XML_ERROR_NOT_STARTED, "missing bridge is explicit error")) return 1;
	if (!check(XML_ErrorString(XML_ERROR_NOT_STARTED) != NULL, "missing bridge has error text")) return 1;
	if (!check(XML_GetCurrentLineNumber(parser) == 1, "line API links")) return 1;
	if (!check(XML_GetCurrentColumnNumber(parser) == 0, "column API links")) return 1;
	if (!check(XML_GetCurrentByteIndex(parser) == -1, "byte index API links")) return 1;
	if (!check(XML_GetCurrentByteCount(parser) == 0, "byte count API links")) return 1;

	XML_GetParsingStatus(parser, &parsing_status);
	if (!check(parsing_status.parsing == XML_FINISHED, "failed parse updates parsing status")) return 1;
	if (!check(parsing_status.finalBuffer == XML_TRUE, "failed parse records final buffer")) return 1;

	XML_ParserFree(parser);
	puts("xpact public ABI smoke: ok");
	return 0;
}
