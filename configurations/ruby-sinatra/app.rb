require 'sinatra/base'
require 'pg'
require 'connection_pool'

class App < Sinatra::Base
    set :logging, false

    $pg = ConnectionPool.new(size: 100, timeout: 5) do
        PG.connect 'postgresql://postgres:webmark@webmarkdb:5432/postgres'
    end

    get '/helloworld' do
        "Hello, world!"
    end

    get '/10-fortunes' do
        $pg.with do |conn|
            conn.exec("select id, message from fortunes limit 10").to_a.to_json
        end
    end

    get '/all-fortunes' do
        $pg.with do |conn|
            conn.exec("select id, message from fortunes").to_a.to_json
        end
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
end
