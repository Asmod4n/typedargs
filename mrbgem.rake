require_relative 'mrblib/version.rb'

MRuby::Gem::Specification.new('typedargs') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'powerfull command-line argument parser for mruby'
  spec.version = TypedArgs::VERSION

  spec.bins = %w(typedargs_test)
end
