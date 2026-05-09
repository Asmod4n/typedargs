# lexer.rb (optimized)
module TypedArgs
  module Internal
    class Lexer
      attr_reader :str

      def initialize(str, start_pos, char_length, parsing_key = false)
        @str = str || ""
        @parsing_key = !!parsing_key
        @i = start_pos || 0
        @start = @i
        @end = [@start + (char_length || 0), @str.length].min
      end

      def parsing_key?
        @parsing_key
      end

      def next_token
        s = @str
        i = @i
        end_i = @end

        # skip whitespace
        while i < end_i
          ch = s[i,1]
          break unless ch <= " "
          i += 1
        end
        @i = i
        return Token.new(:EOF, nil, i) if i >= end_i

        ch = s[i,1]

        # single-char tokens
        case ch
        when "," then @i = i + 1; return Token.new(:COMMA, nil, i)
        when "=" then @i = i + 1; return Token.new(:EQUAL, nil, i)
        when "." then @i = i + 1; return Token.new(:DOT, nil, i)
        when "+" then @i = i + 1; return Token.new(:PLUS, nil, i)
        when ":" then @i = i + 1; return Token.new(:COLON, nil, i)
        when "\""
          start = i
          i += 1

          # scan UTF-8 codepoints until closing quote
          while i < end_i
            cp, ni = Internal.utf8_next(s, i)

            if cp == 0x22  # '"'
              val = s[start + 1, i - (start + 1)]
              @i = ni
              return Token.new(:STRING, val, start)
            end

            i = ni
          end

          raise UnterminatedStringError.new("Unterminated string", start, s)
        end

        # parsing_key fast path
        if @parsing_key
          return ident_token_fast(s, i, end_i)
        end

        # value side: number, ident-like, or raw
        if ascii_digit?(ch) || (ch == "-" && peek_ascii_digit?(s, i, end_i))
          return number_token_fast(s, i, end_i)
        end

        if ident_start_char?(ch)
          # try to scan an ident-like token; if any char fails ident_continue, fall back to raw
          j = i
          all_ident = true
          while j < end_i
            cc = s[j,1]
            break if cc == ","
            unless ident_continue_char?(cc)
              all_ident = false
              break
            end
            j += 1
          end
          if all_ident
            # produce IDENT token
            val = s[i, j - i]
            @i = j
            return Token.new(:IDENT, val, i)
          else
            # raw value: scan until comma (the only intra-arg terminator)
            start = i
            while i < end_i
              cc = s[i,1]
              break if cc == ","
              i += 1
            end
            val = s[start, i - start]
            @i = i
            # detect all-dash invalid number
            if all_dashes?(val)
              raise InvalidCharacterError.new("Illegal number", start, s)
            end
            return Token.new(:STRING, val, start)
          end
        end

        # fallback raw value
        start = i
        while i < end_i
          cc = s[i,1]
          break if cc == ","
          i += 1
        end
        val = s[start, i - start]
        @i = i
        if all_dashes?(val)
          raise InvalidCharacterError.new("Illegal number", start, s)
        end
        Token.new(:STRING, val, start)
      end

      private

      # IDENT token when parsing_key true
      def ident_token_fast(s, i, end_i)
        start = i
        ch = s[i,1]
        unless ident_start_char?(ch)
          if ascii_digit?(ch)
            raise InvalidKeyStartError.new("Invalid key start", i, s)
          else
            raise InvalidCharacterError.new("Illegal character in key", i, s)
          end
        end
        i += 1
        while i < end_i
          c = s[i,1]
          break unless ident_continue_char?(c)
          i += 1
        end
        val = s[start, i - start]
        @i = i
        Token.new(:IDENT, val, start)
      end

      def number_token_fast(s, i, end_i)
        start = i
        digits = 0
        dot = false

        if s[i,1] == "-"
          i += 1
        end

        while i < end_i
          c = s[i,1]
          if ascii_digit?(c)
            digits += 1
            i += 1
          elsif c == "."
            raise InvalidNumberError.new("Invalid number format", start, s) if dot
            dot = true
            i += 1
          else
            break
          end
        end

        raise InvalidCharacterError.new("Illegal number", start, s) if digits == 0

        val = s[start, i - start]
        @i = i
        Token.new(:NUMBER, val, start)
      end

      # helpers (inlined ASCII fast paths)
      def ascii_digit?(ch)
        ch >= "0" && ch <= "9"
      end

      def all_dashes?(str)
        k = 0
        while k < str.length
          return false if str[k,1] != "-"
          k += 1
        end
        true
      end

      def ident_start_char?(ch)
        return true if ch == "_"
        return true if (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")
        # non-ASCII single-char candidate
        ch.length == 1 && ch > "\u007F"
      end

      def ident_continue_char?(ch)
        return true if ident_start_char?(ch)
        return true if ascii_digit?(ch)
        return true if ch == "-" || ch == "."
        false
      end

      def peek_ascii_digit?(s, i, end_i)
        return false if (i + 1) >= end_i
        c = s[i + 1,1]
        c >= "0" && c <= "9"
      end
    end
  end
end
