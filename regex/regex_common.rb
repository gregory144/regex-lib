#!/usr/bin/env ruby

module RegexCommon

    def debug_enabled?
        enable = false
        ARGV.each do |a|
            enable = true if a == '-d'
        end
        enable
    end

end

module Regex
    class RegexUtil

        class << self
            # prints information about the current state of the match
            def debug_print(curr_str, len, expr, nfa, states, snapshot)
                puts "Matching #{expr} with \"#{curr_str}\""
                puts "at #{len-1} (\"#{curr_str[0, len-1]}*#{curr_str[len-1, 1]}*#{curr_str[len, curr_str.length-len]}\")"
                if nfa.capture_states
                    puts "in states: "
                    snapshot.each do |snapshot|
                        snapshot.each do |states|
                            state, pos = states
                            puts "#{state}, #{pos}"
                        end
                        puts "end snapshot"
                    end
                else
                    puts "in states: "
                    puts states.inject("") {|sum, x|  sum + (sum.length == 0 ? "" : ", ") + x.to_s }
                end
            end
       
            # used for debugging - reassigns all state ids using a 
            # breadth first search (makes the graph easier to read)
            def reassign_state_ids(nfa) 
                to_reassign = []
                reassigned = Set.new
                to_reassign << nfa.start
                while to_reassign.size > 0
                    reassign = to_reassign.shift
                    if (reassign > 0)
                        #find adjacent states
                        adjacent = []
                        nfa.transitions.each do |key, value|
                            nfa.transitions[reassign].each do |x|
                                adjacent << x
                            end if key == reassign
                            if key.respond_to? :length
                                start, symbol = key
                                if start == reassign
                                    value.each { |x| adjacent << x }
                                end
                            end
                        end
                        nfa.range_transitions.each do |start, value|
                            value.each do |x|
                                symbol, finish = x
                                adjacent << finish 
                            end if start == reassign
                        end
                        nfa.else_transitions.each do |start, finish|
                            if start == reassign
                                adjacent << finish
                            end
                        end
                        unless reassigned.include? reassign
                            reassign_state_id(nfa, reassign, reassigned.size + 1)
                            reassigned << reassign
                        end
                        adjacent.each do |x|
                            to_reassign << x unless to_reassign.include? x or reassigned.include? x and x > 0
                        end
                    end
                end
                nfa.states.clone.each do |x|
                    reassign_state_id(nfa, x, x)
                end
            end

            # used for debugging - reassigns a state id to a new id
            def reassign_state_id(nfa, orig, new_id)
                new_id = -1 * new_id
                nfa.states.delete_if { |x| orig == x }
                nfa.states << new_id
                replaced_transitions = {}
                nfa.transitions.each do |key, value|
                    if value.include? orig
                        value.delete(orig)
                        value << new_id
                    end
                    if value == orig
                        value = new_id
                    end
                    if key == orig
                        replaced_transitions[new_id] = value
                    else
                        if key.respond_to?(:length)
                            start, symbol = key
                            if start == orig
                                replaced_transitions[[new_id, symbol]] = value
                            else
                                replaced_transitions[key] = value
                            end
                        else
                            replaced_transitions[key] = value
                        end
                    end
                end
                nfa.transitions = replaced_transitions
                nfa.start = new_id if nfa.start == orig
                nfa.accept = new_id if nfa.accept == orig
                nfa.start_state_ids.each do |key, value|
                    if nfa.start_state_ids[key] == orig
                        nfa.start_state_ids[key] == new_id
                    end    
                end
                nfa.end_state_ids.each do |key, value|
                    if nfa.end_state_ids[key] == orig
                        nfa.end_state_ids[key] == new_id
                    end    
                end
                replaced_range_trans = {}
                nfa.range_transitions.each do |start, value|
                    n_value = []
                    value.each do |tran_value|
                        symbol, finish = tran_value
                        if finish == orig
                            n_value << [symbol, new_id]
                        else
                            n_value << tran_value
                        end
                    end
                    if start == orig
                        replaced_range_trans[new_id] = n_value 
                    else
                        replaced_range_trans[start] = n_value 
                    end
                end
                nfa.range_transitions = replaced_range_trans
                replace_else_trans = {}
                nfa.else_transitions.each do |start, finish|
                    start = new_id if orig == start
                    finish = new_id if orig == finish
                    replace_else_trans[start] = finish
                end
                nfa.else_transitions = replace_else_trans
                nfa.capture_states.each do |key, value|
                    start, finish = value
                    value[0] == new_id if start == orig
                    value[1] == new_id if finish == orig
                    nfa.capture_states[key] = [start == orig ? new_id : start, finish == orig ? new_id : finish]
                end if nfa.capture_states
            end
        end
    end
end
