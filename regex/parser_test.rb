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
        use_parens = tree.token_type?(:concat, :or)
        pre = case tree.token_type
        when :star then
            '*'
        when :plus then
            '+'
        when :opt then
            '?'
        when :concat then
            '.'
        when :or then
            '|'
        when :simple then
            tree.value
        else 
            ''
        end
        pre += "(" if use_parens
        tree.operands.each do |op|
            pre += prefix(op)
        end if tree.operands
        pre += ")" if use_parens
        pre
    end

    def test_simple
        parse_test("a", "a")
        parse_test("b", "b")
        parse_test("a*", "*a")
        parse_test("a+", "+a")
        parse_test("ab", ".(ab)")
        parse_test("abc", ".(abc)")
        parse_test("abcd", ".(abcd)")
        parse_test("abcde", ".(abcde)")
        parse_test("ab*", ".(a*b)")
        parse_test("ab+", ".(a+b)")
        parse_test("ab?", ".(a?b)")
        parse_test("a*b", ".(*ab)")
        parse_test("a+b", ".(+ab)")
        parse_test("a?b", ".(?ab)")
        parse_test("a*b*", ".(*a*b)")
        parse_test("a+b+", ".(+a+b)")
        parse_test("a?b?", ".(?a?b)")
        parse_test("a??", "??a")
        parse_test("a??b", ".(??ab)")
        parse_test("ab*c", ".(a*bc)")
        parse_test("ab+c", ".(a+bc)")
        parse_test("ab?c", ".(a?bc)")
        parse_test("a*b*c*", ".(*a*b*c)")
        parse_test("a+b+c+", ".(+a+b+c)")
        parse_test("a?b?c?", ".(?a?b?c)")
        parse_test("a*b?c?", ".(*a?b?c)")
        parse_test("a+b?c?", ".(+a?b?c)")
        parse_test("a*?", "?*a")
        parse_test("a+?", "?+a")
        parse_test("a*?b", ".(?*ab)")
        parse_test("a+?b", ".(?+ab)")
        parse_test("a+b*", ".(+a*b)")
        parse_test("a+b*c+", ".(+a*b+c)")
    end

    def test_parens
        parse_test("(a)", "a")
        parse_test("(ab)", ".(ab)")
        parse_test("(ab)c", ".(abc)")
        parse_test("(a)bc", ".(abc)")
        parse_test("a(b)c", ".(abc)")
        parse_test("ab(c)", ".(abc)")
        parse_test("(ab)(cd)", ".(abcd)")
        parse_test("(ab)*(cd)", ".(*.(ab)cd)")
        parse_test("(b)*", "*b")
        parse_test("(b)+", "+b")
        parse_test("a(b)*", ".(a*b)")
        parse_test("a(b)+", ".(a+b)")
        parse_test("a(b)?", ".(a?b)")
        parse_test("(ab)*(cd)*", ".(*.(ab)*.(cd))")
        parse_test("(ab)*(cd)*(e)*", ".(*.(ab)*.(cd)*e)")
        parse_test("(ab)+(cd)+(e)+", ".(+.(ab)+.(cd)+e)")
        parse_test("(ab)*(cd)?(e)*", ".(*.(ab)?.(cd)*e)")
    end

    def test_escape
        parse_test("\\a", "a")
        parse_test("\\(", "(")
        parse_test("\\*", "*")
        parse_test("\\", "\\")
    end

    def test_or
        parse_test("a|b", "|(ab)")
        parse_test("a|b|c", "|(abc)")
        parse_test("a|b|c|d", "|(abcd)")
        parse_test("(a)|b", "|(ab)")
        parse_test("(a)|(b)", "|(ab)")
        parse_test("ab|c", "|(.(ab)c)")
        parse_test("(ab)|c", "|(.(ab)c)")
        parse_test("ab|cd", "|(.(ab).(cd))")
        parse_test("ab|cde|fg", "|(.(ab).(cde).(fg))")
        parse_test("ab|cd*e|fg", "|(.(ab).(c*de).(fg))")
        parse_test("ab|cd+e|fg", "|(.(ab).(c+de).(fg))")
        parse_test("ab|cd|ef|gh", "|(.(ab).(cd).(ef).(gh))")
        parse_test("a*|b", "|(*ab)")
        parse_test("a+|b", "|(+ab)")
        parse_test("a|b*|c", "|(a*bc)")
        parse_test("a|b+|c", "|(a+bc)")
        parse_test("(ab*c)|d|e*", "|(.(a*bc)d*e)")
        parse_test("ab|cd*e|(fg)|hijk", "|(.(ab).(c*de).(fg).(hijk))")
        parse_test("abcd*(efg)|h(ij)*k", "|(.(abc*defg).(h*.(ij)k))")
        parse_test("abcd+(efg)|h(ij)+k", "|(.(abc+defg).(h+.(ij)k))")
    end

    def test_char_class
        parse_test("[a]", "a")
        parse_test("[ab]", "|(ab)")
        parse_test("[abc]", "|(abc)")
        parse_test("[a-b]", "|(ab)")
        parse_test("[a-c]", "|(abc)")
        parse_test("[-a-b]", "|(-ab)")
    end

    def test_syntax
        parse_test_error("(")
        parse_test_error(")")
        parse_test_error("(abc")
        parse_test_error("abc)")
        # nested quantifier
        parse_test_error("a**")
        parse_test_error("a++")
        parse_test_error("a+*")
        parse_test_error("a*+")
        parse_test_error("a?+")
        parse_test_error("a?*")
    end
end 


