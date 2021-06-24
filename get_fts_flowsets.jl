#!/home/david/julia-1.6.1/bin/julia
import GZip
if !@isdefined(CommandLine_loaded)
  include("CommandLine.jl")
end
# if !@isdefined(sort_loaded)
#   include("sort.jl")
# end
if !@isdefined(util_loaded)
  include("util.jl")
end

include("fts_flowsets.jlh")
using Printf
using DelimitedFiles

function get_buckets(fname::String)
  stream = tryopen(fname)
  buckets = Matrix{Float64}(undef,7,15)
  ref_IOcounts = Vector{Float64}(undef,16)
  for i in 1:8
    line = readline(stream)
    field = map(string,split(line))
#    println("get_buckets line $i has fields: $field")
    if i < 8
      for j in 1:15
        buckets[i,j] = myparse(Float64,field[j])
      end
    else
      for j in 1:16
        ref_IOcounts[j] = myparse(Float64, field[j])
      end #for j in 1:16
    end #if i < 8
  end# for i in 1:8
  return buckets, ref_IOcounts
end


function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}(
    "max_recs" => 0,
    "in_file"=>"netflow.gz",
    "file_dir" => "",
    "out_file"=>"test_writer.txt",
    "dim" => 8,
    "nworkers" => 2,
    "buckets" => "buckets.txt"
  )
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values if they are specified
  println("parameters: $defaults")
  nworkers = defaults["nworkers"]
  file_dir = defaults["file_dir"]
  out_file = defaults["out_file"]
  dim = defaults["dim"]
  max_recs = defaults["max_recs"]
  in_file = file_dir*"/"* defaults["in_file"]

  buckets, ref_IOcounts = get_buckets(defaults["buckets"])
  writer_chan = Channel{WriterMessage}(100) # one writer channel
  stream = tryopen(out_file,"w")
  writer_ack = Ref{Bool}(false)
  Threads.@spawn writer(stream,writer_ack) # launch the writer

  worker_chan = [Channel{WorkerMessage}(100) for i in 1:nworkers] # set up the workers
  worker_data = [WorkerData(i,300,10,buckets,ref_IOcounts) for i in 1:nworkers]
  ack_open = [false for i in 1:nworkers]
  for i in 1:nworkers
    println("launching worker $i")
    Threads.@spawn Worker(worker_data[i],ack_open[i])
  end
  println("workers are launched")
  sleep(5)

  reader_chan = Channel(100)
  stream = tryopen(in_file)
  Threads.@spawn reader(stream,2) #launch the reader skip the first two lines

  for i in 1:nworkers
    println("sending OPEN to worker $i")
    dummy = NetflowData(0,"")
    msg = WorkerMessage(OPEN,dummy)
    println("opening Worker $i")
    put!(Worker_chan[i],msg)
    println("waiting for worker $i active signal")
    while !ack_open[i]; end #wait for signal
    println("worker $i is open")
  end

  while true
    msg = take!(reader_chan)
    if(msg.ident == EOF); break; end

    #parse the record
    data = parse(msg.line)
    if data == nothing; continue; end #line was unparsable
    
    
    
    netident = ("one", "two")

    for t in 1:20
      worker_no = t%2
      netflow = NetflowData(t,netident[worker_no])
      netflow.dir = t < 10 ? 1 : 2
      netflow.field = rand(1:16,8)
      msg = WorkerMessage(DATA,netflow)
      put!(Wchan[worker_no],msg)
    end

    for i in 1:2
      put!(Wchan[i],WorkerMessage(QUIT,NetflowData()))
      while !my_worker[i].ack(); end 
      println("worker $i has acknowledged QUIT")
    end

  end #while true
end



# function writeit()
#   i = 0
#   dummy = [1.0,.123456789]
#   nlines = [0,0]
#   max = [2,3]
#   ntries = 0
#   msg = 0
#   while nlines[1] < max[1] || nlines[2] < max[2]
#     if nlines[i+1] < max[i+1]
#       output = OutputData("line$(nlines[i+1]+1) for $(file[i+1]) on channel $(i+1)",dummy,2)
#       msg = WriterMessage(DATA,output)
#       println("master: sending $(msg.output.netident) to  channel $(i+1)")
#       put!(wchan[i+1],msg)
#       println("sent $(msg.output.netident) to channel $(i+1)")
#       nlines[i+1] = nlines[i+1]+1
#     end #if
#     i = (i+1)%2
#   end #while
#   output = OutputData("",dummy,2)
#   qmsg = [WriterMessage(QUIT,output) for i in 1:2]
#   for i in 1:2
#     println("master: sending QUIT on channel $i")
#     put!(wchan[i],qmsg[i])
#     println("master: QUIT sent on channel $i")
#   end
#   for i in 1:2
#     println("master: waiting for EOF on channel $i")
#     msg = take!(wchan[i])
#     if msg.ident != EOF
#       println(stderr,"comms error in writeit on channel $i.  Bailing out")
#       exit(1)
#     end
#     println("master: got EOF on channel $i") 
#   end
#   println("wrote $nlines")
# end

# function readit()
#   i = done = 0
#   while done != 2
#     if isready(rchan[i+1])
#       println("master: waiting for DATA")
#       msg = take!(rchan[i+1])
#       if msg.ident == EOF
#         done += 1
#         println("master: EOF received.  done = $done")
#       else
#         println("master: $(msg.payload)")
#       end #if EOF
#     else
# #      println("channel $(i+1) not ready")
#       i = (i+1)%2 
#     end #if isready
#   end #while
# end

# execution begins here
if occursin("get_fts_flowsets.jl",PROGRAM_FILE)
  #was cluster_flowsets.jl called by a command?
  println("calling main with ARGS = $ARGS")
  main(ARGS) 
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    main(map(string,split(cmd)))
  end
end 
    
