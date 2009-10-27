#!/usr/bin/env ruby

# Parses regular expressions 
# uses Dijkstra's Shunting yard algorithm
class RegexParser

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
        raise SyntaxError.new("#{@oper.size} operators still left on stack: #{@oper}") if @oper.size != 1
        raise SyntaxError.new("#{@dat.size} operands still left on stack: #{@dat}") if @dat.size != 1
    end

    class << self
        def parse(expr)
            self.new(expr).parse
        end
        def parse_tree(expr)
            self.new(expr).parse_tree
        end
    end

    def parse
        do_parse
        @dat.last.value
    end

    def parse_tree
        do_parse
        @dat.last
    end

    # parse the input expression
    def expr
        while @pos < @expr.length
            # decide what to do with the next token
            next_token = scan
            puts "token: #{next_token}, operator? #{next_token.operator}"
            case next_token.token_type
            when :open then
                subexpr
            when :close then
                # do nothing
                break 
            when :simple then
                @dat.push(next_token)
                consume(next_token)
            else
                if next_token.operator then
                    push_operator(next_token)
                else 
                    raise SyntaxError.new("Parsed invalid token: #{next_token} at #{@pos}")
                end
            end
            # check if we need to add a concatenate operator
            push_concat_oper if @dat.size >= 2
        end
        # nothing left on the input, pop operators off the stack until we hit the sentinel
        while (@oper.last != :sentinel)
            pop_operator
        end
    end

    def push_concat_oper
        push_operator(create_token(:concat, nil, 0))
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
    end
   
    # pop an operator from teh operator stack
    # if its unary, give it one operand
    # otherwise, two operands 
    def pop_operator
        op = @oper.pop
        if op.unary
            raise SyntaxError.new("Not enough operands for #{op} operation") if @dat.size < 1
            op.left = @dat.pop
        else
            raise SyntaxError.new("Not enough operands for #{op} operation") if @dat.size < 2
            op.right = @dat.pop
            op.left = @dat.pop
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
   
    # increment the input position pointer if the 
    # next input token matches the given token 
    def consume(token)
        if scan == token
            @pos += token.respond_to?(:length) ? token.length : 1
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
        curr_pos = @pos
        curr_pos+=1 while [' ', '\t', '\r', '\n'].include?(@expr[curr_pos, 1])
        @prev_token = case @expr[curr_pos, 1]
        when '(' then
            create_token(:open)
        when ')' then
            create_token(:close)
        when '*' then
            create_token(:star)
        when 'a'..'z' then
            create_token(:simple, @expr[curr_pos, 1]);
        else
            raise SyntaxError.new("Did not recognize token starting at #{curr_pos}")
        end
        @pos = curr_pos
        @prev_pos = curr_pos
        @prev_token
    end

    # create a token for the give token type
    def create_token(token_type, value = nil, length = 1)
        right_associative = []
        unary = [:star]
        operator = [:star]
        # define operator precedences
        prec = {
            :sentinel => 0,
            :star     => 150, 
            :concat   => 200,
        }
        opts = {
            :right_associative => right_associative.include?(token_type),
            :unary => unary.include?(token_type),
            :operator => operator.include?(token_type),
            :prec => prec[token_type],
            :value => value,
            :length => length
        }
        Node.new(token_type, opts)
    end
   
end

class Node 

    attr_accessor :value, :token_type, :right_associative, :unary, :operator, :prec, :right, :left, :length, :id

    def initialize(token_type, opts = {})
        @token_type = token_type 
        @value = opts[:value] || nil
        @length = opts[:length] || 1
        @right_associative = opts[:right_associative] || false
        @unary = opts[:unary] || false
        @operator = opts[:operator] || false
        @prec = opts[:prec] || -1
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

end

