include("util.jl")
include("EM.jl")
include("Model.jl")
include("AtA.jl")
using LinearAlgebra

#using Debugger
#break_on(:error)

#using Printf
function cluster_main(cmd_line = ARGS)
    defaults = Dict{String,Any}(
        "data_file" =>"data.dat",
        "out_file"=>"print.out",
        "max_states"=>16,
        "dim"=>8
    )
    cl = get_vals(defaults,cmd_line) # replace defaults with command line values
    println("parameters: $defaults")
    nstates = defaults["nstates"]
    dim = defaults["dim"]
    @assert(1 <= dim <= 8)
    Data::Matrix{Float64}(undef,dim,max_lines)
    stream = tryopen(data_file)
    
    nlines::Int64 = 1
    while nlines <= max_lines
        line = readline(stream)
        nfields = split(line)
        if nfields != dim
            println("Wrong number of fields at line $nlines. Bailing out.")
            exit(1)
        end
        for j in 1:dim
            x::Float64 = tryparse(Float64,string(fields[j]))
            if x == nothing
                println("Can't parse field $j of $line = $(field[j]).  Bailing out")
                exit(1)
            end
            Data[nlines,j] = x
        end #j loop
        nlines += 1
    end #nlines loop
    println("read $nlines from $data_file:\n",Data)
end

#------------------------------------------------------
#Begin execution here
include("CommandLine.jl")
if occursin("Cluster.jl",PROGRAM_FILE)
  model_main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    model_main(map(string,split(cmd)))
  end
end 
