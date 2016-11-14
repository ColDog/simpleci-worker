require "worker/version"
require "worker/queue"
require "worker/job"
require "logger"

module Worker
  class << self
    attr_accessor :queue, :logger, :db
  end
end
