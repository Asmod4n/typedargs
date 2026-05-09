module TypedArgs
  module Internal
    @alias_map = {}

    class << self
      def register_alias(short, long)
        @alias_map[short] = long
      end

      def reset_aliases!
        @alias_map = {}
      end

      # If `arg` is a short flag whose first 2 characters are registered as an
      # alias, return the textually-expanded long-flag form. Otherwise return
      # nil.
      #
      # Expansion rule:
      #   "-X" alone        →  alias_target
      #   "-X<payload>"     →  alias_target + payload          (if target ends in "=")
      #                        alias_target + "=" + payload    (otherwise)
      #
      # This makes the README's claim literally true: aliases are textual
      # substitutions performed before parsing, and they can target dotted
      # keys and any operator form (`=`, `+=`, `:fields:=`, `+:fields:=`).
      def expand_short_alias(arg)
        return nil if arg.nil? || arg.length < 2
        short_key = arg[0, 2]
        target = @alias_map[short_key]
        return nil if target.nil?

        if arg.length > 2
          payload = arg[2, arg.length - 2]
          if target.length > 0 && target[target.length - 1, 1] == "="
            target + payload
          else
            target + "=" + payload
          end
        else
          target
        end
      end
    end
  end
end
