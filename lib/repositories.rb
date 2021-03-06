require 'redis'
require 'json'

class CompetitorRepository
  def initialize(redis)
    @redis = redis
  end

  def save!(competitor)
    id = competitor[:id]
    competitor = competitor.map { |k, v| [k, v] }
    @redis.hmset("competitors:#{id}", *competitor)

    id.size.times do |i|
      @redis.zadd("competitors:search:#{id[0..i]}", 0, id)
    end
  end

  def attend_comp!(id, comp_id)
    @redis.sadd("competitors:#{id}:comp_ids", comp_id)
    @redis.hset("competitors:#{id}", "competition_count", @redis.scard("competitors:#{id}:comp_ids"))
  end

  def set_single_record!(id, event_id, time)
    @redis.sadd("competitors:#{id}:single:eventIds", event_id)
    @redis.sadd("competitors:#{id}:eventIds", event_id)
    @redis.set("competitors:#{id}:single:#{event_id}", time)
  end

  def set_average_record!(id, event_id, time)
    @redis.sadd("competitors:#{id}:average:eventIds", event_id)
    @redis.sadd("competitors:#{id}:eventIds", event_id)
    @redis.set("competitors:#{id}:average:#{event_id}", time)
  end

  def find(id)
    @redis.hgetall("competitors:#{id}").tap do |c|
      c["competition_count"] = c["competition_count"].to_i
    end
  end

  def search(id)
    ids = @redis.zrange("competitors:search:#{id}", 0, -1)
    ids.map do |id|
      find(id)
    end
  end

  def records(id)
    events = @redis.smembers("competitors:#{id}:eventIds")
    result = {}
    events.map do |event_id|
      result[event_id] = {
        single: nil_or_number(@redis.get("competitors:#{id}:single:#{event_id}")),
        average: nil_or_number(@redis.get("competitors:#{id}:average:#{event_id}"))
      }
    end
    result
  end

  private
    def nil_or_number(n)
      n ? n.to_i : nil
    end
end

class RecordRepository
  def initialize(redis)
    @redis = redis
  end

  def add_single_record!(competitor_id, event_id, result)
    @redis.zadd("records:#{event_id}:single", result, competitor_id)
  end

  def add_average_record!(competitor_id, event_id, result)
    @redis.zadd("records:#{event_id}:average", result, competitor_id)
  end

  def list_single_records(event_id)
    @redis.zrange("records:#{event_id}:single", 0, -1, with_scores: true)
  end

  def list_average_records(event_id)
    @redis.zrange("records:#{event_id}:average", 0, -1, with_scores: true)
  end
end
