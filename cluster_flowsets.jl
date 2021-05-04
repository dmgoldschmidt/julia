#! /home/david/julia-1.5.3/bin/julia

# This program reads a file of new format flowsets and a model file
# and writes the net_ident, cluster no., and probability.  

import GZip
if !@isdefined(CommandLine_loaded)
  include("CommandLine.jl")
end
if !@isdefined(sort_loaded)
  include("sort.jl")
end
if !@isdefined(util_loaded)
  include("util.jl")
end
if !@isdefined(Model_loaded)
  include("Model.jl")
end


function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}(
    "max_recs" => 0,
    "va_length"=> 1000,
    "flowsets"=>"flowsets.gz",
    "model" => "model.out",
    "file_dir" => "",
    "out_file"=>"clusters.txt"
  )
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values if they are specified
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  flowsets = defaults["file_dir"]*defaults["flowsets"]
  model_file = defaults["file_dir"]*defaults["model"]
  out_file = defaults["file_dir"]*defaults["out_file"] 
  
  stream = tryopen(flowsets)
  nrecs = 0;
  data = Array{Float64}[]
  ident = String[]
  for line in eachline(stream)
    row = split(line)
    
    row0 = Vector{Float64}(undef,8)
    try
      push!(ident,row[1])
      for i in 1:8
        row0[i] = parse(Float64,row[i+1])
      end
    catch
      println(stderr,"Can't parse record $nrecs.  Continuing")
      continue
    end
    nrecs += 1
    push!(data,row0)
    if(nrecs <= 4); println(row);end
    if (max_recs != 0 ? nrecs >= max_recs : false); break; end #early exit?
  end
  close(stream)
  println("\nfound $nrecs records")
  for i in 1:nrecs
    println("$(ident[i]): $(data[i])")
  end
end


#   stream = open(out_file,"w")

#   comp = LexComp(false,[1,2]) #descending sort on cluster no.
#   heapsort(data,nrecs,comp)
#   avg::Float64 = var::Float64 = 0
#   nsize::Int64 = 0
#   prev_cluster = data[1][1]
#   for i in 1:nrecs
#     if data[i][1] != prev_cluster #output the stats
#       avg = round(avg/nsize,digits=3)
#       var = round(sqrt((var - avg*avg)/nsize),digits=3)
#       println(stream,"cluster
#          $prev_cluster: $nsize connections, average prob: $avg")
#       nsize = 0;avg= 0;var = 0
#       prev_cluster = data[i][1]
#     end
#     nsize += 1
#     avg += data[i][2]
#     var += data[i][2]*data[i][2]
#   end
#   close(stream)
# end

# execution begins here
          
if occursin("cluster_flowsets.jl",PROGRAM_FILE)
  #was cluster_flowsets.jl called by a command?
  main(ARGS) 
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    main(map(string,split(cmd)))
  end
end 

