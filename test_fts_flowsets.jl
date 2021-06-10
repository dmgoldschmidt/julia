include("get_fts_flowsets.jl")
file = ["test.out","test1.out"]
chan =[Channel(10) for i in 1:2]
eof = [false for i in 1:2]

for j in 1:2
  Reader(chan[j],file[j]) #open the Readers
  println("$(file[j]) is open.")
end
function doit()
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
doit()
