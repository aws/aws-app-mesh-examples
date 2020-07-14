#################################################################################
####                           Massimo Re Ferre'                             ####
####                             www.it20.info                               ####
####                    Yelb, a simple web application                       ####
################################################################################# 
  
#################################################################################
####   yelb-appserver.rb is the app (ruby based) component of the Yelb app   ####
####          Yelb connects to a backend database for persistency            ####
#################################################################################

require 'sinatra'
require 'aws-sdk-dynamodb' 
require_relative 'modules/pageviews'
require_relative 'modules/getvotes'
require_relative 'modules/restaurant'
require_relative 'modules/hostname'
require_relative 'modules/getstats'
require_relative 'modules/restaurantsdbupdate'
require_relative 'modules/restaurantsdbread'

# the disabled protection is required when running in production behind an nginx reverse proxy
# without this option, the angular application will spit a `forbidden` error message
disable :protection

# the system variable RACK_ENV controls which environment you are enabling
# if you choose 'custom' with RACK_ENV, all systems variables in the section need to be set before launching the yelb-appserver application
# the DDB/Region variables in test/development are there for convenience (there is no logic to avoid exceptions when reading these variables) 
# there is no expectations to be able to use DDB for test/dev 
 
configure :production do
  set :redishost, "redis-server"
  set :port, 4567
  set :yelbdbhost => "yelb-db"
  set :yelbdbport => 5432
  set :yelbddbrestaurants => ENV['YELB_DDB_RESTAURANTS']
  set :yelbddbcache => ENV['YELB_DDB_CACHE']
  set :awsregion => ENV['AWS_REGION']
end
configure :test do
  set :redishost, "redis-server"
  set :port, 4567
  set :yelbdbhost => "yelb-db"
  set :yelbdbport => 5432
  set :yelbddbrestaurants => ENV['YELB_DDB_RESTAURANTS']
  set :yelbddbcache => ENV['YELB_DDB_CACHE']
  set :awsregion => ENV['AWS_REGION']
end
configure :development do
  set :redishost, "localhost"
  set :port, 4567
  set :yelbdbhost => "localhost"
  set :yelbdbport => 5432
  set :yelbddbrestaurants => ENV['YELB_DDB_RESTAURANTS']
  set :yelbddbcache => ENV['YELB_DDB_CACHE']
  set :awsregion => ENV['AWS_REGION']
end
configure :custom do
  set :redishost, ENV['REDIS_SERVER_ENDPOINT']
  set :port, 4567
  set :yelbdbhost => ENV['YELB_DB_SERVER_ENDPOINT']
  set :yelbdbport => 5432
  set :yelbddbrestaurants => ENV['YELB_DDB_RESTAURANTS']
  set :yelbddbcache => ENV['YELB_DDB_CACHE']
  set :awsregion => ENV['AWS_REGION']
  
end

options "*" do
  response.headers["Allow"] = "HEAD,GET,PUT,DELETE,OPTIONS"

  # Needed for AngularJS
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"

  halt HTTP_STATUS_OK
end

$yelbdbhost = settings.yelbdbhost
$redishost = settings.redishost
# the yelbddbcache, yelbdbrestaurants and the awsregion variables are only intended to use in the serverless scenario (DDB)
if (settings.yelbddbcache != nil) then $yelbddbcache = settings.yelbddbcache end 
if (settings.yelbddbrestaurants != nil) then $yelbddbrestaurants = settings.yelbddbrestaurants end 
if (settings.awsregion != nil) then $awsregion = settings.awsregion end 

get '/api/pageviews' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
	  content_type 'application/json'
    @pageviews = pageviews()
end #get /api/pageviews

get '/api/hostname' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
    content_type 'application/json'
    @hostname = hostname()
end #get /api/hostname

get '/api/getstats' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
    content_type 'application/json'
    @stats = getstats()
end #get /api/getstats

get '/api/getvotes' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
    content_type 'application/json'
    @votes = getvotes()
end #get /api/getvotes 

get '/api/ihop' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
    @ihop = restaurantsupdate("ihop")
end #get /api/ihop 

get '/api/chipotle' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS' 
    @chipotle = restaurantsupdate("chipotle")
end #get /api/chipotle 

get '/api/outback' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS'
    @outback = restaurantsupdate("outback")
end #get /api/outback 

get '/api/bucadibeppo' do
    headers 'Access-Control-Allow-Origin' => '*'
    headers 'Access-Control-Allow-Headers' => 'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With'
    headers 'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS' 
    @bucadibeppo = restaurantsupdate("bucadibeppo")
end #get /api/bucadibeppo 
