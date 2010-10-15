module Ear

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

  ## Simple Twitter interactions
  ####################

  def lookup_user_on_twitter(username)
    # try cached copy
    begin
      result = CACHE.get("#{username}-object}")
    rescue
      result = @client.users.show? :screen_name => username
      if result and result.screen_name
        CACHE.set("#{result.screen_name}",result)
      end
    end
    result
  end
  
  def user_by_id_from_cache(id)
    begin
      result = CACHE.get(id.to_s)
      return result
    rescue
      result = @client.users.show? :id => id
      if result and result.id
        CACHE.set(id.to_s,result)
        return result
      end
    end
    return nil
  end
  
  def get_follower_info(username)
    begin
      @client.followers.ids? :screen_name => username
    rescue
      false
    end
  end

  #  Doing the the join calculations
  ################

  def mutual_follower_ids(my_follows, other_follows)
    other_follows & my_follows
  end

  def populate_mutual_followers(mutual_ids)
    result = []
    mutual_ids.each do |id|
      item = user_by_id_from_cache(id)
      result << item unless item.nil?
    end
    result.sort { |x,y| x.name.downcase <=> y.name.downcase }
  end

  # OPTIMIZE: Replace with twitter's friendships/show? method, but that
  #           returns a nested data structure that is messing up Grackle
  #           because there's not an elegant way to nest OpenStruct, which
  #           is what it converts to by default
  def do_they_follow_you(their_name,your_id)
    @following ||= response = begin
      ids_they_follow = @client.followers.ids? :screen_name => their_name
      ids_they_follow.include?(your_id)
    rescue
      false
    end
  end

end

