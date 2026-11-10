/* skipped.c: the document of tests/xp_test_root.e:2341 with a skipped-entity handler and no external entity
   handler; prints the status and every skipped-entity callback (acceptance run, #67). */
#include <stdio.h>
#include <string.h>
#ifdef USE_EXPAT
#include "expat.h"
#else
#include "xpact.h"
#endif
static void XMLCALL on_skipped(void *u, const XML_Char *name, int is_pe) { (void)u; printf("skipped:%s:%d\n", name, is_pe); }
int main(void) {
  const char *docs[] = {
    "<!DOCTYPE doc [<!ENTITY en SYSTEM \"http://example.org/dummy.ent\">]><doc>&en;</doc>",
    "<!DOCTYPE doc [<!ENTITY % pe SYSTEM \"x.ent\"> %pe; <!ENTITY e 'v'>]><doc>&e;</doc>",
    "<!DOCTYPE doc [<!ENTITY % pe SYSTEM \"x.ent\"> %pe;]><doc>&undeclared;</doc>" };
  for (int i = 0; i < 3; i++) {
    for (int pe = 0; pe < 2; pe++) {
      XML_Parser p = XML_ParserCreate(NULL);
      XML_SetSkippedEntityHandler(p, on_skipped);
      if (pe) XML_SetParamEntityParsing(p, XML_PARAM_ENTITY_PARSING_ALWAYS);
      int st = XML_Parse(p, docs[i], (int)strlen(docs[i]), 1);
      printf("doc %d pe-parsing %d: status %d code %d\n", i + 1, pe, st, st ? 0 : (int)XML_GetErrorCode(p));
      XML_ParserFree(p);
    }
  }
  return 0;
}
