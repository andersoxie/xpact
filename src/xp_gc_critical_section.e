note
	description: "Contract-backed temporary Eiffel garbage-collection suspension."

class
	XP_GC_CRITICAL_SECTION

create
	make,
	make_suspended

feature {NONE} -- Initialization

	make
			-- Create inactive critical section.
		do
			create memory
		ensure
			inactive: not is_active
			memory_attached: memory /= Void
		end

	make_suspended
			-- Create critical section and suspend collection immediately.
		do
			make
			enter
		ensure
			active: is_active
			collection_disabled_if_needed: was_collecting implies not collecting
		end

feature -- Access

	is_active: BOOLEAN
			-- Is collection currently under this critical-section policy?

	was_collecting: BOOLEAN
			-- Was collection enabled before `enter'?

	collecting: BOOLEAN
			-- Is Eiffel garbage collection currently enabled?
		do
			Result := memory.collecting
		end

feature -- Basic operations

	enter
			-- Suspend collection, remembering the previous state.
		require
			not_active: not is_active
		do
			was_collecting := memory.collecting
			if was_collecting then
				memory.collection_off
			end
			is_active := True
		ensure
			active: is_active
			previous_state_recorded: was_collecting = old collecting
			collection_disabled_if_needed: was_collecting implies not collecting
		end

	leave
			-- Restore the collection state recorded by `enter'.
		require
			active: is_active
		do
			if was_collecting then
				memory.collection_on
			else
				memory.collection_off
			end
			is_active := False
		ensure
			inactive: not is_active
			collection_state_restored: collecting = was_collecting
		end

	execute (a_action: PROCEDURE)
			-- Execute `a_action' with garbage collection suspended.
		require
			action_attached: a_action /= Void
		do
			memory.execute_without_collection (a_action)
		ensure
			collection_status_preserved: collecting = old collecting
		end

feature {NONE} -- Implementation

	memory: MEMORY
			-- Eiffel runtime memory control.

invariant
	memory_attached: memory /= Void
	active_implies_collection_disabled_if_needed: is_active and was_collecting implies not collecting

end
