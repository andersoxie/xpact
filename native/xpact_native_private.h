#ifndef XPACT_NATIVE_PRIVATE_H
#define XPACT_NATIVE_PRIVATE_H

#include "../include/xpact.h"

struct XML_ParserStruct {
	void *userData;
	XML_Bool useParserAsHandlerArg;
	void *eiffelParser;
	const struct XPACT_EiffelBridge *bridge;
	XML_Memory_Handling_Suite memory;
	XML_Bool hasCustomMemory;
	enum XML_ParamEntityParsing paramEntityParsing;
	XML_Char *base;
	char *buffer;
	int bufferCapacity;
	enum XML_Error errorCode;
	enum XML_Parsing parsing;
	XML_Bool finalBuffer;
	XML_StartElementHandler startElementHandler;
	XML_EndElementHandler endElementHandler;
	XML_CharacterDataHandler characterDataHandler;
	XML_ProcessingInstructionHandler processingInstructionHandler;
	XML_XmlDeclHandler xmlDeclHandler;
	XML_CommentHandler commentHandler;
	XML_StartCdataSectionHandler startCdataSectionHandler;
	XML_EndCdataSectionHandler endCdataSectionHandler;
	XML_DefaultHandler defaultHandler;
	XML_Bool defaultHandlerExpands;
	XML_StartDoctypeDeclHandler startDoctypeDeclHandler;
	XML_EndDoctypeDeclHandler endDoctypeDeclHandler;
	XML_NotStandaloneHandler notStandaloneHandler;
	XML_ElementDeclHandler elementDeclHandler;
	XML_NotationDeclHandler notationDeclHandler;
	XML_AttlistDeclHandler attlistDeclHandler;
	XML_EntityDeclHandler entityDeclHandler;
	XML_UnparsedEntityDeclHandler unparsedEntityDeclHandler;
	XML_ExternalEntityRefHandler externalEntityRefHandler;
	void *externalEntityRefArg;
	XML_Bool hasExternalEntityRefArg;
	XML_SkippedEntityHandler skippedEntityHandler;
	XML_Bool useForeignDTD;
	XML_Parser parentParser;
	XML_Bool nextExternalEntityIsParameter;
	XML_Bool externalEntityIsParameter;
	int externalChildParseCount;
};

#endif
