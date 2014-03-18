# coding: utf-8

Gem::Specification.new do |spec|
  spec.name     = 'fork_pool'
  spec.version  = '0.1.1'
  spec.authors  = ["Roman Le Négrate"]
  spec.email    = ["roman.lenegrate@gmail.com"]
  spec.summary  = "Parallelization through forking"
  spec.homepage = "https://github.com/Roman2K/fork_pool"
  spec.license  = "Unlicense"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^test/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.1'
end
