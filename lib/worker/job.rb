require "json"
require "active_support"
require "active_support/hash_with_indifferent_access"

module Worker
  class Job

    def initialize(data={})
      @data = data
    end

    def self.queue(name=nil)
      @queue = name if name
      @queue || 'default'
    end

    def self.priority(num=nil)
      @priority = num if num
      @priority || 0
    end

    def queue
      self.class.queue
    end

    def priority
      self.class.priority
    end

    def self.deserialize(string)
      self.new(Hash[*JSON.parse(string).map { |k, v| [k.to_sym, v] }.flatten])
    end

    def before
    end

    def on_success
    end

    def on_failure
    end

    def perform
      sleep 5
      puts "performing"
    end

    def run_at
      Time.now
    end

    def serialize
      JSON.generate(Hash[*instance_variables.map { |attr| [attr.to_s.sub('@', ''), instance_variable_get(attr)] }.flatten])
    end

    def enqueue
      Worker.queue.enqueue(self)
    end

  end
end
