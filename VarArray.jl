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

function testVarArray()
  a = Float64[1,2,3]
  v = VarArray(a,0,4)
  println("v[1] = $(v[1])")
  v[4] = 4.0
  println("v[4] = $(v[4]), length(v) = $(length(v))")
  v[5] = 5
end

