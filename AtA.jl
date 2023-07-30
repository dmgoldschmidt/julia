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
    C::Matrix{Float64} #Cholesky of the normal matrix: C^tC = A^tA. 
    U::Matrix{Float64} # Eigenvectors of C^tC.  
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
#    a.X = zeros(Float64,2*d,d)
    a.U = zeros(Float64,d,d)
    a.C = zeros(Float64,d,d)
    for i in 1:d #U is set to the identity matrix
        a.U[i,i] =1.0
    end
    a.v = zeros(Float64,d)
end

function add_row(a::AtA, r::Vector{Float64})
    a.v  .= r;  #copy v to r (temporary space -- r will be zeroed out below)
#    println("ata.add_row: adding row: $(a.v)");
    for i in 1:a.dim
        reset(a.g,a.C[i,i],a.v[i])
        rnd = my_round(3)
#        println("begin add_row at i = $i, a.g: $(a.g)\na.C[$i,$i]: $(rnd(a.C[i,i]))\na.v: $(a.v)\n")
#        println("a.v: $(a.v)")
 #       x = zeros(a.dim+1-i)
 #      y = zeros(a.dim+1-i)
 #       x,y = rotate(a.g,i,a.v[i:a.dim], a.C[i,i:a.dim])
 #       a.v[i:a.dim] .= x
 #       a.C[i,i:a.dim] .= y
        a.C[i,i:length(r)],a.v[i:length(r)] = rotate1(a.g,a.C[i,i:length(r)],a.v[i:length(r)])
 #       println("after Givens.rotate at i= $i: a.v = $(a.v)\na.C = $(a.C)")
 #       exit()
    end
end

function reduce(a::AtA, max_iters::Int64 = 10, eps::Float64 = 1.0e-8)
    println("Begin reduce with max_iters = $max_iters, eps = $eps, C-matrix:\n"); printmat(a.C)
    # step 1: rotate to upper bidiagonal form
    d = a.dim
    for i in 1:d-2
        for j in d:-1:i+2
            reset(a.g,a.C[i,j-1],a.C[i,j]) # rotate cols j & j-1 to zero out C[i.j]

            a.C[i:d,j-1],a.C[i:d,j] =  rotate1(a.g,a.C[i:d,j-1],a.C[i:d,j]) 
            a.U[1:d,j-1],a.U[1:d,j] = rotate1(a.g,a.U[1:d,j-1],a.U[1:d,j])
            #NOTE: accumulate the column rotations in U
#             println("C-matrix after col rotation only at step (i=$i,j=$j):\n"); printmat(a.C)
        
            if a.C[j,j-1] != 0
                # now rotate rows j-1 & j to zero out C[j,j-1] which was just set to a non-zero value above
                reset(a.g, a.C[j-1,j-1],a.C[j,j-1])
                a.C[j-1,j-1:d],a.C[j,j-1:d] = rotate1(a.g,a.C[j-1,j-1:d],a.C[j,j-1:d])
  #              println("C-matrix after row rotation at step (i=$i,j=$j):\n"); printmat(a.C)
                #NOTE: row rotations do not need be saved
            end #if
        end #for j
    end #for i

    #step 2: a) use column rotations to zero out the upper semi-diagonal and put a non-zero in the lower semi-diagonal
    #             b) use row rotations to zero out the new lower semi-diagonal and put a non-zero in the upper semi-diagonal
    #            c) iterate (note that the diagonal is always growing larger)
    done::Bool = false
    niters = 1
    while !done && niters < max_iters
        done = true
        for j in 1:d-1
            if abs(a.C[j,j+1]) > eps
                reset(a.g,a.C[j,j],a.C[j,j+1])
                a.C[j:j+1,j], a.C[j:j+1,j+1] = rotate1(a.g,a.C[j:j+1,j], a.C[j:j+1,j+1])
                a.U[1:d,j],a.U[1:d,j+1] = rotate1(a.g,a.U[1:d,j],a.U[1:d,j+1])
                done = false
            end #if
        end #for j
 #       println("C-matrix after step2a:\n"); printmat(a.C)
        if !done
            done = true
            for i in 1:d-1
                if abs(a.C[i+1,i]) > eps
                    reset(a.g,a.C[i,i],a.C[i+1,i])
                    a.C[i,i:i+1],a.C[i+1,i:i+1] = rotate1(a.g,a.C[i,i:i+1],a.C[i+1,i:i+1])
                    # no need to save row rotation
                    done = false
                end #if
            end #for i
        end #if !done
 #       println("C-matrix after iteration $niters in step 2b:\n"); printmat(a.C)
        niters += 1
    end #while.  Back to the top if not done
    println("exiting reduce with niters = $niters")
end #function

function ata_main(cmd_line = ARGS)
    #=  
1. Generate a random matrix A of size 2*dim x dim
2. Call add_row with each row of A to accumulate Cholesky(A^tA)
3. Call reduce to compute eigenvalues, vectors of A^tA
=# 
                                     
    println("begin ata_main")
    defaults = Dict{String,Any}(
    "dim"=>4,
     "max_iters"=>200,
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
#    reset(ata.g,1.0,2.0)
    println("ata.dim = $(ata.dim), ata.eps= $(ata.eps), ata.g = $(ata.g)")
#    t = atan(2.0)
#    println("Check: $(sin(t)) = $(ata.g.sin_t),  $(cos(t)) = $(ata.g.cos_t)");
    Random.seed!(1234)
    println("begin add_row test\n C: $(ata.C)")
    A = randn(2*dim,dim)
    println("A:\n $A")
    for i in 1:2*dim
        add_row(ata,A[i,1:dim])
    end
    C_orig = zeros(ata.dim,ata.dim)
    C_orig .= ata.C # save original cholesky
    println("after test, C:\n $(ata.C)\nC^tC:\n $( transpose(ata.C)*ata.C)")
    println("A:\n$A\nAtA:\n $(transpose(A)*A)")
    println("------\n\n Begin reduce)")
    reduce(ata,max_iters,eps)
 #   println("\nU^tU:"); printmat(transpose(ata.U)*ata.U)
    N = transpose(C_orig)*C_orig
    println("\nunreduced normal matrix (N):"); printmat(N)
    println("\nEigenvalues (E:"); printmat(transpose(ata.C)*ata.C)
    println("\nUNU^t (diagonalization of N).  Does it equal E?") ; printmat(transpose(ata.U)*N*ata.U)
    println("\nAre the eigenvectors orthonormal?"); printmat(transpose(ata.U)*ata.U)
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


