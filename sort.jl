#! /home/david/julia-1.5.3/bin/julia

"""
This is a heap/sort combo which will sort an Array{T} of any type T.  In general, the user must provide a swap
function to interchange two Array entries and a comparator function (object) to compare two entries.  The defaults 
are std_swap and StdComp(true), which is a functor (function object).  In the default (true) mode, heap returns
a top-down heap, and sort returns a bottom-up (ascending) sort.  These are both reversed if you call with
StdComp(false):  heap(A,n,StdComp(false)).  There is also a LexComp comparator for the rows of a table Array{Array{T}}
which implements lexicographic ordering. It assumes that type T has a "<" operator defined.  To use this, one first 
initializes the object with an Array{Int64} of sort keys, i.e. column indices to use in the lexicographic ordering.
Example: ascending lexicographic sort on columns 1,3,4

comp = LexComp(true,[1,3,4])
A = Array{Array{T}}
.
. (fill the table with n rows)
.
sort(A,n,comp) 

If type T does not have a < operator defined, a custom comparator will need to be written, or one can overload
operator< for type T.

"""
sort_loaded = true
#const ArrayType = Any #Union{Tuple,Array,VarArray}
import Random
struct LexComp #this is a functor (function object).  It is designed for sorting an Array{Array{T}} in lexicographic order
  #Initialize with a Tuple of col. indices and a rev::Bool 
  rev::Bool
  sort_keys::Array{Int64,1}
end

function (c::LexComp)(r, s)
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

mutable struct IndexPair{T} #NOTE: this might have been done with a Tuple, except that we need mutability of values
  index::Int64
  value::T
end

function Base.print(ip::IndexPair)
  print(ip.value)
end


# function (c::IndexPair) Base.:<(x::IndexPair,y::IndexPair)::Bool
#   return x.value < y.value
# end

mutable struct PairComp
  rev::Bool
  ind::Int64
end

PairComp(i::Int64) = PairComp(true,i)

function (p::PairComp)(x::IndexPair{Float64}, y::IndexPair{Float64})
#  println("comparing ", string(x), string(y))
  if p.ind == 1
    return p.rev ? x.index < y.index : x.index > y.index
  else
    return p.rev ? x.value < y.value : x.value > y.value
  end
end

function Base.string(ip::IndexPair)
  v = round(ip.value,digits = 6)
  return "($(ip.index), $v)"
end


function std_swap(A,i,j)
  A[i],A[j] = A[j],A[i]
end

function heap(A, n::Int64, max_n::Int64, comp = StdComp(true), swap = std_swap)
  #the children of A[n] are heaps.  Make A[n] a heap
  #println("n = $n")
  while 2*n <= max_n
    m = 2*n;
    if 2*n+1 <= max_n && comp(A[m],A[m+1])
      m += 1
    end
    if comp(A[n],A[m])
#      println("swapping items $n, $m")
      swap(A,n,m) # now A[n] > max(A[2*n],A[2*n+1]) (with ascending sort order)
    else
      break;
    end
    n = m
  end
end

function heapsort(A, n::Int64 = length(A), comp = StdComp(true), swap = std_swap)
  for i = trunc(Int64,n/2):-1:1
    heap(A,i,n,comp,swap)
  end
  while n > 1
#    println("swapping items A[1] = ",string(A[1]), "A[$n] = ",string(A[n]))
    swap(A,1,n) #biggest remaining guy goes to the end
    n -= 1
    heap(A,1,n,comp,swap)
#    #println(A[1:n])
  end
end

function search(x, A, lower::Int64 = 1, upper::Int64 = length(A))
  if x > A[upper] || A[lower] >= A[upper]; return (upper, A[upper]);end
  if x <= A[lower]; return (lower,A[lower]);end
  while lower < upper-1 # this loop mains the relation A[lower] < x <= A[upper]
    i = trunc(Int64,(upper+lower)/2)
    if x <= A[i]; upper = i
    else lower = i
    end
  end
  try
    return (upper, upper - (upper-x)/(upper-lower))
  catch
    return (upper,0)
  end
end

function sort_main(cmd_line = ARGS)
  defaults = Dict{String,Any}("nrows"=>5,"ncols"=>2, "seed"=>12345)
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  nrows = defaults["nrows"]
  ncols = defaults["ncols"]
  seed = defaults["seed"]
  Random.seed!(seed)
  A = Matrix{IndexPair{Float64}}(undef,nrows,ncols)
  for i in 1:nrows
    for j in 1:ncols
      A[i,j] = IndexPair(i,rand())
    end
  end
  comp = PairComp(true,2)
  println("input:",A)
  for j in 1:ncols
    v = A[:,j]
    heapsort(v,5,PairComp(2))
    A[:,j] = v
    println("after 1st sort: ",A)
    heapsort(v,5,PairComp(1))
    A[:,j] = v
    println("after 2nd sort: ",A)
  end
end

# execute main iff
# a) it's being run from a file containing the string "sort.jl", or
# b) it's being run from the REPL
if occursin("sort.jl",PROGRAM_FILE)
  include("CommandLine.jl")
  sort_main(ARGS)
else
  if isinteractive()
    include("CommandLine.jl")
    print("enter command line: ")
    cmd = readline()
    sort_main(map(string,split(cmd)))
  end
end # to execute directly from command line: ./sort.jl <ARGS>




            
  
  
