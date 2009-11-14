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
        use_parens = tree.token_type?(:concat, :or, :not)
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
        when :not then
            'N'
        when :cap then
            'C'
        when :simple then
            tree.value
        when :anchor then
            case tree.value
            when :newline
                '^'
            when :endline
                '$'
            end
        when :num then
            "#{tree.value.respond_to?(:begin) ? "#{tree.value.begin},#{tree.value.end}" : tree.value}"
            tree.value
        when :any then
            '.'
        when :range then
            "-(#{tree.value.begin},#{tree.value.end})"
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
        parse_test(".", ".")
        parse_test("a.b", ".(a.b)")
        parse_test("..", ".(..)")
        parse_test("...", ".(...)")
        parse_test(".*", "*.")
        parse_test(".+", "+.")
        parse_test(".?", "?.")
    end

    def test_parens
        parse_test("(a)", "Ca")
        parse_test("(.)", "C.")
        parse_test("(ab)", "C.(ab)")
        parse_test("(a.)", "C.(a.)")
        parse_test("(ab)c", ".(C.(ab)c)")
        parse_test("(a)bc", ".(Cabc)")
        parse_test("a(b)c", ".(aCbc)")
        parse_test("ab(c)", ".(abCc)")
        parse_test("(ab)(cd)", ".(C.(ab)C.(cd))")
        parse_test("(ab)*(cd)", ".(*C.(ab)C.(cd))")
        parse_test("(b)*", "*Cb")
        parse_test("(.)*", "*C.")
        parse_test("(b)+", "+Cb")
        parse_test("a(b)*", ".(a*Cb)")
        parse_test("a(b)+", ".(a+Cb)")
        parse_test("a(b)?", ".(a?Cb)")
        parse_test("(ab)*(cd)*", ".(*C.(ab)*C.(cd))")
        parse_test("(ab)*(cd)*(e)*", ".(*C.(ab)*C.(cd)*Ce)")
        parse_test("(ab)+(cd)+(e)+", ".(+C.(ab)+C.(cd)+Ce)")
        parse_test("(ab)*(cd)?(e)*", ".(*C.(ab)?C.(cd)*Ce)")
        parse_test("(?:a)", "a")
        parse_test("a(?:b)c", ".(abc)")
        parse_test("a(?:b)*c", ".(a*bc)")
        parse_test("a(?:b*c)?", ".(a?.(*bc))")
        parse_test("(ab)*(?:cd)?(?:e)*", ".(*C.(ab)?.(cd)*e)")
    end

    def test_escape
        parse_test("\\(", "(")
        parse_test("\\*", "*")
        parse_test("\\", "\\")
        parse_test("\\.", ".")
        parse_test("\\t", "\t")
        parse_test("\\n", "\n")
        parse_test("\\d", "-(0,9)")
        parse_test("\\w", "|(-(a,z)-(A,Z)-(0,9)_)")
        parse_test("\\s", "|( \t\r\n)")
    end

    def test_or
        parse_test("a|b", "|(ab)")
        parse_test("a|b|c", "|(abc)")
        parse_test("a|b|c|d", "|(abcd)")
        parse_test("(a)|b", "|(Cab)")
        parse_test("(a)|(b)", "|(CaCb)")
        parse_test("ab|c", "|(.(ab)c)")
        parse_test("(ab)|c", "|(C.(ab)c)")
        parse_test("(?:ab)|c", "|(.(ab)c)")
        parse_test("ab|cd", "|(.(ab).(cd))")
        parse_test("ab|cde|fg", "|(.(ab).(cde).(fg))")
        parse_test("ab|cd*e|fg", "|(.(ab).(c*de).(fg))")
        parse_test("ab|cd+e|fg", "|(.(ab).(c+de).(fg))")
        parse_test("ab|cd|ef|gh", "|(.(ab).(cd).(ef).(gh))")
        parse_test("a*|b", "|(*ab)")
        parse_test("a+|b", "|(+ab)")
        parse_test("a|b*|c", "|(a*bc)")
        parse_test("a|b+|c", "|(a+bc)")
        parse_test("(ab*c)|d|e*", "|(C.(a*bc)d*e)")
        parse_test("(?:ab*c)|d|e*", "|(.(a*bc)d*e)")
        parse_test("ab|cd*e|(fg)|hijk", "|(.(ab).(c*de)C.(fg).(hijk))")
        parse_test("abcd*(efg)|h(ij)*k", "|(.(abc*dC.(efg)).(h*C.(ij)k))")
        parse_test("abcd+(efg)|h(ij)+k", "|(.(abc+dC.(efg)).(h+C.(ij)k))")
    end

    def test_char_class
        parse_test("[a]", "a")
        parse_test("[ab]", "|(ab)")
        parse_test("[abc]", "|(abc)")
        parse_test("[a-b]", "-(a,b)")
        parse_test("[a-c]", "-(a,c)")
        parse_test("[-a-b]", "|(--(a,b))")
        parse_test("[a-c.]", "|(-(a,c).)")
        parse_test("[\\ta\\n]", "|(\ta\n)")
        parse_test("[^a]", "N(a)")
        parse_test("[^abcd]", "N(abcd)")
        parse_test("[^a-z]", "N(-(a,z))")
        parse_test("[^-a-z]", "N(--(a,z))")
    end

    def test_repetition
        parse_test("a{1}", "a")
        parse_test("a{3}", ".(aaa)")
        parse_test("a{3,5}", ".(aaa?a?a)")
        parse_test("(ab){3,5}", ".(C.(ab)C.(ab)C.(ab)?C.(ab)?C.(ab))")
        parse_test("(a|b){3,5}", ".(C|(ab)C|(ab)C|(ab)?C|(ab)?C|(ab))")
        parse_test("(?:a|b){3,5}", ".(|(ab)|(ab)|(ab)?|(ab)?|(ab))")
        parse_test("a{10,11}", ".(aaaaaaaaaa?a)")
        parse_test("a{0,}", "*a")
        parse_test("a{1,}", ".(a*a)")
        parse_test("a{2,}", ".(aa*a)")
        parse_test("a{10,}", ".(aaaaaaaaaa*a)")
    end

    def test_syntax
        parse_test_error("")
        parse_test_error("(")
        parse_test_error(")")
        parse_test_error("(?:")
        parse_test_error("(abc")
        parse_test_error("(?:abc")
        parse_test_error("abc)")
        parse_test_error("[")
        parse_test_error("]")
        parse_test_error("[ab")
        parse_test_error("ab]")
        parse_test_error("a{0}")
        parse_test_error("a{a,b}")
        # nested quantifier
        parse_test_error("a**")
        parse_test_error("a++")
        parse_test_error("a+*")
        parse_test_error("a*+")
        parse_test_error("a?+")
        parse_test_error("a?*")
    end

    def test_anchors
        parse_test("^a", ".(^a)")
        parse_test("^abc", ".(^abc)")
        parse_test("^abc$", ".(^abc$)")
    end
end 

