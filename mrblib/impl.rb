module TypedArgs
  module Internal
    module Impl
      class << self
        def parse(argv)
          out = {}
          i = 0
          n = argv.size
          while i < n
            a = argv[i]
            if a && a.length > 0
              if long_flag?(a)
                parse_long(out, a)
              elsif short_flag?(a)
                # Alias expansion happens BEFORE parsing, per the README.
                # If a 2-char short prefix is aliased, we textually rewrite
                # the entire arg into a long-flag form and dispatch there.
                expanded = Internal.expand_short_alias(a)
                if expanded
                  if long_flag?(expanded)
                    parse_long(out, expanded)
                  else
                    # Alias target wasn't a long-flag form; treat the original
                    # arg as a short flag (best-effort fallback).
                    parse_short(out, a)
                  end
                else
                  parse_short(out, a)
                end
              end
            end
            i += 1
          end
          out
        end

        private

        def long_flag?(arg)
          arg.length >= 2 &&
          arg[0,1] == "-" &&
          arg[1,1] == "-"
        end

        def short_flag?(arg)
          arg.length >= 1 &&
          arg[0,1] == "-" &&
          !(arg.length >= 2 && arg[1,1] == "-")
        end

        def parse_long(out, arg)
          body = arg[2, arg.length - 2]   # strip "--"

          eq_idx = body.index("=")
          if eq_idx
            key_str = body[0, eq_idx]
            val_str = body[(eq_idx + 1), body.length - (eq_idx + 1)]
          else
            key_str = body
            val_str = nil
          end

          key_lex = Lexer.new(key_str, 0, key_str.length, true)
          key_ast = KeyParser.new(key_lex).parse

          # Long-flag keys are taken at face value; the alias map applies
          # only to short flags (per README).
          name = key_ast[:name]

          ScriptCheck.validate_key(key_str)

          if val_str
            val_lex = Lexer.new(val_str, 0, val_str.length, false)
            vp = ValueParser.new(val_lex)

            case key_ast[:kind]
            when :scalar, :array_scalar
              value = vp.parse_scalar
            when :hash, :array_hash
              tuple = vp.parse_tuple(key_ast[:fields].size)
              value = build_hash(key_ast[:fields], tuple)
            end
          else
            value = true
          end

          assign(out, name, key_ast, value)
        end

        # parse_short handles short flags that DO NOT have an alias.
        # Aliased short flags are rewritten and dispatched to parse_long.
        def parse_short(out, arg)
          # Strip the leading dash; everything after it is the bare name
          # candidate (until any attached value).
          name = arg[1, arg.length - 1]

          if name.nil? || name.length == 0
            raise InvalidKeyStartError.new(
              "Invalid key start", 1, arg
            )
          end

          # Validate the first character of the short-flag name.
          c0 = name[0,1]
          unless c0 == "_" ||
                (c0 >= "A" && c0 <= "Z") ||
                (c0 >= "a" && c0 <= "z") ||
                (c0 > "\u007F")
            raise InvalidCharacterError.new(
              "Illegal character in short flag", 1, arg
            )
          end

          # The bare name is just the first character. Everything else
          # (if any) is the attached value.
          name = c0

          if arg.length > 2
            val_str = arg[2, arg.length - 2]
            val_lex = Lexer.new(val_str, 0, val_str.length, false)
            vp      = ValueParser.new(val_lex)
            value   = vp.parse_scalar
          else
            value = true
          end

          out[name] = value
        end

        def build_hash(fields, vals)
          h = {}
          i = 0
          while i < fields.size
            h[fields[i]] = vals[i]
            i += 1
          end
          h
        end

        def assign(out, name, spec, value)
          case spec[:kind]
          when :scalar
            out[name] = value
          when :hash
            # Hash tuple assignment overwrites the previous value, per README.
            out[name] = value
          when :array_scalar
            existing = out[name]
            arr = existing.is_a?(Array) ? existing : []
            arr.push(value)
            out[name] = arr
          when :array_hash
            existing = out[name]
            arr = existing.is_a?(Array) ? existing : []
            arr.push(value)
            out[name] = arr
          end
        end
      end
    end
  end
end
