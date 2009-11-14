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
                matched = false
                cap_matches = []
                if @nfa.capture_states
                    @snapshot.each do |curr|
                        state, curr_pos = curr.last
                        if @nfa.accept == state
                            matched = true
                            cap_matches << curr
                        end
                    end
                else
                    @states.each do |state|
                        matched = true if @nfa.accept == state
                    end
                end
                matched ? cap(cap_matches, str) : nil
            end

            def find(str)
                @str = str if @nfa.capture_states or @nfa.assertions or debug_enabled?
                matches = []
                cap_matches = []
                str.size.times do |i|
                    reset
                    len = 0
                    if passed_assertions(@str, i, @nfa.start)
                        @nfa.capture_states ? 
                            @snapshot << [[@nfa.start, len]] :
                            @states << @nfa.start
                    end
                    move_epsilon(len, i)
                    str[i, str.size-i].each_char do |char|
                        len += 1
                        move(char, len)
                        break if @states.empty?
                        move_epsilon(len, i+len)
                        RegexUtil.debug_print(str[i, str.size-i], len, @expr, @nfa, @states, @snapshot) if debug_enabled?
                        matched = false
                        if @nfa.capture_states
                            @snapshot.each do |curr|
                                state, curr_pos = curr.last
                                if @nfa.accept == state
                                    matched = true
                                    cap_matches << curr
                                end
                            end
                        else
                            @states.each do |state|
                                matched = true if @nfa.accept == state
                            end
                        end
                        matches << [i, len] if matched
                    end 
                    break if matches.size > 0 or cap_matches.size > 0 
                end
                match = nil
                matches.each do |x|
                    match = x if match == nil or x[1] > match[1]
                end
                match ? cap(cap_matches, str[match[0], match[1]]) : nil
            end

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

            def get(i, snapshots, full = nil)
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
                            check_assertions(str, pos)
                        end
                        break if old_states.size == @states.size 
                    end
                else
                    new_states = []
                    #any outgoing trans
                    new_snapshots = @snapshot
                    while true do
                        any_outgoing_trans = false
                        snapshot2 = []
                        new_snapshots.each do |states|
                            state, snap_pos = states.last
                            finish = @nfa.move(state, nil)
                            finish.each do |fin|
                                if passed_assertions(str, pos, fin)
                                    unless new_states.include? fin
                                        new_states << fin
                                        eps = @nfa.move(fin, nil)
                                        any_outgoing_trans = true if (eps and eps.size > 0)
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
                end
            end

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
                    end
                    passed
                else
                    true
                end
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
        if !/^-/.match(a)
            expr = a if num == 0
            str = a if num == 1
            num += 1
        end
    end
    Regex::GraphGen.gen_nfa(expr, "out/nfa0.dot") if gen_graph
    puts Regex::Regex.find(expr, str)
    
end
