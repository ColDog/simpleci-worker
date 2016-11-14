require "worker/version"
require "worker/queue"
require "worker/job"
require "logger"

module Worker
  class << self
    attr_accessor :queue, :logger, :db, :env

    def db_config
      db[env]
    end

  end
end

Worker.env = :test
Worker.db = {
    test: {
        adapter: 'sqlite',
    }
}

Worker.queue = Worker::Queue.new
Worker.logger = Logger.new(STDOUT)
