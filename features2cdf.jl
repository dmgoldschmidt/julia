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

function features2cdf_main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("max_recs" => 0,"file_dir" => ".", "cdf_cols" =>[2,3,4,5,6], "va_length"=> 1000,"min_recs"=>10,"in_file"=>"wsa.features.txt","out_file"=>"wsa.cdf.txt")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  max_recs = defaults["max_recs"] # max no of records to read
  file_dir = defaults["file_dir"] # directory for all i/o files
  cdf_cols = defaults["cdf_cols"] # columns to convert to cdf
  min_recs = defaults["min_recs"] # min no of records in a flowset
  va_length = defaults["va_length"] # initial length for VarArray (max. length is now 10x)
  in_file = defaults["in_file"] # raw wsa file to read
  out_file = defaults["out_file"] # feature vector output
  if file_dir != "."
    in_file = file_dir*"/"*in_file
    out_file = file_dir*"/"*out_file
  end
  nfeat = length(cdf_cols)
  stream = occursin(".gz",in_file) ? GZip.open(in_file) : open(in_file)
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
  cdfs = Matrix{IndexPair{Float64}}(undef,nrecs,nfeat)
  for i in 1:nrecs
    try
      for j in 1:nfeat
        cdfs[i,j] = IndexPair{Float64}(i,parse(Float64,data[i][cdf_cols[j]]))
      end
    catch x
      println(x,": format error at line $i")
      continue
    end
  end
  #  x = collect(1:nrecs)./Float64(nrecs)
  nrecs0 = Float64(nrecs)
  for j in 1:nfeat
#    println("before 1st sort: $(cdfs[:,j])")
    v = cdfs[:,j]
    heapsort(v,nrecs,PairComp(2)) # ascending sort on value
    cdfs[:,j] = v # for some reason, this work around seems to be necessary.
#    println("after 1st sort: $(cdfs[:,j])")
    for i in 1:nrecs;v[i].value = i/nrecs0; end
    heapsort(v,nrecs,PairComp(1)) # restore original order
    cdfs[:,j] = v #put the pairs back into the matrix
#    println("after 2nd sort: $(cdfs[:,j])")
  end
  stream = open(out_file,"w")
  for i in 1:nrecs
    j0 = 1
    for j in 1:length(data[i])
      if j in cdf_cols
        print(stream," ",round(cdfs[i,j0].value,digits=6));j0 += 1
      else
        print(stream," ",data[i][j])
      end
    end
    print(stream,"\n")
  end
  close(stream)
end

# execute main iff
# a) it's being run from a file containing the string "features2cdf.jl", or
# b) it's being run from the REPL
if occursin("features2cdf.jl",PROGRAM_FILE)
  include("CommandLine.jl")
  features2cdf_main(ARGS)
else
  if isinteractive()
    include("CommandLine.jl")
    print("enter command line: ")
    cmd = readline()
    features2cdf_main(map(string,split(cmd)))
  end
end # to execute directly from command line: ./features2cdf.jl <ARGS>


