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

@enum Ident OPEN=1 DATA=2 ERROR=3 EOF=4 EXIT=5 RAW=6 COMPLETE=7

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

function Reader(c::Channel,file::String)
  stream = tryopen(file)
  Threads.@spawn begin
    t = Threads.threadid()
    for line in eachline(stream)
#      println("thread $t: sending $line")
      put!(c,ReaderMessage(DATA,line)) 
#      println("thread $t: DATA sent")
    end
    close(stream)
#    println("thread $t: closed $file. Sending eof")
    put!(c,ReaderMessage(EOF,""))
#    println("thread $t: EOF sent")
  end #@spawn
end

function Writer(c::Channel,file::String)
  stream = tryopen(file,"w")
  println("opened $file")
  Threads.@spawn begin
    t = Threads.threadid()
    println("writing to $file on thread $t")
    while true
      msg = take!(c)
      println("thread $t: got $(msg.ident) $(msg.output.netident)")
      exit(0)
      if msg.ident == QUIT
        break
      else
        println("thread $t: writing $(msg.output.netident)")
        write(stream,"$(msg.output.netident)")
        for x in msg.output.data; write(stream," $x"); end
        write(stream,"\n")
      end
    end
    close(stream)
    println("thread $t: closed $file.")
  end #@spawn
end

# function Parser(c:Channel{ParserMessage})
# end

# function Worker(c::Channel{WorkerMessage})
# end



