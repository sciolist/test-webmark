require "raze"
require "db"
require "pg"

CONN = DB.open "postgres://app:app@db/app"

get "/helloworld" do |ctx|
  "Hello, world"
end

get "/10-fortunes" do |ctx|
  list = Array(NamedTuple(id: Int32, message: String)).new
  CONN.query_each("select id, message from fortunes limit 10") do |rs|
    list.push({ id: rs.read(Int32), message: rs.read(String) })
  end
  list.to_json
end

get "/all-fortunes" do |ctx|
  list = Array(NamedTuple(id: Int32, message: String)).new
  CONN.query_each("select id, message from fortunes") do |rs|
    list.push({ id: rs.read(Int32), message: rs.read(String) })
  end
  list.to_json
end

get "/primes" do
    list = [] of Int32
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

puts "Listening on http://127.0.0.1:3000"
Raze.config.logging = false
Raze.config.port = 3000
Raze.config.env = "production"
Raze.config.reuse_port = true
Raze.run
