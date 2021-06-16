include("util.jl")
include("stats.jl")

@enum Ident OPEN=1 DATA=2 ERROR=3 EOF=4 QUIT=5 RAW=6 

mutable struct Signal
  s::Threads.Atomic{Bool}
  function Signal(b::Bool)
    return new(Threads.Atomic{Bool}(b))
  end
#  function Signal(b::Threads.Atomic{Bool})
#    return new(b)
end
function (sig::Signal)()
  t = Threads.Atomic{Bool}(true)
  return sig.s[] == t[] ? true : false
end

mutable struct NetflowData #reader -> master
  time::Int64 # rounded to nearest second
  netident::String # enip|webip|webport
  field::Array{Float64}
  dir::Int8
  function NetflowData(t::Int64 = 0,n::String = "",b::Matrix{Float64} = zeros(8,16),d = 0)
    return new(t,n,b,d)
  end
end

mutable struct WorkerMessage
  ident::Ident
  record::NetflowData
end

mutable struct OutputData #worker -> writer
  netident::String
  data::Array{Float64}
  nrecs::Int64
end


mutable struct ReaderMessage
  ident::Ident
  payload::String
end

mutable struct ParserMessage
  ident::Ident
  line::String
  data::NetflowData
end

mutable struct WriterMessage
  ident::Ident
  output::OutputData
end

struct Reader
  chan::Channel
  file::String
  chan_no::Int64
end

function (r::Reader)()
  t = Threads.threadid()
  #println("opening file $(r.file) on thread $t")
  stream = tryopen(r.file)
  #println("$(r.file) is open")
  for line in eachline(stream)
    #println("thread $t: sending $line")
    put!(r.chan,ReaderMessage(DATA,line))
    #println("thread $t: DATA sent")
  end
  close(stream)
  #    #println("thread $t: closed $file. Sending eof")
  put!(r.chan,ReaderMessage(EOF,""))
  #    #println("thread $t: EOF sent")
end

struct Writer
  chan::Channel
  file::String
  chan_no::Int64
end

function (writer::Writer)()
  stream = tryopen(writer.file,"w")
  t = Threads.threadid()
  while true
    #println("writer on thread $t: waiting for OutputData")
    msg = take!(writer.chan)
    #println("thread $t: got $(msg.ident) $(msg.output.netident)")
    if msg.ident == QUIT
      #println("thread $t: got QUIT")
      close(stream)
      #println("thread $t: closed $(writer.file)")
      msg.ident = EOF
      put!(writer.chan,msg)
      break
    else
      #println("thread $t: writing $(msg.output.netident)")
      line = "$(msg.output.netident)"
      for x in msg.output.data; line = line*(" $x"); end
      #println(stream,line)
    end
  end #while
  #println("writer exiting")
end



mutable struct My_Worker
  my_worker_no::Int64
  master::Channel
  writer::Channel
  duration::Int64
  min_recs::Int64
  active::Signal
  ack::Signal
  buckets::Matrix{Float64} # bucket boundaries
#  ref::Matrix{Float64} # expected frac of total
end

mutable struct FlowsetData
  start_time::Int64 
  netident::String
  nrecs::Int64
  hist::Matrix{Int64}
  io_pattern::Int64
  function FlowsetData(t,i, h = ones(Int64,8,16), io = 0) #constructor
    #println("constructing FlowsetData($time,$ident)")
    return new(t,i,h,io) #basic flattening for the counts
  end
end
start = (1,4)
stop = (3,7)
function(w::My_Worker)()
  t = Threads.threadid()
  #println("worker $(w.worker_no) on thread $t")
  w.active = Signal(false)
  #println("worker $(w.worker_no): set active signal to false")
  current_data = 0#FlowsetData(0,"worker $(w.worker_no)",ones(Int64,8,16),0) # initialize current values
  #println("worker $(w.worker_no): entering while loop")
  while true
    #println("worker $(w.worker_no) on thread $t: waiting for message")
    msg = take!(w.master)
    
    if msg.ident == OPEN # open a new flowset
      #println("worker $(w.worker_no) on thread $t: got $(msg.ident). active = $(w.active())")
      if w.active() # an active worker can't be OPENed.  Must expire or get QUIT first
        #println("worker $w.worker_no: got OPEN message while active.  Bailing out")
        exit(0)
      else
        time = msg.record.time
        netident = msg.record.netident
        #println("initializing time = $time, netident = $netident")
        current_data = FlowsetData(time,netident) # inactive, so re-initialize
        w.active = Signal(true)
      end
      continue #while true
    end
    
    if msg.ident == DATA || msg.ident == QUIT
      if !w.active(); continue; end  #ignore 

    elseif msg.ident == QUIT || (msg.ident == DATA && msg.record.time - current_data.start_time > current_data.duration)   # flowset has expired
      if current_data.nrecs >= w.min_recs #OK to write (if not, just ignore)
        line = netident
        chi_sq = Array{Float64}(undef,8)
        for i in 1:8 #convert counts to tail probs for each feature
          bucket_sum = 1 #flattening
          for j in 1:16; bucket_sum += hist[i,j]; end
          for j in 1:16
            expected = bucket_sum/16.0 #= reference distro is uniform. The bucket sizes are non-uniform in general. They
                                         are computed by a separate function making the overall distribution uniform, and 
                                         they are set by the master task when the workers are launched. NOTE: this doesn't
                                         work for iopattern! =#   
            x = hist[i,j] - expected
            chi_sq[i] = stats.gammaq(15,(x*x)/expected)
          end #for j
          line = line*" $chi_sq[i]" # add to the output line
        end #for i
        line = line*"\n"
        output = OutputData(current_data.netident,line,nrecs)
        put!(w.writer,WriterMessage(DATA,output)) # send it to the writer
      end #output written
      w.active = Signal(false)
      if msg.ident == QUIT
        w.ack[] = Signal(true) # acknowledge quit
        break
      end # my_worker will exit

    else # time has not expired.  Update current_data.hist from NetflowData
      dir = msg.record.dir # direction of flow: 1 = input, 2 = output
      for i in start[dir]:stop[dir] # input fields = 1,2,3.  output fields = 4,5,6,7
        j = 0
        while msg.record.field[i] > w.buckets[j] && j < 16 # find the bucket
          j += 1
        end
        current_data.hist[i,j] += 1 #update the bucket count
      end
      current_data.iopattern = ((current_data.iopattern << 1) | (dir-1)) & 15 #update io pattern by one bit (dir-1) after left shift 1 
      current_data.hist[8,current_data.iopattern] += 1 
      current_data.nrecs += 1
    end # msg.ident == DATA
  end #while true
end #function
  
    

    
    
      
        
        






