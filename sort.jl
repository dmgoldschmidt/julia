"""
This is a heap/sort combo which will sort an Array{T} of any type T.  In general, the user must provide a swap
function to interchange two Array entries and a comparator function (object) to compare two entries.  The defaults 
are std_swap and StdComp(true), which is a functor (function object).  In the default (true) mode, heap returns
a top-down heap, and sort returns a bottom-up (ascending) sort.  These are both reversed if you call with
StdComp(false):  heap(A,n,StdComp(false)).  There is also a TableComp comparator for the rows of a table Array{Array{T}}
which implements lexicographic ordering. It assumes that type T has a "<" operator defined.  To use this, one first 
initializes the object with an Array{Int64} of sort keys, i.e. column indices to use in the lexicographic ordering.
Example: ascending lexicographic sort on columns 1,3,4

comp = TableComp(true,[1,3,4])
A = Array{Array{T}}
.
. (fill the table with n rows)
.
sort(A,n,comp) 

If type T does not have a < operator defined, a custom comparator will need to be written, or one can overload
operator< for type T.

"""

struct TableComp #this is a functor (function object).  It is designed for sorting an Array{Array{T}}.
  #Initialize with a Tuple of col. indices and a rev::Bool 
  rev::Bool
  sort_keys::Array{Int64,1}
end

function (c::TableComp)(r::Array, s::Array)
  for j in c.sort_keys # we have to do this in order!
    if r[j] != s[j]
      return c.rev ? r[j] < s[j] : r[j] > s[j]
    end
  end
  return false # equality for all keys
end

struct StdComp
  rev::Bool #rev = true makes a top-down heap and a bottom-up (ascending) sort
end

function (c::StdComp)(x,y)
  return c.rev ? x <  y : x > y
end

const ArrayType = Union{Array,VarArray}
function std_swap(A,i,j)
  A[i],A[j] = A[j],A[i]
end

function heap(A::ArrayType, n::Int64, max_n::Int64, comp = StdComp(true), swap = std_swap)
  #the children of A[n] are heaps.  Make A[n] a heap
  #println("n = $n")
  while 2*n <= max_n
    m = 2*n;
    if 2*n+1 <= max_n && comp(A[m],A[2*n+1])
      m += 1
    end
#    #println("m = $m")
    #println("is ",A[n]," < ",A[m], A[n] < A[m]);
    if comp(A[n],A[m])
      swap(A,n,m) #now A[n] >= max(A[2*n],A[2*n+1] (with rev = false)
      #println("swapping $n, $m")
    else
      break;
    end
    n = m
  end
end

function heapsort(A::ArrayType, n::Int64 = length(A), comp = StdComp(true), swap = std_swap)
  for i = trunc(Int64,n/2):-1:1
    heap(A,i,n,comp,swap)
#    #println(A[1:n])
  end
#  #println("heap complete")
  while n > 1
    swap(A,1,n)
    n -= 1
    heap(A,1,n,comp,swap)
#    #println(A[1:n])
  end
end

function search(x, A::ArrayType, lower::Int64 = 1, upper::Int64 = length(A))
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

# using Random
# Random.seed!(12345)
# A = Vector{Int64}[]
# row = Array{Int64,1}(undef,4)
# for i in 1:8
#   push!(A,rand(1:8,4))
# end
# comp = TableComp(true,[1,2])
# println("input:")
# for i in 1:length(A)
#   println(i,":",A[i])
# end
# heapsort(A,8,comp)
# for i in 1:length(A)
#   println(i,":",A[i])
# end
# c = TableComp(false,[3,1])
# heapsort(A,8,c)
# println("descending order:")
# for i in 1:length(A)
#   println(i,":",A[i])
# end



            
  
  
