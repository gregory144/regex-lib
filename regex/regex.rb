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
        end

        class Matcher
            attr_accessor :states, :pos, :nfa
            
            def initialize(nfa)
                @pos = 0
                @states = Set.new
                @nfa = nfa
            end

            # match the given string against the NFA
            def match(str)
                @states << @nfa.start
                move_epsilon
                str.each_char do |char|
                    move(char)
                    break if @states.empty?
                    move_epsilon
                end
                matched = false
                @states.each do |state|
                    matched = true if @nfa.accept == state
                end
                matched
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
    puts Regex::Regex.match(ARGV[0], ARGV[1])
end
