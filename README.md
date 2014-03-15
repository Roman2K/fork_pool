# ForkPool

Ruby library for parallelizing tasks in multiple processes.

## Usage

```ruby
require 'fork_pool'

array = Array.new(1_000_000) { rand }

jobs = 20.times.map do
  lambda do |done|
    p $$ => array.sort.size
    done.call
  end
end

on_done = lambda do
  p :done
end

ForkPool.new(jobs, 8, on_done: on_done).wait
```
