#!/usr/bin/env ruby

require 'node'

module Regex

    # a class to handle the construction of a
    # non-deterministic finite automaton
    # from a parse tree of a regular expression
    class NFA 

        attr_accessor :states, :transitions, :start, :accept, :start_state_ids, :end_state_ids

        def initialize()
            @states = 0
            @start_state_ids = {}
            @end_state_ids = {}
            @transitions = {}
        end

        # add a trantsition from state 
        # start to state finish on input symbol
        def add_trans(start, finish, symbol)
            @transitions[[start, symbol]] = [] unless @transitions[[start, symbol]]
            @transitions[[start, symbol]] << finish
        end

        # returns the finishing states moving 
        # from state start on input symbol
        def move(start, symbol)
            @transitions[[start, symbol]] || (@transitions[[start, :any]] if symbol)
        end

        class << self
            # construct an NFA from the given parse tree
            def construct(tree)
                tree.assign_tree_ids
                nfa = NFA.new
                NFA.create_states(nfa, tree)
                nfa.start = nfa.start_state_ids[tree.id]
                nfa.accept = nfa.end_state_ids[tree.id]
                nfa
            end

            # recursively create states for 
            # each node in the parse tree
            def create_states(nfa, tree)
                tree.operands.each do |node|
                    NFA.create_states(nfa, node)
                end if tree.operands && tree.operands.size > 0
                case tree.token_type
                when :simple, :any
                    first = nfa.states + 1
                    second = nfa.states + 2
                    symbol = tree.value
                    symbol = :any if tree.token_type == :any
                    nfa.add_trans(first, second, symbol)
                    nfa.states += 2
                    nfa.start_state_ids[tree.id] = first
                    nfa.end_state_ids[tree.id] = second
                when :star, :plus, :opt
                    nfa.add_trans(
                        nfa.start_state_ids[tree.operands.first.id],
                        nfa.end_state_ids[tree.operands.first.id],
                        nil
                    ) unless tree.token_type == :plus
                    nfa.add_trans(
                        nfa.end_state_ids[tree.operands.first.id],
                        nfa.start_state_ids[tree.operands.first.id],
                        nil
                    ) unless tree.token_type == :opt
                    nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                    nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.first.id]
                when :concat
                    tree.operands.each_with_index do |operand, i|
                        break if i == tree.operands.size - 1
                        op1 = operand
                        op2 = tree.operands[i+1]
                        nfa.add_trans(
                            nfa.end_state_ids[op1.id],
                            nfa.start_state_ids[op2.id],
                            nil
                        )
                    end
                    nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                    nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.last.id]
                when :or
                    first = nfa.states + 1
                    second = nfa.states + 2 
                    nfa.states += 2 
                    tree.operands.each_with_index do |operand, i|
                        nfa.add_trans(first, nfa.start_state_ids[operand.id], nil)
                        nfa.add_trans(nfa.end_state_ids[operand.id], second, nil)
                        
                    end
                    nfa.start_state_ids[tree.id] = first
                    nfa.end_state_ids[tree.id] = second
                end
            end
            
        end

    end

end

if __FILE__ == $0
    require 'parser'
    require 'graph_gen'

    ARGV.each_with_index do |expr, i|
        Regex::GraphGen.gen_nfa(expr, "out/nfa#{i}.dot")
    end
end
