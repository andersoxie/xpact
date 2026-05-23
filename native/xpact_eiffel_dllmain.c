#include <windows.h>

#include "eif_main.h"
#include "eif_macros.h"
#include "eif_sig.h"

extern void egc_init_plug(void);
extern void egc_rcdt_init(void);
extern void emain(int argc, EIF_NATIVE_CHAR **argv);

static int xp_eiffel_initialized;

static void
xp_initialize_eiffel_bridge(HINSTANCE instance) {
	if (xp_eiffel_initialized) {
		return;
	}
	ghInstance = instance;
	eif_hInstance = instance;
	eif_hPrevInstance = NULL;
	eif_lpCmdLine = GetCommandLineW();
	eif_nCmdShow = SW_HIDE;

	eif_alloc_init();
#ifdef EIF_THREADS
	eif_thr_init_root();
#endif
	{
		GTCX
		struct ex_vect *exvect;
		jmp_buf exenv;
		int argc = 1;
        EIF_NATIVE_CHAR *argv[] = {L"xpact.dll", L""};

		egc_init_plug();
		initsig();
		initstk();
		exvect = exset((char *)0, 0, (char *)0);
		exvect->ex_jbuf = &exenv;
		if (setjmp(exenv)) {
			failure();
		}
		eif_rtinit(argc, argv, NULL);
		egc_rcdt_init();
		emain(argc, argv);
	}
	xp_eiffel_initialized = 1;
}

BOOL WINAPI
DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
	(void)reserved;
	switch (reason) {
	case DLL_PROCESS_ATTACH:
		xp_initialize_eiffel_bridge(instance);
		break;
	case DLL_PROCESS_DETACH:
		if (xp_eiffel_initialized) {
			reclaim();
			xp_eiffel_initialized = 0;
		}
		break;
	default:
		break;
	}
	return TRUE;
}
