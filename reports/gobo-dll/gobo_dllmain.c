/* DllMain and lazy start-up for xpact.dll built with Gobo Eiffel (gec).
 * Gobo's generated C has a main() that initialises its runtime (signals, Boehm GC, exception filter)
 * and calls GE_main(), which creates the root object XP_NATIVE_LIBRARY_ROOT. Its make registers the
 * Eiffel parser behind include/xpact.h (XPACT_RegisterEiffelRuntimeBridgePointers). The generated
 * C is compiled with -Dmain=xp_gobo_main, so this DLL runs exactly Gobo's own start-up.
 *
 * It runs on the first XML_ParserCreate* call (xp_gobo_ensure_runtime, once), not in DllMain: the Boehm GC
 * starts its parallel marker threads and waits for them, and new threads cannot start while DllMain holds
 * the Windows loader lock (the first build hung in LoadLibrary unless GC_MARKERS=1).
 */
#include <windows.h>

extern int xp_gobo_main(int argc, char **argv);
extern void xp_gobo_release_thread(void);

static INIT_ONCE xp_gobo_once = INIT_ONCE_STATIC_INIT;

static BOOL CALLBACK
xp_gobo_start(PINIT_ONCE once, PVOID parameter, PVOID *context) {
	(void)once;
	(void)parameter;
	(void)context;
	xp_gobo_main(0, NULL);
	return TRUE;
}

void
xp_gobo_ensure_runtime(void) {
	InitOnceExecuteOnce(&xp_gobo_once, xp_gobo_start, NULL, NULL);
}

BOOL WINAPI
DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
	(void)instance;
	(void)reserved;
	if (reason == DLL_THREAD_DETACH) {
		xp_gobo_release_thread(); /* a thread that called into Eiffel through the C API is leaving */
	}
	return TRUE;
}
