#ifndef XPACT_NATIVE_PRIVATE_H
#define XPACT_NATIVE_PRIVATE_H

#include "../include/xpact.h"
#include <stdlib.h>
#include <string.h>

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
	XML_StartNamespaceDeclHandler startNamespaceDeclHandler;
	XML_EndNamespaceDeclHandler endNamespaceDeclHandler;
	XML_Bool hasNamespaceSeparator;
	XML_Char namespaceSeparator;
	XML_Bool returnNsTriplet;
	XML_Bool hasBillionLaughsMaximumAmplification;
	float billionLaughsMaximumAmplification;
	XML_Bool hasBillionLaughsActivationThreshold;
	unsigned long long billionLaughsActivationThresholdBytes;
	XML_UnknownEncodingHandler unknownEncodingHandler;
	void *unknownEncodingHandlerData;
	XML_Bool useForeignDTD;
	XML_Parser parentParser;
	XML_Bool nextExternalEntityIsParameter;
	XML_Bool externalEntityIsParameter;
	int externalChildParseCount;
	XML_Bool stopRequested;
	XML_Bool stopResumable;
	int activeCallbackKind;
	int stopCallbackKind;
	XML_Bool reparseDeferralEnabled;
};

#define XPACT_CALLBACK_NONE 0
#define XPACT_CALLBACK_CHARACTER_DATA 1

static XML_Bool
xp_private_append_utf8(char **buffer, int *length, int *capacity, int codepoint) {
	int needed;
	char bytes[4];
	int count;
	char *resized;

	if (codepoint < 0 || codepoint > 0x10ffff || (codepoint >= 0xd800 && codepoint <= 0xdfff)) {
		return XML_FALSE;
	}
	if (codepoint <= 0x7f) {
		bytes[0] = (char)codepoint;
		count = 1;
	} else if (codepoint <= 0x7ff) {
		bytes[0] = (char)(0xc0 | (codepoint >> 6));
		bytes[1] = (char)(0x80 | (codepoint & 0x3f));
		count = 2;
	} else if (codepoint <= 0xffff) {
		bytes[0] = (char)(0xe0 | (codepoint >> 12));
		bytes[1] = (char)(0x80 | ((codepoint >> 6) & 0x3f));
		bytes[2] = (char)(0x80 | (codepoint & 0x3f));
		count = 3;
	} else {
		bytes[0] = (char)(0xf0 | (codepoint >> 18));
		bytes[1] = (char)(0x80 | ((codepoint >> 12) & 0x3f));
		bytes[2] = (char)(0x80 | ((codepoint >> 6) & 0x3f));
		bytes[3] = (char)(0x80 | (codepoint & 0x3f));
		count = 4;
	}
	needed = *length + count + 1;
	if (needed > *capacity) {
		int newCapacity = *capacity * 2;
		if (newCapacity < needed) {
			newCapacity = needed;
		}
		resized = (char *)realloc(*buffer, (size_t)newCapacity);
		if (resized == NULL) {
			return XML_FALSE;
		}
		*buffer = resized;
		*capacity = newCapacity;
	}
	memcpy(*buffer + *length, bytes, (size_t)count);
	*length += count;
	(*buffer)[*length] = '\0';
	return XML_TRUE;
}

static XML_Bool
xp_private_unknown_encoding_info_is_valid(const XML_Encoding *info, enum XML_Error *errorCode) {
	int i;
	for (i = 0; i < 128; i++) {
		if (info->map[i] != i) {
			*errorCode = XML_ERROR_UNKNOWN_ENCODING;
			return XML_FALSE;
		}
	}
	for (i = 128; i < 256; i++) {
		int code = info->map[i];
		if (code == -1) {
			continue;
		}
		if (code >= -4 && code <= -2) {
			if (info->convert == NULL) {
				*errorCode = XML_ERROR_UNKNOWN_ENCODING;
				return XML_FALSE;
			}
			continue;
		}
		if (code < -4 || (code >= 0 && code < 128) || code > 0xffff) {
			*errorCode = XML_ERROR_UNKNOWN_ENCODING;
			return XML_FALSE;
		}
	}
	return XML_TRUE;
}

static XML_Bool
xp_has_unknown_encoding_handler(XML_Parser parser) {
	return parser != NULL && parser->unknownEncodingHandler != NULL ? XML_TRUE : XML_FALSE;
}

static char *
xp_decode_unknown_encoding_input(
	XML_Parser parser,
	const XML_Char *encoding,
	const char *input,
	int length,
	int *decodedLength,
	enum XML_Error *errorCode
) {
	XML_Encoding info;
	char *decoded;
	int capacity;
	int outputLength;
	int i;
	XML_Bool ok = XML_TRUE;

	if (decodedLength != NULL) {
		*decodedLength = 0;
	}
	if (errorCode != NULL) {
		*errorCode = XML_ERROR_NONE;
	}
	if (
		parser == NULL
		|| parser->unknownEncodingHandler == NULL
		|| encoding == NULL
		|| input == NULL
		|| length < 0
		|| decodedLength == NULL
		|| errorCode == NULL
	) {
		if (errorCode != NULL) {
			*errorCode = XML_ERROR_UNKNOWN_ENCODING;
		}
		return NULL;
	}
	memset(&info, 0, sizeof(info));
	if (parser->unknownEncodingHandler(parser->unknownEncodingHandlerData, encoding, &info) == XML_STATUS_ERROR) {
		*errorCode = XML_ERROR_UNKNOWN_ENCODING;
		return NULL;
	}
	if (!xp_private_unknown_encoding_info_is_valid(&info, errorCode)) {
		if (info.release != NULL) {
			info.release(info.data);
		}
		return NULL;
	}

	capacity = (length * 2) + 1;
	if (capacity < 16) {
		capacity = 16;
	}
	decoded = (char *)malloc((size_t)capacity);
	if (decoded == NULL) {
		*errorCode = XML_ERROR_NO_MEMORY;
		if (info.release != NULL) {
			info.release(info.data);
		}
		return NULL;
	}
	outputLength = 0;
	decoded[0] = '\0';
	for (i = 0; i < length && ok; ) {
		unsigned char byte = (unsigned char)input[i];
		int map = info.map[byte];
		if (map >= 0) {
			if (map >= 0xd800 && map <= 0xdfff) {
				*errorCode = XML_ERROR_INVALID_TOKEN;
				ok = XML_FALSE;
			} else {
				ok = xp_private_append_utf8(&decoded, &outputLength, &capacity, map);
				if (!ok) {
					*errorCode = XML_ERROR_NO_MEMORY;
				}
				i++;
			}
		} else if (map == -1) {
			*errorCode = XML_ERROR_INVALID_TOKEN;
			ok = XML_FALSE;
		} else if (map >= -4 && map <= -2) {
			int sequenceLength = -map;
			int codepoint;
			if (i + sequenceLength > length) {
				*errorCode = XML_ERROR_PARTIAL_CHAR;
				ok = XML_FALSE;
			} else {
				codepoint = info.convert(info.data, input + i);
				if (codepoint < 0 || codepoint > 0x10ffff || (codepoint >= 0xd800 && codepoint <= 0xdfff)) {
					*errorCode = XML_ERROR_INVALID_TOKEN;
					ok = XML_FALSE;
				} else {
					ok = xp_private_append_utf8(&decoded, &outputLength, &capacity, codepoint);
					if (!ok) {
						*errorCode = XML_ERROR_NO_MEMORY;
					}
					i += sequenceLength;
				}
			}
		} else {
			*errorCode = XML_ERROR_UNKNOWN_ENCODING;
			ok = XML_FALSE;
		}
	}
	if (info.release != NULL) {
		info.release(info.data);
	}
	if (!ok) {
		free(decoded);
		return NULL;
	}
	*decodedLength = outputLength;
	return decoded;
}

static void
xp_free_unknown_encoding_input(char *input) {
	free(input);
}

#endif
