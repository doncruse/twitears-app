require "sinatra"
require "oauth"
require "oauth/consumer"
require 'grackle'

enable :sessions

require 'lib/logic'
include Ear

  # TODO:  In order to go about 5000 for the popularity limit, I need to
  #        add paging (cursor) for the follower_ids

  # TODO:  To speed this up, I should investigate ways to retrieve more 
  #        than one user's profile information at a time

POPULARITY_LIMIT = 5000
DEFAULT_TTL = 72000

configure do
  require 'memcached'
  CACHE = Memcached.new
end

  # If you've logged in, initalize your data
  ####################

before do
  session[:oauth] ||= {}  
  
  consumer_key = ENV["consumer_key"]
  consumer_secret = ENV["consumer_secret"]

  @consumer ||= OAuth::Consumer.new(consumer_key, consumer_secret, :site => "http://twitter.com")
  
  if !session[:oauth][:request_token].nil? && !session[:oauth][:request_token_secret].nil?
    @request_token = OAuth::RequestToken.new(@consumer, session[:oauth][:request_token], session[:oauth][:request_token_secret])
  end
  
  if !session[:oauth][:access_token].nil? && !session[:oauth][:access_token_secret].nil?
    @access_token = OAuth::AccessToken.new(@consumer, session[:oauth][:access_token], session[:oauth][:access_token_secret])
  end
  
  if @access_token
    @client = Grackle::Client.new(:auth => {
      :type => :oauth,
      :consumer_key => consumer_key,
      :consumer_secret => consumer_secret,
      :token => @access_token.token, 
      :token_secret => @access_token.secret
    })    
  end
end

  # Some of the language used on the results page
  ####################

helpers do
  def following_me_status(following)
    if following
      "<div class='following_me_status' id='follows_yes'>This person follows you.</div>"
    else
      "<div class='following_me_status' id='follows_no'>This person does <strong>not</strong> follow you.</div>"
    end
  end

  def results_cloud_intro(joined_size, following)
    if following and joined_size == 0
      "But you do not have any other mutual followers"
    elsif following and joined_size == 1
      "And you have <span class='cloud_hi'>1 mutual follower</span>"
    elsif following
      "And you have <span class='cloud_hi'>#{joined_size} mutual followers</span>"
    elsif joined_size == 0
      "And you do not have any mutual followers"
    elsif joined_size == 1
      "But you do have <span class='cloud_hi'>1 mutual follower</span>"
    else
      "But you do have <span class='cloud_hi'>#{joined_size} mutual followers</span>"
    end
  end
end

  # The URL map for Sinatra is below
  ##########################

get '/' do
  if @access_token
    load_user_info
    erb :home
  else
    erb :start
  end
end

post '/user' do
  if params[:username].blank?
    @access_token = nil
    erb :start
  else
    user_obj = lookup_user_on_twitter(params[:username].downcase)
    if too_popular(user_obj)  
      @popular_user = params[:username] || "You"
      erb :selfpopularity
      redirect '/'
    end
  end
end

get '/show' do
  load_user_info
  @otheruser = params[:otheruser] || ""

  if (@otheruser.downcase == @user_name.downcase)
    @error = "That's you!  It takes two to have a conversation."
    redirect '/'
  end

  other_user_obj = lookup_user_on_twitter(@otheruser)
  if other_user_obj.nil?
    @error = "Couldn't find that user."
    redirect '/'
  end

    # check to make sure other user is not too cool for school
  if too_popular(other_user_obj)
    erb :popularity
  else

  my_follows = get_follower_info(@user_name)
  other_follows = get_follower_info(@otheruser)

  if (my_follows == false) or (my_follows.empty?)
    @error = "That username does not seem to have any followers."
    redirect '/'
  end

  if (other_follows == false) or (other_follows.empty?)
    @error = "Twitter choked on that username.  Please try again."
    redirect '/'
  end

  joined_ids = mutual_follower_ids(my_follows, other_follows)
  @joined = populate_mutual_followers(joined_ids)

  @following = do_they_follow_you(@otheruser, @user_id)

  erb :results
  end
end

post '/show' do
  redirect '/' if params[:otheruser].empty?
  redirect "/show?otheruser=#{params[:otheruser]}"
end

get '/about' do
  erb :about
end

  ## These URLs implement Oauth login for Twitter
  ###########################

get "/request" do
  @request_token = @consumer.get_request_token(:oauth_callback => "http://#{request.host}/auth")
  session[:oauth][:request_token] = @request_token.token
  session[:oauth][:request_token_secret] = @request_token.secret
  redirect @request_token.authorize_url
end

get "/auth" do
  @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier]
  session[:oauth][:access_token] = @access_token.token
  session[:oauth][:access_token_secret] = @access_token.secret
  redirect "/"
end

get "/logout" do
  response.delete_cookie("user_info")
  @access_token = nil
  session[:oauth] = {}
  erb :start
end