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
        assert_raise SyntaxError, "testing for error with regex #{expr}" do
            Regex::Regex.match(expr, nil)
        end
    end

    def find_test(expr, str, options = {}, matches = nil)
        found = Regex::Regex.find(expr, str)
        if matches and matches.is_a?(String)
            assert_equal(matches, found, "matching #{expr} with #{str}: expected #{matches}")
        elsif matches
            matches.each_with_index do |p, i|
                assert_equal(p, found[i], "matching #{expr} with #{str}: expected capture group #{i} to be \"#{p}\", got \"#{found[i]}\"")
            end if matches
        else
            assert_nil(found, "matching #{expr} with #{str}: expected nil, got: \"#{found}\"")
        end
    end

    def capture_test(expr, str, matches)
        capture_match_test(expr, str, matches)
        capture_find_test(expr, str, matches)
    end

    def capture_match_test(expr, str, matches)
        assert_equal(matches, Regex::Regex.match(expr, str), "matching #{expr} with #{str}")
    end

    def capture_find_test(expr, str, matches)
        assert_equal(matches, Regex::Regex.find(expr, str), "matching #{expr} with #{str}")
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
        regex_test("a\\tb", ["a\tb"], ["a\\tb"])
        regex_test("a\\nb", ["a\nb"], ["a\\nb"])
        regex_test("a\\db", ["a0b", "a7b"], ["", "abb", "adb", "aab", "ab"])
        regex_test("a\\wb", ["a8b", "a7b", "aab", "a_b"], ["", "a#b", "a b", "a]b", "ab"])
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
        regex_test("\\([0-9][0-9][0-9]\\)-[0-9][0-9](0|1|2|3|4|5|6|7|8|9)-[0-9][0-9][0-9][0-9]", ["(123)-456-7890"], ["", "1", "(111)-111-111"])
        regex_test("[^a]", ["b", "c", "d"], ["", "a", "abc"])
        regex_test("[^abc]", ["j", "k", "d"], ["", "a", "b", "c", "aa"])
        regex_test("[^a]+", ["j", "bnbjkk", "bbbbbbbb"], ["", "a", "aaa", "kjfkakjk"])
        regex_test("[^a-c]+", ["j", "nooooppppjkk", "nnnnnnnnn"], ["", "a", "aaa", "kjfkakjk", "jkafjbajfs", "eeeeeeeeeceee"])
        regex_test("a[^a-c]+b", ["ajb", "anooooppppjkkb", "annnnnnnnnb"], ["", "a", "aaa", "akjfkakjkb", "jikafjbajfs", "ajikafjbajfsb", "aeeeeeeeeeceeeb"])
        regex_test("[^\\t]+", ["1234124"], ["3214234\t234234", "\t", "a\tb"])
        regex_test("<a[ \\t\\n]+href=\\\"[^\\\"]*\\\">", ["<a href=\"hello this is a tag\">", "<a href=\"\">"], ["", "<a href=>", "<a href=\"\"\">", "<a href=\"this\" is \">"])
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
        regex_test("[^a-c]{3}", ["ddd", "def", "000"], ["", "a", "b", "c", "aa", "aaaa", "aaa", "bbb", "ccc", "abc", "abb", "bbc"])
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

    def test_find
        find_test("a", "a", nil, "a")
        find_test("a", "bab", nil, "a")
        find_test("ab", "ab", nil, "ab")
        find_test("ab", "1ab1", nil, "ab")
        find_test("a*", "1aa1", nil, "aa")
        find_test("[0-9]*", "jsflkjasdfkjjlksdf34324jalskfjksdaf", nil, "34324")
        find_test("[0-9]{3}", "jsflkjasdfkjjlksdf34324jalskfjksdaf", nil, "343")
        find_test("[\\d]{3}", "jsflkjasdfkjjlksdf34324jalskfjksdaf", nil, "343")
        find_test("[^\\d]{3}", "jsflkjasdfkjjlksdf34324jalskfjksdaf", nil, "jsf")
        find_test("[^\\d]{3}", "34324jalskfjksdaf", nil, "jal")
        find_test("\\w+@\\w+\\.(com|org|net|edu)", "this is my email address: greg@gtgross.com. do you need anything else", nil, ["greg@gtgross.com", "com"])
        find_test("address", "this is my email address: greg@gtgross.com. do you need anything else", nil, "address")
        find_test("ab|cdef|ghi", "abcdefghijkl", nil, "ab")
        find_test("cdef|ab|ghi", "abcdefghijkl", nil, "ab")
        find_test("ab|cdef|ghi", "01234abcdefghijkl", nil, "ab")
        find_test("cdef|ab|ghi", "01234abcdefghijkl", nil, "ab")
        find_test("[a-b]*|cdef|ghi", "01234bacdefghijkl", nil, "ba")
        find_test("[4-6]", "0123456789", nil, "4")
    end

    def test_capture
        capture_test("a", "a", "a")
        capture_test("a", "b", nil)
        capture_test("b", "b", "b")
        capture_test("(a)*", "aaa", ["aaa", "a"])
        capture_test("([a-c])*", "abc", ["abc", "c"])
        capture_test("a(b)c", "abc", ["abc", "b"])
        capture_test("(a)(b)(c)", "abc", ["abc", "a", "b", "c"])
        capture_test("([0-9]{3})-([0-9]{3})-([0-9]{4})", "123-456-7890", ["123-456-7890", "123", "456", "7890"])
        capture_test("a(b|c)d", "abd", ["abd", "b"])
        capture_test("a(b|c)d", "acd", ["acd", "c"])
        capture_test("(ab|c)d", "cd", ["cd", "c"])
        capture_test("(ab|c)d", "abd", ["abd", "ab"])
        capture_test("(((a)*)((b)*))", "aaaaabbbbb", ["aaaaabbbbb", "aaaaabbbbb", "aaaaa", "a", "bbbbb", "b"])
        capture_test("a((b))c(de*f){2}ghi", "abcdfdfghi", ["abcdfdfghi", "b", "b", "df"])
        capture_test("a((b))c(de*f){2}ghi", "abcdefdfghi", ["abcdefdfghi", "b", "b", "df"])
        capture_test("a((b))c(de*f){2}ghi", "abcdefdefghi", ["abcdefdefghi", "b", "b", "def"])
        capture_test("a((b))c((de*f){2})ghi", "abcdefdefghi", ["abcdefdefghi", "b", "b", "defdef", "def"])
        capture_test("<a[ \\t\\n]+href=\\\"[^\\\"]*\\\">", "", nil)
        capture_test("<a[ \\t\\n]+href=\\\"([^\\\"]*)\\\">", "<a href=\"\">", ["<a href=\"\">", ""])
        capture_test("<a[ \\t\\n]+href=\\\"([^\\\"]*)\\\">", "<a href=\"this is a test\">", ["<a href=\"this is a test\">", "this is a test"])
    end

    def test_anchors
        find_test("^a", "a", nil, "a")
        find_test("^a", "b", nil, nil)
        find_test("^a", "ba", nil, nil)
        find_test("a$", "ba", nil, "a")
        find_test("a$", "bab", nil, nil)
        find_test("^a$", "bab", nil, nil)
        find_test("^a$", "ab", nil, nil)
        find_test("^a$", "ba", nil, nil)
        find_test("^a$", "a", nil, "a")
        find_test("^abc", "\nabc", nil, "abc")
        find_test("^abc", "abc", nil, "abc")
        find_test("^abc", "babc", nil, nil)
        find_test("^abc", "ddd\nabc", nil, "abc")
        find_test("^abc", "dddabc", nil, nil)
        find_test("^abc$", "ddd\nabc", nil, "abc")
        find_test("^abc$", "ddd\nabcd", nil, nil)
        find_test("^abc$", "ddd\nabc\nddd", nil, "abc")
        find_test("^abc$", "ddd\nabcd\nddd", nil, nil)
        find_test("^[a-z]{3}$", "ddd\nabcd\nddd", nil, "ddd")
        find_test("^[a-z]{3}$", "dd\nabcd\neee", nil, "eee")
        find_test("^abc$\\n^abc$", "abc\nabc", nil, "abc\nabc")
        find_test("^abc$\\n^abc$", "ab\nabc", nil, nil)
        find_test("^abc$\\n^abc$", "abcabc", nil, nil)
        find_test("^(?:[0-9]{2,4})$\\n^[0-9]{2,4}$", "12\n34", nil, "12\n34")
        find_test("^(?:[0-9]{2,4})$\\n^[0-9]{2,4}$", "1234\n567", nil, "1234\n567")
        regex_test("^a", ["a"], ["b", "ba", "ab"])
        regex_test("a$", "a", ["b", "ba", "ab"])
        regex_test("^a$", "a", ["b", "ba", "ab"])
        regex_test("^abc", "abc", ["b", "ba", "ab", "abcd", "0abc", "ddd\nabc\nddd"])
        capture_match_test("^(a)", "a", ["a", "a"])
        capture_match_test("^a(b*)c", "ac", ["ac", ""])
        capture_match_test("^a(b*)c", "abbbc", ["abbbc", "bbb"])
        capture_match_test("^a(b*)c", "adc", nil)
        capture_match_test("a(b*)c$", "abbbc", ["abbbc", "bbb"])
        capture_match_test("a(b*)c$", "ac", ["ac", ""])
        capture_find_test("^(a)", "b\na", ["a", "a"])
        capture_find_test("^a(b)*c", "000\nabbbbcdef\n", ["abbbbc", "b"])
        capture_find_test("^([0-9]{2,4})$", "000\nabc", ["000", "000"])
        capture_find_test("(^[0-9]{2,4}$)", "000\nabc", ["000", "000"])
        capture_find_test("^[\\s]*([0-9]{2,4})$", "abc\n \t010\nabc", [" \t010", "010"])
    end
end 

