#! /home/david/julia-1.5.3/bin/julia
import GZip

function is_dotted_quad(s::String)
  fields = split(s,".")
  if length(fields) != 4; return false; end
  for field in fields
    n = tryparse(Int64,field)
    if n == nothing; return false; end
    if n < 1 || n > 255; return false; end
  end
  return true
end
  
include("CommandLine.jl")
include("Table.jl")
include("sort.jl")
defaults = Dict{String,Any}("max_recs" => 0,"duration"=>300,"in_file"=>"none","out_file"=>"none")
cl = get_vals(defaults)
println("parameters: $defaults")
max_recs = defaults["max_recs"]
duration = defaults["duration"]
in_file = defaults["in_file"]
out_file = defaults["out_file"]

stream = occursin(".gz",in_file) ? GZip.open(in_file) : open(in_file)

nrecs = nlines = 0
data = Array{String}[]
readline(stream);readline(stream)
for line in eachline(stream)
  #  global max_recs
  global nrecs,nlines,max_recs
  nrecs += 1
  row = split(line,"|")
  if !is_dotted_quad(string(row[4])) || !is_dotted_quad(string(row[6])); continue; end
  push!(data, row)
  nlines += 1
  if(nlines <= 4); println(row);end
  if (max_recs != 0 ? nrecs > max_recs : false); break;end
end
close(stream)
println("\nfound $nlines records")
comp = TableComp(true,[3,4,6,12])
heapsort(data,nlines,comp)
if out_file == "none"
  stream = stdout
else
  stream = open(out_file,"w")
end
for record in data
  for field in record
    write(stream,field*" ")
  end
  write(stream,"\n")
end
exit(0)

 
