/* Test 10 shim: CPython's pyexpat.c includes "expat.h"; build it against xpact's Expat-compatible header. */
#ifndef XPACT_EXPAT_SHIM_H
#define XPACT_EXPAT_SHIM_H
#include "xpact.h"
#ifndef XML_DTD
#define XML_DTD 1
#endif
#endif
