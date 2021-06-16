include("get_fts_flowsets.jl")

function writeit()
  i = 0
  dummy = [1.0,.123456789]
  nlines = [0,0]
  max = [2,3]
  ntries = 0
  msg = 0
  while nlines[1] < max[1] || nlines[2] < max[2]
    if nlines[i+1] < max[i+1]
      output = OutputData("line$(nlines[i+1]+1) for $(file[i+1]) on channel $(i+1)",dummy,2)
      msg = WriterMessage(DATA,output)
      println("master: sending $(msg.output.netident) to  channel $(i+1)")
      put!(wchan[i+1],msg)
      println("sent $(msg.output.netident) to channel $(i+1)")
      nlines[i+1] = nlines[i+1]+1
    end #if
    i = (i+1)%2
  end #while
  output = OutputData("",dummy,2)
  qmsg = [WriterMessage(QUIT,output) for i in 1:2]
  for i in 1:2
    println("master: sending QUIT on channel $i")
    put!(wchan[i],qmsg[i])
    println("master: QUIT sent on channel $i")
  end
  for i in 1:2
    println("master: waiting for EOF on channel $i")
    msg = take!(wchan[i])
    if msg.ident != EOF
      println(stderr,"comms error in writeit on channel $i.  Bailing out")
      exit(1)
    end
    println("master: got EOF on channel $i") 
  end
  println("wrote $nlines")
end

function readit()
  i = done = 0
  while done != 2
    if isready(rchan[i+1])
      println("master: waiting for DATA")
      msg = take!(rchan[i+1])
      if msg.ident == EOF
        done += 1
        println("master: EOF received.  done = $done")
      else
        println("master: $(msg.payload)")
      end #if EOF
    else
#      println("channel $(i+1) not ready")
      i = (i+1)%2 
    end #if isready
  end #while
end


# file = ["test2.out","test3.out"]
# wchan =[Channel(0) for i in 1:2]
# for j in 1:2
#   writer = Writer(wchan[j],file[j],j)
#   Threads.@spawn writer()
# end
# writeit()
# println("\n***writeit() has finished***\n")

# file = ["test2.out","test3.out"]
# rchan =[Channel(0) for i in 1:2]
# for j in 1:2
#   println("Opening Reader $j")
#   reader = Reader(rchan[j],file[j],j) #open the Readers
#   Threads.@spawn @async reader()
#   println("Reader $j is open")
# end
# sleep(1)
buckets = Matrix{Float64}(undef,8,15) #set up some buckets
for i in 1:8
  for j in 1:15
    buckets[i,j] = 1.0*j
  end
end
println("buckets = $(buckets[1,:])")
wchan = Channel(0) # one writer channel
writer = Writer(wchan,"print.out",0)
Threads.@spawn @async writer() # launch the writer
println("writer is launched")

Wchan = [Channel(100) for i in 1:2] # set up two workers

my_worker = [My_Worker(i,Wchan[i],wchan,300,10,Signal(false),Signal(false),buckets) for i in 1:2]
for i in 1:2
  println("launching worker $i")
  Threads.@spawn @async my_worker[i]()
end
println("workers are launched")
sleep(5)

netident = ("one", "two")
for i in 1:2
  println("sending OPEN to worker $i")
  dummy = NetflowData(0,netident[i])
  msg = WorkerMessage(OPEN,dummy)
  put!(Wchan[i],msg)
  println("waiting for worker $i active signal")
  while !my_worker[i].active(); end #wait for signal
  println("worker $i is active")
end

for t in 1:20
  worker_no = t%2
  netflow = NetflowData(t,netident[worker_no])
  netflow.dir = t < 10 ? 1:2
  netflow.field = rand(1:16,8)
  msg = WorkerMessage(DATA,netflow)
  put!(Wchan[worker_no],msg)
end

for i in 1:2
  put!(Wchan[i],WorkerMessage(QUIT,NetflowData()))
  while !my_worker[i].ack(); end 
  println("worker $i has acknowledged QUIT")
end

  
