include("util.jl")
include("AtA.jl")
using LinearAlgebra

#using Debugger
#break_on(:error)

#using Printf


function Cluster_main(cmd_line = ARGS)
    defaults = Dict{String,Any}(
        "data_file" =>"",
        "out_file" =>"print.out",
        "max_states"=>16,
        "max_lines" =>10000,
        "dim"=>5,
        "max_iters"=>10,
        "eps"=>1.0e-8
    )
    cl = get_vals(defaults,cmd_line) # replace defaults with command line values
    println("parameters: $defaults")
    max_states = defaults["max_states"]
    max_lines = defaults["max_lines"]
    data_file = defaults["data_file"]
    out_file = defaults["out_file"]
    dim = defaults["dim"]
    @assert(1 <= dim <= 8)

    max_iters = defaults["max_iters"]
    eps = defaults["eps"]
    ata::AtA = AtA()
    reset(ata,dim,eps)
    println("ata.dim = $(ata.dim), ata.eps= $(ata.eps), ata.g = $(ata.g)")
    if data_file != ""  # read data from file
        stream = tryopen(data_file)
        nlines::Int64 = 1
        while nlines <= max_lines
            line = readline(stream)
            fields = split(line)
            fields = map(String,fields)
            println("fields: $fields")
            nfields = length(fields)
            if nfields != dim
                println("Wrong number of fields ($nfields) at line $nlines.  exiting read loop")
                break
            end
            for j in 1:dim
                x::Float64 = tryparse(Float64,string(fields[j]))
                if x == nothing
                    println("Can't parse field $j of $line = $(field[j]).  Bailing out")
                    exit(1)
                end
                Data[nlines,j] = x
            end #j loop
            add_row(ata,Data[nlines,1:dim])
            nlines += 1
        end #nlines while loop
        println("read $nlines lines from $data_file:\n",Data[1:nlines,1:dim])
    else # generate random data
        A = randn(2*dim,dim)
        println("A:\n $A")
        for i in 1:2*dim
            add_row(ata,A[i,1:dim])
        end
    end #if
    println("Cholesky:")
    printmat(ata.C)
end #cluster_main

#------------------------------------------------------
#Begin execution here
include("CommandLine.jl")
if occursin("Cluster.jl",PROGRAM_FILE)
  Cluster_main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    Cluster_main(map(string,split(cmd)))
  end
end 
