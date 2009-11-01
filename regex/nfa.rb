#!/usr/bin/env ruby

require 'node'

module Regex

    class NFA 

        attr_accessor :states, :transitions, :start, :accept, :start_state_ids, :end_state_ids

        def initialize()
            @states = 0
            @start_state_ids = {}
            @end_state_ids = {}
            @transitions = {}
        end

        def add_trans(start, finish, symbol)
            @transitions[[start, symbol]] = [] unless @transitions[[start, symbol]]
            @transitions[[start, symbol]] << finish
        end

        class << self
            def construct(tree)
                tree.assign_tree_ids
                nfa = NFA.new
                NFA.create_states(nfa, tree)
                first = 0
                last = nfa.states + 1 
                nfa.states += 2
                nfa.add_trans(first, nfa.start_state_ids[tree.id], nil)
                nfa.add_trans(nfa.end_state_ids[tree.id], last, nil)
                nfa.start = first
                nfa.accept = last
                nfa
            end

            def create_states(nfa, tree)
                tree.operands.each do |node|
                    NFA.create_states(nfa, node)
                end if tree.operands && tree.operands.size > 0
                case tree.token_type
                when :simple
                    first = nfa.states + 1
                    second = nfa.states + 2
                    nfa.add_trans(first, second, tree.value)
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
