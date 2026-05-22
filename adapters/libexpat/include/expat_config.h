#ifndef XPACT_ADAPTER_EXPAT_CONFIG_H
#define XPACT_ADAPTER_EXPAT_CONFIG_H

/*
 * Minimal configuration header for compiling upstream Expat tests against the
 * xpact libexpat-compatible ABI. Keep feature macros aligned with xpact.h.
 */

#ifndef XML_CONTEXT_BYTES
#define XML_CONTEXT_BYTES 1024
#endif

#ifndef XML_DTD
#define XML_DTD 1
#endif

#ifndef XML_GE
#define XML_GE 1
#endif

#ifndef XML_NS
#define XML_NS 1
#endif

#ifndef BYTEORDER
#if defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__) && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define BYTEORDER 4321
#else
#define BYTEORDER 1234
#endif
#endif

#define HAVE_MEMMOVE 1
#define HAVE_BCOPY 0
#define HAVE_GETRANDOM 0
#define HAVE_SYSCALL_GETRANDOM 0
#define HAVE_ARC4RANDOM_BUF 0
#define HAVE_SYS_GETRANDOM 0
#define HAVE_SYS_PARAM_H 0
#define HAVE_SYS_RANDOM_H 0
#define HAVE_UNISTD_H 0

#endif
