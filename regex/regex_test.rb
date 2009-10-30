#!/usr/bin/env ruby

require 'test/unit'
require 'regex'

class Regex_Test < Test::Unit::TestCase

    def regex_test(expr, matches, no_matches = [])
        matches = [matches] unless matches.respond_to? :size
        no_matches = [no_matches] unless no_matches.respond_to? :size
        matches.each do |m|
            assert(Regex::Regex.match(expr, m), "matching #{expr} with #{m} (expected true)")
        end
        no_matches.each do |m|
            assert(!Regex::Regex.match(expr, m), "matching #{expr} with #{m} (expected false)")
        end
    end
    
    def regex_test_error(expr)
        assert_raise SyntaxError do
            Regex::Regex.match(expr, nil)
        end
    end

    def test_simple
        regex_test("a", ["a"], ["", "b"])
        regex_test("b", "b")
        regex_test("a*", ["", "a", "aa", "aaaaaa"], ["aaaabaaaa", "b", "baaa", "aaab"])
        regex_test("a?", ["", "a"], ["aa", "aaaaaa", "aaaabaaaa", "b", "baaa", "aaab"])
        regex_test("ab", ["ab"], ["", "a", "b", "abc", "abb", "aab"])
        regex_test("abc", ["abc"], ["", "a", "b", "c", "ab", "bc", "aabc", "abbc", "abcc", "abcabc"])
        regex_test("abcd", "abcd", "abccd")
        regex_test("abcde", "abcde", "abde")
        regex_test("ab*", ["a", "ab", "abb", "abbbbb"], ["b", "ba"])
        regex_test("ab?", ["a", "ab"], ["abb", "abbbbb", "b", "ba"])
        regex_test("a*b", ["b", "ab", "aab"], "a")
        regex_test("a*b*", ["", "a", "b", "ab", "aa", "bb", "aab", "abb", "aaa", "aaabbb"], ["ba", "c", "aaaac"])
        regex_test("a**", ["", "a", "aaaaa"], ["b"])
        regex_test("a??", ["", "a"], ["aa", "aaa", "b"])
        regex_test("a**b", ["b", "ab", "aab"]) 
        regex_test("ab*c", ["ac", "abc", "abbc", "abbbbbbbc"], ["bbbbbc", "abbbbb", "a", "c"])
        regex_test("ab?c", ["ac", "abc"], ["abbc", "abbbc", "bbbbbc", "abbbbb", "a", "c"])
        regex_test("a*b*c*", ["", "a", "b", "c", "ab", "ac", "bc", "aa", "bb", "cc", "aab", "abb", "abbc", "aaaaaaabc", "aaabbbbbbc"], 
            ["d", "ad", "ba", "ca", "cb", "aaaaabbbbbabbc", "aacbc"])
    end

    def test_parens
        regex_test("(a)", "a")
        regex_test("(ab)", "ab", "a")
        regex_test("(ab)c", "abc", "ac")
        regex_test("(a)bc", "abc", "bc")
        regex_test("a(b)c", "abc", "ab")
        regex_test("ab(c)", "abc", "")
        regex_test("(ab)(cd)", "abcd", "bcd")
        regex_test("(ab)*(cd)", ["cd", "abcd"], ["acd", "acid", "bcd"])
        regex_test("(b)*", ["", "b", "bbb"], ["ba", "ab"])
        regex_test("a(b)*", ["a", "ab", "abbb"], ["aa", "aba"])
        regex_test("(ab)*(cd)*", ["", "ab", "ababab", "cd", "cdcd", "abcd", "ababcd", "abcdcd"], ["acd", "abc", "abd", "abababbab", "cdcdccdc"])
        regex_test("(ab)*(cd)*(e)*", ["", "abe", "abcde", "cdeeeeee"], ["cdabe", "abce", "abce", "abababbcdcdcdeee", "abecd"])
    end

    def test_escape
        regex_test("a\\*b", ["a*b"], ["ab", "aaaab", "b"])
        regex_test("ac*b", ["acb", "ab", "acb"], ["aaaab", "b"])
        regex_test("a\\**b", ["a*b", "a**b", "ab", "a*****b"], ["aaaab", "b"])
    end

    def test_or
        regex_test("a|b", ["a", "b"], ["", "ab"])
        regex_test("a|b|c", ["a", "b", "c"], ["d", "ab", "bc"])
        regex_test("a|b|c|d", ["b", "d"], ["", "e"])
        regex_test("a|b?|c", ["a", "", "b", "c"], ["d", "ab", "bc"])
        regex_test("(a)|b", ["a", "b"], ["", "ab", "c"])
        regex_test("(a)|(b)", ["a", "b"], ["", "ab"])
        regex_test("ab|c", ["ab", "c"], ["", "ac", "abc"])
        regex_test("(ab)|c", ["ab", "c"], ["", "ac", "abc"])
        regex_test("ab|cd", ["ab", "cd"], ["abcd", "a", "b", "c", "d", "ac", "ad", "bc", "bd", "", "e"])
        regex_test("ab|cde|fg", ["ab", "cde", "fg"], ["", "a", "c", "f", "d", "abfg", "cdefg"])
        regex_test("ab|cd*e|fg", ["ab", "cde", "cdddde", "fg"], ["", "a", "c", "cdee", "cdeee", "h"])
        regex_test("ab|cd?e|fg", ["ab", "cde", "ce", "fg"], ["", "a", "c", "cdee", "cdeee", "h"])
        regex_test("ab|cd|ef|gh", ["ab", "cd", "ef", "gh"], ["", "e"])
        regex_test("a*|b", ["", "a", "b", "aaa", "aaaaaaaaaaaaaaaa"], ["aaaab", "aab"])
        regex_test("a|b*|c", ["", "a", "b", "bbbb", "bbbbbbb", "c"], ["ab", "bd"])
        regex_test("(ab*c)|d|e*", ["", "ac", "d", "e", "eeee", "abc", "abbbbbc"], ["a", "bbbbc", "abcde", "acd"])
        regex_test("ab|cd*e|(fg)|hijk", ["ab", "ce", "cde", "fg", "hijk"], ["", "abc", "cdee"])
        regex_test("abcd*(efg)|h(ij)*k", ["abcefg", "hk", "abcdefg", "hijk", "abcddddefg", "hijijijijijk"], ["", "abcdef", "hij", "ijk"])
    end

    def test_char_class
        regex_test("\\([0-9][0-9][0-9]\\)", ["(123)", "(000)", "(999)"], ["()", "(aaa)"])
        regex_test("\\([0-9][0-9][0-9]\\)-[0-9][0-9](0|1|2|3|4|5|6|7|8|9)-[0-9][0-9][0-9][0-9]", ["(123)-456-7890"])
    end

    def test_syntax
        regex_test_error("(")
        regex_test_error(")")
        regex_test_error("(ab")
        regex_test_error("abc)")
    end
end 


