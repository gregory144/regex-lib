#!/usr/bin/env ruby

require 'node'
require 'regex_common'

module Regex

    # a class to handle the construction of a
    # non-deterministic finite automaton
    # from a parse tree of a regular expression
    class NFA 
        extend RegexCommon

        attr_accessor :states, :transitions, :start, :accept, :start_state_ids, :end_state_ids, :range_transitions, :else_transitions, :capture_states, :assertions

        def initialize(tree)
            @states = []
            @start_state_ids = {}
            @end_state_ids = {}
            @transitions = {}
            @range_transitions = {} 
            @else_transitions = {}

            create_states(tree)
        end

        # add a trantsition from state 
        # start to state finish on input symbol
        def add_trans(start, finish, symbol = nil)
            if symbol.respond_to?(:begin)
                @range_transitions[start] = [] unless @range_transitions[start]
                @range_transitions[start].unshift [symbol, finish]
            elsif symbol == :any
                @transitions[start] = [] unless @transitions[start]
                @transitions[start].unshift finish
            else
                @transitions[[start, symbol]] = [] unless @transitions[[start, symbol]]
                @transitions[[start, symbol]].unshift finish
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
            move = @transitions[[start, symbol]] 
            if symbol and not move
                @range_transitions[start].each do |r| 
                    range, finish = r 
                    return [finish] if range === symbol
                end if @range_transitions[start]
                if not move and @else_transitions[start]
                    return [@else_transitions[start]] 
                end
                return @transitions[start] if symbol != "\n"
            end
            return move
        end

        def create_state
            (@states << (@states.size > 0 ? @states.last + 1 : 1)).last
        end
        
        # recursively create states for 
        # each node in the parse tree
        def create_states(tree)
            tree.operands.each do |node|
                create_states(node)
            end if tree.operands && tree.operands.size > 0
            case tree.token_type
            when :simple, :any, :range
                first = create_state
                second = create_state
                symbol = tree.value
                symbol = :any if tree.token_type == :any
                add_trans(first, second, symbol)
                @start_state_ids[tree.id] = first
                @end_state_ids[tree.id] = second
            when :anchor
                first = create_state
                assertion = { :type => tree.value }
                @assertions = {} unless @assertions
                @assertions[first] = assertion
                @start_state_ids[tree.id] = first
                @end_state_ids[tree.id] = first
            when :star, :plus, :opt
                first = @start_state_ids[tree.operands.first.id]
                second = @end_state_ids[tree.operands.first.id]
                if tree.operands.first.token_type?(:cap)
                    n_first = create_state
                    n_second = create_state
                    add_trans(n_first, first)
                    add_trans(second, n_second)
                    first = n_first
                    second = n_second
                # special case: unary operators under concat operators here 
                # can cause issues with capturing parenthesis upstream
                elsif tree.operands.first.token_type?(:concat)
                    if (tree.operands.first.operands.first.token_type?(:star, :plus, :opt))
                        n_first = create_state
                        add_trans(n_first, first)
                        first = n_first
                    end
                end
                add_trans(first, second) unless tree.token_type == :plus
                add_trans(second, first) unless tree.token_type == :opt
                @start_state_ids[tree.id] = first
                @end_state_ids[tree.id] = second
            when :concat
                tree.operands.each_with_index do |operand, i|
                    break if i == tree.operands.size - 1
                    op1 = operand
                    op2 = tree.operands[i+1]
                    add_trans(@end_state_ids[op1.id], @start_state_ids[op2.id])
                end
                @start_state_ids[tree.id] = @start_state_ids[tree.operands.first.id] 
                @end_state_ids[tree.id] = @end_state_ids[tree.operands.last.id]
            when :or
                # gather all simple operands into one 
                simple_operands = []
                tree.operands.each_with_index do |operand, i|
                    simple_operands.unshift(operand) if operand.token_type?(:simple)
                end 
                keep_extra_states = true
                if simple_operands.size == tree.operands.size
                    keep_extra_states = false
                    first = @start_state_ids[simple_operands.first.id]
                    second = @end_state_ids[simple_operands.first.id]
                else
                    first = create_state
                    second = create_state
                    tree.operands.each_with_index do |operand, i|
                        if not operand.token_type?(:simple) 
                            add_trans(first, @start_state_ids[operand.id])
                            add_trans(@end_state_ids[operand.id], second)
                        end
                    end
                end
                simple_operands.each_with_index do |operand, i|
                    if not (not keep_extra_states and i == 0)
                        add_trans(first, second, operand.value)
                        remove_state(@start_state_ids[operand.id]) 
                        remove_state(@end_state_ids[operand.id]) 
                    end
                end
                @start_state_ids[tree.id] = first
                @end_state_ids[tree.id] = second
            when :not
                else_state = create_state
                first = @start_state_ids[tree.operands.first.id]
                second = @end_state_ids[tree.operands.first.id]
                tree.operands.each_with_index do |operand, i|
                    unless i == 0
                        add_trans(first, second, operand.value)
                        remove_state(@start_state_ids[operand.id]) 
                        remove_state(@end_state_ids[operand.id]) 
                    end
                end
                @else_transitions[first] = else_state
                @start_state_ids[tree.id] = first
                @end_state_ids[tree.id] = else_state
            when :cap
                @capture_states = {} unless @capture_states
                first = start = @start_state_ids[tree.operands.first.id]
                second = finish = @end_state_ids[tree.operands.first.id]
                need_first = need_second = false
                cap = has_cap(tree.operands)
                cap.each do |cap_node|
                    cap_states = @capture_states[cap_node.value]
                    if cap_states 
                        first_child, second_child = cap_states
                        need_first = true if first_child == first
                        need_second = true if second_child == second
                    end
                end if cap
                need_first = need_second = true if first_unary(tree.operands)
                if need_first
                    first = create_state
                    add_trans(first, start)
                end
                if need_second
                    second = create_state
                    add_trans(finish, second)
                end
                capture_states[tree.value] = [first, second]
                @start_state_ids[tree.id] = first 
                @end_state_ids[tree.id] = second
            else
                raise SyntaxError.new("Unrecognized node in parse tree")
            end
        end

        def has_cap(operands) 
            ret = []
            operands.each do |op|
                ret << op if op.token_type == :cap 
                ret2 = has_cap(op.operands)
                ret = ret + ret2
            end if operands
            ret
        end

        def first_unary(operands) 
            ret = if operands
                if operands.first && operands.first.unary
                    true
                else
                    first_unary(operands.first.operands) if operands.first
                end
            end
            ret
        end 

        class << self
            # construct an NFA from the given parse tree
            def construct(tree)
                tree.assign_tree_ids
                nfa = NFA.new(tree)
                nfa.start = nfa.start_state_ids[tree.id]
                nfa.accept = nfa.end_state_ids[tree.id]
                RegexUtil.reassign_state_ids(nfa) if debug_enabled?
                nfa
            end

        end

    end

end

if __FILE__ == $0
    require 'parser'
    require 'graph_gen'

    num = 0
    ARGV.each_with_index do |expr, i|
        unless /^-/.match(expr)
            Regex::GraphGen.gen_nfa(expr, "out/nfa#{num}.dot") 
            num += 1
        end
    end
end
