include("get_fts_flowsets.jl")

function writeit()
  i = 0
  dummy = [1.0,.123456789]
  nlines = [0,0]
  ntries = 0
  while nlines[1] < 2 && nlines[2] < 3
    println("waiting for channel $(i+1)")
    if isopen(chan[i+1])
      output = OutputData("line$(nlines[i+1]+1) from $(file[i+1])",dummy,2)
      msg = WriterMessage(DATA,output)
      put!(chan[i+1],msg)
      println("sent $(msg.output.netident) to Writer $i")
      nlines[i+1] = nlines[i+1]+1
    else
      println("write channel $(i+1) not open")
      i = (i+1)%2
      ntries += 1
      if ntries > 10; break; end
    end #if isready
  end #while
  println("wrote $nlines")
end

function readit()
  i = done = 0
  while done != 2
    if isready(chan[i+1])
#      println("master: waiting for DATA")
      msg = take!(chan[i+1])
      if msg.ident == EOF
        println("master: EOF received.  Exiting")
        eof[i+1] = true
        done += 1
      else
        println("master: $(msg.payload)")
      end #if EOF
    else
#      println("channel $(i+1) not ready")
      i = (i+1)%2
    end #if isready
  end #while
end

file = ["test.out","test1.out"]
chan =[Channel(10) for i in 1:2]
eof = [false for i in 1:2]
for j in 1:2
  Writer(chan[j],file[j]) #open the Writers
  println("Writer $j has started.")
end
writeit()
exit(0)
for j in 1:2
  Reader(chan[j],file[j]) #open the Readers
  println("Reader $j has started.")
end
readit()
