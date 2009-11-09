#!/usr/bin/env ruby

require 'node'

module Regex

    # Parses regular expressions 
    # uses Dijkstra's Shunting yard algorithm
    class Parser

        #define constants for types of operators
        RIGHT_ASSOCIATIVE = [:or]
        UNARY = [:star, :plus, :opt, :rep, :cap]
        POSTFIX = [:star, :plus, :opt, :rep, :cap]
        OPERATOR = [:star, :plus, :opt, :concat, :or, :rep, :not, :cap]
        # define operator precedences
        PREC = {
            :sentinel => 0,
            :cap      => 25,
            :or       => 50,
            :not      => 50,
            :concat   => 100,
            :star     => 150, 
            :plus     => 150, 
            :opt      => 150, 
            :rep      => 150, 
        }

        def initialize(expr)
            @expr = expr.strip
            @oper = []
            @dat = []
            @pos = 0
            @prev_pos = -1
            @prev_token = nil
            @cap_groups = 0
        end

        # initial parser entry point
        # set up stacks and begin parsing
        def do_parse
            return if @pos > 0
            @oper.push(create_token(:sentinel))
            expr
            raise SyntaxError.new("Not all input consumed") if @pos < @expr.length
            raise SyntaxError.new("#{@oper.size} operators still left on stack: #{@oper}") if @oper.size != 1
            raise SyntaxError.new("#{@dat.size} operands still left on stack: #{@dat}") if @dat.size != 1
        end

        class << self
            def parse_tree(expr)
                self.new(expr).parse_tree
            end
        end

        def parse_tree
            do_parse
            @dat.last
        end

        # parse the input expression
        def expr
            # keep the number of operands before we start
            # (useful for sub expressions)
            size = [@dat.size]

            while @pos < @expr.length
                # decide what to do with the next token
                next_token = scan
                #puts "token: #{next_token}, operator? #{next_token.operator}"
                case next_token.token_type
                when :open then
                    subexpr
                when :close then
                    # do nothing
                    break 
                when :cls_open then
                    char_class
                when :rep_open then
                    rep
                when :simple, :any, :range then
                    @dat.push(next_token)
                    consume(next_token)
                when :or then
                    if next_token.operands.size > 0
                        # if the token already has operands
                        # dont push it as an operator, just 
                        # add it as an operand (for example, 
                        # for \w escape sequences)
                        @dat.push(next_token)
                        consume(next_token)
                    else
                        push_concat_oper(@dat.size - size.pop - 1, :or)
                        push_operator(next_token)
                        size.push(@dat.size)
                    end
                else
                    if next_token.operator then
                        push_operator(next_token)
                    else 
                        raise SyntaxError.new("Parsed invalid token: #{next_token} at #{@pos}")
                    end
                end
            end
            # nothing left on the input, pop operators off the stack until we hit the sentinel
            push_concat_oper(@dat.size - size.last - 1, :or) 
            # check if we need to add any concatenate operator
            # how many operands since the last sentinel
            push_concat_oper(@dat.size - size.shift - 1)
        end

        # add concatenation operators to the stack if necessary 
        # and pop all operators off until a sentinel or the given op is reached
        def push_concat_oper(since, op = nil)
            since.times { push_operator(create_token(:concat, nil, 0)) } if @dat.size >= 2
            while (@oper.last != :sentinel and (op.nil? or @oper.last != op))
                pop_operator
            end
        end

        # push an operator from input onto the stack
        # if there are higher precedence operators
        # on the stack already, give them their
        # operators before pushing it onto the stack
        def push_operator(next_oper)
            top_oper = @oper.last
            while (next_oper.right_associative ? 
                top_oper.prec > next_oper.prec : #right associative operator on top
                top_oper.prec >= next_oper.prec) #left associative operator on top
                pop_operator
                top_oper = @oper.last
            end
            consume(next_oper) if next_oper.length > 0
            @oper.push(next_oper)
            # special case for postfix unary operators
            # pop it from the stack right away so that it gets 
            # the correct operand. example: a*b: star needs to 
            # get 'a' operand instead of 'b'
            pop_operator if next_oper.unary and next_oper.postfix
        end
       
        # pop an operator from the operator stack
        # if its unary, give it one operand
        # otherwise, two operands 
        def pop_operator
            op = @oper.pop
            if op.unary
                raise SyntaxError.new("Not enough operands for #{op} operation: #{@dat.size} left") if @dat.size < 1
                operand = @dat.pop
                raise SyntaxError.new("Nested quantifiers (?*+) not allowed)") if op.token_type?(:plus, :star) and operand.token_type?(:plus, :star, :opt)
                op.operands.push(operand)
            else
                raise SyntaxError.new("Not enough operands for #{op} operation: #{@dat.size} left") if @dat.size < 2
                operand1 = @dat.pop
                operand2 = @dat.pop
                if operand1.token_type?(op.token_type)
                    op.operands.concat(operand1.operands)
                else
                    op.operands.unshift(operand1)
                end
                if operand2.token_type?(op.token_type)
                    op.operands = operand2.operands.concat(op.operands)
                else
                    op.operands.unshift(operand2)
                end
            end
            @dat.push(op)
        end

        # evaluate a sub expression wrapped in parens
        def subexpr
            capture = scan.value
            if capture
                @cap_groups += 1
                cap_group = @cap_groups
            end
            @oper.push(create_token(:sentinel))
            consume(:open)
            expr
            consume(:close)
            if capture
                @oper.push(create_token(:cap, cap_group))
                pop_operator
            end
            @oper.pop
        end

        def char_class
            negate = false
            consume(:cls_open)
            chars = [] # a list of characters in the class
            expand_from = nil
            prev_token = nil
            while @pos < @expr.length
                next_token = scan_char_class
                case next_token.token_type
                when :cls_close
                    break
                when :dash
                    #expand from prev_token to the next
                    expand_from = prev_token
                    consume(:dash, scan_char_class)
                when :negate
                    negate = true
                    consume(:negate, scan_char_class)
                else
                    # expand the characters specified
                    if expand_from  
                        chars.delete_if { |chr| chr.token_type?(:simple) and chr.value == expand_from.value }
                        chars << create_token(:range, expand_from.value..next_token.value, 3)
                        expand_from = nil
                    else
                        chars << next_token
                    end
                    consume(next_token, scan_char_class)
                    prev_token = next_token
                end
            end
            if chars.size == 0
                raise SyntaxError.new("Cannot have empty character class") 
            elsif chars.size == 1 and not negate
                @dat.push(chars.first)
            else
                token_type = negate ? :not : :or
                or_op = create_token(token_type)
                chars.each do |chr|
                    or_op.operands.push(chr)
                end
                @dat.push(or_op)
            end
            consume(:cls_close)
        end

        # handles repetition
        # if a repetition operator is found, it is copied
        # and concatenated the number of times specified
        def rep
            open_ended = false
            # parse from the input
            consume(:rep_open)
            rep_num_1 = scan_rep
            rep_num_2 = nil
            consume(:num, scan_rep)
            next_token = scan_rep
            if next_token.token_type?(:comma)
                consume(:comma, scan_rep)
                rep_num_2 = scan_rep
                if rep_num_2.token_type?(:num)
                    consume(:num, scan_rep)
                else
                    open_ended = true
                    rep_num_2 = nil
                end
            end
            consume(:rep_close, scan_rep)
            value = (rep_num_2) ? (rep_num_1.value..rep_num_2.value) : rep_num_1.value
            required = value
            optional = 0
            if value.is_a?(Range)
                required = value.begin
                optional = value.end - value.begin
            end
            if required == 0 and optional == 0 and not open_ended
                @dat.pop #nothing should be matched
            elsif required == 1 and optional == 0 and not open_ended
                #do nothing, the operand is already on the stack
            else
                # create the concatenation operator with 
                # the correct number of operands
                push_operator(create_token(:rep, value, 0))
                if @dat.last.token_type?(:rep)
                    rep = @dat.pop
                    concat = create_token(:concat)
                    required.times do |i|
                        concat.operands << rep.operands.first.clone
                    end
                    if open_ended
                        star = create_token(:star)
                        star.operands << rep.operands.first.clone
                        concat.operands << star
                    else
                        optional.times do
                            opt = create_token(:opt)
                            opt.operands << rep.operands.first.clone
                            concat.operands << opt
                        end
                    end
                    concat.operands.size == 1 ? @dat.push(concat.operands.first) : @dat.push(concat)
                else
                    raise SyntaxError.new("Expected to see rep token on top of the stack")
                end
            end
        end
      
        # increment the input position pointer if the 
        # next input token matches the given token 
        def consume(token, scanned = scan)
            if scanned == token
                @pos += scanned.respond_to?(:length) ? scanned.length : 1
            else 
                raise SyntaxError.new("Expected #{token} at #{@pos}")
            end
        end 

        # tokenizer
        # read input string and return a value representing the token
        def scan
            # if we have already found the current token, return it
            return @prev_token if @pos == @prev_pos
            #skip whitespace
            @prev_token = case @expr[@pos, 1]
            when '(' then
                next_two = @expr[@pos+1, 2] if @expr.size > @pos + 2
                if next_two == "?:"
                    create_token(:open, false, 3)
                else
                    create_token(:open, true, 1)
                end
            when ')' then
                create_token(:close)
            when '[' then
                create_token(:cls_open)
            when ']' then
                create_token(:cls_close)
            when '{' then
                create_token(:rep_open)
            when '}' then
                create_token(:rep_close)
            when '*' then
                create_token(:star)
            when '+' then
                create_token(:plus)
            when '?' then
                create_token(:opt)
            when '|' then
                create_token(:or)
            when '\\'
                scan_escaped
            when '.' then
                create_token(:any)
            else
                create_token(:simple, @expr[@pos, 1]);
            end
            @prev_pos = @pos
            @prev_token
        end

        # tokenizer for escaped characters
        def scan_escaped
            non_readable = {'t'=>"\t", 'r'=>"\r", 'n'=>"\n", 
                'a'=>"\a", 'e'=>"\e", 'f'=>"\f", 'v'=>"\v" }
            if @expr.size > @pos + 1
                char = @expr[@pos+1, 1]
                char = non_readable[char] if non_readable[char]
                if char == 'd'
                    create_token(:range, '0'..'9', 2)
                elsif char == 'w'
                    or_oper = create_token(:or, nil, 2)
                    or_oper.operands << create_token(:range, 'a'..'z', 0)
                    or_oper.operands << create_token(:range, 'A'..'Z', 0)
                    or_oper.operands << create_token(:range, '0'..'9', 0)
                    or_oper.operands << create_token(:simple, '_', 0)
                    or_oper
                elsif char == 's'
                    or_oper = create_token(:or, nil, 2)
                    or_oper.operands << create_token(:simple, ' ', 0)
                    or_oper.operands << create_token(:simple, "\t", 0)
                    or_oper.operands << create_token(:simple, "\r", 0)
                    or_oper.operands << create_token(:simple, "\n", 0)
                    or_oper
                else    
                    create_token(:simple, char, 2)
                end
            else
                create_token(:simple, @expr[@pos, 1]);
            end
        end

        # tokenizer for when we are inside a character class [ ]
        def scan_char_class
            return @prev_token if @pos == @prev_pos
            @prev_token = case @expr[@pos, 1]
            when ']' then
                create_token(:cls_close)
            when '-'
                (@expr[@pos+1, 1] != ']' and not @prev_token == :cls_open) ? create_token(:dash) : create_token(:simple, '-')
            when '^'
                @prev_token == :cls_open ? create_token(:negate) : create_token(:simple, '^')  
            when '\\'
                scan_escaped
            else
                create_token(:simple, @expr[@pos, 1]);
            end
            @prev_pos = @pos
            @prev_token
        end

        # tokenizer for when we are inside a repetition { }
        def scan_rep
            return @prev_token if @pos == @prev_pos
            curr_pos = @pos
            @prev_token = case @expr[curr_pos, 1]
            when '}' then
                create_token(:rep_close)
            when ','
                create_token(:comma) 
            else
                # parse a number
                digits = ""
                while curr_pos < @expr.length and ('0'..'9') === @expr[curr_pos, 1] 
                    digits += @expr[curr_pos, 1]
                    curr_pos += 1
                end
                create_token(:num, digits.to_i, curr_pos - @pos);
            end
            #@pos = curr_pos
            @prev_pos = @pos
            @prev_token
        end

        # create a token for the give token type
        def create_token(token_type, value = nil, length = 1)
            Node.new(token_type, value, 
                RIGHT_ASSOCIATIVE.include?(token_type), 
                UNARY.include?(token_type),
                POSTFIX.include?(token_type),
                OPERATOR.include?(token_type),
                length,
                PREC[token_type])
        end
       
    end

end


if __FILE__ == $0
    require 'graph_gen'

    ARGV.each_with_index do |expr, i|
        Regex::GraphGen.gen(Regex::Parser.parse_tree(expr), "out/tree#{i}.dot")
    end
end
