#! /home/david/julia-1.5.3/bin/julia
import GZip
include("VarArray.jl")
include("CommandLine.jl")
include("sort.jl")

StreamType = Union{IOStream,Base.TTY}

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

mutable struct Flowset
  ident::String
  nrecs::Int64
  threat::Float64
  start_time::Float64
  iat::VarArray{Float64}
  dur::VarArray{Float64}
  bytes_in::VarArray{Float64}
  bytes_out::VarArray{Float64}
end
vtype = VarArray{Float64}
Flowset(length) = Flowset("",0,0.0,0.0,vtype([],0,length),vtype([],0,length),vtype([],0,length),vtype([],0,length))

function print(fl::Flowset, stream::StreamType = stdout)
  println(stream,"Flowset $(fl.ident) : start: $(fl.start_time) nrecs: $(fl.nrecs) threat: $(fl.threat)\n")
end

function get_med(values::vtype, nrecs::Int64, n::Int64 = 2)
  heapsort(values,nrecs)
  if n < 2 || n > nrecs; n = 2; end
  avg = 0
  for i in 1:n-1
    j = trunc(Int64,nrecs*i/n) + 1
    avg += values[j]
  end
  return avg/(n-1)
end
    
function save_feature_vector(fl::Flowset, stream::StreamType = stdout,  n::Int64 = 2)
#  print(fl,stream)
  iat = round(get_med(fl.iat,fl.nrecs,n), digits=6)
  dur = get_med(fl.dur,fl.nrecs,n)
  in_bytes = get_med(fl.bytes_in,fl.nrecs,n)
  out_bytes = get_med(fl.bytes_out,fl.nrecs,n)
  println(stream,fl.ident," $iat $dur $in_bytes $out_bytes $(fl.threat) $(fl.nrecs)")
  return (iat,dur,in_bytes,out_bytes) 
end


function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("max_recs" => 0,"timeout"=>300,"va_length"=> 10,"in_file"=>"wsa.sample","out_file"=>"none")
  cl = get_vals(defaults,cmd_line)
  println("parameters: $defaults")
  max_recs = defaults["max_recs"]
  timeout = defaults["timeout"]
  va_length = defaults["va_length"]
  in_file = defaults["in_file"]
  out_file = defaults["out_file"]

  stream = occursin(".gz",in_file) ? GZip.open(in_file) : open(in_file)

  nrecs = 0;nlines = 0
  data = Array{String}[]
  readline(stream);readline(stream) #skip header
  for line in eachline(stream)
#    global nrecs,nlines,max_recs
    nrecs += 1
    row = split(line,"|")
    if !is_dotted_quad(string(row[4])) || !is_dotted_quad(string(row[6])); continue; end
    push!(data, row)
    nlines += 1
    if(nlines <= 4); println(row);end
    if (max_recs != 0 ? nrecs > max_recs : false); break; end #early exit?
  end
  close(stream)
  println("\nfound $nlines records")
  comp = TableComp(true,[4,6,12,1]) #sort on ident,time
  heapsort(data,nlines,comp)

  comp = TableComp(true,[4,6,12])
  fl = Flowset(va_length)
  if out_file == "none"
    stream = stdout
  else
    stream = open(out_file,"w")
  end
  nfeatures = 0
  prev_time = tryparse(Float64,data[1][1]) #initialize to the first time we're going to see 
  for i in 1:length(data)
 #   println(stream,data[i])
    time = tryparse(Float64,data[i][1])
    nf = i == 1 ? true : comp(data[i-1],data[i]) #NOTE: comp returns false on equality
    new_flowset = (i == 1 || nf)
    if new_flowset
      if i > 1
        save_feature_vector(fl,stream) # process current flowset
        nfeatures += 1
        end
      fl.ident = data[i][4]*"|"*data[i][6]*"|"*data[i][12]
      fl.nrecs = 0
      fl.threat = tryparse(Float64,data[i][15])
      fl.start_time = time
      prev_time = time
    end
      #process the record
    if time - fl.start_time < timeout # if not, ignore the remaning records in this flowset
      fl.nrecs += 1
      fl.iat[fl.nrecs] = time - prev_time
      fl.dur[fl.nrecs] = tryparse(Float64,data[i][10])
      fl.bytes_in[fl.nrecs] = tryparse(Float64,data[i][13])
      fl.bytes_out[fl.nrecs] = tryparse(Float64,data[i][14])
      fl.threat = tryparse(Float64,data[i][15])
      prev_time = time
    end
    if i == length(data)
      save_feature_vector(fl,stream) # process the last flowset
      nfeatures += 1
    end
  end # on to the next data record
  close(stream)
  println("largest flowset was $(length(fl.iat)), there were $nfeatures feature vectors")
end # of main

# if out_file == "none"
#   stream = stdout
# else
#   stream = open(out_file,"w")
# end
# for record in data
#   for field in record
#     write(stream,field*" ")
#   end
#   write(stream,"\n")
# end


 
