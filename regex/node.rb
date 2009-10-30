#!/usr/bin/env ruby

module Regex

    class Node 

        attr_accessor :value, :token_type, :right_associative, :unary, :postfix, :operator, :prec, :operands, :length, :id

        def initialize(token_type, opts = {})
            @token_type = token_type 
            @value = opts[:value] || nil
            @length = opts[:length] || 1
            @right_associative = opts[:right_associative] || false
            @unary = opts[:unary] || false
            @postfix = opts[:postfix] || false
            @operator = opts[:operator] || false
            @prec = opts[:prec] || -1
            @operands = []
        end

        # handles node objects and token type symbols 
        def ==(other)
            @token_type == ((other.respond_to?(:token_type) && other.token_type) || other)
        end
       
        def to_s
            "Node: " + (case @token_type
                when :simple
                    @value.to_s
                else
                    @token_type.to_s
                end
                )
        end

        def assign_tree_ids(curr_id = 0)
            @id = curr_id
            curr_id += 1
            @operands.each do |operand|
                curr_id = operand.assign_tree_ids(curr_id)
            end
            curr_id
        end
     
    end

end
