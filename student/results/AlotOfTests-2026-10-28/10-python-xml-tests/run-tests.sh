#!/bin/sh
# Test 10: CPython 3.14.0's XML test suites, once with Python's own Expat (baseline) and once on xpact.
# usage: sh run-tests.sh baseline|xpact|xpact_assertions
HERE="$(cd "$(dirname "$0")" && pwd -W)"
PY="$LOCALAPPDATA/Programs/Python/Python314/python.exe"
TESTS="test_pyexpat test_xml_etree test_xml_etree_c test_sax test_minidom test_pulldom test_xml_dom_minicompat test_xml_dom_xmlbuilder test_xmlrpc test_plistlib"
if [ "$1" = baseline ]; then PP="$HERE/download/cpython/Lib"; else PP="$HERE/build/$1;$HERE/download/cpython/Lib"; fi
PYTHONPATH="$PP" "$PY" -c "import pyexpat; print('pyexpat:', pyexpat.__file__, pyexpat.EXPAT_VERSION)"
PYTHONPATH="$PP" "$PY" -m test $TESTS -v --timeout 600
