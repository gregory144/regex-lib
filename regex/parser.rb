#!/usr/bin/env ruby

require 'node'

module Regex

    # Parses regular expressions 
    # uses Dijkstra's Shunting yard algorithm
    class Parser

        def initialize(expr)
            @expr = expr.strip
            @oper = []
            @dat = []
            @pos = 0
            @prev_pos = -1
            @prev_token = nil
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
                when :simple, :any then
                    @dat.push(next_token)
                    consume(next_token)
                when :or then
                    push_concat_oper(@dat.size - size.pop - 1, :or)
                    push_operator(next_token)
                    size.push(@dat.size)
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
            @oper.push(create_token(:sentinel))
            consume(:open)
            expr
            consume(:close)
            @oper.pop
        end

        def char_class
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
                else
                    # expand the characters specified
                    if expand_from
                        (expand_from.value.succ..next_token.value).each do |c|
                            chars << create_token(:simple, c)
                        end
                        expand_from = nil
                    else
                        chars << next_token
                    end
                    consume(next_token, scan_char_class)
                    prev_token = next_token
                end
            end
            case chars.size
            when 0
                raise SyntaxError.new("Cannot have empty character class") 
            when 1
                @dat.push(chars.first)
            else
                or_op = create_token(:or)
                chars.each do |chr|
                    or_op.operands.push(chr)
                end
                @dat.push(or_op)
            end
            consume(:cls_close)
        end
       
        # increment the input position pointer if the 
        # next input token matches the given token 
        def consume(token, scanned = scan)
            if scanned == token
                @pos += token.respond_to?(:length) ? token.length : 1
            else 
                raise SyntaxError.new("Expected #{token} at #{@pos}")
            end
        end 

        # tokenizer
        # read input string and return a value representing the token
        def scan()
            # if we have already found the current token, return it
            return @prev_token if @pos == @prev_pos
            #skip whitespace
            curr_pos = @pos
            curr_pos+=1 while [' ', '\t', '\r', '\n'].include?(@expr[curr_pos, 1])
            @prev_token = case @expr[curr_pos, 1]
            when '(' then
                create_token(:open)
            when ')' then
                create_token(:close)
            when '[' then
                create_token(:cls_open)
            when ']' then
                create_token(:cls_close)
            when '*' then
                create_token(:star)
            when '+' then
                create_token(:plus)
            when '?' then
                create_token(:opt)
            when '|' then
                create_token(:or)
            when '\\'
                if @expr.size > curr_pos + 1
                    create_token(:simple, @expr[curr_pos+1, 1], 2);
                else
                    create_token(:simple, @expr[curr_pos, 1]);
                end
            when '.' then
                create_token(:any)
            else
                create_token(:simple, @expr[curr_pos, 1]);
            end
            @pos = curr_pos
            @prev_pos = curr_pos
            @prev_token
        end

        def scan_char_class
            return @prev_token if @pos == @prev_pos
            @prev_token = case @expr[@pos, 1]
            when ']' then
                create_token(:cls_close)
            when '-'
                (@expr[@pos+1, 1] != ']' and not @prev_token == :cls_open) ? create_token(:dash) : create_token(:simple, '-')
            else
                create_token(:simple, @expr[@pos, 1]);
            end
            @prev_pos = @pos
            @prev_token
        end

        # create a token for the give token type
        def create_token(token_type, value = nil, length = 1)
            right_associative = [:or]
            unary = [:star, :plus, :opt]
            postfix = [:star, :plus, :opt]
            operator = [:star, :plus, :opt, :concat, :or]
            # define operator precedences
            prec = {
                :sentinel => 0,
                :or       => 50,
                :concat   => 100,
                :star     => 150, 
                :plus     => 150, 
                :opt      => 150, 
            }
            opts = {
                :right_associative => right_associative.include?(token_type),
                :unary => unary.include?(token_type),
                :postfix => postfix.include?(token_type),
                :operator => operator.include?(token_type),
                :prec => prec[token_type],
                :value => value,
                :length => length
            }
            Node.new(token_type, opts)
        end
       
    end

end


if __FILE__ == $0
    require 'graph_gen'

    ARGV.each_with_index do |expr, i|
        Regex::GraphGen.gen(Regex::Parser.parse_tree(expr), "out/tree#{i}.dot")
    end
end
