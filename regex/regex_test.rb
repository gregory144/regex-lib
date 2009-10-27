#!/usr/bin/env ruby

require 'test/unit'
require 'regex'

class RegexParser_Test < Test::Unit::TestCase

    def parse_test(expr, tree)
        assert_equal(tree, RegexParser.parse(expr), "#{expr} != #{tree}")
    end

    def test_simple
        parse_test("a", Node.new(:simple, "a"))
    end

end 
