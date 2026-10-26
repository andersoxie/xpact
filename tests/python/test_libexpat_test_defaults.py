"""Check adapter test defaults using the real shim and a small native API mock.

This exercises both configurations without Eiffel or an upstream Expat checkout.
"""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
ADAPTER = REPO / "adapters/libexpat"
CMAKE = shutil.which("cmake")
if CMAKE is None:
    fallback = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "CMake/bin/cmake.exe"
    if fallback.is_file():
        CMAKE = str(fallback)
if CMAKE is None and os.name == "nt":
    # Visual Studio ships its own CMake next to the C++ tools.
    vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
    if vswhere.is_file():
        found = subprocess.run(
            [str(vswhere), "-latest", "-products", "*", "-requires",
             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
             "-find", "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"],
            capture_output=True, text=True, timeout=15).stdout.splitlines()
        if found:
            CMAKE = found[0].strip()

MOCK = r"""
#undef XML_Parse
#undef XML_ParserCreate
#undef XML_ParserCreateNS
#undef XML_ParserCreate_MM
#undef XML_ParserReset
#include "xpact.h"
#include <stdlib.h>
struct XML_ParserStruct { XML_Bool deferral; int kind; };
static int calls;
static int fail_factory;
static int fail_reset;
static XML_Parser make_parser(int kind) {
  XML_Parser parser;
  if (fail_factory) return NULL;
  parser = (XML_Parser)calloc(1, sizeof(*parser));
  if (parser) { parser->deferral=XML_TRUE; parser->kind=kind; }
  return parser;
}
XML_Parser XMLCALL XML_ParserCreate(const XML_Char *encoding) { (void)encoding; return make_parser(1); }
XML_Parser XMLCALL XML_ParserCreateNS(const XML_Char *encoding, XML_Char separator) { (void)encoding;(void)separator;return make_parser(2); }
XML_Parser XMLCALL XML_ParserCreate_MM(const XML_Char *encoding,const XML_Memory_Handling_Suite *memsuite,const XML_Char *separator) { (void)encoding;(void)memsuite;(void)separator;return make_parser(3); }
XML_Bool XMLCALL XML_ParserReset(XML_Parser parser,const XML_Char *encoding) { (void)encoding;if(!parser||fail_reset)return XML_FALSE;parser->deferral=XML_TRUE;return XML_TRUE; }
XML_Bool XMLCALL XML_SetReparseDeferralEnabled(XML_Parser parser,XML_Bool enabled) { calls++;if(!parser)return XML_FALSE;parser->deferral=enabled;return XML_TRUE; }
XML_Parser XMLCALL XML_ExternalEntityParserCreate(XML_Parser parser,const XML_Char *context,const XML_Char *encoding) { XML_Parser child=make_parser(4);(void)context;(void)encoding;if(child)child->deferral=parser->deferral;return child; }
void XMLCALL XML_ParserFree(XML_Parser parser) { free(parser); }
enum XML_Status XMLCALL XML_Parse(XML_Parser parser,const char *bytes,int length,int final) { (void)parser;(void)bytes;(void)length;(void)final;return XML_STATUS_OK; }
unsigned long long XMLCALL XPACT_TestingAccountingGetCountBytesDirect(XML_Parser parser) { (void)parser;return 0; }
unsigned long long XMLCALL XPACT_TestingAccountingGetCountBytesIndirect(XML_Parser parser) { (void)parser;return 0; }
int mock_calls(void) { return calls; }
int mock_deferral(XML_Parser parser) { return parser->deferral; }
int mock_kind(XML_Parser parser) { return parser->kind; }
void mock_fail(int factory,int reset) { fail_factory=factory;fail_reset=reset; }
"""

CALLER = r"""
#include "expat.h"
#include <assert.h>
#include <stdio.h>
extern XML_Bool g_reparseDeferralEnabledDefault;
int mock_calls(void);
int mock_deferral(XML_Parser parser);
int mock_kind(XML_Parser parser);
void mock_fail(int factory,int reset);
int main(void) {
 int d;
 for(d=0;d<=1;d++) {
  XML_Parser parsers[3];int i;
  g_reparseDeferralEnabledDefault=(XML_Bool)d;
  parsers[0]=XML_ParserCreate(NULL);
  parsers[1]=XML_ParserCreateNS(NULL,':');
  parsers[2]=XML_ParserCreate_MM(NULL,NULL,NULL);
  for(i=0;i<3;i++) {
   int before=mock_calls();XML_Parser child;
   assert(parsers[i]!=NULL);assert(mock_kind(parsers[i])==i+1);
   assert(mock_deferral(parsers[i])==d);
   g_reparseDeferralEnabledDefault=(XML_Bool)!d;
   mock_fail(0,1);
   assert(!XML_ParserReset(parsers[i],NULL));
   assert(mock_calls()==before);assert(mock_deferral(parsers[i])==d);
   mock_fail(0,0);
   assert(XML_ParserReset(parsers[i],NULL));
   assert(mock_calls()==before+1);assert(mock_deferral(parsers[i])==!d);
   g_reparseDeferralEnabledDefault=(XML_Bool)d;
   child=XML_ExternalEntityParserCreate(parsers[i],NULL,NULL);
   assert(child!=NULL);assert(mock_deferral(child)==!d);
   assert(mock_calls()==before+1);
   XML_ParserFree(child);XML_ParserFree(parsers[i]);
  }
  mock_fail(1,0);
  { int before=mock_calls();assert(XML_ParserCreate(NULL)==NULL);assert(XML_ParserCreateNS(NULL,':')==NULL);assert(XML_ParserCreate_MM(NULL,NULL,NULL)==NULL);assert(mock_calls()==before); }
  mock_fail(0,0);
 }
 puts("default propagation sequences passed");return 0;
}
"""


@unittest.skipUnless(os.name == "nt" and CMAKE, "Windows, CMake, and MSVC are required")
class NativeTestDefaultTests(unittest.TestCase):
    def test_factory_and_reset_defaults_match_each_test_configuration(self):
        vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
        if not vswhere.is_file():
            self.skipTest("Visual Studio C++ tools are not installed")
        version = subprocess.run(
            [str(vswhere), "-latest", "-products", "*", "-requires",
             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationVersion"],
            capture_output=True, text=True, timeout=15, check=True).stdout.strip()
        if not version:
            self.skipTest("Visual Studio C++ tools are not installed")
        help_text = subprocess.run([CMAKE, "--help"], capture_output=True, text=True, timeout=15, check=True).stdout
        generator = re.search(rf"Visual Studio {re.escape(version.split('.')[0])} \d{{4}}", help_text)
        if generator is None:
            self.skipTest("CMake cannot use the installed Visual Studio version")
        (REPO / "build").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="libexpat defaults tests ", dir=REPO / "build") as temporary:
            source = Path(temporary).resolve()
            self.assertTrue(source.is_relative_to((REPO / "build").resolve()))
            (source / "mock.c").write_text(MOCK, encoding="utf-8")
            (source / "caller.c").write_text(CALLER, encoding="utf-8")
            # Use the actual suite mappings so a missing factory wrapper is observable.
            mappings = re.findall(r"^\s*(XML_\w+=xpact_adapter_\w+)\s*$",
                                  (ADAPTER / "CMakeLists.txt").read_text(encoding="utf-8"), re.MULTILINE)
            definitions = "\n".join(mappings)
            (source / "CMakeLists.txt").write_text(
                "cmake_minimum_required(VERSION 3.20)\nproject(test_defaults_fixture C)\n"
                f'add_executable(test_defaults_fixture caller.c mock.c "{(ADAPTER / "xpact_test_shims.c").as_posix()}")\n'
                f'target_include_directories(test_defaults_fixture PRIVATE "{(ADAPTER / "include").as_posix()}" "{(REPO / "include").as_posix()}")\n'
                f"target_compile_definitions(test_defaults_fixture PRIVATE XML_STATIC\n{definitions}\n)\n"
                "target_compile_options(test_defaults_fixture PRIVATE /W4 /WX)\n",
                encoding="utf-8")
            build = source / "compiled"
            for command in (
                [CMAKE, "-S", str(source), "-B", str(build), "-G", generator.group(), "-A", "x64"],
                [CMAKE, "--build", str(build), "--config", "Debug", "--parallel", "2"],
            ):
                result = subprocess.run(command, capture_output=True, text=True, errors="replace", timeout=90)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(build / "Debug/test_defaults_fixture.exe")],
                                    capture_output=True, text=True, errors="replace", timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("default propagation sequences passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
