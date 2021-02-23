#! /home/david/julia-1.5.3/bin/julia
util_loaded = true
StreamType = Union{IOStream,Base.TTY}
NumType = Union{Int64,Float64}
StringType = Union{String,SubString{String}}

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

function tryopen(filename::String)
  if endswith(filename,".gz")
    println("endswith .gz")
  end
  stream::StreamType = stdin
  try
    stream = endswith(filename,".gz") ? GZip.open(filename) : open(filename)
  catch
    println(stderr,"Can't open $filename. Bailing out.")
    exit(1)
  end
  return stream
end

#NOTE: sizehint!(A,n) may be a good idea

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



