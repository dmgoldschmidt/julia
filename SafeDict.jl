@enum Option quit=0 find=1 add=2 complete=3
# mutable struct DictResp
#   found::Bool
#   value::Int64
# end

mutable struct SafeDictRequest
  option::Option
  key::String
  value
  found::Bool
end

function SafeDict(n::Int64  = 0) #default to no buffer
  request = Channel(n)
  nthreads = Threads.nthreads()
  println("starting with $nthreads threads")
  if n < 0
    println(stderr,"SafeDict: n must be >= 0.  Bailing out")
    exit(0)
  end
  @Threads.spawn begin
    dict = Dict{String,Int64}()
    t = Threads.threadid()
    #      println("@spawn has begun on thread $t, task spawned = $(SafeDict.task_spawned)")
    while(true)
      req = take!(request)
      req.found = haskey(dict,req.key)
#      println("\nfound = $(req.found)")
      if req.option == add
#        println("adding $(req.key) => $(req.value)")
        dict[req.key] = req.value
#        println("add complete")
      elseif req.found #option = find
        req.value = dict[req.key]
#        println("found $(req.key)=>$(req.value)")
      else #option = find, key not found
#        println("key $(req.key) not found")
        req.value = nothing
      end #if
      req.option = complete
    end #while
  end #@spawn
  return request
end #function

function add_key(sd::Channel,key::String,value::Int64)
  req = SafeDictRequest(add,key,value,true)
  println("add_key: adding key = $key, value = $value on thread $(Threads.threadid())")
  put!(sd,req)
  
  while req.option != complete;
#    println("req.option = $(req.option)")
    sleep(.1);end
  return req.found
end

function find_key(sd::Channel,key::String)
  req = SafeDictRequest(find,key,0,false)
  put!(sd,req)
  while req.option != complete;sleep(.01);end
  return req.value
end

safe_dict = SafeDict(10)
s = "1,2,3,4,5,6,7,8,9"
chr = split(s,',')
println("begin for loop")
Threads.@threads for i in 1:9
  found = add_key(safe_dict,string(chr[i]),i)
  println("add_key returns $found on thread $(Threads.threadid())")
end
println("all adds completed\n\n")
Threads.@threads for i in 9:-1:1
  n = find_key(safe_dict,string(chr[i]))
  println("chr[$i] => $n on thread $(Threads.threadid())")
end
str = "bad_key"
n = find_key(safe_dict,str)
println("bad_key value: $n")


