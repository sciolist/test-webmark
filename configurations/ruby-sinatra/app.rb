require 'sinatra'
require 'pg'
require 'connection_pool'

set :server, 'puma'
set :logging, false
set :port, 3000

$pg = ConnectionPool.new(size: 5, timeout: 5) do
    PG.connect
end

def list sql
    items = []
    $pg.with do |conn|
        rs = conn.exec sql
        rs.each do |row|
            items << row
        end
    end
    items
end

get '/helloworld' do
    "Hello, world!"
end

get '/10-fortunes' do
    list("select id, message from fortunes limit 10").to_json
end

get '/all-fortunes' do
    list("select id, message from fortunes").to_json
end

get '/primes' do
    list = []
    (2..10000).each do |t| 
        ok = true
        (2...t).each do |v|
            if t % v == 0
                ok = false
                break
            end
        end
        list << t if ok
    end
    list.join "\n"
end
