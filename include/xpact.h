#ifndef XPACT_H
#define XPACT_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Phase 1 public ABI target.
 *
 * This header deliberately mirrors the core libexpat event-driven shape while
 * the Eiffel implementation is brought up behind it. The exported DLL/SO entry
 * points will use these names so downstream C callers can move toward a
 * libexpat-compatible surface without seeing Eiffel internals.
 */

typedef void *XML_Parser;
typedef char XML_Char;
typedef int XML_Bool;
typedef int enum_XML_Status;

#define XML_TRUE 1
#define XML_FALSE 0
#define XML_STATUS_ERROR 0
#define XML_STATUS_OK 1

typedef void (*XML_StartElementHandler) (
	void *userData,
	const XML_Char *name,
	const XML_Char **atts
);

typedef void (*XML_EndElementHandler) (
	void *userData,
	const XML_Char *name
);

typedef void (*XML_CharacterDataHandler) (
	void *userData,
	const XML_Char *s,
	int len
);

XML_Parser XML_ParserCreate (const XML_Char *encoding);
void XML_ParserFree (XML_Parser parser);
void XML_SetUserData (XML_Parser parser, void *userData);
void XML_SetElementHandler (
	XML_Parser parser,
	XML_StartElementHandler start,
	XML_EndElementHandler end
);
void XML_SetCharacterDataHandler (
	XML_Parser parser,
	XML_CharacterDataHandler handler
);
enum_XML_Status XML_Parse (
	XML_Parser parser,
	const char *s,
	int len,
	int isFinal
);
const XML_Char *XML_ErrorString (int code);

#ifdef __cplusplus
}
#endif

#endif

