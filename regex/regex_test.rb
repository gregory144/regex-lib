#!/usr/bin/env ruby

require 'test/unit'
require 'regex'

class RegexParser_Test < Test::Unit::TestCase

    def parse_test(expr, str)
        assert_equal(str, prefix(RegexParser.parse_tree(expr)), "#{expr} != #{str}")
    end

    def prefix(tree)
        return '' unless tree
        pre = case tree.token_type
        when :star then
            '*'
        when :concat then
            '+'
        when :or then
            '|'
        when :simple then
            tree.value
        else 
            ''
        end
        tree.operands.each do |op|
            pre += prefix(op)
        end if tree.operands
        pre
    end

    def test_simple
        parse_test("a", "a")
        parse_test("b", "b")
        parse_test("a*", "*a")
        parse_test("ab", "+ab")
        parse_test("abc", "+a+bc")
        parse_test("abcd", "+a+b+cd")
        parse_test("abcde", "+a+b+c+de")
        parse_test("ab*", "+a*b")
        parse_test("a*b", "+*ab")
        parse_test("a*b*", "+*a*b")
        parse_test("a**", "**a")
        parse_test("a**b", "+**ab")
        parse_test("ab*c", "+a+*bc")
        parse_test("a*b*c*", "+*a+*b*c")
    end

    def test_parens
        parse_test("(a)", "a")
        parse_test("(ab)", "+ab")
        parse_test("(ab)c", "++abc")
        parse_test("(a)bc", "+a+bc")
        parse_test("a(b)c", "+a+bc")
        parse_test("ab(c)", "+a+bc")
        parse_test("(ab)(cd)", "++ab+cd")
        parse_test("(ab)*(cd)", "+*+ab+cd")
        parse_test("(b)*", "*b")
        parse_test("a(b)*", "+a*b")
        parse_test("(ab)*(cd)*", "+*+ab*+cd")
        parse_test("(ab)*(cd)*(e)*", "+*+ab+*+cd*e")
    end

    def test_or
        parse_test("a|b", "|ab")
        parse_test("a|b|c", "|a|bc")
        parse_test("a|b|c|d", "|a|b|cd")
        parse_test("(a)|b", "|ab")
        parse_test("(a)|(b)", "|ab")
        parse_test("ab|c", "|+abc")
        parse_test("(ab)|c", "|+abc")
        parse_test("ab|cd", "|+ab+cd")
        parse_test("a*|b", "|*ab")
        parse_test("a|b*|c", "|a|*bc")
        parse_test("(ab*c)|d|e*", "|+a+*bc|d*e")
    end
end 
