@enum Option start=0 find=1 add=2 complete=3
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
      println("\nfound = $(req.found)")
      if req.option == add
        println("adding $(req.key) => $(req.value)")
        dict[req.key] = req.value
        println("add complete")
      elseif req.found #option = find
        req.value = dict[req.key]
        println("found $(req.key)=>$(req.value)")
      else #option = find, key not found
        println("key $(req.key) not found")
        req.value = nothing
      end #if
      req.option = complete
    end #while
  end #@spawn
  return request
end #function

function add_key(sd::Channel,key::String,value::Int64)
  req = SafeDictRequest(add,key,value,true)
  println("add_key: adding key = $key, value = $value")
  put!(sd,req)
  
  while req.option != complete;
#    println("req.option = $(req.option)")
    sleep(.1);end
  return req.found
end

function find_key(sd::Channel,key::String)
  req = SafeDictRequest(find,key,0,false)
  put!(sd,req)
  while req.option != complete;sleep(.1);end
  return req.value
end

safe_dict = SafeDict()
s = "1,2,3,4,5,6,7,8,9"
chr = split(s,',')
println("begin for loop")
for i in 1:9
  #add_req = DictRequest(add,chr[i],i)
 # put!(safe_dict,add_req)
  found = add_key(safe_dict,string(chr[i]),i)
  println("add_key returns $found")
  # while add_req.option != complete
  #   sleep(1) #println("add_req.option = $(add_req.option)")
  # end
  
  # # ntries = 0
  # # while add_req.option != comple
  # #   println("add_req.option != complete")
  # #   ntries += 1
  # #   if ntries > 10; exit; end
  # #   continue
  # # end
#   find_req = DictRequest(find,chr[i],0)
#   put!(safe_dict,find_req)
#   while(find_req.option != complete)
#     sleep(1)
# #    println("find_req.option =  $(find_req.option)")
#   end
  n = find_key(safe_dict,string(chr[i]))
  println("chr[$i] => $n")
end
str = "bad_key"
n = find_key(safe_dict,str)
println("bad_key value: $n")


