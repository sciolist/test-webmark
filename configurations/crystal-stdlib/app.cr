require "http/server"
require "db"
require "pg"

CONN = DB.open "postgresql://postgres:webmark@webmarkdb:5432/postgres?max_pool_size=100"
ROUTES = Hash(String, Hash(String, (HTTP::Server::Context -> ))).new
def route(method : String, route : String, &block : (HTTP::Server::Context -> ))
  ROUTES[method] ||= Hash(String, (HTTP::Server::Context -> )).new
  ROUTES[method][route] = block
end

route "GET", "/helloworld" do |ctx|
  ctx.response.print "Hello, world!"
end

route "GET", "/10-fortunes" do |ctx|
  list = Array(NamedTuple(id: Int32, message: String)).new
  CONN.using_connection do |conn|
    conn.query_each("select id, message from fortunes limit 10") do |rs|
      list.push({ id: rs.read(Int32), message: rs.read(String) })
    end
  end
  ctx.response.print list.to_json
end

route "GET", "/all-fortunes" do |ctx|
  list = Array(NamedTuple(id: Int32, message: String)).new
  CONN.using_connection do |conn|
    conn.query_each("select id, message from fortunes") do |rs|
      list.push({ id: rs.read(Int32), message: rs.read(String) })
    end
  end
  ctx.response.print list.to_json
end

route "GET", "/primes" do |ctx|
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
  ctx.response.print list.join("\n")
end

server = HTTP::Server.new do |context|
  handler = ROUTES[context.request.method][context.request.path]
  handler.call(context)
end

server.bind_tcp("0.0.0.0", 3000, true)
server.listen
