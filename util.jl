util_loaded = true
#module util
import GZip
StreamType = Union{IOStream,Base.TTY,GZip.GZipStream}
NumType = Union{Int64,Float64}
StringType = Union{String,SubString{String}}
VecType = Union{Matrix,Vector}

struct my_round
  digits::Int64
end
function (r::my_round)(x::Float64)
  return round(x ; sigdigits=r.digits)
end

function printmat(M::Matrix, ndigits = 5, s = "")
    rnd = my_round(ndigits)
    nrows = size(M)[1]
    ncols = size(M)[2]
    println(s)
    for i in 1:nrows
        for j in 1:ncols
            print("$(rnd(M[i,j])) ")
        end
        print("\n")
    end
end

function printmat(V::Vector, ndigits = 5, s = "")
    rnd = my_round(ndigits)
    println(s)
    for i in 1:size(V)[1]
        print("$(rnd(V[i])) ")
    end
    print("\n")
end


function is_dotted_quad(s::StringType)
  fields = split(s,".")
  if length(fields) != 4; return false; end
  for field in fields
    n = tryparse(Int64,field)
    if n == nothing; return false; end
    if n < 1 || n > 255; return false; end
  end
  return true
end

function tryopen(filename::String, mode::String = "r")
  if endswith(filename,".gz")
    println("endswith .gz")
  end
  stream::StreamType = stdin
  try
    stream = endswith(filename,".gz") ? GZip.open(filename,mode) : open(filename,mode)
  catch
    println(stderr,"Can't open $filename. Bailing out.")
    exit(1)
  end
  return stream
end

function myparse(T::DataType, s::String)
  if T == String || T == Any;return s;end
  x = 0
  try
    x = parse(T,s)
  catch
    println(stderr,"Can't parse $s as a $T.  Bailing out.")
    exit(1)
  end
  return x
end

#NOTES:
#1. sizehint!(A,n) may be a good idea
#2. should be mutable.  Then update length if extended, write a
#   function returning current length
#3. add a max_length member and get rid of 100x

struct VarArray{T}
  A::Array{T}
  null::T
  length::Int64
end

function Base.setindex!(v::VarArray, x, i)
  try
    0 < i <= 100*v.length || throw(BoundsError())
  catch
    println("VarArray bounds error:  setindex[$i] with v = $(v.length)")
    exit(0)
  end
  
  if i > length(v.A)
    for j in length(v.A)+1:i
      push!(v.A,v.null)
    end
  end
  v.A[i] = x
end

function Base.getindex(v::VarArray, i::Int64)
  return v.A[i]
end

function Base.length(v::VarArray)
  return length(v.A)
end

mutable struct Welford
  S1::Vector{Float64}
  S2::Matrix{Float64}
  weight::Float64
  tau::Float64
  function Welford(dim::Int64, t::Float64 = 1.0)
    weight = 0;
    S1 = zeros(dim);
    S2 = zeros(dim,dim);
    return new(S1,S2,weight,t);
  end
end

function update(W::Welford, x::Vector{Float64}, w::Float64 = 1.0)
#  println("updating $W with $x")
  if w < 1.0e-10; return; end
  delta = w.*x
  if W.weight > 0; delta -= (w/W.weight).*W.S1; end
  W.weight = W.tau*W.weight + w
  W.S1 = W.tau.*W.S1 + w.*x
  W.S2 = W.tau.*W.S2 + delta*transpose(x - (1.0/W.weight).*W.S1)
#  println("new W: $W")
end

function mean(W::Welford)
  return W.weight == 0 ? W.S1 : (1.0/W.weight).*W.S1
end
function covariance(W::Welford)
  return W.weight == 0 ? W.S2 : (1.0/W.weight).*W.S2
end

#end #module util    
