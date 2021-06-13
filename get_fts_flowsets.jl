include("util.jl")
include("stats.jl")

mutable struct OutputData #worker -> writer
  netident::String
  data::Array{Float64}
  nrecs::Int64
end

@enum Ident OPEN=1 DATA=2 ERROR=3 EOF=4 QUIT=5 RAW=6 ACK=7 

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
  stream = tryopen(r.file)
  t = Threads.threadid()
  for line in eachline(stream)
    #      println("thread $t: sending $line")
    put!(r.chan,ReaderMessage(DATA,line)) 
    #      println("thread $t: DATA sent")
  end
  close(stream)
  #    println("thread $t: closed $file. Sending eof")
  put!(r.chan,ReaderMessage(EOF,""))
  #    println("thread $t: EOF sent")
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
    println("thread $t: about to get OutputData from $(writer.chan)")
    msg = take!(writer.chan)
    println("thread $t: got $(msg.ident) $(msg.output.netident)")
    if msg.ident == QUIT
      println("thread $t: got QUIT")
      close(stream)
      println("thread $t: closed $(writer.file)")
      msg.ident = EOF
      put!(writer.chan,msg)
      break
    else
      println("thread $t: writing $(msg.output.netident)")
      line = "$(msg.output.netident)"
      for x in msg.output.data; line = line*(" $x"); end
      println(stream,line)
    end
  end #while
  println("writer exiting")
end

mutable struct NetflowData #reader -> master
  time::Int64 # rounded to nearest second
  netident::String # enip|webip|webport
  data::Array{Float64}
  dir::Int8
  function NetflowData(t::Int64 = 0,n::String = "",d::Array{Float64} = [0],d1 = 0)
    return new(t,n,d,d1)
  end
end

mutable struct WorkerMessage
  ident::Ident
  record::NetflowData
end


mutable struct Worker
  master::Channel
  writer::Channel
  duration::Int64
  min_recs::Int64
  worker_no::Int64
  active::Threads.Atomic{Bool}
  buckets::Matrix{Float64}(8,15) # bucket boundaries
  ref::Matrix{Float64}(8,16) # expected frac of total
end

mutable struct FlowsetData
  start_time::Int64 
  netident::String
  nrecs::Int64
  hist::Matrix{Int64,8,16}
  io_pattern::Int8
  
  function FlowsetData(time::Int64,ident::String)
    return new(time,ident0,ones(Int64,8,16),0) #basic flattening for the counts
  end
end

function(w::Worker)()
  t = Threads.threadid()
  w.active = false
  current = FlowsetData(0,"") # initialize current values
  while true
    msg = take!(w.master)
    if msg.ident == OPEN # open a new flowset
      if w.active[] # an active worker can't be OPENed.  Must expire or get QUIT first
        put!(w.master,WorkerMessage(ERROR,NetflowData()))
      else
        current = FlowsetData(msg.record.time,msg.record.netident ) # inactive, so re-initialize
        w.active[] = true
        put!(w.master, WorkerMessage(ACK,NetflowData()))
      end
      continue #while true
    end
    
    if msg.ident == DATA || msg.ident == QUIT
      if !w.active[]; continue; end  #ignore 

      if msg.ident == QUIT || msg.record.time - current.start_time > duration   # flowset has expired
        if current.nrecs >= w.min_recs #OK to write (if not, just ignore)
          line = netident
          chi_sq = Array{Float64}(undef,8)
          for i in 1:8 #convert counts to tail probs for each feature
            for j in 1:16
              expected = (nrecs-1)*ref[i][j]
              x = hist[i,j] - expected
              chi_sq[i] = stats.gammaq(nrecs-1,(x*x)/expected)
            end #for j
            line = line*" $chi_sq[i]"
          end #for i
          line = line*"\n"
          put!(w.writer,line) # send it to the writer
        end #output written
        w.active[] = false
        if msg.ident == QUIT; break; end
        continue #while true
      end #if msg.ident == QUIT || ....

      # OK to update current.hist from NetflowData
      for i in 1:7
        j = 0
        while msg.record.data[i] > w.buckets[j] && j < 16
          j += 1
        end
        current.hist[i,j] += 1
      end
      dir = msg.record.data[1] > 0? 0 : 1 # 0 for input record, 1 for output
      current.iopattern = ((current.iopattern << 1) | dir) & 15 #update io pattern
      current.hist[8,iopattern] += 1 
      current.nrecs += 1
    end # msg.ident == DATA
  end #while true
end #function
  
    

    
    
      
        
        






