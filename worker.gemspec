# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'worker/version'

Gem::Specification.new do |spec|
  spec.name          = "simpleci-worker"
  spec.version       = Worker::VERSION
  spec.authors       = ["Colin Walker"]
  spec.email         = ["colinwalker270@gmail.com"]

  spec.summary       = %q{Database based job execution. Rails independent.}
  spec.homepage      = "https://github.com/simpleci-worker"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_dependency "sequel", "~> 4.40"
  spec.add_dependency "activesupport", ">= 4.0"
end
