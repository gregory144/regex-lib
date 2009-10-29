#!/usr/bin/env ruby

require 'test/unit'
require 'nfa'
require 'regex'
require 'node'

class NFA_Test < Test::Unit::TestCase

    def nfa_test(expr, start, accept, num_states, trans)
        nfa = NFA.construct(RegexParser.parse_tree(expr))
        assert_not_nil(nfa)
        assert_equal(start, nfa.start)
        assert_equal(accept, nfa.accept)
        assert_equal(num_states, nfa.states)
        assert_equal(trans.size, nfa.transitions.size)
        trans.each do |k,v|
            assert_equal(nfa.transitions[k], trans[k])
        end
    end

    def test_simple
        nfa_test("a", 0, 3, 4, {
            [0, nil] => [1], 
            [1, "a"] => [2], 
            [2, nil] => [3],
        })
        nfa_test("ab", 0, 5, 6, {
            [0, nil] => [1], 
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
        })
        nfa_test("abc", 0, 7, 8, {
            [0, nil] => [1], 
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
            [5, "c"] => [6], 
            [6, nil] => [7], 
        })
        nfa_test("ab|c", 0, 9, 10, {
            [0, nil] => [7], 
            [7, nil] => [1, 5], 
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [8], 
            [5, "c"] => [6], 
            [6, nil] => [8], 
            [8, nil] => [9], 
        })

    end

end 


