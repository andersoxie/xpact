
/* ---- appended by reports/gobo-dll/build_gobo_dll.ps1 to Gobo's generated C (needs its runtime internals) ----
 * xp_gobo_ensure_thread: let a thread that Gobo did not create call Eiffel code, the way Gobo's own
 * GE_thread_create_with_attr / GE_thread_routine set up a thread: register it with the Boehm GC, give it a
 * GE_context with a thread context, per-thread onces and an exception manager, then register the context.
 * Called by the xpact bridge before every call into Eiffel (cheap after the first time).
 */
#ifdef GE_USE_THREADS
static GE_call xp_gobo_external_call = {"", "xpact C API call", 0};

static __declspec(thread) int xp_adopted;
static __declspec(thread) GE_context* xp_adopted_context;
/* GE_new_context allocates the context with GE_calloc (collectable). Gobo's own threads keep it on the stack of
 * GE_thread_routine; here only Windows TLS points to it, and Boehm does not scan TLS. This uncollectable slot
 * keeps the context (and everything reachable from it) alive until the thread leaves. */
static __declspec(thread) void** xp_adopted_root;

void xp_gobo_ensure_thread(void)
{
	GE_context* l_context;
	GE_thread_context* l_thread_context;
	struct GC_stack_base l_stack_base;

	if (xp_adopted || GE_current_context()) {
		xp_adopted = 1;
		return;
	}
	if (GC_get_stack_base(&l_stack_base) == GC_SUCCESS) {
		GC_register_my_thread(&l_stack_base);
	}
	xp_adopted = 2; /* 2 = this file registered the thread and must release it */
	l_thread_context = (GE_thread_context*)GE_unprotected_calloc_uncollectable(1, sizeof(GE_thread_context));
	l_thread_context->thread_id = GE_current_thread();
	l_thread_context->is_alive = 1;
	l_thread_context->initial_priority = GE_thread_default_priority();
	l_context = GE_new_context(0);
	xp_adopted_root = (void**)GC_MALLOC_UNCOLLECTABLE(sizeof(void*));
	*xp_adopted_root = l_context;
	l_context->thread = l_thread_context;
	l_context->call = &xp_gobo_external_call;
	GE_register_thread_context(l_context);
	GE_thread_init_onces(l_context);
	GE_init_exception(l_context);
	xp_adopted_context = l_context;
}

/* xp_gobo_release_thread: called from DllMain(DLL_THREAD_DETACH). Like the end of Gobo's GE_thread_routine,
 * unbind and free the per-thread data, then remove the thread from the Boehm GC: a registered thread that has
 * exited makes the next collection fail (step 4 of reports/issue-0304/steps.c crashed without this). */
void xp_gobo_release_thread(void)
{
	GE_context* l_context = xp_adopted_context;

	if (xp_adopted != 2 || !l_context) {
		return;
	}
	EIF_TSD_SET(GE_thread_context_key, 0, "Cannot remove thread context to TSD.");
	if (l_context->thread_onces) {
		GE_free_onces(l_context->thread_onces);
	}
	GE_free_exception(l_context);
	xp_adopted_context = 0;
	xp_adopted = 0;
	if (xp_adopted_root) {
		GC_FREE(xp_adopted_root);
		xp_adopted_root = 0;
	}
	GC_unregister_my_thread();
}
#else
void xp_gobo_ensure_thread(void) {}
void xp_gobo_release_thread(void) {}
#endif
