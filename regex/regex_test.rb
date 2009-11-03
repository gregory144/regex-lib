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
        regex_test(".", ["a", "b", "c", ".", "0"], ["", "aa", "bb", ".."])
        regex_test("b", "b")
        regex_test("a*", ["", "a", "aa", "aaaaaa"], ["aaaabaaaa", "b", "baaa", "aaab"])
        regex_test(".*", ["", "a", "aa", "aaaaaa", "aba", "234adf", "asdfSAFa342"]) 
        regex_test(".+", ["a", "aa", "aaaaaa", "aba", "234adf", "asdfSAFa342"], [""]) 
        regex_test("a?", ["", "a"], ["aa", "aaaaaa", "aaaabaaaa", "b", "baaa", "aaab"])
        regex_test("ab", ["ab"], ["", "a", "b", "abc", "abb", "aab"])
        regex_test("abc", ["abc"], ["", "a", "b", "c", "ab", "bc", "aabc", "abbc", "abcc", "abcabc"])
        regex_test("abcd", "abcd", "abccd")
        regex_test("abcde", "abcde", "abde")
        regex_test("ab*", ["a", "ab", "abb", "abbbbb"], ["b", "ba"])
        regex_test("ab+", ["ab", "abb", "abbbbb"], ["a", "b", "ba"])
        regex_test("ab?", ["a", "ab"], ["abb", "abbbbb", "b", "ba"])
        regex_test("a*b", ["b", "ab", "aab"], "a")
        regex_test("a+b", ["ab", "aab"], ["a", "b", ""])
        regex_test("a*b*", ["", "a", "b", "ab", "aa", "bb", "aab", "abb", "aaa", "aaabbb"], ["ba", "c", "aaaac"])
        regex_test("a+b+", ["ab", "aab", "abb", "aabbb"], ["", "a", "b", "ba", "aaa", "bbb", "c", "aaaac"])
        regex_test("a??", ["", "a"], ["aa", "aaa", "b"])
        regex_test("ab*c", ["ac", "abc", "abbc", "abbbbbbbc"], ["bbbbbc", "abbbbb", "a", "c"])
        regex_test("ab?c", ["ac", "abc"], ["abbc", "abbbc", "bbbbbc", "abbbbb", "a", "c"])
        regex_test("a*b*c*", ["", "a", "b", "c", "ab", "ac", "bc", "aa", "bb", "cc", "aab", "abb", "abbc", "aaaaaaabc", "aaabbbbbbc"], 
            ["d", "ad", "ba", "ca", "cb", "aaaaabbbbbabbc", "aacbc"])
    end

    def test_parens
        regex_test("(a)", "a")
        regex_test("(.)", ["a", "b"])
        regex_test("(ab)", "ab", "a")
        regex_test("(ab)c", "abc", "ac")
        regex_test("(a.)c", ["abc", "aac", "a3c"], ["ac", ""])
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

    def test_rep
        regex_test("ab{3}c", ["abbbc"], ["", "ac", "a", "c", "ab", "bc", "abc", "abbc", "abbbbc"])
        regex_test("ab{3,5}c", ["abbbc", "abbbbc", "abbbbbc"], ["", "ac", "a", "c", "ab", "bc", "abc", "abbc", "abbbbbbc"])
        regex_test("(ab){3,5}", ["ababab", "abababab", "ababababab"], ["", "a", "b", "ab", "abab", "ababa", "ababb", "abababababab", "abababababa", "abababababb"])
        regex_test("(a|b){2,3}", ["aa", "bb", "ab", "ba", "aaa", "bbb", "aab", "aba", "abb", "baa", "bab", "bba"], ["", "a", "b", "c", "ac", "ca", "caa", "abbc", "baac"])
        regex_test("a{1,}", ["a", "aa", "aaaaaa"], ["", "b", "ab"])
        regex_test("a{3,}", ["aaa", "aaaaaa", "aaaaaaaaaaaa"], ["", "a", "aa", "b", "ab"])
        regex_test("(a|b){2,}", ["ab", "aa", "bb", "abb", "aaa", "bbb", "aabbabababa"], ["", "a", "b"])
        regex_test("(ab)*c{11}d", ["cccccccccccd", "abcccccccccccd", "ababcccccccccccd"], ["", "acccccccccccd", "ccccccccccd", "abcd"])
        regex_test("[a-c]{3}", ["aaa", "abc", "ccc"], ["", "a", "b", "c", "aa", "aaaa"])
        regex_test("a{3}b{3}", ["aaabbb"], ["aaa", "bbb", "aabb", "aabbb", "aaabb"])
        regex_test("\\(?[0-9]{3}", ["000", "(000"], ["00", "0"])
        regex_test("\\(?[0-9]{3}\\)?-?[0-9]{3}-?[0-9]{4}", ["1111111111", "2222222222", "(111)-111-1111", "(1001001000", "100)100-1000", "100-1001000"], ["100+100+1000", "1000-100-1000", "10-100-1000", "100-1000-100"])
        regex_test("\\(?[0-9]{3}\\)?-?[0-9]{3}-?[0-9]{4}(x?[0-9]{1,5})?", ["1111111111", "2222222222", "(111)-111-1111", "(1001001000", "100)100-1000", "100-1001000", "100-100-1000x1", "100-100-1000x11111", "100100100011111", "1001001000x111"], ["100+100+1000", "1000-100-1000", "10-100-1000", "100-1000-100", "1001001000x", "1001001000x111111"])
    end

    def test_syntax
        regex_test_error("(")
        regex_test_error(")")
        regex_test_error("(ab")
        regex_test_error("abc)")
        regex_test_error("[")
        regex_test_error("]")
        regex_test_error("[ab")
        regex_test_error("ab]")
        # nested quantifier
        regex_test_error("a**")
        regex_test_error("a++")
        regex_test_error("a+*")
        regex_test_error("a*+")
        regex_test_error("a?+")
        regex_test_error("a?*")
    end
end 


