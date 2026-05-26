#ifndef XPACT_ADAPTER_EXPAT_H
#define XPACT_ADAPTER_EXPAT_H

#include "../../../include/xpact.h"

enum XML_Status XMLCALL
xpact_adapter_XML_Parse(XML_Parser parser, const char *s, int len, int isFinal);

#define XML_Parse xpact_adapter_XML_Parse

#endif
