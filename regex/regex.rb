#!/usr/bin/env ruby

require 'set'

require 'nfa'
require 'parser'
require 'regex_common'

module Regex

    class Regex

        class << self
            def match(pattern, str)
                nfa = NFA.construct(Parser.parse_tree(pattern))
                matcher = Matcher.new(nfa, pattern)
                matcher.match(str)
            end

            def find(pattern, str)
                nfa = NFA.construct(Parser.parse_tree(pattern))
                matcher = Matcher.new(nfa, pattern)
                matcher.find(str)
            end
        end

        class Matcher
            include RegexCommon

            attr_accessor :states, :nfa, :snapshot, :str, :expr
            
            def initialize(nfa, expr = nil)
                @snapshot = nil
                @states = nil
                @nfa = nfa
                @expr = expr if debug_enabled?
                reset
            end

            def reset
                @snapshot = @snapshot ? @snapshot.clear : [] 
                @states = @states ? @states.clear : Set.new
            end

            # match the given string against the NFA
            def match(str)
                len = 0
                @str = str if @nfa.capture_states or @nfa.assertions or debug_enabled?
                if passed_assertions(@str, len, @nfa.start)
                    @nfa.capture_states ? 
                        @snapshot << [[@nfa.start, len]] :
                        @states << @nfa.start
                end
                move_epsilon(len, len)
                str.each_char do |char|
                    len += 1
                    move(char, len)
                    break if @states.empty?
                    move_epsilon(len, len)
                    RegexUtil.debug_print(str, len, @expr, @nfa, @states, @snapshot) if debug_enabled?
                end
                matches = matches?
                matches ? cap(matches, str) : nil
            end

            def find(str)
                @str = str if @nfa.capture_states or @nfa.assertions or debug_enabled?
                matches = []
                cap_matches = []
                (str.size > 0 ? str.size : 1).times do |i|
                    reset
                    len = 0
                    # make sure the assertions pass (if there are any)
                    if passed_assertions(str, i, @nfa.start)
                        @nfa.capture_states ? 
                            @snapshot << [[@nfa.start, len]] :
                            @states << @nfa.start
                    end
                    move_epsilon(len, i)
                    RegexUtil.debug_print(str[i, str.size-i], len+1, @expr, @nfa, @states, @snapshot) if debug_enabled?
                    #check to see if it already matches
                    curr_matches = matches?
                    if curr_matches
                        curr_matches.each { |x| cap_matches << x }
                        matches << [i, len]
                    end
                    str[i, str.size-i].each_char do |char|
                        len += 1
                        move(char, len)
                        break if @states.empty?
                        move_epsilon(len, i+len)
                        RegexUtil.debug_print(str[i, str.size-i], len, @expr, @nfa, @states, @snapshot) if debug_enabled?
                        curr_matches = matches?
                        if curr_matches
                            curr_matches.each { |x| cap_matches << x }
                            matches << [i, len]
                        end
                    end 
                    break if matches.size > 0 or cap_matches.size > 0 
                end
                match = nil
                matches.each do |x|
                    match = x if match == nil or x[1] > match[1]
                end
                match ? cap(cap_matches, str[match[0], match[1]]) : nil
            end

            # do we have a match?
            # returns an array of matching snapshots/states
            # or false if not a match
            def matches?
                matches = []
                if @nfa.capture_states
                    @snapshot.each do |curr|
                        state, curr_pos = curr.last
                        if @nfa.accept == state
                            matches << curr
                        end
                    end
                else
                    @states.each do |state|
                        matches << state if @nfa.accept == state
                    end
                end
                matches.size > 0 ? matches : false
            end

            # gets the capture groups to return to the consumer
            def cap(snapshots, full)
                if @nfa.capture_states
                    cap = [full]
                    @nfa.capture_states.size.times do |i|
                        cap << get(i+1, snapshots, full)
                    end 
                    cap
                else
                    full
                end
            end

            # gets a specific capture group
            def get(i, snapshots, full = nil)
                puts "getting captured string: #{i}" if debug_enabled?
                puts "#{snapshots.size} possible matches" if debug_enabled?
                full = @str unless full
                return nil unless @nfa.capture_states
                start, finish = @nfa.capture_states[i]
                return nil unless start and finish
                start_pos = nil
                finish_pos = nil
                [snapshots.last].each do |curr|
                    puts "looking at snapshot: " if debug_enabled?
                    curr.each do |r|
                        state, curr_pos = r
                        puts "#{state}, #{curr_pos}" if debug_enabled?
                        start_pos = curr_pos if (state == start)
                        finish_pos = curr_pos if (state == finish)
                    end
                end
                puts "found capture #{i} between #{start_pos} and #{finish_pos} (#{start} - #{finish})" if debug_enabled?
                start_pos and finish_pos ? 
                    full[start_pos, finish_pos - start_pos] :
                    nil
            end

            # advance one input character through
            # the NFA
            def move(char, len = 0)
                if not @nfa.capture_states
                    old_states = @states.to_a
                    @states.clear
                    old_states.each do |start|
                        finish = @nfa.move(start, char)
                        @states.merge(finish) if finish
                    end
                else
                    to_add = []
                    @snapshot.clone.each do |states|
                        state, curr_pos = states.last
                        finish = @nfa.move(state, char)
                        if finish
                            finish.each do |fin|
                                n_snapshot = states.clone << [fin, len]
                                to_add << n_snapshot
                            end 
                        end
                    end
                    @snapshot = to_add
                    @states = @snapshot.map { |states| states.last.first }.uniq
                end
            end

            # move over epsilon transitions
            # until there are no more to move over
            def move_epsilon(len = 0, pos = 0)
                if not @nfa.capture_states
                    while true do
                        old_states = @states.to_a
                        old_states.each do |start|
                            finish = @nfa.move(start, nil)
                            @states.merge(finish) if finish
                            check_assertions(@str, pos)
                        end
                        break if old_states.size == @states.size 
                    end
                else
                    new_snapshots = @snapshot
                    while true do
                        any_outgoing_trans = false
                        snapshot2 = []
                        new_snapshots.each do |states|
                            new_states = new_states(states)
                            state, snap_pos = states.last
                            finish = @nfa.move(state, nil)
                            finish.each do |fin|
                                if passed_assertions(@str, pos, fin)
                                    unless new_states.include? fin
                                        outgoing = @nfa.move(fin, nil)
                                        any_outgoing_trans = true if (outgoing and outgoing.size > 0)
                                        n_snapshot = states.clone << [fin, len]
                                        snapshot2 << n_snapshot
                                    end
                                end
                            end if finish
                        end
                        new_snapshots = snapshot2
                        @snapshot = @snapshot + snapshot2 
                        @states = @snapshot.map { |states| states.last.first }.uniq
                        break unless any_outgoing_trans
                    end
                    @snapshot = clean_snapshots(@snapshot)
                end
            end

            # removes states from snapshots that will not be relevant later
            # (i.e. keeps the current state and any states that are needed for 
            # capturing parenthesis
            def clean_snapshots(snapshots)
                cap_states = Set.new
                @nfa.capture_states.size.times do |i|
                    @nfa.capture_states[i+1].each do |x|
                        cap_states << x
                    end
                end

                snapshots.each do |snapshot|
                    curr_cap_states = cap_states.to_a
                    snapshot.reverse_each do |r|
                        state, curr_pos = r
                        if curr_cap_states.include?(state) or snapshot.last == r
                            curr_cap_states.delete(state)
                        else
                            snapshot.delete(r)
                        end
                    end
                end
                snapshots.uniq
            end


            # finds all states at the current position
            def new_states(snapshot)
                new_states = []
                curr_pos = snapshot.last.last
                snapshot.reverse_each do |x|
                    state, pos = x
                    break if pos != curr_pos
                    new_states << state
                end
                new_states
            end

            # check the assertions of all current states
            def check_assertions(str, pos)
                @states.delete_if do |state|
                    not passed_assertions(str, pos, state)
                end
            end

            # returns true if the given string and position pass
            # the current state's assertions
            def passed_assertions(str, pos, state)
                assertion = @nfa.assertions[state] if @nfa.assertions
                if assertion
                    passed = false
                    case assertion[:type]
                        when :newline
                            last_char = str[pos-1, 1] if pos > 0
                            passed = true if not last_char or last_char == "\n"
                        when :endline
                            next_char = str[pos, 1] if pos < str.length
                            passed = true if not next_char or next_char == "\n"
                        when :start_string
                            passed = true if pos == 0
                        when :end_string
                            ends_with_line_break = str[str.length-1, 1] == "\n"
                            passed = ends_with_line_break ? pos == str.length - 1 : pos == str.length
                        when :abs_end_string
                            passed = pos == str.length
                        when :word_boundary
                            last_word = word_char? str[pos-1, 1] if pos > 0
                            next_word = word_char? str[pos, 1] if pos < str.length
                            passed = last_word ^ next_word
                        when :between_word
                            last_word = word_char? str[pos-1, 1] if pos > 0
                            next_word = word_char? str[pos, 1] if pos < str.length
                            passed = last_word == next_word
                    end
                    passed
                else
                    true
                end
            end

            # is the given character a 'word' 
            # character (leter, number or underscore)
            def word_char?(c)
                ('a'..'z') === c or 
                ('A'..'Z') === c or 
                ('0'..'9') === c or 
                '_' == c
            end

        end

    end

end

if __FILE__ == $0
    require 'graph_gen'
    require 'nfa'

    expr = nil
    str = nil
    num = 0
    gen_graph = false
    ARGV.each do |a|
        gen_graph = true if /^-g/.match(a)
        if !/^-(d|g)/.match(a)
            expr = a if num == 0
            str = a if num == 1
            num += 1
        end
    end
    Regex::GraphGen.gen_nfa(expr, "out/nfa0.dot") if gen_graph
    puts Regex::Regex.find(expr, str)
    
end
