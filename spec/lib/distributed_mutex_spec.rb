# frozen_string_literal: true

RSpec.describe DistributedMutex do
  let(:key) { "test_mutex_key" }

  after do
    Discourse.redis.del(key)
  end

  it "allows only one mutex object to have the lock at a time" do
    mutexes = (1..10).map do
      DistributedMutex.new(key, redis: DiscourseRedis.new)
    end

    x = 0
    mutexes.map do |m|
      Thread.new do
        m.synchronize do
          y = x
          sleep 0.001
          x = y + 1
        end
      end
    end.map(&:join)

    expect(x).to eq(10)
  end

  it "handles auto cleanup correctly" do
    m = DistributedMutex.new(key)

    Discourse.redis.setnx key, Time.now.to_i - 1

    start = Time.now
    m.synchronize do
      "nop"
    end

    # no longer than a second
    expect(Time.now).to be <= start + 1
  end

  it "allows the validity of the lock to be configured" do
    mutex = DistributedMutex.new(key, validity: 2)

    mutex.synchronize do
      expect(Discourse.redis.ttl(key)).to be <= 3
      expect(Discourse.redis.get(key).to_i).to be_within(1.second).of(Time.now.to_i + 2)
    end

    mutex = DistributedMutex.new(key)

    mutex.synchronize do
      expect(Discourse.redis.ttl(key)).to be <= DistributedMutex::DEFAULT_VALIDITY + 1
      expect(Discourse.redis.get(key).to_i).to be_within(1.second).of(Time.now.to_i + DistributedMutex::DEFAULT_VALIDITY)
    end
  end

  it "maintains mutex semantics" do
    m = DistributedMutex.new(key)

    expect {
      m.synchronize do
        m.synchronize {}
      end
    }.to raise_error(ThreadError)
  end

  context "readonly redis" do
    before do
      Discourse.redis.slaveof "127.0.0.1", "65534"
    end

    after do
      Discourse.redis.slaveof "no", "one"
    end

    it "works even if redis is in readonly" do
      m = DistributedMutex.new(key)
      start = Time.now
      done = false

      expect {
        m.synchronize do
          done = true
        end
      }.to raise_error(Discourse::ReadOnly)

      expect(done).to eq(false)
      expect(Time.now).to be <= start + 1
    end
  end

  context "executions" do
    it "should not allow critical sections to overlap" do
      connections = 3.times.map { DiscourseRedis.new }

      scenario =
        Concurrency::Scenario.new do |execution|
          locked = false

          Discourse.redis.del('mutex_key')

          connections.each do |connection|
            connection.unwatch
          end

          3.times do |i|
            execution.spawn do
              begin
                redis =
                  Concurrency::RedisWrapper.new(
                    connections[i],
                    execution
                  )

                2.times do
                  DistributedMutex.synchronize('mutex_key', redis: redis) do
                    raise "already locked #{execution.path}" if locked
                    locked = true

                    execution.yield

                    raise "already unlocked #{execution.path}" unless locked
                    locked = false
                  end
                end
              rescue Redis::ConnectionError
              end
            end
          end
        end

      scenario.run(runs: 10)
    end
  end
end
