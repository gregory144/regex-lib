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
        when :simple then
            tree.value
        else 
            ''
        end 
        pre += prefix(tree.left)
        pre += prefix(tree.right)
        pre
    end

    def verify(tree, node_type, value = nil)
        return tree.value == value if value 
        return tree.token_type == node_type
    end

    def parse_operand(tree, str, num_operands = 1)
        len = tree_equals(tree.left, str)
        (len = tree_equals(tree.right, str[len..-1])) if num_operands == 2
        len
    end

    def test_simple
        parse_test("a", "a")
        parse_test("b", "b")
        parse_test("a*", "*a")
        parse_test("ab", "+ab")
        parse_test("abc", "+a+bc")
        parse_test("abcd", "+a+b+cd")
    end

end 
