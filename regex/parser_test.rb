#!/usr/bin/env ruby

require 'test/unit'
require 'parser'
require 'node'

class Parser_Test < Test::Unit::TestCase

    def parse_test(expr, str)
        assert_equal(str, prefix(Regex::Parser.parse_tree(expr)), "#{expr} != #{str}")
    end

    def parse_test_error(expr)
        assert_raise SyntaxError do
            Regex::Parser.parse_tree(expr)
        end
    end

    def prefix(tree)
        return '' unless tree
        pre = case tree.token_type
        when :star then
            '*'
        when :opt then
            '?'
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
        parse_test("ab?", "+a?b")
        parse_test("a*b", "+*ab")
        parse_test("a?b", "+?ab")
        parse_test("a*b*", "+*a*b")
        parse_test("a?b?", "+?a?b")
        parse_test("a**", "**a")
        parse_test("a??", "??a")
        parse_test("a**b", "+**ab")
        parse_test("a??b", "+??ab")
        parse_test("ab*c", "+a+*bc")
        parse_test("ab?c", "+a+?bc")
        parse_test("a*b*c*", "+*a+*b*c")
        parse_test("a?b?c?", "+?a+?b?c")
        parse_test("a*b?c?", "+*a+?b?c")
        parse_test("a*?", "?*a")
        parse_test("a*?b", "+?*ab")
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
        parse_test("a(b)?", "+a?b")
        parse_test("(ab)*(cd)*", "+*+ab*+cd")
        parse_test("(ab)*(cd)*(e)*", "+*+ab+*+cd*e")
        parse_test("(ab)*(cd)?(e)*", "+*+ab+?+cd*e")
    end

    def test_escape
        parse_test("\\a", "a")
        parse_test("\\(", "(")
        parse_test("\\*", "*")
        parse_test("\\", "\\")
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
        parse_test("ab|cde|fg", "|+ab|+c+de+fg")
        parse_test("ab|cd*e|fg", "|+ab|+c+*de+fg")
        parse_test("ab|cd|ef|gh", "|+ab|+cd|+ef+gh")
        parse_test("a*|b", "|*ab")
        parse_test("a|b*|c", "|a|*bc")
        parse_test("(ab*c)|d|e*", "|+a+*bc|d*e")
        parse_test("ab|cd*e|(fg)|hijk", "|+ab|+c+*de|+fg+h+i+jk")
        parse_test("abcd*(efg)|h(ij)*k", "|+a+b+c+*d+e+fg+h+*+ijk")
    end

    def test_syntax
        parse_test_error("(")
        parse_test_error(")")
        parse_test_error("(abc")
        parse_test_error("abc)")
    end
end 


