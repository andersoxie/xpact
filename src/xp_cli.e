note
	description: "Small xpact command line smoke target."

class
	XP_CLI

create
	make

feature {NONE} -- Initialization

	make
		local
			l_handler: XP_NULL_EVENT_HANDLER
			l_parser: XP_PARSER
			l_ok: BOOLEAN
		do
			create l_handler.make
			create l_parser.make (l_handler)
			l_ok := l_parser.parse ("<xpact><phase n=%"1%">credible release</phase></xpact>")
			if l_ok then
				io.put_string ("xpact smoke parse: ok%N")
			else
				io.put_string ("xpact smoke parse: ")
				io.put_string (l_parser.last_error)
				io.put_new_line
			end
		end

end

