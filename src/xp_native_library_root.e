note
	description: "Root used when packaging xpact as an Eiffel-backed native library."

class
	XP_NATIVE_LIBRARY_ROOT

create
	make

feature {NONE} -- Initialization

	make
			-- Install the Eiffel parser behind the native C ABI.
		local
			l_bridge: XP_NATIVE_BRIDGE_EXPORT
		do
			create l_bridge.make
			bridge := l_bridge
			installed := l_bridge.install
			check
				runtime_bridge_installed: installed
			end
		ensure
			installed: installed
			bridge_attached: attached bridge
		end

feature -- Access

	bridge: detachable XP_NATIVE_BRIDGE_EXPORT
			-- Eiffel bridge retained for the lifetime of the native runtime.

	installed: BOOLEAN
			-- Was the bridge installed?

end
