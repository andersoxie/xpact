/* The suite's compile definitions rename API declarations to the wrappers.
 * Read the genuine declarations here before defining those wrappers. */
#undef XML_Parse
#undef XML_ParserCreate
#undef XML_ParserCreateNS
#undef XML_ParserCreate_MM
#undef XML_ParserReset
#include "expat.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#undef XML_Parse

XML_Bool g_reparseDeferralEnabledDefault = XML_TRUE;
unsigned int g_bytesScanned = 0;

extern unsigned long long XMLCALL
XPACT_TestingAccountingGetCountBytesDirect(XML_Parser parser);

extern unsigned long long XMLCALL
XPACT_TestingAccountingGetCountBytesIndirect(XML_Parser parser);

static XML_Parser
xpact_adapter_apply_reparse_default(XML_Parser parser) {
	if (parser != NULL) {
		(void)XML_SetReparseDeferralEnabled(parser, g_reparseDeferralEnabledDefault);
	}
	return parser;
}

XML_Parser XMLCALL
xpact_adapter_XML_ParserCreate(const XML_Char *encoding) {
	return xpact_adapter_apply_reparse_default(XML_ParserCreate(encoding));
}

XML_Parser XMLCALL
xpact_adapter_XML_ParserCreateNS(const XML_Char *encoding, XML_Char namespaceSeparator) {
	return xpact_adapter_apply_reparse_default(XML_ParserCreateNS(encoding, namespaceSeparator));
}

XML_Parser XMLCALL
xpact_adapter_XML_ParserCreate_MM(
	const XML_Char *encoding,
	const XML_Memory_Handling_Suite *memsuite,
	const XML_Char *namespaceSeparator
) {
	return xpact_adapter_apply_reparse_default(XML_ParserCreate_MM(encoding, memsuite, namespaceSeparator));
}

XML_Bool XMLCALL
xpact_adapter_XML_ParserReset(XML_Parser parser, const XML_Char *encoding) {
	XML_Bool reset = XML_ParserReset(parser, encoding);
	if (reset) {
		(void)xpact_adapter_apply_reparse_default(parser);
	}
	return reset;
}

enum XML_Status XMLCALL
xpact_adapter_XML_Parse(XML_Parser parser, const char *s, int len, int isFinal) {
	if (len > 0) {
		g_bytesScanned += (unsigned int)len;
	}
	return XML_Parse(parser, s, len, isFinal);
}

void
_INTERNAL_trim_to_complete_utf8_characters(const char *from, const char **fromLimRef) {
	const char *fromLim = *fromLimRef;
	size_t walked = 0;
	for (; fromLim > from; fromLim--, walked++) {
		const unsigned char prev = (unsigned char)fromLim[-1];
		if ((prev & 0xf8u) == 0xf0u) {
			if (walked + 1 >= 4) {
				fromLim += 3;
				break;
			}
			walked = 0;
		} else if ((prev & 0xf0u) == 0xe0u) {
			if (walked + 1 >= 3) {
				fromLim += 2;
				break;
			}
			walked = 0;
		} else if ((prev & 0xe0u) == 0xc0u) {
			if (walked + 1 >= 2) {
				fromLim += 1;
				break;
			}
			walked = 0;
		} else if ((prev & 0x80u) == 0x00u) {
			break;
		}
	}
	*fromLimRef = fromLim;
}

unsigned long long
testingAccountingGetCountBytesDirect(XML_Parser parser) {
	return XPACT_TestingAccountingGetCountBytesDirect(parser);
}

unsigned long long
testingAccountingGetCountBytesIndirect(XML_Parser parser) {
	return XPACT_TestingAccountingGetCountBytesIndirect(parser);
}

const char *
unsignedCharToPrintable(unsigned char c) {
	static char buffer[8];
	if (c == '\\') {
		return "\\\\";
	}
	if (c == '"') {
		return "\\\"";
	}
	if (c == '\t') {
		return "\\t";
	}
	if (c == '\n') {
		return "\\n";
	}
	if (c == '\r') {
		return "\\r";
	}
	if (c >= 32 && c <= 126) {
		buffer[0] = (char)c;
		buffer[1] = '\0';
		return buffer;
	}
	(void)snprintf(buffer, sizeof(buffer), "\\x%X", (unsigned int)c);
	return buffer;
}

void *
expat_malloc(XML_Parser parser, size_t size, int sourceLine) {
	(void)parser;
	(void)sourceLine;
	return malloc(size);
}

void *
expat_realloc(XML_Parser parser, void *ptr, size_t size, int sourceLine) {
	(void)parser;
	(void)sourceLine;
	return realloc(ptr, size);
}

void
expat_free(XML_Parser parser, void *ptr) {
	(void)parser;
	free(ptr);
}
