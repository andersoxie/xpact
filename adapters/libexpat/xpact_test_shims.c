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
