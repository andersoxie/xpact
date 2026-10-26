#ifndef XPACT_TEST_REGISTRATION_H
#define XPACT_TEST_REGISTRATION_H

/* Read declarations before replacing the upstream registration calls. */
#include <expat.h>
#include "minicheck.h"
#include "common.h"

void xpact_adapter_add_test(TCase *test_case, tcase_test_function test,
                            const char *name, const char *source);

#define tcase_add_test(tc, test) \
    xpact_adapter_add_test((tc), (test), #test, __FILE__)

#ifdef XML_DTD
#define tcase_add_test__ifdef_xml_dtd(tc, test) tcase_add_test((tc), test)
#else
#define tcase_add_test__ifdef_xml_dtd(tc, test) ((void)0)
#endif

#if XML_GE == 1
#define tcase_add_test__if_xml_ge(tc, test) tcase_add_test((tc), test)
#else
#define tcase_add_test__if_xml_ge(tc, test) ((void)0)
#endif

#endif
