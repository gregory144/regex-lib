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
            attr_accessor :states, :pos, :nfa, :snapshot, :str
            
            def initialize(nfa)
                @nfa = nfa
                reset
            end

            def reset(pos = 0)
                @pos = pos
                @snapshot = @snapshot ? @snapshot.clear : [] 
                @states = @states ? @states.clear : Set.new
            end

            # match the given string against the NFA
            def match(str)
                @str = str if @nfa.capture_states
                @states << @nfa.start
                move_epsilon
                @snapshot << @states.to_a if @nfa.capture_states
                str.each_char do |char|
                    move(char)
                    break if @states.empty?
                    move_epsilon
                    @snapshot << @states.to_a if @nfa.capture_states
                end
                matched = false
                @states.each do |state|
                    matched = true if @nfa.accept == state
                end
                matched ? cap(str) : nil
            end

            def cap(full)
                if @nfa.capture_states
                    cap = [full]
                    @nfa.capture_states.keys.each do |i|
                        cap << get(i, full)
                    end 
                    cap
                else
                    full
                end
            end

            def get(i, full = nil)
                full = @str unless full
                return nil unless @nfa.capture_states
                start, finish = @nfa.capture_states[i]
                return nil unless start and finish
                start_pos = nil
                finish_pos = nil
                @snapshot.each_with_index do |states, pos|
                    start_pos = pos if states.include?(start) and not start_pos
                    finish_pos = pos if states.include?(finish) 
                end
                start_pos and finish_pos ? 
                    full[start_pos, finish_pos - start_pos] :
                    nil
            end

            def find(str)
                @str = str if @nfa.capture_states
                matches = []
                str.size.times do |i|
                    reset(i)
                    @states << @nfa.start
                    move_epsilon
                    @snapshot << @states.to_a if @nfa.capture_states
                    len = 0
                    str[i, str.size-i].each_char do |char|
                        len += 1
                        move(char)
                        break if @states.empty?
                        move_epsilon
                        @snapshot << @states.to_a if @nfa.capture_states
                        matched = false
                        @states.each do |state|
                            matched = true if @nfa.accept == state
                        end
                        matches << [i, len] if matched
                    end
                    break if matches.size > 0
                end
                match = nil
                matches.each do |x|
                    match = x if match == nil or x[1] > match[1]
                end
                match ? cap(str[match[0], match[1]]) : nil
            end

            # advance one input character through
            # the NFA
            def move(char)
                old_states = @states.to_a
                @states.clear
                old_states.each do |start|
                    finish = @nfa.move(start, char)
                    @states.merge(finish) if finish
                end
            end

            # move over epsilon transitions
            # until there are no more to move over
            def move_epsilon
                while true do
                    old_states = @states.to_a
                    old_states.each do |start|
                        finish = @nfa.move(start, nil)
                        @states.merge(finish) if finish
                    end
                    break if old_states.size == @states.size
                end
            end
        end

    end

end

if __FILE__ == $0
    puts Regex::Regex.find(ARGV[0], ARGV[1])
end
