include("util.jl")
mutable struct NetflowData #reader -> master
  time::Int64 # rounded to nearest second
  netident::String # enip|webip|webport
  data::Array{Float64}
end

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

mutable struct WorkerMessage
  ident::Ident
  data::NetflowData
  closed::Bool
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
      msg.ident = ACK
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

# function Parser(c:Channel{ParserMessage})
# end

# function Worker(c::Channel{WorkerMessage})
# end



