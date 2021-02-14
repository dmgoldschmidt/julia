# make a union of string,float for table type T

struct TableRow{T}
  data::Array{T}
#  col::Array{Int64}
end

function Base.getindex(r::TableRow, j;Int64)
  return r.data[j]
end

struct Comp
  cols::Array{Int64}
  rev::Bool
end

function (c::Comp)(r::TableRow, s::TableRow)
  for j in c.cols # we have to do this in order!
    if r.data[j] != s.data[j]
      if(c.rev)
        return r.data[j] > s.data[j]
      else
        return r.data[j] < s.data[j]
      end
    end
  end
  return false
end

  
# function Base.:<(r::TableRow, s::TableRow)
#   global sort_cols
#   for j in sort_cols # we have to do this in order!
#     if r.data[sort_cols[j]] != s.data[sort_cols[j]]
#       return r.data[sort_cols[j]] < s.data[sort_cols[j]]
#     end
#   end
#   return false
# end

function testTable()
  sort_cols = Int64[1,2]
  A = TableRow{Int64}[] # A Table is an Array of TableRow
  push!(A,TableRow([1,3,3]))
  push!(A,TableRow([1,4,4]))
  push!(A,TableRow([1,2,2]))

  println(A)
  lt = Comp([1,2],false)
  println(lt)
  println("is A[1] < A[2]? ", lt(A[1], A[2]))
  println("is A[1] < A[3]? ", lt(A[1], A[3]))
  A[1],A[2] = A[2],A[1]
  println("swapped: ",A)
end
  
          


