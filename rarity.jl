#! /home/david/julia-1.5.3/bin/julia
import GZip
include("VarArray.jl")
include("CommandLine.jl")
include("sort.jl")
include("util.jl")

function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("max_recs" => 0,"va_length"=> 1000,"in_file"=>"wsa.07-01.features.txt",
                              "out_file"=>"wsa.07-01.ext_features.txt")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  in_file = defaults["in_file"] # raw wsa file to read
  out_file = defaults["out_file"] # feature vector output

  stream = tryopen(in_file)
  rarity = Dict{String,Int64}()
  nrecs = 0;
  data = Array{String}[]
  for line in eachline(stream)
    row = map(string,split(line))
    webip0 = map(string,split(row[1],"|"))
    webip = webip0[2]
    if !haskey(rarity,webip)
      rarity[webip] = 1
    else
      rarity[webip] += 1
    end
    nrecs += 1
    push!(data,row)
    if(nrecs <= 4); println(row);end
    if (max_recs != 0 ? nrecs >= max_recs : false); break; end #early exit?
  end
  close(stream)
  println("\nfound $nrecs records")

  stream = open(out_file,"w")
  for row in data
    webip0 = map(string,split(row[1],"|"))
    webip = webip0[2]
    for field in row
      print(stream,field," ")
    end
    print(stream,rarity[webip],"\n")
  end
end

if occursin("rarity.jl",PROGRAM_FILE)
  main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    main(map(string,split(cmd)))
  end
end 

