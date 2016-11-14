require "sequel"
require "logger"

module Worker

  class Queue
    attr_reader :id
    attr_accessor :jobs_per_worker, :max_job_time, :queue_name, :max_attempts, :logger, :poll_interval, :log_backtrace

    def initialize(opts={})
      @logger = Logger.new(STDOUT)

      db_config = opts[:db_config] || Worker.db
      db_config.merge(logger: logger) if opts[:log_queries]

      @db = Sequel.connect(db_config)

      name = `hostname`.chomp("\n")

      @id = "#{name}.#{Process.pid}.#{rand(0..1000)}-#{opts[:queue_name] || 'all'}"

      @jobs_per_worker = opts[:jobs_per_worker] || 5
      @max_job_time = opts[:max_job_time] || 5 * 60 # in seconds
      @queue_name = opts[:queue_name]
      @max_attempts = opts[:max_attempts] || 20
      @poll_interval = opts[:poll_interval] || 5 # 5 second polling
      @log_backtrace = !!opts[:log_backtrace]

      @db_adapter = db_config[:adapter]

      create_table
    end

    def create_table
      db.create_table? :worker_jobs do
        primary_key :id
        Time     :locked_at,  null: true
        Time     :run_at,     null: true
        String   :locked_by,  null: true
        String   :handler,    null: false, text: true
        String   :last_error, null: true,  text: true
        String   :queue,      null: false, default: 'default'
        String   :job_class,  null: false
        Integer  :attempts,   null: false, default: 0
        Integer  :priority,   null: false, default: 0
      end
    end

    def set_error(job, error)
      db[:worker_jobs]
          .where(id: job[:id])
          .update(last_error: error.backtrace.join("\n"), run_at: Time.now + 10)
    end

    def remove(id)
      db[:worker_jobs].where(id: id).delete
    end

    # cleans locked by jobs that have been dormant for a while
    def clean_locks
      db[:worker_jobs].where('locked_at < ?', Time.now - max_job_time).update(locked_by: nil)
    end

    # locks a set of jobs for this worker
    def dequeue

      if @db_adapter == 'mysql2' || @db_adapter == 'mysql'
        query = db[:worker_jobs]
                    .limit(jobs_per_worker)
                    .where('`run_at` < ?', Time.now)
                    .where('`locked_by` IS NULL')
                    .reverse_order('priority')
      else
        query = db[:worker_jobs]
                    .where(
                        '`run_at` < ? AND `locked_by` IS NULL AND `id` in (SELECT `id` FROM `worker_jobs` ORDER BY `priority` DESC LIMIT ?)',
                        Time.now, jobs_per_worker)
      end

      if queue_name
        query = query.where(queue: queue_name)
      end

      query.update(locked_by: id, locked_at: Time.now)
      db[:worker_jobs].where(locked_by: id)
    end

    def enqueue(job)
      db[:worker_jobs].insert(
          job_class: job.class.name,
          queue: job.queue,
          priority: job.priority,
          handler: job.serialize,
          run_at: job.run_at,
      )
    end

    def unlock_all
      db[:worker_jobs].where(locked_by: id).update(locked_by: nil)
    end

    def db
      @db
    end

    def run(number_to_run=nil)
      begin
        while true

          logger.debug("Polling")

          t1 = Time.now
          failures = 0
          successes = 0

          dequeue.each do |item|

            if number_to_run
              number_to_run -= 1
            end

            logger.info("Performing #{item[:job_class]}.#{item[:id]} attempts=#{item[:attempts]} priority=#{item[:priority]} run_at=#{item[:run_at]}")

            job = nil
            begin
              job = eval(item[:job_class]).deserialize(item[:handler])

              Timeout::timeout(max_job_time) do
                job.before
                job.perform
                job.on_success
              end

              remove(item[:id])

              successes += 1
              logger.info("Successful #{item[:job_class]}.#{item[:id]}")

            rescue Exception => e

              job.on_failure if job

              if item[:attempts] + 1 > max_attempts
                remove(item[:id])
              else
                set_error(item, e)
              end

              failures += 1
              logger.info("Failed #{item[:job_class]}.#{item[:id]} err: #{e.class.name} #{e.message}")
              if log_backtrace
                puts e.backtrace
              end

            end
          end

          t2 = Time.now

          if failures + successes > 0
            logger.info("Performed #{failures + successes} jobs in #{t2 - t1} seconds")
          end

          return if number_to_run && number_to_run <= 0
          sleep(poll_interval)
        end
      rescue StandardError => e
        logger.warn("Exiting due to #{e}")
        return
      ensure
        logger.info("Unlocking")
        unlock_all
      end

    end

  end
end
