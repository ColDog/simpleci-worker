require 'test_helper'

class TestJob < Worker::Job
  attr_accessor :test, :foobar

  def self.runs
    @runs
  end

  def self.runs=(val)
    @runs = val
  end

  def initialize(data={})
    @data = data
    @test = data[:test]
    @foobar = data[:foobar]
    @sleep = data[:sleep]
  end

  def perform
    sleep(@sleep) if @sleep
    self.class.runs += 1
  end

end

class WorkerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Worker::VERSION
  end

  def test_it_can_serialize
    job = TestJob.new(test: 'test', foobar: 'baz')
    str = job.serialize

    assert str.is_a?(String)

    job2 = TestJob.deserialize(str)
    assert job2.test, job.test
  end

  def test_it_can_perform
    TestJob.runs = 0
    job = TestJob.new(test: 'test', foobar: 'baz')
    job.enqueue

    Worker.queue.run(1)

    assert TestJob.runs == 1
  end

  def test_it_will_timeout
    TestJob.runs = 0
    job = TestJob.new(test: 'test', foobar: 'baz', sleep: 3)
    job.enqueue

    Worker.queue.max_job_time = 1
    Worker.queue.run(1)

    assert TestJob.runs == 0
  end

end
