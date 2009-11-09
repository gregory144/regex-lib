#!/usr/bin/env ruby

require 'set'

require 'nfa'
require 'parser'

module Regex

    class Regex

        class << self
            def match(pattern, str)
                nfa = NFA.construct(Parser.parse_tree(pattern))
                matcher = Matcher.new(nfa)
                matcher.match(str)
            end

            def find(pattern, str)
                nfa = NFA.construct(Parser.parse_tree(pattern))
                matcher = Matcher.new(nfa)
                matcher.find(str)
            end
        end

        class Matcher
            attr_accessor :states, :nfa, :snapshot, :str
            
            def initialize(nfa)
                @nfa = nfa
                reset
            end

            def reset
                @snapshot = @snapshot ? @snapshot.clear : [] 
                @states = @states ? @states.clear : Set.new
            end

            # match the given string against the NFA
            def match(str)
                len = 0
                @str = str if @nfa.capture_states
                @states << @nfa.start
                @snapshot << [[@nfa.start, len]] if @nfa.capture_states
                move_epsilon    
                str.each_char do |char|
                    len += 1
                    move(char, len)
                    break if @states.empty?
                    move_epsilon(len)
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

            def cap(snapshot, full)
                if @nfa.capture_states
                    cap = [full]
                    @nfa.capture_states.size.times do |i|
                        cap << get(i+1, snapshot, full)
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
                    curr.each do |r|
                        state, curr_pos = r
                        start_pos = curr_pos if (state == start)
                        finish_pos = curr_pos if (state == finish)
                    end
                end
                start_pos and finish_pos ? 
                    full[start_pos, finish_pos - start_pos] :
                    nil
            end

            def find(str)
                @str = str if @nfa.capture_states
                matches = []
                cap_matches = []
                str.size.times do |i|
                    reset
                    @states << @nfa.start
                    len = 0
                    @snapshot << [[@nfa.start, len]] if @nfa.capture_states
                    move_epsilon(len)
                    str[i, str.size-i].each_char do |char|
                        len += 1
                        move(char, len)
                        break if @states.empty?
                        move_epsilon(len)
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
            def move_epsilon(len = 0)
                if not @nfa.capture_states
                    while true do
                        old_states = @states.to_a
                        old_states.each do |start|
                            finish = @nfa.move(start, nil)
                            @states.merge(finish) if finish
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
                                unless new_states.include? fin
                                    new_states << fin
                                    eps = @nfa.move(fin, nil)
                                    any_outgoing_trans = true if (eps and eps.size > 0)
                                    n_snapshot = states.clone << [fin, len]
                                    snapshot2 << n_snapshot
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
        end

    end

end

if __FILE__ == $0
    puts Regex::Regex.find(ARGV[0], ARGV[1])
end
