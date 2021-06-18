# mutable struct Worker
#   id::Int
#   jobs::Channel{Int}
#   results::Channel{Tuple}
# end


const jobs = [Channel{Int}(32) for i in 1:4]
const results = Channel{Tuple}(32) #[Channel{Tuple}(32) for i in 1:4]
for i in 1:4
  println("jobs $i: $(jobs[i])")
end


function worker(i,jobs) #(job_no::Int)
  t = Threads.threadid()
  println("Worker $i (channel $jobs) on thread $t waiting for jobs")
  flush(stdout)
#  exit(0)
  for job in jobs 
    exec_time = rand()
    sleep(exec_time)
    put!(results,(job,exec_time))
    println("job $job was sent by worker $i")
  end
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
  Threads.@spawn worker(i,jobs[i])
  println("worker $i started")
end

println("all workers launched") 

while n > 0
  job_no, exec_time = take!(results)
  println("job $job_no finished in $(round(exec_time; digits=2)) seconds")
  global n = n-1
end
for i in 1:4
  close(jobs[i])
end
close(results)


  
  
