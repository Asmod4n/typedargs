# value_parser.rb
module TypedArgs
  module Internal
    class ValueParser
      def initialize(lexer)
        @lx  = lexer
        @tok = @lx.next_token
      end

      def parse_tuple(expected)
        vals = []
        vals.push(parse_scalar)
        while @tok.type == :COMMA
          consume(:COMMA)
          vals.push(parse_scalar)
        end
        if vals.size != expected
          raise ArityMismatchError.new("Arity mismatch: expected #{expected}, got #{vals.size}", @tok.pos, @lx.str)
        end
        vals
      end

      def parse_scalar
        if @tok.type == :EOF
          raise UnexpectedTokenError.new("Unexpected EOF", @tok.pos, @lx.str)
        end

        case @tok.type
        when :STRING
          v = @tok.value
          consume(:STRING)
          v
        when :NUMBER
          v = @tok.value
          consume(:NUMBER)
          convert_number_token(v)
        when :IDENT
          v = @tok.value
          consume(:IDENT)
          case v
          when "true"  then true
          when "false" then false
          when "nil"   then nil
          else
            v
          end
        else
          buf = ""
          while @tok.type != :COMMA && @tok.type != :EOF
            buf += @tok.value.to_s
            @tok = @lx.next_token
          end
          buf
        end
      end

      private

      def convert_number_token(s)
        return s.to_i if integer_string?(s)
        if Object.const_defined?(:Float)
          return s.to_f if float_string?(s)
        end
        raise InvalidNumberError.new("Invalid number", @tok.pos, @lx.str)
      end

      def integer_string?(s)
        i = 0
        n = s.length
        return false if n == 0
        if s[0,1] == "-"
          return false if n == 1
          i = 1
        end
        while i < n
          ch = s[i,1]
          return false unless ch >= "0" && ch <= "9"
          i += 1
        end
        true
      end

      def float_string?(s)
        i = 0
        n = s.length
        return false if n == 0
        if s[0,1] == "-"
          return false if n == 1
          i = 1
        end
        seen_dot = false
        digits = 0
        while i < n
          ch = s[i,1]
          if ch == "."
            return false if seen_dot
            seen_dot = true
          elsif ch >= "0" && ch <= "9"
            digits += 1
          else
            return false
          end
          i += 1
        end
        seen_dot && digits > 0
      end

      def consume(type)
        if @tok.type != type
          raise UnexpectedTokenError.new("Expected #{type}, got #{@tok.type}", @tok.pos, @lx.str)
        end
        @tok = @lx.next_token
      end
    end
  end
end
