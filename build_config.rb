MRuby::Build.new do |conf|
  toolchain :gcc
  enable_debug
  conf.enable_debug
  #conf.enable_sanitizer "address,undefined,leak"
  conf.cc.defines << 'MRB_UTF8_STRING'
  conf.cxx.defines << 'MRB_UTF8_STRING'
  conf.enable_test
  conf.enable_bintest
  conf.gem File.expand_path(File.dirname(__FILE__))
end
