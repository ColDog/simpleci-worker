$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'worker'

$VERBOSE=nil

require 'minitest/autorun'

Worker.db = { adapter: 'mysql2', database: 'worker-test', user: 'root' }
Worker.queue = Worker::Queue.new
Worker.logger = Logger.new(STDOUT)
