note
    description: "Small, bounded routines with deliberately violated contracts."
class
    ASSERTION_SUBJECT
create
    make
feature
    make
        do
            is_valid := True
        end
    is_valid: BOOLEAN
    test_pre (allowed: BOOLEAN)
        require
            deliberate_precondition: allowed
        do
        end
    test_post (expected: BOOLEAN)
        do
        ensure
            -- Use a dynamic expression: EiffelStudio raises on literal `ensure False'
            -- even when ordinary postcondition monitoring is off.
            deliberate_postcondition: expected
        end
    test_check
        do
            check deliberate_check: False end
        end
    test_invariant
        do
            is_valid := False
        end
    test_loop_invariant
        local
            i: INTEGER
        do
            from i := 0
            invariant deliberate_loop_invariant: i < 0
            until i = 2
            loop i := i + 1
            end
        end
    test_loop_variant
        local
            i: INTEGER
        do
            from i := 0
            until i = 2
            loop i := i + 1
            variant deliberate_loop_variant: 1
            end
        end
    test_negative_variant
        local
            i: INTEGER
        do
            from i := 0
            until i = 2
            loop i := i + 1
            variant deliberate_negative_variant: -1
            end
        end
invariant
    deliberate_invariant: is_valid
end
