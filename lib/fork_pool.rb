class ForkPool
  def initialize(jobs, concurrency=jobs.length, **opts)
    on_start = opts[:on_start] || lambda { }
    on_done  = opts[:on_done] || lambda { }

    @workers      = Array.new(concurrency) { Worker.new(jobs, on_start) }
    @job_indexes  = jobs.length.times
    @on_done      = on_done
    @coordinators = [start_job_feeder, start_done_caller]
  end

  def wait
    @coordinators.each &:join
    @workers.each &:wait
  end

private

  def start_job_feeder
    Thread.new do
      pipes = @workers.map(&:jobs_pipe)
      pipes_ready_for_read(pipes) { |p| p.up.r }.each do |pipe, r|
        r.gets or next pipe.close
        begin
          idx = @job_indexes.next
        rescue StopIteration
          pipe.close
        else
          pipe.down.w.puts idx
        end
      end
    end
  end

  def start_done_caller
    Thread.new do
      pipes = @workers.map(&:done_pipe)
      pipes_ready_for_read(pipes) { |p| p.r }.each do |pipe, r|
        r.gets or next pipe.close
        @on_done.call
      end
    end
  end

  def pipes_ready_for_read(pipes)
    Enumerator.new do |y|
      pipes = pipes.each.with_object({}) do |pipe, map|
        map[yield pipe] = pipe
      end
      loop do
        pipes.delete_if { |r,| r.closed? }
        break if pipes.empty?
        ready = IO.select(pipes.keys)[0]
        ready.each do |r|
          y << [pipes.fetch(r), r]
        end
      end
    end
  end

  class Worker
    def initialize(jobs, on_start)
      pipes = [
        @jobs_pipe = Pipes::Bidirectional.new,
        @done_pipe = Pipes::Upstream.new,
      ]
      @pid = fork do
        on_start.call
        pipes.each &:init_child
        @jobs_pipe.up.w.puts
        while idx = @jobs_pipe.down.r.gets
          done = lambda { @done_pipe.w.puts }
          jobs.fetch(idx.to_i).call(done)
          @jobs_pipe.up.w.puts
        end
        pipes.each &:close
      end
      pipes.each &:init_parent
    end

    attr_reader :jobs_pipe
    attr_reader :done_pipe

    def wait
      Process.wait @pid
    end
  end

  module Pipes
    class Unidirectional
      def initialize
        @r, @w = IO.pipe
      end

      attr_reader :r, :w

      def close
        [@r, @w].each do |io|
          io.close unless io.closed?
        end
      end
    end

    class Upstream < Unidirectional
      def init_parent
        @w.close
      end

      def init_child
        @r.close
      end
    end

    class Downstream < Unidirectional
      def init_parent
        @r.close
      end

      def init_child
        @w.close
      end
    end

    class Bidirectional
      def initialize
        @both = [
          @up = Upstream.new,
          @down = Downstream.new,
        ]
      end

      attr_reader :up, :down

      def init_parent
        @both.each &:init_parent
      end

      def init_child
        @both.each &:init_child
      end

      def close
        @both.each &:close
      end
    end
  end
end
