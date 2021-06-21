# mutable struct Worker
#   id::Int
#   jobs::Channel{Int}
#   results::Channel{Tuple}
# end
function main()
  include("util.jl")
  stream = open("print.out","w";lock = true)
  jobs = [Channel{Int64}(32) for i in 1:4]
  results = Channel{Tuple}(32) #[Channel{Tuple}(32) for i in 1:4]

  done = Vector{Bool}(undef,4)
  for i in 1:4
    done[i] = false
    println("jobs $i: $(jobs[i])")
  end

  function writer(stream)
    t = Threads.threadid()
    println("writer on thread $t waiting for output")
    while true
      job_no,exec_time = take!(results)
      println(stream,"job $job_no finished in $(round(exec_time; digits=2)) seconds")
    end
  end
  Threads.@spawn writer(stream)

  function worker(i) #(job_no::Int)
    t = Threads.threadid()
    my_jobs = jobs[i]
    #  my_signal = signals[i]
    println("Worker $i (channel $my_jobs) on thread $t waiting for jobs")
    flush(stdout)
    #  exit(0)
    for job in my_jobs
      if job == 0; break; end  #quit message
      exec_time = rand()
      sleep(exec_time)
      put!(results,(job,exec_time))
      println("job $job was sent by worker $i")
    end
    done[i] = true #signal master that we got the quit signal
    println("Worker $i is done")
  end

  function send_jobs(n)
    for i in 1:n
      j = i%4
      put!(jobs[j+1],i)
      println("sent job $i to jobs[$(j+1)]")
    end
  end

  n = 12
  send_jobs(n)
  println("all jobs sent")
  
  for i in 1:4
    println("starting worker $i")
    Threads.@spawn worker(i)
    println("worker $i started")
  end

  println("all workers launched")
  for i in 1:4
    put!(jobs[i],0)
    println("sent quit message to worker $i")
  end
  #sleep(10)
  # if isready(signals[1])
  #   println("worker 1 has quit")
  # end
  # exit(0)


  nquit = 0
  ntries = 0

  while nquit < 4 && ntries < 10
    ntries += 1
    for i in 1:4
      if done[i]
        println("task $i has finished")
        close(jobs[i])
        nquit += 1
      else
        println("task $i is not finished")
        sleep(1)
      end
    end
  end
  close(results)
end #main
main()

  
  
