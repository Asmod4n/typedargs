module TypedArgs
  class Error < StandardError; end
  class SyntaxError < Error
    attr_reader :pos, :source

    def initialize(msg, pos, source)
      @pos    = pos
      @source = source || ""
      line    = @source
      pointer = " " * @pos + "^"
      pretty  = "\n" + line + "\n" + pointer + "\nSyntax error: " + msg
      super(pretty)
    end
  end

  class InvalidCharacterError < SyntaxError; end
  class InvalidKeyStartError < SyntaxError; end
  class UnterminatedStringError < SyntaxError; end
  class ArityMismatchError < SyntaxError; end
  class UnexpectedTokenError < SyntaxError; end
  class InvalidSuffixPositionError < SyntaxError; end
  class InvalidFieldListError < SyntaxError; end
  class InvalidNumberError < SyntaxError; end

  class << self
    def alias(short, long)
      Internal.register_alias(short, long)
    end

    # Clear all registered aliases. Useful for test isolation.
    def reset_aliases!
      Internal.reset_aliases!
    end

    def opts(*argv)
      args = argv.empty? ? ::ARGV : argv
      Internal::Impl.parse(args)
    end
  end
end
