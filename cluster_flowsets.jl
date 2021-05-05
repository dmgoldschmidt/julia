#! /home/david/julia-1.5.3/bin/julia

# This program reads a file of new format flowsets and a model file
# and writes the net_ident, and cluster probability vector.  

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
#    "va_length"=> 1000,
    "flowsets"=>"flowsets.gz",
    "model" => "model.out",
    "file_dir" => "",
    "out_file"=>"clusters.txt",
    "dim" => 8,
    "nstates" => 16
  )
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values if they are specified
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
#  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  flowsets = defaults["file_dir"]*defaults["flowsets"]
  model_file = defaults["file_dir"]*defaults["model"]
  out_file = defaults["file_dir"]*defaults["out_file"] 
  dim = defaults["dim"]
  nstates = defaults["nstates"]
  
  stream = tryopen(flowsets)
  nrecs = 0;
  data = Array{Float64}[]
  ident = String[]
  for line in eachline(stream)
    row = map(string,split(line))
    if length(row) < dim+1
      println(stderr,"dimension error. record $nrecs has length $(length(row)). Bailing out.")
      exit(1)
    end
    
    row0 = Vector{Float64}(undef,dim)
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
  #  if(nrecs <= 4); println(row);end
    if (max_recs != 0 ? nrecs >= max_recs : false); break; end #early exit?
  end
  close(stream)
  println("\nfound $nrecs records")
  # for i in 1:nrecs
  #   println("$(ident[i]): $(data[i])")
  # end
  stream = tryopen(out_file,"w")
  model = read_model(nstates,dim,model_file)
  rnd = my_round(5)
  for i in 1:nrecs
    gamma = map(rnd,prob(model,data[i]))
    print(stream,ident[i],":")
    max_prob = 0.0
    max_j = 0
    for j in 1:nstates
      print(stream," ",gamma[j])
      if gamma[j] > max_prob
        max_prob = gamma[j]
        max_j = j
      end
    end
    print(stream," $max_j: $max_prob\n")
  end
  close(stream)
end

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

