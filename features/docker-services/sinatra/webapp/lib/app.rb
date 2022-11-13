require "rubygems"
require "sinatra"
require "json"
require "redis"
require 'uri'
require 'net/http'
require 'logger'

# Webapp that connects to a redisdb instance.
class App < Sinatra::Application

      set :bind, '0.0.0.0' ## bind on all interfaces.

      # Local Consul agent to get Redis database address and port
      uri = URI.parse("http://#{ENV['CONSUL_HTTP_ADDR']}/v1/catalog/service/redis?pretty")

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      body = response.body
      address = JSON.parse(body)[0]['ServiceAddress']
      port = JSON.parse(body)[0]['ServicePort']
      redis = Redis.new(:host => address, :port => port)

      get '/info' do
        "<h1>DockerBook Test Redis-enabled Sinatra app</h1>"
      end

      get '/json' do
        params = redis.get "params"
        params
      end

      post '/json/?' do
        redis.set "params", [params].to_json
      end

end



