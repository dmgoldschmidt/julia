include("/home/parallels/code/julia/util.jl")
using LinearAlgebra
#using Debugger
#break_on(:error)
#using Printf

function QR(R::Matrix{Float64})
    nrows = size(R)[1]
    ncols = size(R)[2]
    @assert(nrows >= ncols)

    Q = zeros(nrows,nrows)
    for i in 1:nrows
        Q[i,i] = 1.0
    end
    
    for j in 1:ncols 
        for i in j+1:nrows  #zero column j below R[j,j]
            a = R[j,j]*R[j,j]
            b = R[i,j]*R[i,j]
            c = abs(b < a) ? R[j,j]*sqrt(1+b/a) : R[i,j]*sqrt(1+a/b)
  #          println("c = $c, sqrt(a+b) = $(sqrt(a
            cos_t = R[j,j]/c
            sin_t = R[i,j]/c
            M = [cos_t sin_t;-sin_t cos_t]
   #         printmat(M,3,"cos_t sin_t;-sin_t cos_t]: ")
            for k in j:ncols #apply Givens rotation to rows j, i
                x = cos_t*R[j,k] + sin_t*R[i,k]
                R[i,k] = -sin_t*R[j,k] + cos_t*R[i,k]
                R[j,k] = x
            end
            for k in 1:ncols
                x = cos_t*Q[j,k] + sin_t*Q[i,k]
                Q[i,k] = -sin_t*Q[j,k] + cos_t*Q[i,k]
                Q[j,k] = x
            end #k
 #           println("i,j = $i,$j: ");printmat(Q,3,"Q:\n");printmat(R,3,"R:\n")
 #           if i > 2; break;end
        end #i
 #       break
    end
    return Q,R
end


function qr_main(cmd_line = ARGS)
    #=  
1. Generate a random matrix A of size dim x dim
2. Upper triangularize with QR
3. Check Q for orthogonality
4. Check R^tR = A^tA
=# 
                                     
    println("begin qr_main")
    defaults = Dict{String,Any}(
        "dim"=>4,
    )
    cl = get_vals(defaults,cmd_line) # replace defaults with command line values
     dim::Int64 = defaults["dim"]
    @assert(1 <= dim <= 8)

    A = randn(dim,dim)
    printmat(A,3,"A:\n");printmat(transpose(A)*A,3,"A^tA:\n")
    Q,R = QR(A)
    printmat(transpose(Q)*Q, 3, "Q^tQ:\n")
    printmat(R,3,"R:\n")
    printmat(transpose(R)*R,3,"R^tR:\n")
end    
#------------------------------------------------------
#Begin execution here
import Pkg; Pkg.add("Distributions")
using Random, Distributions
include("CommandLine.jl")
if occursin("QR.jl",PROGRAM_FILE)
qr_main(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    qr_main(map(string,split(cmd)))
  end
end 


