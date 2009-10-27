#!/usr/bin/env ruby

# Parses numeric expressions with operators
# using the Dijkstra's Shunting yard algorithm
class ExpressionParser

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
        @oper.push(create_token(:sentinel))
        expr
        raise SyntaxError.new("#{@oper.size} operators still left on stack: #{@oper}") if @oper.size != 1
        raise SyntaxError.new("#{@dat.size} operands still left on stack: #{@dat}") if @dat.size != 1
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
            #puts "token: #{next_token}, operator? #{next_token.operator}"
            case next_token.token_type
            when :open then
                subexpr
            when :close then
                # do nothing
                break 
            when :num then
                @dat.push(next_token)
                consume(next_token)
            else
                if next_token.operator then
                    push_operator(next_token)
                else 
                    raise SyntaxError.new("Parsed invalid token: #{next_token} at #{@pos}")
                end
            end
        end
        # nothing left on the input, pop operators off the stack until we hit the sentinel
        while (@oper.last != :sentinel)
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
        consume(next_oper)
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
        when '+' then
            create_token(:plus)
        when '-' then
            # decide whether this is a unary or binary operator
            # it is binary if the previous read token is not an operator OR
            # if the previous read token is a left associative, unary operator (like '!')
            create_token(
                ((@prev_token && !@prev_token.operator) ||
                    (@prev_token && @prev_token.operator && !@prev_token.right_associative && @prev_token.unary)) ?
                   :minus :
                   :neg 
            )
        when '*' then
            create_token(:mult)
        when '/' then
            create_token(:div)
        when '%' then
            create_token(:mod)
        when '^' then
            create_token(:pow)
        when '!' then
            create_token(:fact)
        when '0'..'9' then
            # check if the last token was also a number - this is a syntax error
            raise SyntaxError.new("Two numbers in a row, invalid syntax") if @prev_token && @prev_token == :num
            s_value = @expr[curr_pos..-1][/^[0-9]+(\.[0-9]+)?/]
            create_token(:num, s_value.to_f, s_value.length)
        #when 'a'..'z', 'A'..'Z' then
        #    create_token(:ident, @expr[curr_pos..-1][/^[a-zA-Z][a-zA-Z0-9]*/])
        else
            raise SyntaxError.new("Did not recognize token starting at #{curr_pos}")
        end
        @pos = curr_pos
        @prev_pos = curr_pos
        @prev_token
    end

    # create a token for the give token type
    def create_token(token_type, value = nil, length = 1)
        right_associative = [:neg, :pow]
        unary = [:neg, :fact]
        # '(' is an operator so that '-' is identified as a unary operator when it follows '('
        operator = [:open, :plus, :minus, :neg, :mult, :div, :mod, :pow, :fact, :ident]
        # define operator precedences
        prec = {
            :sentinel => 0,
            :plus     => 150, 
            :minus    => 150, 
            :mult     => 300, 
            :div      => 300,
            :mod      => 300,
            :neg      => 300,
            :pow      => 400,
            :fact     => 350
        }
        opts = {}
        opts[:right_associative] = right_associative.include?(token_type)
        opts[:unary] = unary.include?(token_type)
        opts[:operator] = operator.include?(token_type)
        opts[:prec] = prec[token_type]
        opts[:value] = value
        opts[:length] = length
        Token.new(token_type, opts)
    end
   
end

class Token

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

    # handles tokens and integers
    def ==(other)
        @token_type == ((other.respond_to?(:token_type) && other.token_type) || other)
    end
   
    def to_s
        "Token: " + (case @token_type
            when :num
                @value.to_s
            when :minus 
                "-(binary)"
            when :neg 
                "-(unary)"
            else
                @token_type.to_s
            end
            )
    end

    # find the value of the given token
    # handles numeric operands and operators
    def value
        case @token_type
        when :num 
            @value
        when :plus
            @left.value + @right.value
        when :minus
            @left.value - @right.value
        when :mult
            @left.value * @right.value
        when :div
            @left.value / @right.value
        when :mod
            @left.value % @right.value
        when :neg
            @left.value * -1
        when :pow
            @left.value ** @right.value
        when :fact
            fact(@left.value.floor)
        else
            raise SyntaxError.new("Undefined operator in tree: #{self}")
        end
    end
   
    # calculate the factorial of the given integer 
    def fact(num)
        (2..num).inject(1) { |product, i| product*i }
    end
end

