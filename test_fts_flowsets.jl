include("get_fts_flowsets.jl")
#reader = Channel(Reader,10;)
taskrefs = [Ref{Task}() for i in 1:2]
readers = [Channel(Reader,10;taskref = taskrefs[i]) for i in 1:2]
file = ["test.out","test1.out"]
for i in 1:2
  msg = ReaderMessage(OPEN,file[i])
  println("about to put $(msg.ident), $(msg.payload) on channel taskref[$i]")
  put!(readers[i],msg)
  ntries = 0
  while msg.ident != COMPLETE
    ntries += 1
    sleep(1)
    println("ntries = $ntries")
    if ntries > 10; break; end
  end 
end
println("readers: $readers")
for i in 1:2
  for msg in readers[i]
    if msg.ident == EOF ; break; end
    println(msg.payload)
  end
end
