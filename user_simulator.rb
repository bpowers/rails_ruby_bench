# Initially based on Discourse's user_simulator script

#require 'gabbler'

# Example options array passed into these functions
#options = {
#  :user_offset => 0,
#  :random_seed => 1234567890,
#  :delay => nil,
#  :iterations => 100,
#  :warmup_iterations => 0,
#  :port_num => 4567,
#  :worker_threads => 5,
#  :out_dir => "/tmp",
#}

# We want our script to generate a consistent output, so we
# monkeypatch Array#sample to use our RNG. That's what Gabbler
# uses. So we use thread-local RNGs, to allow consistent per-thread
# results. Also, ew.  We may want to inline Gabbler's functionality or
# otherwise avoid this problem in the future.
class Array
  def sample
    self[Thread.current["RNG"].rand(size)]
  end
end

def sentence
  @gabbler ||= Gabbler.new.tap do |gabbler|
    story = File.read(File.dirname(__FILE__) + "/alice.txt")
    gabbler.learn(story)
  end

  sentence = ""
  until sentence.length > 800 do
    sentence << @gabbler.sentence
    sentence << "\n"
  end
  sentence
end

ACTIONS = [:read_topic, :post_reply, :post_topic, :get_latest]  # Not active: :save_draft, :delete_reply. See below.

class DiscourseClient
  def initialize(options)
    @cookies = nil
    @csrf = nil
    @prefix = "http://localhost:#{options[:port_num]}"

    @last_topics = Topic.order('id desc').limit(10).pluck(:id)
    @last_posts = Post.order('id desc').limit(10).pluck(:id)
  end

  def get_csrf_token
    resp = RestClient.get "#{@prefix}/session/csrf.json"
    @cookies = resp.cookies
    @csrf = JSON.parse(resp.body)["csrf"]
  end

  def request(method, url, payload = nil)
    args = { :method => method, :url => "#{@prefix}#{url}", :cookies => @cookies, :headers => { "X-CSRF-Token" => @csrf } }
    args[:payload] = payload if payload
    begin
      resp = RestClient::Request.execute args
    rescue RestClient::Found => e  # 302 redirect
      resp = e.response
    end
    @cookies = resp.cookies  # Maintain continuity of cookies
    resp
  end

  # Given the randomized parameters for an action, take that action.
  # See below for randomized parameter generation from the random
  # seed.
  def action_from_args(action_type, text, fp)
    case action_type
    when :read_topic
      # Read Topic
      topic_id = @last_topics[-1]
      request(:get, "/t/#{topic_id}.json?track_visit=true&forceLoad=true")
    when :save_draft
      # Save draft - currently not active, need to fix 403. Wrong topic ID?
      topic_id = @last_topics[-1]
      post_id = @last_posts[-1]  # Not fully correct
      draft_hash = { "reply" => text * 5, "action" => "edit", "title" => "Title of draft reply", "categoryId" => 11, "postId" => post_id, "archetypeId" => "regular", "metaData" => nil, "sequence" => 0 }
      request(:post, "/draft.json", "draft_key" => "topic_#{topic_id}", "data" => draft_hash.to_json)
    when :post_reply
      # Post reply
      request(:post, "/posts", "raw" => text * 5, "unlist_topic" => "false", "category" => "9", "topic_id" => topic_id, "is_warning" => "false", "archetype" => "regular", "typing_during_msecs" => "2900", "composer_open_duration_msecs" => "12114", "featured_link" => "", "nested_post" => "true")
      # TODO: request(:delete, "/draft.json", "draft_key" => "topic_XX", "sequence" => "0")
      # TODO: update @last_posts
    when :post_topic
      # Post new topic
      request(:post, "/posts", "raw" => "", "title" => text, "unlist_topic" => "false", "category" => "", "is_warning" => "false", "archetype" => "regular", "typing_duration_msecs" => "6300", "composer_open_duration_msecs" => "31885", "nested_post" => "true")
      # TODO: request(:delete, "/draft.json", "topic_id" => "topic_XX")
      # TODO: request(:get, "/t/#{topic_id}.json?track_visit=true&forceLoad=true")
      # TODO: update @last_topics
=begin
Started GET "/composer_messages?composer_action=createTopic&_=1483481672874" for ::1 at 2017-01-03 14:39:19 -0800
lProcessing by ComposerMessagesController#index as JSON
  Parameters: {"composer_action"=>"createTopic", "_"=>"1483481672874"}
Completed 200 OK in 27ms (Views: 0.1ms | ActiveRecord: 1.6ms)
Started GET "/similar_topics?title=This%20is%20a%20new%20topic.%20Totally.&raw=And%20this%20is%20the%20body.%20Yup!%20It%27s%20awesome.%0A&_=1483481672875" for ::1 at 2017-01-03 14:39:32 -0800
Processing by SimilarTopicsController#index as JSON
  Parameters: {"title"=>"This is a new topic. Totally.", "raw"=>"And this is the body. Yup! It's awesome.\n", "_"=>"1483481672875"}
Completed 200 OK in 35ms (Views: 0.1ms | ActiveRecord: 16.0ms)
Started POST "/draft.json" for ::1 at 2017-01-03 14:39:34 -0800
Processing by DraftController#update as JSON
  Parameters: {"draft_key"=>"new_topic", "data"=>"{\"reply\":\"And this is the body. Yup! It's awesome.\\n\",\"action\":\"createTopic\",\"title\":\"This is a new topic. Totally.\",\"categoryId\":null,\"postId\":null,\"archetypeId\":\"regular\",\"metaData\":null,\"composerTime\":14745,\"typingTime\":5000}", "sequence"=>"2"}
Completed 200 OK in 14ms (Views: 0.3ms | ActiveRecord: 5.1ms)
Started GET "/similar_topics?title=This%20is%20a%20new%20topic.%20Totally.&raw=And%20this%20is%20the%20body.%20Yup!%20It%27s%20awesome.%20Totally%20awesome.%0A&_=1483481672876" for ::1 at 2017-01-03 14:39:42 -0800
Processing by SimilarTopicsController#index as JSON
  Parameters: {"title"=>"This is a new topic. Totally.", "raw"=>"And this is the body. Yup! It's awesome. Totally awesome.\n", "_"=>"1483481672876"}
Completed 200 OK in 23ms (Views: 0.1ms | ActiveRecord: 8.9ms)
Started POST "/draft.json" for ::1 at 2017-01-03 14:39:42 -0800
Processing by DraftController#update as JSON
  Parameters: {"draft_key"=>"new_topic", "data"=>"{\"reply\":\"And this is the body. Yup! It's awesome. Totally awesome.\\n\",\"action\":\"createTopic\",\"title\":\"This is a new topic. Totally.\",\"categoryId\":null,\"postId\":null,\"archetypeId\":\"regular\",\"metaData\":null,\"composerTime\":23385,\"typingTime\":6300}", "sequence"=>"2"}
Completed 200 OK in 8ms (Views: 0.2ms | ActiveRecord: 1.4ms)
=end
    when :delete_reply
      # Delete reply, currently not active, need to get correct Post ID
      request(:delete, "/posts/#{post_num}")
      request(:get, "/posts/#{post_num - 1}")
      # TODO: update @last_posts
    when :get_latest
      # Get latest
      request(:get, "/latest.json?order=default")
    else
      raise "Something is wrong! Illegal value: #{action_type}"
    end
  end
end

def log(s)
  print "[#{Process.pid}]: #{s}\n"
end

def worker_thread(options)
  rng = Thread.current["RNG"]
  # Randomize which action(s) to take, and randomize topic and reply
  # data, plus a random number for offsets.  Since we don't randomize
  # again after this, the random seed's effect is limited to this line
  # and before.  Each array starts with an action number starting with
  # action 1, up to the number of iterations plus the number of warmup
  # iterations. Then it has an action type, a sentence (not always used)
  # and a floating-point argument (not always used.)
  actions = (1..(options[:iterations] + options[:warmup_iterations])).map { |i| [ ACTIONS.sample, sentence, rng.rand() ] }

  user = User.offset(options[:user_offset]).first
  unless user
    print "No user at offset #{options[:user_offset].inspect}! Exiting.\n"
    exit -1
  end

  log "Simulating activity for user id #{user.id}: #{user.name}"

  log "Getting Rails CSRF token..."
  client = DiscourseClient.new(options)
  client.get_csrf_token

  log "Logging in as #{user.username.inspect}..."
  client.request :post, "/session", { "login" => user.username, "password" => "password" }
  client.request :post, "/login", { "login" => user.username, "password" => "password", "redirect" => "http://localhost:#{options[:port_num]}/" }

  # Do these iterations but don't time them.
  options[:warmup_iterations].times do |i|
    client.action_from_args *actions[i]
  end

  t0 = Time.now
  options[:iterations].times do |i|
    client.action_from_args *actions[i + options[:warmup_iterations]]
  end
  iteration_time = Time.now - t0
end

def run_trials(options)
  output_times = []

  threads = (1..options[:worker_threads]).map do |offset|
    Thread.new do
      Thread.current["RNG"] = Random.new(options[:random_seed] + offset * 100)
      begin
        output_times << worker_thread(options.merge(:user_offset => offset))
      rescue Exception => e
        STDERR.print "Exception in worker thread: #{e.message}\n#{e.backtrace.join("\n")}\n"
        raise e # Re-raise the exception
      end
    end
  end

  threads.each { |t| t.join }
  output_times
end
