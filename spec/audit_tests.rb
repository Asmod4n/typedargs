#!/usr/bin/env ruby
# spec/audit_tests.rb
#
# Conformance tests for the README. Each test asserts that the code now
# matches what the README claims. They are organized by the claim numbers
# from the original audit, so the history is traceable: every test that
# used to lock in a bug now locks in the fix.
#
# Run from repo root:
#   ruby -Ilib spec/audit_tests.rb
#
# Designed for plain CRuby. No mruby toolchain needed.
# Uses minitest if installed; falls back to an inline shim otherwise.

begin
  require "minitest/autorun"
rescue LoadError
  module Minitest
    class Assertion < StandardError; end
    class Skip < Assertion; end

    class Test
      @@subclasses = []
      def self.inherited(sub); @@subclasses << sub; super; end
      def self.all_subclasses; @@subclasses; end
      def self.runnable_methods
        public_instance_methods(true).map(&:to_s).grep(/\Atest_/).sort
      end

      def setup; end

      def run_one(name)
        setup
        send(name)
        :pass
      rescue Skip => e
        [:skip, e.message]
      rescue Assertion => e
        [:fail, e.message, e.backtrace]
      rescue => e
        [:error, "#{e.class}: #{e.message}", e.backtrace]
      end

      def assert(c, m=nil)
        raise Assertion, (m || "Expected truthy, got #{c.inspect}") unless c
        true
      end
      def refute(c, m=nil)
        raise Assertion, (m || "Expected falsy, got #{c.inspect}") if c
        true
      end
      def assert_equal(e,a,m=nil); assert e==a, (m || "Expected #{e.inspect}, got #{a.inspect}"); end
      def refute_equal(e,a,m=nil); refute e==a, (m || "Did not expect #{e.inspect} == #{a.inspect}"); end
      def assert_nil(v,m=nil);     assert v.nil?, (m || "Expected nil, got #{v.inspect}"); end
      def refute_nil(v,m=nil);     refute v.nil?, (m || "Expected non-nil"); end
      def assert_kind_of(k,o,m=nil); assert o.kind_of?(k), (m || "Expected #{o.inspect} to be a #{k}"); end
      def assert_match(p,s,m=nil); assert p === s, (m || "Expected #{s.inspect} to match #{p.inspect}"); end
      def refute_match(p,s,m=nil); refute p === s, (m || "Did not expect #{s.inspect} to match #{p.inspect}"); end
      def assert_includes(c,i,m=nil); assert c.include?(i), (m || "Expected #{c.inspect} to include #{i.inspect}"); end
      def refute_includes(c,i,m=nil); refute c.include?(i), (m || "Did not expect #{c.inspect} to include #{i.inspect}"); end

      def assert_raises(*classes)
        yield
        raise Assertion, "Expected one of #{classes.inspect} to be raised, nothing was"
      rescue Assertion
        raise
      rescue => e
        return e if classes.any? { |c| e.is_a?(c) }
        raise Assertion, "Expected one of #{classes.inspect}, got #{e.class}: #{e.message}"
      end

      def skip(msg = "skipped"); raise Skip, msg; end
    end

    module_function

    def run!
      runs = fails = errors = skips = 0
      failures = []
      Test.all_subclasses.each do |klass|
        klass.runnable_methods.each do |m|
          runs += 1
          result = klass.new.run_one(m)
          case result
          when :pass
            print "."
          when Array
            tag, msg, bt = result
            case tag
            when :skip  then skips  += 1; print "S"
            when :fail  then fails  += 1; print "F"; failures << ["FAIL", klass, m, msg, bt]
            when :error then errors += 1; print "E"; failures << ["ERROR", klass, m, msg, bt]
            end
          end
        end
      end
      puts
      failures.each do |tag, klass, m, msg, bt|
        puts "\n#{tag}: #{klass}##{m}"
        puts "  #{msg}"
        bt.first(4).each { |l| puts "    #{l}" } if bt
      end
      puts "\n#{runs} runs, #{fails} failures, #{errors} errors, #{skips} skips"
      exit(fails + errors > 0 ? 1 : 0)
    end
  end

  at_exit { Minitest.run! unless $! }
end

require "typedargs"

REPO_ROOT  = File.expand_path("..", __dir__)
MRBLIB_DIR = File.join(REPO_ROOT, "mrblib")

# Reset alias state between every test. Aliases are global module state, so
# without this they leak between tests and produce confusing failures.
module AliasReset
  def setup
    super
    TypedArgs.reset_aliases!
  end
end

# ============================================================================
# CLAIM 1 — Hash tuple assignment OVERWRITES (per README).
# Was: code merged. Now: code overwrites.
# ============================================================================
class Claim01_HashTupleOverwrites < Minitest::Test
  include AliasReset

  def test_same_field_set_overwrites
    r = TypedArgs.opts("--foo:min,max:=1,2", "--foo:min,max:=3,4")
    assert_equal({"min" => 3, "max" => 4}, r["foo"])
  end

  def test_different_field_sets_overwrite_README_contract
    # The crux: the README says hash assignment overwrites. With a merge
    # implementation, this test fails — old keys would stick around.
    r = TypedArgs.opts("--db:user:=root", "--db:host:=local")
    assert_equal({"host" => "local"}, r["db"],
      "Hash assignment must overwrite per README contract")
  end

  def test_scalar_then_hash_replaces_with_fresh_hash
    r = TypedArgs.opts("--foo=1", "--foo:a:=2")
    assert_equal({"a" => 2}, r["foo"])
  end
end

# ============================================================================
# CLAIM 2 — Aliases CAN target operator forms (per README).
# Was: parse_short rejected the `:` and `+` characters in resolved names.
# Now: short flags are textually rewritten before parsing, so any operator
# form is legal as an alias target.
# ============================================================================
class Claim02_AliasOperatorForms < Minitest::Test
  include AliasReset

  def test_alias_to_hash_operator_form
    TypedArgs.alias("-r", "--range:min,max:=")
    r = TypedArgs.opts("-r5,10")
    assert_equal({"min" => 5, "max" => 10}, r["range"])
  end

  def test_alias_to_array_append_operator_form
    TypedArgs.alias("-i", "--item+=")
    r = TypedArgs.opts("-iapple", "-ibanana")
    assert_equal ["apple", "banana"], r["item"]
  end

  def test_alias_to_array_of_hashes_operator_form
    TypedArgs.alias("-S", "--servers+:name,port:=")
    r = TypedArgs.opts("-Salpha,80", "-Sbeta,443")
    assert_equal(
      [{"name" => "alpha", "port" => 80}, {"name" => "beta", "port" => 443}],
      r["servers"]
    )
  end

  def test_alias_to_dotted_key
    TypedArgs.alias("-D", "--db.user")
    assert_equal({"db.user" => true}, TypedArgs.opts("-D"))
  end

  def test_alias_to_dotted_key_with_value
    TypedArgs.alias("-D", "--db.user")
    assert_equal({"db.user" => "root"}, TypedArgs.opts("-Droot"))
  end
end

# ============================================================================
# CLAIM 3 — Aliases expand BEFORE parsing (per README), via textual rewrite.
# Long flags do NOT consult the alias map.
# ============================================================================
class Claim03_AliasExpansionBeforeParsing < Minitest::Test
  include AliasReset

  def test_short_alias_with_attached_value_inserts_equals
    # Existing getopt-style behavior must be preserved: `-p8080` with
    # alias `--port` → `port=8080`.
    TypedArgs.alias("-p", "--port")
    assert_equal({"port" => 8080}, TypedArgs.opts("-p8080"))
  end

  def test_short_alias_with_operator_target_concatenates
    # When the alias target ends in `=` (any operator form), no extra `=`
    # is inserted — the payload is appended directly.
    TypedArgs.alias("-r", "--range:min,max:=")
    assert_equal({"range" => {"min" => 5, "max" => 10}}, TypedArgs.opts("-r5,10"))
  end

  def test_long_flag_does_NOT_consult_alias_map
    # The README only describes short-flag aliases. The long-flag path
    # must take the typed key at face value.
    TypedArgs.alias("verbose", "--debug")
    r = TypedArgs.opts("--verbose=1")
    assert_equal({"verbose" => 1}, r,
      "Long flags must not be subject to alias rewriting")
  end

  def test_short_bare_alias_resolves_to_boolean_true
    TypedArgs.alias("-v", "--verbose")
    assert_equal({"verbose" => true}, TypedArgs.opts("-v"))
  end
end

# ============================================================================
# CLAIM 4 — Test isolation: TypedArgs.reset_aliases! exists and works.
# Was: no public way to clear the global alias map; tests leaked state.
# Now: a public reset method is provided.
# ============================================================================
class Claim04_AliasResetAPI < Minitest::Test
  def test_reset_aliases_clears_registered_aliases
    TypedArgs.alias("-x", "--something")
    assert_equal({"something" => true}, TypedArgs.opts("-x"))

    TypedArgs.reset_aliases!

    # After reset, -x falls back to bare-short-flag handling: key "x", true.
    assert_equal({"x" => true}, TypedArgs.opts("-x"))
  end

  def test_reset_aliases_is_idempotent
    TypedArgs.reset_aliases!
    TypedArgs.reset_aliases!
    assert_equal({"x" => true}, TypedArgs.opts("-x"))
  end
end

# ============================================================================
# CLAIM 5 — CI workflow gates `gem push` on tag pushes (not every commit).
# Note: my earlier assertion that "Ruby 4.0.1 doesn't exist" was wrong —
# Ruby 4.0.x is shipping. Only the trigger-scoping concern survives.
# ============================================================================
class Claim05_CIWorkflowTagGating < Minitest::Test
  WORKFLOW = File.join(REPO_ROOT, ".github", "workflows", "gem-push.yml")

  def test_workflow_triggers_only_on_tag_pushes
    skip "workflow file not present" unless File.exist?(WORKFLOW)
    yml = File.read(WORKFLOW)
    assert_match(/on:\s*\n\s*push:\s*\n\s*tags:/m, yml,
      "Workflow must trigger on tag pushes, not on every commit to main")
  end

  def test_workflow_does_not_trigger_on_branch_push
    skip "workflow file not present" unless File.exist?(WORKFLOW)
    yml = File.read(WORKFLOW)
    refute_match(/push:\s*\n\s*branches:/m, yml,
      "Branch-push trigger would re-publish the gem on every commit")
  end

  def test_workflow_does_not_trigger_on_pull_request
    skip "workflow file not present" unless File.exist?(WORKFLOW)
    yml = File.read(WORKFLOW)
    refute_match(/^\s*pull_request:/m, yml,
      "PR trigger would attempt gem push from forks")
  end
end

# ============================================================================
# CLAIM 6 — build_config.rb has no stray trailing literal.
# ============================================================================
class Claim06_BuildConfigClean < Minitest::Test
  CONFIG = File.join(REPO_ROOT, "build_config.rb")

  def test_no_stray_top_level_integer_after_end
    skip "build_config.rb not present" unless File.exist?(CONFIG)
    src = File.read(CONFIG)
    refute_match(/end\s*\n\s*\d+\s*\z/, src,
      "Stray trailing literal after the build block has been removed")
  end

  def test_file_ends_with_end_block
    skip "build_config.rb not present" unless File.exist?(CONFIG)
    src = File.read(CONFIG)
    assert_match(/end\s*\z/, src, "File should end at the build block's `end`")
  end
end

# ============================================================================
# CLAIM 7 — convert_number_token passes the lexer source string (not the
# number text) to the error, so the caret would point correctly if the
# branch is reached. The branch remains unreachable in practice given the
# current lexer regex, but the latent code is now correct.
# ============================================================================
class Claim07_ConvertNumberCorrectSource < Minitest::Test
  VALUE_PARSER = File.join(MRBLIB_DIR, "value_parser.rb")

  def test_source_arg_is_lexer_string_not_token_text
    src = File.read(VALUE_PARSER)
    assert_match(
      /raise\s+InvalidNumberError\.new\("Invalid number",\s*@tok\.pos,\s*@lx\.str\)/,
      src,
      "InvalidNumberError must receive @lx.str as the source so the caret points correctly"
    )
    refute_match(
      /raise\s+InvalidNumberError\.new\("Invalid number",\s*@tok\.pos,\s*s\)/,
      src,
      "Old form (passing the number text `s`) should be gone"
    )
  end

  def test_all_lexer_emitted_numbers_round_trip_to_numeric
    [
      "0", "1", "12", "1234567890",
      "-0", "-1", "-12345",
      "0.0", "1.0", "1.", "-1.5",
    ].each do |raw|
      r = TypedArgs.opts("--n=#{raw}")
      assert_kind_of Numeric, r["n"], "#{raw.inspect} should produce a Numeric"
    end
  end
end

# ============================================================================
# CLAIM 8 — Mixed-script keys are rejected uniformly, including via short
# flag aliases. The rewrite-then-dispatch model routes aliased short flags
# through parse_long, which runs ScriptCheck.
# ============================================================================
class Claim08_ScriptCheckUniform < Minitest::Test
  include AliasReset

  def test_long_flag_with_mixed_script_is_rejected
    err = assert_raises(TypedArgs::InvalidCharacterError) do
      TypedArgs.opts("--Latin\u03B1=1")
    end
    assert_match(/mixed-script/, err.message)
  end

  def test_short_alias_to_mixed_script_long_name_is_also_rejected
    TypedArgs.alias("-Z", "--Latin\u03B1")
    err = assert_raises(TypedArgs::InvalidCharacterError) do
      TypedArgs.opts("-Z")
    end
    assert_match(/mixed-script/, err.message,
      "Aliased short flags must be subject to the same script check as long flags")
  end
end

# ============================================================================
# CLAIM 9 — Dead SCRIPT_* constants in utf8.rb have been removed.
# ============================================================================
class Claim09_NoDeadScriptConstants < Minitest::Test
  def test_constants_are_not_defined
    %i[SCRIPT_ASCII SCRIPT_LATIN SCRIPT_GREEK SCRIPT_CYRILLIC SCRIPT_OTHER].each do |c|
      refute TypedArgs::Internal.const_defined?(c, false),
        "TypedArgs::Internal::#{c} should be removed"
    end
  end

  def test_no_references_in_source_tree
    Dir[File.join(MRBLIB_DIR, "*.rb")].each do |f|
      src = File.read(f, encoding: "UTF-8")
      refute_match(/SCRIPT_(ASCII|LATIN|GREEK|CYRILLIC|OTHER)/, src,
        "#{File.basename(f)} should not reference removed SCRIPT_* constants")
    end
  end
end

# ============================================================================
# CLAIM 10 — Lexer raw-value comment now matches behavior.
# ============================================================================
class Claim10_LexerCommentAccurate < Minitest::Test
  LEXER = File.join(MRBLIB_DIR, "lexer.rb")

  def test_comment_says_until_comma
    src = File.read(LEXER)
    refute_match(/# raw value: scan until whitespace or comma/, src,
      "Old misleading comment should be gone")
    assert_match(/# raw value: scan until comma/, src,
      "New comment should describe actual behavior")
  end

  def test_whitespace_inside_value_is_preserved
    r = TypedArgs.opts("--msg=hello world")
    assert_equal "hello world", r["msg"],
      "Whitespace within an argv element is part of the value, not a terminator"
  end
end

# ============================================================================
# CLAIM 11 — README override-rules table holds end-to-end.
# ============================================================================
class Claim11_OverrideRulesTable < Minitest::Test
  include AliasReset

  def test_scalar_then_array_replaces_with_singleton_array
    assert_equal({"foo" => [2]}, TypedArgs.opts("--foo=1", "--foo+=2"))
  end

  def test_two_array_appends_concatenate
    assert_equal({"foo" => [1, 2]}, TypedArgs.opts("--foo+=1", "--foo+=2"))
  end

  def test_two_hashes_overwrite
    r = TypedArgs.opts("--foo:min,max:=1,2", "--foo:min,max:=3,4")
    assert_equal({"foo" => {"min" => 3, "max" => 4}}, r)
  end

  def test_two_array_hash_appends_collect
    r = TypedArgs.opts("--foo+:min,max:=1,2", "--foo+:min,max:=3,4")
    assert_equal(
      {"foo" => [{"min" => 1, "max" => 2}, {"min" => 3, "max" => 4}]},
      r
    )
  end

  def test_scalar_array_hash_scalar_collapses_to_final_scalar
    r = TypedArgs.opts(
      "--foo=1", "--foo+=2", "--foo:name:=alpha", "--foo=bar"
    )
    assert_equal({"foo" => "bar"}, r)
  end
end

# ============================================================================
# Baseline — README headline examples.
# ============================================================================
class Baseline_HeadlineExamples < Minitest::Test
  include AliasReset

  def test_scalar
    assert_equal "fast", TypedArgs.opts("--mode=fast")["mode"]
  end

  def test_typed_scalars
    r = TypedArgs.opts("--n=5", "--f=1.5", "--b=true", "--z=nil")
    assert_equal 5,    r["n"]
    assert_equal 1.5,  r["f"]
    assert_equal true, r["b"]
    assert_nil   r["z"]
    assert r.key?("z"), "nil literal still produces a present key"
  end

  def test_array_append
    r = TypedArgs.opts("--item+=a", "--item+=b")
    assert_equal ["a", "b"], r["item"]
  end

  def test_hash_tuple
    r = TypedArgs.opts("--range:min,max:=5,10")
    assert_equal({"min" => 5, "max" => 10}, r["range"])
  end

  def test_array_of_hashes
    r = TypedArgs.opts(
      "--servers+:name,port:=alpha,80",
      "--servers+:name,port:=beta,443"
    )
    assert_equal 2, r["servers"].size
    assert_equal({"name" => "alpha", "port" => 80},  r["servers"][0])
    assert_equal({"name" => "beta",  "port" => 443}, r["servers"][1])
  end

  def test_dotted_keys_are_flat_strings
    r = TypedArgs.opts("--db.user=root", "--cache.redis.host=localhost")
    assert_equal "root",      r["db.user"]
    assert_equal "localhost", r["cache.redis.host"]
    refute r["db"].is_a?(Hash), "dotted keys must NOT auto-nest"
  end

  def test_short_flag_alias_basic_example
    TypedArgs.alias("-v", "--verbose")
    assert_equal({"verbose" => true}, TypedArgs.opts("-v"))
  end
end
