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

            def move(char)
                new_states = Set.new
                @states.each do |start|
                    finish = @nfa.transitions[[start, char]] || 
                        @nfa.transitions[[start, :any]]
                    new_states = new_states | finish if finish
                end
                @states = new_states
            end

            def move_epsilon
                new_states = Set.new
                while true do
                    snapshot = new_states
                    @states.each do |start|
                        finish = @nfa.transitions[[start, nil]]
                        new_states = new_states | finish if finish
                    end
                    @states = new_states
                    break if snapshot.size == new_states.size
                end
            end
        end

    end

end

if __FILE__ == $0
    puts Regex::Regex.match(ARGV[0], ARGV[1])
end
