note
	description: "[
		#304: run XP_PARSER on N Eiffel threads at the same time (EiffelStudio's own THREAD class,
		no C bridge, no outside threads). Each thread parses the threads.c document `rounds' times.
		Usage: xp_mt_parse_test <threads> <rounds>
	]"

class
	XP_MT_PARSE_TEST

create
	make

feature {NONE} -- Initialization

	make
		local
			l_threads: ARRAYED_LIST [WORKER_THREAD]
			l_thread: WORKER_THREAD
			l_count, i: INTEGER
			l_control: THREAD_CONTROL
		do
			l_count := argument_integer (1, 4)
			rounds := argument_integer (2, 1000)
			create counter_mutex.make
			create l_threads.make (l_count)
			from i := 1 until i > l_count loop
				create l_thread.make (agent work)
				l_threads.extend (l_thread)
				i := i + 1
			end
			across l_threads as t loop t.item.launch end
			create l_control
			l_control.join_all
			io.put_string ("eiffel threads " + l_count.out + ", parses " + (l_count * rounds).out
				+ ": good " + good.out + ", bad " + bad.out + "%N")
		end

feature {NONE} -- Work

	rounds: INTEGER

	good, bad: INTEGER

	counter_mutex: MUTEX

	work
			-- Parse the document `rounds' times with a fresh parser each time.
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
			k, l_good, l_bad: INTEGER
		do
			from k := 1 until k > rounds loop
				create l_handler.make
				create l_parser.make (l_handler)
				l_ok := l_parser.parse ("<?xml version='1.0'?><!DOCTYPE r [<!ENTITY e 'text'>]><r a='1'><c>&e;</c><c>x &amp; y</c><c/></r>")
				if l_ok then l_good := l_good + 1 else l_bad := l_bad + 1 end
				k := k + 1
			end
			counter_mutex.lock
			good := good + l_good
			bad := bad + l_bad
			counter_mutex.unlock
		end

	argument_integer (a_index, a_default: INTEGER): INTEGER
		local
			l_args: ARGUMENTS_32
		do
			create l_args
			Result := a_default
			if l_args.argument_count >= a_index and then l_args.argument (a_index).is_integer then
				Result := l_args.argument (a_index).to_integer
			end
		end

end
