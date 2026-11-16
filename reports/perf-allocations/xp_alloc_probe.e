note
	description: "[
		Where does parse time go? Parses one file `rounds' times with XP_PARSER and a null handler
		(single-threaded runtime, finalized) and prints wall time, garbage-collection cycles and GC CPU time.
		Usage: xp_alloc_probe <file> <rounds> [gc_off]
	]"

class
	XP_ALLOC_PROBE

inherit
	MEMORY

create
	make

feature {NONE} -- Initialization

	make
		local
			l_args: ARGUMENTS_32
			l_text: STRING_8
			l_rounds, k, l_good: INTEGER
			l_start: DATE_TIME
			l_ms: INTEGER_64
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_full, l_incr: GC_INFO
		do
			create l_args
			l_text := file_text (l_args.argument (1).to_string_8)
			l_rounds := l_args.argument (2).to_integer
			if l_args.argument_count >= 3 then
				collection_off
			end
			create l_start.make_now
			from k := 1 until k > l_rounds loop
				create l_handler.make
				create l_parser.make (l_handler)
				if l_parser.parse (l_text) then l_good := l_good + 1 end
				k := k + 1
			end
			l_ms := ((create {DATE_TIME}.make_now).relative_duration (l_start).fine_seconds_count * 1000).truncated_to_integer_64
			l_full := gc_statistics ({MEM_CONST}.full_collector)
			l_incr := gc_statistics ({MEM_CONST}.incremental_collector)
			io.put_string ("bytes " + l_text.count.out + " rounds " + l_rounds.out + " ok " + l_good.out
				+ " | wall " + l_ms.out + " ms"
				+ " | full GC cycles " + l_full.cycle_count.out + " cpu " + (l_full.cpu_time * 1000).truncated_to_integer.out + " ms"
				+ " | incremental GC cycles " + l_incr.cycle_count.out + " cpu " + (l_incr.cpu_time * 1000).truncated_to_integer.out + " ms%N")
		end

	file_text (a_path: STRING_8): STRING_8
		local
			l_file: RAW_FILE
		do
			create l_file.make_open_read (a_path)
			l_file.read_stream (l_file.count)
			Result := l_file.last_string
			l_file.close
		end

end
