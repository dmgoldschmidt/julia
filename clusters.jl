#! /home/david/julia-1.5.3/bin/julia
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

function main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("max_recs" => 0,"va_length"=> 1000,"in_file"=>"clusters.out",
                              "out_file"=>"clusters.info.txt")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  in_file = defaults["in_file"] # raw wsa file to read
  out_file = defaults["out_file"] # feature vector output

  try
    stream = occursin(".gz",in_file) ? GZip.open(in_file) : open(in_file)
  catch
    println(stderr,"Can't open $infile. Bailing out.")
    exit(1)
  end
  sort_cols = [3,4] # sort on cluster_no, max_prob
  nrecs = 0;
  data = Array{NumType}[]
  for line in eachline(stream)
    row = split(line)
    row0 = []
    try
      row0 = [parse(Int64,row[3]),parse(Float64,row[4])]
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
  stream = open(out_file,"w")

  comp = LexComp(false,[1,2]) #descending sort on cluster no.
  heapsort(data,nrecs,comp)
  avg::Float64 = var::Float64 = 0
  nsize::Int64 = 0
  prev_cluster = data[1][1]
  for i in 1:nrecs
    if data[i][1] != prev_cluster #output the stats
      avg = round(avg/nsize,digits=3)
      var = round(sqrt((var - avg*avg)/nsize),digits=3)
      println(stream,"cluster $prev_cluster: $nsize connections, average prob: $avg")
      nsize = 0;avg= 0;var = 0
      prev_cluster = data[i][1]
    end
    nsize += 1
    avg += data[i][2]
    var += data[i][2]*data[i][2]
  end
  close(stream)
end

if occursin("clusters.jl",PROGRAM_FILE)
  main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    main(map(string,split(cmd)))
  end
end 

