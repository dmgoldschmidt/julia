include("util.jl")
mutable struct NetflowData #reader -> master
  time::Int64 # rounded to nearest second
  netident::String # enip|webip|webport
  data::Array{Float64}
end

mutable struct OutputData #worker -> writer
  netident::String
  data::Array{Float64}
  size::Int64
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
  data::OutputData
end

function Reader(c::Channel)
  println("task Reader has started")
  opened::Bool = false
  stream = stdin
  msg = nothing
  while(!opened) #wait for "open" message
    msg = take!(c)
    if msg.ident == OPEN
      stream = tryopen(msg.payload)
      opened = true
      msg.ident = COMPLETE
      println("opened $(msg.payload)")
    end
  end
  for line in eachline(stream)
    println("about to put $line")
    put!(c,ReaderMessage(DATA,line))
  end
  close(stream)
  println("closed $(msg.payload)")
  put!(c,ReaderMessage(EOF,""))
end

# function Writer(c::Channel{WriterMessage})
# end

# function Parser(c:Channel{ParserMessage})
# end

# function Worker(c::Channel{WorkerMessage})
# end



