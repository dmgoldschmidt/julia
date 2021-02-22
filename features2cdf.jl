#! /home/david/julia-1.5.3/bin/julia
import GZip
include("VarArray.jl")
include("CommandLine.jl")
include("sort.jl")

StreamType = Union{IOStream,Base.TTY}

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

# struct IndexPair{T}
#   index::Int64
#   value::T
# end

# function (c::IndexPair) Base.:<(x::IndexPair,y::IndexPair)::Bool
#   return x.value < y.value
# end

# struct PairComp
#   rev::Bool
# end

# function (p:PairComp)(x,y)::Bool
#   return p.rev ? x < y : x > y
# end



function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("max_recs" => 0,"va_length"=> 10,"min_recs"=>10,"in_file"=>"wsa.features.txt",
                              "out_file"=>"none")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
  min_recs = defaults["min_recs"] # min no of records in a flowset
  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  in_file = defaults["in_file"] # raw wsa file to read
  out_file = defaults["out_file"] # feature vector output

  stream = occursin(".gz",in_file) ? GZip.open(in_file) : open(in_file)
  float_cols = [2,3,4,5]
  nrecs = 0;
  data = Array{StringType}[]
  for line in eachline(stream)
    nrecs += 1
    row = split(line)
    push!(data,row)
    if(nrecs <= 4); println(row);end
    if (max_recs != 0 ? nrecs >= max_recs : false); break; end #early exit?
  end
  close(stream)
  println("\nfound $nrecs records")
  cdfs = Matrix{IndexPair{Float64}}(undef,nrecs,4)
  for i in 1:nrecs
    try
      for j in 1:4
        cdfs[i,j] = IndexPair{Float64}(i,parse(Float64,data[i][j+1]))
      end
    catch x
      println(x,": format error at line $i")
      continue
    end
  end
  #  x = collect(1:nrecs)./Float64(nrecs)
  nrecs0 = Float64(nrecs)
  for j in 1:4
#    println("before 1st sort: $(cdfs[:,j])")
    v = cdfs[:,j]
    heapsort(v,nrecs,PairComp(2)) # ascending sort on value
    cdfs[:,j] = v # for some reason, this work around seems to be necessary.
#    println("after 1st sort: $(cdfs[:,j])")
    for i in 1:nrecs;v[i].value = i/nrecs0; end
    heapsort(v,nrecs,PairComp(1)) # restore original order
    cdfs[:,j] = v
#    println("after 2nd sort: $(cdfs[:,j])")
  end
  stream = open(out_file,"w")
  for i in 1:nrecs
    print(stream,data[i][1])
    for j in 1:4; print(stream," ",round(cdfs[i,j].value,digits=6)); end
    for j in 6:7; print(stream," ",data[i][j]); end
    print(stream,"\n")
  end
  close(stream)
end

if ARGS != []; main(ARGS); end # to execute directly from command line: ./features2cdf.jl (at least one option or value)
