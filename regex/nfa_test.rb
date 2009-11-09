#!/usr/bin/env ruby

require 'test/unit'
require 'nfa'
require 'parser'
require 'node'

class NFA_Test < Test::Unit::TestCase

    def nfa_test(expr, start, accept, num_states, trans, range_trans = nil, else_trans = nil, capture_states = nil)
        nfa = Regex::NFA.construct(Regex::Parser.parse_tree(expr))
        assert_not_nil(nfa)
        assert_equal(start, nfa.start)
        assert_equal(accept, nfa.accept)
        assert_equal(num_states, nfa.states.size)
        assert_equal(trans.size, nfa.transitions.size)
        trans.each do |k,v|
            assert_equal(nfa.transitions[k], trans[k])
        end
        range_trans.each do |start, v|
            assert_equal(nfa.range_transitions[start], v)
        end if range_trans
        else_trans.each do |start, v|
            assert_equal(nfa.else_transitions[start], v)
        end if else_trans
        assert_equal(capture_states, nfa.capture_states) if capture_states
    end

    def test_simple
        nfa_test("a", 1, 2, 2, {
            [1, "a"] => [2], 
        })
        nfa_test("ab", 1, 4, 4, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
        })
        nfa_test("abc", 1, 6, 6, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
            [5, "c"] => [6], 
        })
        nfa_test("ab*c", 1, 6, 6, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [3, nil] => [4], 
            [4, nil] => [5, 3], 
            [5, "c"] => [6], 
        })
        nfa_test("ab+c", 1, 6, 6, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5, 3], 
            [5, "c"] => [6], 
        })
        nfa_test("ab|c", 7, 8, 6, {
            [7, nil] => [1], 
            [7, "c"] => [8], 
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [8], 
        })
        nfa_test("a(b)c", 1, 6, 6, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
            [5, "c"] => [6], 
        }, nil, nil, {
            1 => [3, 4]
        })
        nfa_test("a(bc)d", 1, 8, 8, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
            [5, "c"] => [6], 
            [6, nil] => [7], 
            [7, "d"] => [8], 
        }, nil, nil, {
            1 => [3, 6]
        })
        nfa_test("a(?:bc)d", 1, 8, 8, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [5], 
            [5, "c"] => [6], 
            [6, nil] => [7], 
            [7, "d"] => [8], 
        })
        nfa_test("ab((c)|d)e", 1, 14, 12, {
            [1, "a"] => [2], 
            [2, nil] => [3], 
            [3, "b"] => [4], 
            [4, nil] => [11], 
            [11, nil] => [9], 
            [9, nil] => [5], 
            [9, "d"] => [10], 
            [5, "c"] => [6], 
            [6, nil] => [10], 
            [10, nil] => [12], 
            [12, nil] => [13], 
            [13, "e"] => [14], 
        }, nil, nil, {
            1 => [11, 12],
            2 => [5, 6]
        })
        nfa_test("[a-c]", 1, 2, 2, {}, {
            1 => [["a".."c", 2]]
        })
        nfa_test("a[^a-c]b", 1, 7, 7, {
            [1, "a"] => [2],
            [2, nil] => [3],
            [5, nil] => [6],
            [6, "b"] => [7],
            }, {
            3 => [["a".."c", 4]]
            }, {
            3 => 5
        })
        nfa_test("ab{3}c", 1, 10, 10, {
            [1, "a"] => [2],
            [2, nil] => [3], 
            [3, "b"] => [4],
            [4, nil] => [5], 
            [5, "b"] => [6],
            [6, nil] => [7], 
            [7, "b"] => [8],
            [8, nil] => [9], 
            [9, "c"] => [10],
        })
        nfa_test("ab{10,11}c", 1, 26, 26, {
            [1, "a"] => [2],
            [2, nil] => [3], 
            [3, "b"] => [4],
            [4, nil] => [5], 
            [5, "b"] => [6],
            [6, nil] => [7], 
            [7, "b"] => [8],
            [8, nil] => [9], 
            [9, "b"] => [10],
            [10, nil] => [11], 
            [11, "b"] => [12],
            [12, nil] => [13], 
            [13, "b"] => [14],
            [14, nil] => [15], 
            [15, "b"] => [16],
            [16, nil] => [17], 
            [17, "b"] => [18],
            [18, nil] => [19], 
            [19, "b"] => [20],
            [20, nil] => [21], 
            [21, "b"] => [22],
            [22, nil] => [23], 
            [23, "b"] => [24],
            [23, nil] => [24],
            [24, nil] => [25], 
            [25, "c"] => [26],
        })
        nfa_test("a|b|c", 5, 6, 2, {
            [5, "a"] => [6],
            [5, "b"] => [6],
            [5, "c"] => [6],
        })
        nfa_test(".", 1, 2, 2, {
            1 => [2],
        })

    end

end 


