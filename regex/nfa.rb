#!/usr/bin/env ruby

require 'node'

module Regex

    # a class to handle the construction of a
    # non-deterministic finite automaton
    # from a parse tree of a regular expression
    class NFA 

        attr_accessor :states, :transitions, :start, :accept, :start_state_ids, :end_state_ids, :range_transitions, :else_transitions, :capture_states

        def initialize()
            @states = []
            @start_state_ids = {}
            @end_state_ids = {}
            @transitions = {}
            @range_transitions = {} 
            @else_transitions = {}
        end

        # add a trantsition from state 
        # start to state finish on input symbol
        def add_trans(start, finish, symbol = nil)
            if symbol.respond_to?(:begin)
                @range_transitions[start] = [] unless @range_transitions[start]
                @range_transitions[start] << [symbol, finish]
            else
                @transitions[[start, symbol]] = [] unless @transitions[[start, symbol]]
                @transitions[[start, symbol]] << finish
            end
        end

        def remove_state(state)
            @states.delete(state)
            @transitions.delete_if do |k, finish|
                start, symbol = k
                start == state or finish == state
            end
            @range_transitions.delete(state)
            @else_transitions.delete(state)
        end

        # returns the finishing states moving 
        # from state start on input symbol
        def move(start, symbol)
            move = (@transitions[[start, symbol]] || (@transitions[[start, :any]] if symbol and symbol != "\n"))
            if @range_transitions[start]
                range, finish = @range_transitions[start].each { |r| range, finish = r; move = [finish] if range === symbol } 
                #move = [finish] if range === symbol 
            end
            if symbol and not move and @else_transitions[start]
                move = [@else_transitions[start]]
            end
            return move
        end

        def create_state
            (@states << (@states.size > 0 ? @states.last + 1 : 1)).last
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
                when :simple, :any, :range
                    first = nfa.create_state
                    second = nfa.create_state
                    symbol = tree.value
                    symbol = :any if tree.token_type == :any
                    nfa.add_trans(first, second, symbol)
                    nfa.start_state_ids[tree.id] = first
                    nfa.end_state_ids[tree.id] = second
                when :star, :plus, :opt
                    nfa.add_trans(
                        nfa.start_state_ids[tree.operands.first.id],
                        nfa.end_state_ids[tree.operands.first.id]
                    ) unless tree.token_type == :plus
                    nfa.add_trans(
                        nfa.end_state_ids[tree.operands.first.id],
                        nfa.start_state_ids[tree.operands.first.id]
                    ) unless tree.token_type == :opt
                    nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                    nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.first.id]
                when :concat
                    tree.operands.each_with_index do |operand, i|
                        break if i == tree.operands.size - 1
                        op1 = operand
                        op2 = tree.operands[i+1]
                        nfa.add_trans(nfa.end_state_ids[op1.id], nfa.start_state_ids[op2.id])
                    end
                    nfa.start_state_ids[tree.id] = nfa.start_state_ids[tree.operands.first.id] 
                    nfa.end_state_ids[tree.id] = nfa.end_state_ids[tree.operands.last.id]
                when :or
                    # gather all simple operands into one 
                    simple_operands = []
                    tree.operands.each_with_index do |operand, i|
                        simple_operands << operand if operand.token_type?(:simple)
                    end 
                    keep_extra_states = true
                    if simple_operands.size == tree.operands.size
                        keep_extra_states = false
                        first = nfa.start_state_ids[simple_operands.first.id]
                        second = nfa.end_state_ids[simple_operands.first.id]
                    else
                        first = nfa.create_state
                        second = nfa.create_state
                        tree.operands.each_with_index do |operand, i|
                            if not operand.token_type?(:simple) 
                                nfa.add_trans(first, nfa.start_state_ids[operand.id])
                                nfa.add_trans(nfa.end_state_ids[operand.id], second)
                            end
                        end
                    end
                    simple_operands.each_with_index do |operand, i|
                        if not (not keep_extra_states and i == 0)
                            nfa.add_trans(first, second, operand.value)
                            nfa.remove_state(nfa.start_state_ids[operand.id]) 
                            nfa.remove_state(nfa.end_state_ids[operand.id]) 
                        end
                    end
                    nfa.start_state_ids[tree.id] = first
                    nfa.end_state_ids[tree.id] = second
                when :not
                    else_state = nfa.create_state
                    first = nfa.start_state_ids[tree.operands.first.id]
                    second = nfa.end_state_ids[tree.operands.first.id]
                    tree.operands.each_with_index do |operand, i|
                        unless i == 0
                            nfa.add_trans(first, second, operand.value)
                            nfa.remove_state(nfa.start_state_ids[operand.id]) 
                            nfa.remove_state(nfa.end_state_ids[operand.id]) 
                        end
                    end
                    nfa.else_transitions[first] = else_state
                    nfa.start_state_ids[tree.id] = first
                    nfa.end_state_ids[tree.id] = else_state
                when :cap
                    nfa.capture_states = {} unless nfa.capture_states
                    start = nfa.start_state_ids[tree.operands.first.id]
                    finish = nfa.end_state_ids[tree.operands.first.id]
                    nfa.capture_states[tree.value] = [start, finish]
                    nfa.start_state_ids[tree.id] = start
                    nfa.end_state_ids[tree.id] = finish
                    
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
