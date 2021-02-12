# make a union of string,float for table type T

mutable struct Table{T}
  data::Array{Array{T}}
  col::Array{Int64} # ordered subset of the column indices
  row::Array{Int64} # permutation of the row indices
  nrows::Int64
  ncols::Int64
end

struct TableRow
  t::Table
  i::Int64 #permuted row index
end

function Base.getindex(t::Table, Int64::i)
  1 <= i <= t.nrows || throw(BoundsError(t,i))
  return TableRow(t,t.row[i])
end

function Base.getindex(r:TableRow, j:Int64)
  1 <= j <= t.ncols || throw(BoundsError(r,i))
  return t.data[r.i][j]
end

function Base.:<(r::TableRow, s::TableRow)
  r.t == s.t || throw("Can't compare rows from different Tables")
  for j in r.t.col # we have to do this in order!
    if r.t.data[r.i][j] != s.t.data[r.i][j]
      return r.t.data[r.i][j] < s.t.data[r.i][j]
    end
  end
  return false
end

  
