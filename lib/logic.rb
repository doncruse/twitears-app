# require 'twitter'

module Ear

  ## The cookie store
  ####################
  
  def load_user_info
    unless @client and (current_user = @client.account.verify_credentials?)
      redirect '/'
    end
    @user_name = current_user.screen_name
    @user_id = current_user.id
    @name = current_user.name
    @icon = current_user.profile_image_url
    @no = current_user.followers_count
  end

  def too_popular(user_obj)
    user_obj.followers_count.to_i > POPULARITY_LIMIT
  end

  def set_user_info(user_obj)
    unless user_obj.nil? or user_obj.screen_name.blank?
      whole = [user_obj.screen_name,
              user_obj.id,
              user_obj.name,
              user_obj.profile_image_url,
              user_obj.followers_count].join("|")
      future = (Time.now + 3000) #.strftime("%a, %d-%b-%Y %H:%M:%S GMT")
      response.set_cookie("user_info", { :value => whole, :expires =>  future, :domain => "twitears.heroku.com" } )
    end
  end

  def set_session_user_info(user_obj)
    unless user_obj.nil? or user_obj.screen_name.blank?
      whole = [user_obj.screen_name,
              user_obj.id,
              user_obj.name,
              user_obj.profile_image_url,
              user_obj.followers_count].join("|")
      response.set_cookie("user_info", whole)
    end
  end

  
  def reset_follower_count(number)
    old = request.cookies["user_info"]
    parts = old.split("|")
    parts[4] = number
    whole = parts.join("|")
    future = (Time.now + 30000) #.strftime("%a, %d-%b-%Y %H:%M:%S GMT")
    response.set_cookie("user_info", { :value => whole, :expires => future, :domain => "twitears.com" } )
    @no = number
  end

  ## Simple Twitter interactions
  ####################

  def lookup_user_on_twitter(username)
    begin
      result = Sinatra::Cache.cache("#{username}-object") do
        @client.users.show? :screen_name => username
      end
      result
    rescue
      return nil
    end
  end
  
  
  def get_follower_info(username)
    begin
      #result = Sinatra::Cache.cache("#{username}-follower-ids") do
        @client.followers.ids? :screen_name => username
      #end
      #result
    rescue
      false
    end
  end

  def calculate_page_count(follower_count)
    begin
      (follower_count / 100).to_i + 1
    rescue
      1
    end
  end

  # pagination has been replaced with cursors
  def load_follower_objects(username, page_count)
    follower_set = {}
    (1..page_count).each do |x|
      one_pass = @client.followers? :screen_name => username # :page => x)
      one_pass.each do |x|
        # next unless x.is_a?(Mash)
        follower_set[x.id] = {:name => x.name, :icon => x.profile_image_url, :screen_name => x.screen_name }
      end
    end
    follower_set
  end

  def retrieve_follower_objects(username)
    # get from cache OR retrieve
  end
  
  # Calculations
  ##############
  
  def mutual_followers(my_follows, other_follows, follower_set)
    joined_ids = other_follows & my_follows
    joined_followers = []
    i = 0
    joined_ids.each do |x|
      joined_followers << follower_set[x]
    end
    joined_followers
  end

  def do_they_follow_you(otheruser, your_id)
    begin
      other_following = get_follower_info(otheruser)
      return true if other_following.include?(your_id)
      return false
    rescue
      return false
    end
  end

end

