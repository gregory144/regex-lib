#!/usr/bin/env ruby

require 'test/unit'
require 'syard'

class ExpressionParser_Test < Test::Unit::TestCase

    def parse_test(expr, val = -1)
        assert_equal(val, ExpressionParser.new(expr).parse, "Expression #{expr} != #{val}")
    end

    def test_num
        parse_test("1", 1)
        parse_test("10", 10)
        parse_test("999", 999)
    end

    def test_simple
        parse_test("1+1", 2)
        parse_test("10*10", 100)
        parse_test("100/10", 10)
    end

    def test_parens
        parse_test("(1)", 1)
        parse_test("1+(1)", 2)
        parse_test("1+(2*2)", 5)
        parse_test("(1+(2*2))", 5)
    end

    def test_whitespace
        parse_test(" 1 ", 1)
        parse_test(" 1 + 1 ", 2)
        parse_test(" ( 1 ) * ( 2 ) *    13", 26)
    end

    def test_fpnum
        parse_test("1.0", 1)
        parse_test("1.0 + 1", 2)
        parse_test("1.2", 1.2)
        parse_test("1.2+3.9", 5.1)
    end
    
    def test_prec
        parse_test("1 - 1 + 1", 1)
        parse_test("1 + 2 * 3", 7)
    end

    def test_unary
        parse_test("1!", 1)
        parse_test("5!", 120)
        parse_test("1-5!", -119)
        parse_test("1-(5!)", -119)
    end

    def test_neg
        parse_test("-1", -1)
        parse_test("(-1)", -1)
        parse_test("2+-1", 1)
        parse_test("3--2", 5)
        parse_test("1+(-5)", -4)
        parse_test("10-(-1)", 11)
        parse_test("-1*8", -8)
        parse_test("8 * -1", -8)
        parse_test("1--1", 2)
        parse_test("1---1", 0)
    end

    def test_right_associative
        parse_test("2^2", 4)
        parse_test("1+2^2", 5)
        parse_test("(5^5) - (5^4)", 2500)
    end
    
    def test_complex
        parse_test("5!-1", 119)
        parse_test("2^2!", 24)
        parse_test("(2^2)!", 24)
        parse_test("2^(2!)", 4)
        parse_test("2^(2!*2)", 16)
        parse_test("1+(2^ (2!*4))", 257)
        parse_test(" ( 50^2 + 80 * 14 ) ^ 3 + 15", 47437928015)
    end

    def test_fails
        assert_raise(SyntaxError) { parse_test("") }
        assert_raise(SyntaxError) { parse_test("(") }
        assert_raise(SyntaxError) { parse_test(")") }
        assert_raise(SyntaxError) { parse_test("()") }
        assert_raise(SyntaxError) { parse_test(")(") }
        assert_raise(SyntaxError) { parse_test("a") }
        assert_raise(SyntaxError) { parse_test("$") }
        assert_raise(SyntaxError) { parse_test("1 + a") }
        assert_raise(SyntaxError) { parse_test("a*a") }
        assert_raise(SyntaxError) { parse_test("1 + ") }
        assert_raise(SyntaxError) { parse_test("+ 1") }
        assert_raise(SyntaxError) { parse_test("1++1") }
        assert_raise(SyntaxError) { parse_test("1**1") }
        assert_raise(SyntaxError) { parse_test("1 1") }
        assert_raise(SyntaxError) { parse_test("1 1 + 3") }
        assert_raise(SyntaxError) { parse_test("-") }
        assert_raise(SyntaxError) { parse_test("- 2 3") }
        assert_raise(SyntaxError) { parse_test("2 3 -") }
    end

    def test_perf
        expr = (1..1000).inject("1") { |x, y| x + "+(100*2)" }

        parse_test(expr, 1+(200*1000))
    end

end 
