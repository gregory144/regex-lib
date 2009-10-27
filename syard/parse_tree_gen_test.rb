#!/usr/bin/env ruby

require 'test/unit'
require 'parse_tree_gen'
require 'syard'

class ParseTreeGen_Test < Test::Unit::TestCase

    def test_read_template

        tree = ExpressionParser.new("(1+(1 * 15)^2 !) % 13 / 3").parse_tree

        pt = ParseTreeGen.new
        pt.gen(tree)
    end

end 
