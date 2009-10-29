#!/usr/bin/env ruby

require 'node'

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
            when :star
                nfa.add_trans(
                    nfa.start_state_ids[tree.operands.first.id],
                    nfa.end_state_ids[tree.operands.first.id],
                    nil
                )
                nfa.add_trans(
                    nfa.end_state_ids[tree.operands.first.id],
                    nfa.start_state_ids[tree.operands.first.id],
                    nil
                )
                nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.first.id]
            when :concat
                nfa.add_trans(
                    nfa.end_state_ids[tree.operands.first.id],
                    nfa.start_state_ids[tree.operands.last.id],
                    nil
                )
                nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.last.id]
            when :or
                first = nfa.states + 1
                second = nfa.states + 2 
                nfa.states += 2 
                nfa.add_trans(first, nfa.start_state_ids[tree.operands.first.id], nil)
                nfa.add_trans(first, nfa.start_state_ids[tree.operands.last.id], nil)
                nfa.add_trans(nfa.end_state_ids[tree.operands.first.id], second, nil)
                nfa.add_trans(nfa.end_state_ids[tree.operands.last.id], second, nil)
                nfa.start_state_ids[tree.id] = first
                nfa.end_state_ids[tree.id] = second
            end
        end
        
    end

end

