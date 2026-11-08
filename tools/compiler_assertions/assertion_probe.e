note
    description: "Deliberate contract violations used to qualify compiler assertion behavior."
class
    ASSERTION_PROBE
create
    make
feature {NONE}
    make
        local
            args: ARGUMENTS
            subject: ASSERTION_SUBJECT
            mode: STRING
            exceptions: EXCEPTIONS
        do
            create args
            create subject.make
            if args.argument_count = 1 then
                mode := args.argument (1)
                if mode.same_string ("pre") then
                    subject.test_pre (False)
                elseif mode.same_string ("post") then
                    subject.test_post (False)
                elseif mode.same_string ("check") then
                    subject.test_check
                elseif mode.same_string ("invariant") then
                    subject.test_invariant
                elseif mode.same_string ("loop_invariant") then
                    subject.test_loop_invariant
                elseif mode.same_string ("loop_variant") then
                    subject.test_loop_variant
                elseif mode.same_string ("negative_variant") then
                    subject.test_negative_variant
                else
                    io.error.put_string ("Unknown assertion probe%N")
                    create exceptions
                    exceptions.die (2)
                end
                io.put_string ("PROBE_COMPLETED " + mode + "%N")
            else
                io.error.put_string ("Supply exactly one assertion probe name%N")
                create exceptions
                exceptions.die (2)
            end
        end
end
