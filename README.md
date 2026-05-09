# TypedArgs

Structured CLI arguments for mruby and CRuby. Lets you pass arrays, hashes, and arrays of records on the command line without quoting JSON or writing a config file.

```
--mode=fast
--item+=apple --item+=banana
--range:min,max:=5,10
--servers+:name,port:=alpha,80
--servers+:name,port:=beta,443
```

becomes

```ruby
{
  "mode"    => "fast",
  "item"    => ["apple", "banana"],
  "range"   => {"min" => 5, "max" => 10},
  "servers" => [
    {"name" => "alpha", "port" => 80},
    {"name" => "beta",  "port" => 443}
  ]
}
```

It's a small, dependency-free parser that runs anywhere mruby runs (embedded, BusyBox, Alpine, sandboxed VMs) and on CRuby ≥ 2.5.

## When you'd want this

You have a CLI that takes input that's genuinely structured — a list of servers, a set of feature toggles, a hash of coordinates — and the alternatives don't fit:

- JSON on argv means escaping `'{"servers":[{"name":"alpha"}]}'` past the shell.
- Repeating a flag with an ad-hoc convention (`--server alpha:80 --server beta:443`) means inventing a mini-syntax per tool.
- A config file is heavy when you only have three values to pass.

If your CLI takes scalars and the occasional list, a normal option parser is probably a better fit. TypedArgs earns its place when structure is the point.

## The four operators

| Form | Meaning |
|---|---|
| `--key=value` | scalar |
| `--key+=value` | append to array |
| `--key:f1,f2:=v1,v2` | hash with named fields |
| `--key+:f1,f2:=v1,v2` | append a hash to an array |

Scalar values are auto-typed: integers, floats, `true`, `false`, `nil`, and otherwise strings. Tuple arity is enforced — declaring two fields means you must supply two values.

## Usage

```ruby
require "typedargs"

args = TypedArgs.opts("--mode=fast", "--debug=true")
args["mode"]   # => "fast"
args["debug"]  # => true
```

Calling `TypedArgs.opts` with no arguments reads from `ARGV`. In mruby you provide `ARGV` yourself; see `tools/typedargs_test/test.c`.

## Keys

Keys are letters, digits, underscore, dash, and dot. They can't start with a digit or dash. Dotted keys (`--db.host=localhost`) are stored as **flat strings**, not nested hashes — `args["db.host"]`, not `args["db"]["host"]`. Auto-nesting opens ambiguities the grammar avoids.

## Short-flag aliases

```ruby
TypedArgs.alias("-v", "--verbose")
TypedArgs.opts("-v")        # => {"verbose" => true}
TypedArgs.opts("-vfoo")     # => {"verbose" => "foo"}
```

The alias target can be any long-flag form, including operators:

```ruby
TypedArgs.alias("-r", "--range:min,max:=")
TypedArgs.opts("-r5,10")    # => {"range" => {"min" => 5, "max" => 10}}

TypedArgs.alias("-S", "--servers+:name,port:=")
TypedArgs.opts("-Salpha,80", "-Sbeta,443")
# => {"servers" => [{"name"=>"alpha","port"=>80}, {"name"=>"beta","port"=>443}]}
```

Aliases are textual rewrites performed before parsing. `TypedArgs.reset_aliases!` clears the alias map (useful in tests).

## Override rules

Flags apply in argv order. Later flags overwrite earlier ones unless they're accumulating.

| Sequence | Result |
|---|---|
| `--foo=1` then `--foo+=2` | `[2]` |
| `--foo+=1` then `--foo+=2` | `[1, 2]` |
| `--foo:a,b:=1,2` then `--foo:a,b:=3,4` | `{"a"=>3, "b"=>4}` |
| `--foo+:a,b:=1,2` then `--foo+:a,b:=3,4` | `[{"a"=>1,"b"=>2}, {"a"=>3,"b"=>4}]` |
| `--foo=1`, `--foo+=2`, `--foo:n:=x`, `--foo=bar` | `"bar"` |

The operator on each flag determines the shape of the value at that key.

## Errors

Invalid input raises a `TypedArgs::SyntaxError` subclass with a caret pointing at the offending byte:

```
--range:min,max:=5
                 ^
Syntax error: Arity mismatch: expected 2, got 1
```

The exception classes are `InvalidCharacterError`, `InvalidKeyStartError`, `UnterminatedStringError`, `ArityMismatchError`, `UnexpectedTokenError`, `InvalidSuffixPositionError`, `InvalidFieldListError`, and `InvalidNumberError`.

## Caveats

The shell still owns word-splitting and metacharacter handling — `--secret=p$ssw0rd` will need quoting in bash regardless of what TypedArgs does after argv arrives. Strictness around scalars (e.g. `12.34.56` raises rather than parsing as a string) is intentional but stricter than most option parsers.

## Installation

For CRuby:

```
gem install typedargs
```

For mruby, add to your `build_config.rb`:

```ruby
conf.gem mgem: 'typedargs'
```

## License

Apache-2.0.