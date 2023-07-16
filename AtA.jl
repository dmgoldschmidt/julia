#= Compute the Cholesky matrix C = UA of the normal matrix AtA = C^tC  given the matrix A row-by-row
where U is orthonormal.

Programming lessons learned:
1. AtA is originally defined with all parameters undefined.  Then reset is used to define the parameters.
see below or Givens.jl for  examples.  Other attemps to build non-trivial constructors failed.
2. Don't use member functions.  Just provide the struct instance (e.g. "a") in the calling sequence of the function.
Downside:  this means all struct members need to have (i.e "a.") appended to their names
3. Call by reference doesn't really work.  The documentation says that arrays are passed by reference, which certainly 
makes sense, BUT if your function modifies the array contents, you have to return the array, because it seems that
the modified contents don't wind up in the original array.

=#

include("/home/parallels/code/julia/util.jl")
using LinearAlgebra
#using Debugger
#break_on(:error)
#using Printf

include("/home/parallels/code/julia/Givens.jl")

mutable struct AtA
    dim::Int64
    eps::Float64
    C::Matrix{Float64} #Cholesky of the normal matrix: C^tC = A^tA
    U::Matrix{Float64} # Eigenvectors of C^tC
    X::Matrix{Float64} # reusable storage for C and U
    v::Vector{Float64} # reusable storage for the next row of A to be rotated into C

    g::Givens
    AtA() = new() #produce an instance with all parameters undefined.  See reset below to complete the def. 
    # AtA(d::Int64,e::Float64) = new(d,e)
    # X = zeros(2*dim,dim)
    # println("X: $X")
    # C = X[1:dim,:] #first d rows
    # println("C: $C")
    # U = X[d:2*dim,:] #remaining d rows s
    # for i in 1:dim #U is set to the identity matrix
    #     U[i,i] = 1.0
    # end
    # println("U:  $U")
end


function reset(a::AtA, d::Int64,e::Float64) #Julia-style member functions
    a.dim =d
    a.eps =e
    a.g = Givens()
    a.X = zeros(Float64,2*d,d)
    a.C = a.X[1:d,:] #first dim rows
    a.U = a.X[d:2*d,:] #remaining dim rows s
    for i in 1:d #U is set to the identity matrix
        a.U[i,i] =1.0
    end
    a.v = zeros(Float64,d)
end

function add_row(a::AtA, r::Vector{Float64})
    a.v  .= r;  #copy v to r (temporary space -- r will be zeroed out below)
    println("adding row: $(a.v)");
    for i in 1:a.dim
        reset(a.g,a.C[i,i],a.v[i])
        println("a.g: $(a.g)")
        println("a.v: $(a.v)")
 #       x = zeros(a.dim+1-i)
 #      y = zeros(a.dim+1-i)
 #       x,y = rotate(a.g,i,a.v[i:a.dim], a.C[i,i:a.dim])
 #       a.v[i:a.dim] .= x
 #       a.C[i,i:a.dim] .= y
        a.v[i:a.dim], a.C[i,i:a.dim] = rotate1(a.g,a.v[i:a.dim], a.C[i,i:a.dim])
        println("after Givens.rotate at i= $i: a.v = $(a.v)\na.C = $(a.C)")
        exit()
    end
end

function reduce(a::AtA, max_iters::Int64 = 10)
end



function ata_main(cmd_line = ARGS)
    println("begin ata_main")
    defaults = Dict{String,Any}(
    "dim"=>3,
     "max_iters"=>10,
      "eps"=>1.0e-8
    )
    cl = get_vals(defaults,cmd_line) # replace defaults with command line values
    println("parameters: $defaults")
    dim = defaults["dim"]
    @assert(1 <= dim <= 8)
    max_iters = defaults["max_iters"]
    eps = defaults["eps"]
    ata::AtA = AtA()
    reset(ata,dim,eps)
    reset(ata.g,1.0,2.0)
    println("ata.dim = $(ata.dim), ata.eps= $(ata.eps), ata.g = $(ata.g)")
    t = atan(2.0)
    println("Check: $(sin(t)) = $(ata.g.sin_t),  $(cos(t)) = $(ata.g.cos_t)");
    Random.seed!(1234)
    println("seed returned")
#    d = Normal()
 #   Normal(0,1.0)
 #   println("mean(d) = $(mean(d))")
    println("begin add_row test\n C: $(ata.C)")
    A = randn(dim,dim)
    println("A:\n $A")
    for i in 1:dim
        add_row(ata,A[i,1:dim])
    end
    println("after test, C:\n $(ata.C)\nC^tC:\n $( transpose(ata.C)*ata.C)")
end

#------------------------------------------------------
#Begin execution here
import Pkg; Pkg.add("Distributions")
using Random, Distributions
include("CommandLine.jl")
include("Givens.jl")
if occursin("AtA.jl",PROGRAM_FILE)
ata_main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    model_main(map(string,split(cmd)))
  end
end 


