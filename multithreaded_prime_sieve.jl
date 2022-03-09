#=
This code comes mostly from the talk "JuliaCon 2019 | Multi-threading in Julia with PARTR":
https://youtu.be/HfiRnfKxI64?t=729

It is a Julia translation of this Go code:
https://github.com/thomas11/csp/blob/f2ec7c4/csp.go#765

I fixed a few errors in the Julia code:
* replaced numPrimes with n
* replaced `if m < m` with `if m < mp`
* replaced `if length(primes)==n` with `if i == n`
* replaced `n` with `k` in the last part of the function

To run this code, execute the following shell command
(set the number of threads to the number of cores on your system):
JULIA_NUM_THREADS=4 julia multithreaded_prime_sieve.jl
=#
using Dates
function S61_SIEVE(n::Integer)
  done = Threads.Atomic{Bool}(false)
  primes = Int[]
  sieves = [Channel{Int}() for _ = 1:n]
  for i in 1:n
    println(Time(now()),": begin iteration $i")
    Threads.@spawn begin
      println(Time(now()),": begin task $i")
#      iterno = i
      mp = p = take!(sieves[i])
      t = Threads.threadid()
      println("\n",Time(now()),": entering task $i (thread $t), I got p = $p")
      push!(primes, p)
      if i == n
        done[] = true
        return
      end
      for m in sieves[i]
        t = Threads.threadid()
        println(Time(now()),": task $i (thread $t): I got $m from sieves[$i]")
        while m > mp; mp += p; end
        if m < mp
          println(Time(now()),": task $i (thread $t): mp = $(mp). Putting $m into sieves[$(i+1)]")
          put!(sieves[i + 1], m)
          flush(stdout)
        end
      end # for m 
    end #@spawn
  end # for i
  t = Threads.threadid()
  println(Time(now()),": task 0 (thread $t): putting 2 into sieves[1]")
  put!(sieves[1], 2)
  k = 3
  while !done[]
    println(Time(now()),": task 0 (thread $t): putting $k into sieves[1]")
    put!(sieves[1], k)
#    while !isready(sieves[1]); continue; end
    k += 2
  end
  return primes
end #function

primes = S61_SIEVE(10)
println("Found $(length(primes)) primes:")
println(primes)
