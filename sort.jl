function swap(A,i,j)
  temp = A[i]
  A[i] = A[j]
  A[j] = temp
end

function heap(A::Array, n::Int64, max_n::Int64, rev::Bool = false) #the children of A[n] are heaps.  Make A[n] a heap
  while 2*n <= max_n
    m = 2*n;
    if 2*n+1 <= max_n && (rev ? A[m] > A[2*n+1] : A[m] < A[2*n+1])
      m += 1
    end
#    println("is ",A[n]," > ",A[m]);
    if (rev ? A[n] > A[m] : A[n] < A[m])
      A[n],A[m] = A[m],A[n] #now A[n] >= max(A[2*n],A[2*n+1] (with rev = false)
    else
      break;
    end
    n = m
  end
end

function heapsort(A::Array, n::Int64, rev::Bool = false)
  for i = trunc(Int64,n/2):-1:1
    heap(A,i,n,rev)
#    println(A[1:n])
  end
#  println("heap complete")
  while n > 1
    A[1],A[n] = A[n],A[1] #swap(A,1,n)
    n -= 1
    heap(A,1,n,rev)
#    println(A[1:n])
  end
end

function search(x, A::Array, lower::Int64 = 1, upper::Int64 = length(A))
  if x > A[upper] || A[lower] >= A[upper]; return (upper, A[upper]);end
  if x <= A[lower]; return (lower,A[lower]);end
  while lower < upper-1 # this loop mains the relation A[lower] < x <= A[upper]
    i = trunc(Int64,(upper+lower)/2)
    if x <= A[i]; upper = i
    else lower = i
    end
  end
  return (upper, upper - (upper-x)/(upper-lower))
end

    
  
    



                
using Random
Random.seed!(12345)
A = rand(1:1000,65)
println("input: ",A);
heapsort(A,65)
for i in 1:length(A);println(i,":",A[i]);end
#heapsort(A,64,true)
#println(A)
println(search(A[25]+pi,A))


            
  
  
