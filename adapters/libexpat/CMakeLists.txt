cmake_minimum_required(VERSION 3.20)

project(xpact_libexpat_adapter C)

set(EXPAT_SOURCE_DIR "" CACHE PATH "Path to an upstream libexpat checkout or source release")
set(XPACT_LIBRARY "" CACHE FILEPATH "Path to the native xpact library or Windows import library exposing the libexpat ABI")
set(XPACT_INCLUDE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../include" CACHE PATH "Path to xpact public headers")

if(NOT EXPAT_SOURCE_DIR)
	message(FATAL_ERROR "Set EXPAT_SOURCE_DIR to an upstream libexpat checkout")
endif()

if(EXISTS "${EXPAT_SOURCE_DIR}/expat/tests")
	set(EXPAT_DIR "${EXPAT_SOURCE_DIR}/expat")
elseif(EXISTS "${EXPAT_SOURCE_DIR}/tests")
	set(EXPAT_DIR "${EXPAT_SOURCE_DIR}")
else()
	message(FATAL_ERROR "Could not find expat/tests below EXPAT_SOURCE_DIR")
endif()

if(NOT EXISTS "${XPACT_LIBRARY}")
	message(FATAL_ERROR "Set XPACT_LIBRARY to the native xpact library before building the C suite")
endif()

set(EXPAT_TESTS_DIR "${EXPAT_DIR}/tests")
set(EXPAT_LIB_DIR "${EXPAT_DIR}/lib")

set(EXPAT_TEST_SOURCES
	acc_tests.c
	alloc_tests.c
	basic_tests.c
	chardata.c
	common.c
	dummy.c
	handlers.c
	memcheck.c
	minicheck.c
	misc_tests.c
	ns_tests.c
	nsalloc_tests.c
	runtests.c
	structdata.c
)

set(EXPAT_TEST_SOURCE_PATHS "")
foreach(source_name IN LISTS EXPAT_TEST_SOURCES)
	set(source_path "${EXPAT_TESTS_DIR}/${source_name}")
	if(NOT EXISTS "${source_path}")
		message(FATAL_ERROR "Missing upstream Expat test source: ${source_path}")
	endif()
	list(APPEND EXPAT_TEST_SOURCE_PATHS "${source_path}")
endforeach()

add_library(xpact_expat UNKNOWN IMPORTED GLOBAL)
set_target_properties(xpact_expat PROPERTIES
	IMPORTED_LOCATION "${XPACT_LIBRARY}"
	INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/include;${XPACT_INCLUDE_DIR}"
)

add_executable(xpact_libexpat_runtests
	${EXPAT_TEST_SOURCE_PATHS}
	"${CMAKE_CURRENT_LIST_DIR}/xpact_test_shims.c"
)
target_include_directories(xpact_libexpat_runtests
	BEFORE PRIVATE
		"${CMAKE_CURRENT_LIST_DIR}/include"
		"${XPACT_INCLUDE_DIR}"
		"${EXPAT_TESTS_DIR}"
		"${EXPAT_LIB_DIR}"
)
target_compile_definitions(xpact_libexpat_runtests PRIVATE
	XML_TESTING
	XML_DTD=1
	XML_GE=1
	XML_CONTEXT_BYTES=1024
)
target_link_libraries(xpact_libexpat_runtests PRIVATE xpact_expat)

enable_testing()
add_test(NAME upstream-libexpat-runtests COMMAND xpact_libexpat_runtests)
