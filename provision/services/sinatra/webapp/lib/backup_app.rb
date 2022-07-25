require "rubygems"
require "sinatra"
require "json"
require "redis"

class App < Sinatra::Application

      # Webapp that connects to a redisdb instance.
      
      # Docker’s own network stack.
      # Docker containers exposing ports and binding interfaces so that container services are published on the local Docker host’s external 
      # network (e.g., binding port  80 inside a container to a high port on the local host).
      
      # In addition to this capability, Docker has another facet.
      # Docker internal networking.
      # Every Docker container is assigned an IP address, provided through an interface created when we installed Docker. 
      # That interface is called docker0. 
      # ip add show docker0
      # The docker0 interface is a virtual Ethernet bridge that connects our containers and the local host network.
      
      # redis = Redis.new(:host => '172.18.0.2', :port => '6379') 
      redis = Redis.new(:host => 'redisdb', :port => '6379') 

      set :bind, '0.0.0.0'

      get '/info' do
        "<h1>DockerBook Test Redis-enabled Sinatra app</h1>"
      end

      get '/json' do
        params = redis.get "params"
        params.to_json
      end

      post '/json/?' do
        redis.set "params", [params].to_json
        #params.to_json
      end
end



