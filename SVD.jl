# function SVDcomp(A::Matrix{Float64}, max_iters::Int64 = 10, eps::Float64 = 1.0e-8)
#     nrowsR::Int64 = nrowsU::Int64 = ncolsU =size(A)[1]
#     ncolsR::Int64 = ncolsV::Int64 = nrowsV::Int64 = size(A)[2]
#     V::Matrix{Float64} = zeros(nrowsV,ncolsV) # column rotations
#     U::Matrix{Float64} = zeros(nrowsU,ncolsU) # row rotations
#     R::Matrix{Float64} = zeros(nrowsR,ncolsR)
#     g::Givens = Givens()

#     #step 0: rotate to upper triangular form and save U = row rotations
#     R .= A #copy to R
#     U,R = QR(R) # R is now upper-triangular
# #    printmat(U'*U,5,"U'*U:\n")

#     for i in 1:ncols; V[i,i] = 1.0; end
#     # step 1: rotate to upper bidiagonal form with row + col rotations

#     for i in 1:nrowsR-2
#         for j in ncolsR:-1:i+2  
#             reset(g,R[i,j-1],R[i,j]) # set up to rotate cols j & j-1 to zero out R[i.j]
#             g_cols::Givens .= g #save it for V update below
#             R[i:nrowsR,j-1],R[i:nrowsR,j] =  rotate1(g,R[i:nrows,j-1],R[i:nrows,j])
#         if R[j,j-1] != 0
#             # now rotate rows j-1 & j to zero out R[j,j-1] which was just set to a non-zero value above
#             reset(g, R[j-1,j-1],R[j,j-1])
#             g_rows::Givens .= g #save it for U update below
#             R[j-1,j-1:ncols],R[j,j-1:ncols] = rotate1(g,R[j-1,j-1:ncols],R[j,j-1:ncols])
#             printmat(R,5,"R-matrix after row rotation at step (i=$i,j=$j):\n")
#         end #if
#         end #for j
#     end #for i
    
#     #now update U and V
#     for j in n:-1,i+2
#         # accumulate the column rotations in V
#         V[1:ncols,j-1],V[1:ncols,j] = rotate1(g,V[1:ncols,j-1],V[1:ncols,j]) #NOTE V has dim ncols x ncols
#         printmat(R,5,"step 1: R-matrix after col rotation only at step (i=$i,j=$j):\n")
#     end    
#             U[j-1,1:ncols],U[j,1:ncols] = rotate1(g,U[j-1,1:ncols],U[j,1:ncols])
#         end #if
#         printmat(R,5,"step 1: R-matrix after row rotation correction at step (i=$i,j=$j):\n")
#     end #for j

#     printmat(U'*U,5,"U'*U after step 1:\n")
    
#     #step 2: a) use column rotations to zero out the upper semi-diagonal and put a non-zero in the lower semi-diagonal
#     #             b) use row rotations to zero out the new lower semi-diagonal and put a non-zero in the upper semi-diagonal
#     #            c) iterate (note that the diagonal is always growing larger)
#     niters = 1
#     max_err::Float64 = 0.0
#     while niters < max_iters
#         max_err = eps
#         println("begin iteration $niters")
#         for j in 1:ncols-1
#             if abs(R[j,j+1]) > eps
#                 if abs(R[j,j+1]) > max_err; max_err = abs(R[j,j+1]);end
#                 println("updating column $(j+1) with R[$j,$(j+1)] = $(R[j,j+1]), max_err = $max_err")
#                 reset(g,R[j,j],R[j,j+1])
#                 R[j:j+1,j], R[j:j+1,j+1] = rotate1(g,R[j:j+1,j], R[j:j+1,j+1])
#                 V[1:ncols,j],V[1:ncols,j+1] = rotate1(g,V[1:ncols,j],V[1:ncols,j+1])
#             end #if
#         end #for j
#         println("R-matrix after step2a:\n"); printmat(R)
#         printmat(U'*U,5,"U'*U after step 2a\n")
 
#         #begin step 2b
#         for i in 1:min(nrows,ncols)-1
#             if abs(R[i+1,i]) > eps
#                 if abs(R[i+1,i]) > max_err; max_err = abs(R[i+1,i]);end
#                 println("updating row $(i+1) with R[$(i+1),$i] = $(R[i+1,i]), max_err = $max_err")
#                 reset(g,R[i,i],R[i+1,i])
#                 R[i,i:i+1],R[i+1,i:i+1] = rotate1(g,R[i,i:i+1],R[i+1,i:i+1])
#                 U[i,1:ncols],U[i+1,1:ncols] = rotate1(g,U[i,1:ncols],U[i+1,1:ncols])
#             end #if
#         end #for i
#         printmat(R,5,"R-matrix during step 2b after  iteration $niters with max_err = $max_err:\n")
#         printmat(U'*U,5,"U'*U after step 2b(iteration $niters\n")
#         niters += 1
#         if max_err <= eps;break;end
#     end #while niters<max_iters
#     println("exiting SVD with niters=$niters, max_err = $max_err")
#     return R,U,V
# end #function SVDcomp

function SVDcomp1(A::Matrix{Float64}, max_iters::Int64 = 10, eps::Float64 = 1.0e-8)
    m::Int64 = size(A)[1]
    n::Int64 = size(A)[2]
    X::Matrix{Float64} = zeros(m+n,m+n)
    V::Matrix{Float64} = zeros(n,n) # column rotations
    U::Matrix{Float64} = zeros(m,m) # row rotations
    R::Matrix{Float64} = zeros(m,n) #reduced A-matrix
    g::Givens = Givens()
    transposed::Bool = false
    if m < n # replace A by A transpose 
        A = A'
        m,n = n,m
        transposed = true
    end
    # function QR requires m >= n
    
    #step 0: rotate to upper triangular form and save U = row rotations
    R .= A #copy to R
    U,R = QR(R)
    X[1:m,1:n] .= R
    X[1:m,n+1:n+m] .= U
    X[m+1:m+n,1:n] = 1.0*Matrix(I,n,n)
    #=  
    R = U*A is now upper-triangular in the upper left m x n quadrant of X 
    Q = upper right m x m quadrant of X
    I (identity matrix) = lower n x n quadrant of X
    =#
    printmat(X,3,"X-matrix after step 0\n")
    # step 1: rotate to upper bidiagonal form with row & col rotations
    for i in 1:m-2
        for j in n:-1:i+2  
            reset(g,X[i,j-1],X[i,j]) # set up to rotate cols j & j-1 to zero out R[i.j]
            X[i:m+n,j-1],X[i:m+n,j] =  rotate1(g,X[i:m+n,j-1],X[i:m+n,j])
        if X[j,j-1] != 0
            # now rotate rows j-1 & j to zero out R[j,j-1] which was just set to a non-zero value above
            reset(g,X[j-1,j-1],X[j,j-1])
            X[j-1,j-1:m+n],X[j,j-1:m+n] = rotate1(g,X[j-1,j-1:m+n],X[j,j-1:m+n])
            printmat(X,3,"X-matrix after row rotation at step (i=$i,j=$j):\n")
        end #if
        end #for j
    end #for i
    
    #step 2: a) use column rotations to zero out the upper semi-diagonal and put a non-zero in the lower semi-diagonal
    #             b) use row rotations to zero out the new lower semi-diagonal and put a non-zero in the upper semi-diagonal
    #            c) iterate (note that the diagonal is always growing larger)
    niters = 1
    max_err::Float64 = 0.0
    while niters < max_iters
        max_err = eps
        
#        println("begin iteration $niters at step 2a")
        printmat(X,3,"X-matrix before step 2a:\n")
        for j in 1:n-1
            if abs(X[j,j+1]) > eps
                if abs(X[j,j+1]) > max_err
                    max_err = abs(X[j,j+1])
                    println("updated max_err to $max_err at step 2a, iteration $niters, j = $j")
                end
                println("updating column $(j+1) with X[$j,$(j+1)] = $(X[j,j+1]), max_err = $max_err")
                reset(g,X[j,j],X[j,j+1])
                X[j:m+n,j], X[j:m+n,j+1] = rotate1(g,X[j:m+n,j], X[j:m+n,j+1])
            end #if
        end #for j
        printmat(X,3,"X-matrix after step 2a:\n")
         
        println("begin step 2b")
        for i in 1:m-1
            if abs(X[i+1,i]) > eps
                if abs(X[i+1,i]) > max_err
                    max_err = abs(X[i+1,i])
                    println("updated max_err to $max_err at step 2b, iteration $niters, i = $i")
                end
                println("updating row $(i+1) with R[$(i+1),$i] = $(R[i+1,i]), max_err = $max_err")
                reset(g,X[i,i],X[i+1,i])
                X[i,i:m+n],X[i+1,i:m+n] = rotate1(g,X[i,i:m+n],X[i+1,i:m+n])
            end #if
        end #for i
        printmat(X,3,"X-matrix during step 2b after  iteration $niters with max_err = $max_err:\n")
        niters += 1
        if max_err <= eps;break;end
    end #while niters<max_iters
    println("exiting SVD with niters=$niters, max_err = $max_err")
    return transposed ? X' : X
end #function SVDComp1



function SVDmain(cmd_line = ARGS)
    defaults = Dict{String, Any}(
        "nrows" => 3,
        "ncols" => 3,
        "max_iters" => 10,
        "eps" => 1.0e-8,
        "seed" => 12345
    )
    # A = randn(3,5)
    # printmat(A, 3, "A:\n")
    # B = zeros(3,3)
    # for i in 1:3
    #     B[i,i] = 1.0
    # end
    # printmat(B,3,"B:\n")
    # replace_slice(A,1:3,3:5,B)
    # println(A,3,"Modified A:\n")
    # exit(0)

    println("SVDmain: cmd_line = $cmd_line")
    cl = get_vals(defaults,cmd_line)
    nrows::Int64 = defaults["nrows"]
    ncols::Int64 = defaults["ncols"]
    max_iters::Int64 = defaults["max_iters"]
    eps::Float64 = defaults["eps"]
    seed::Int64 = defaults["seed"]
    println("nrows = $nrows, ncols = $ncols,  max_iters = $max_iters, eps = $eps, seed = $seed")

    rng = MersenneTwister(seed)

    A = randn(rng,nrows,ncols)
    printmat(A,5,"Begin SVDmain with max_iters = $max_iters, eps = $eps, and  A-matrix:\n");
    X = SVDcomp1(A,max_iters,eps)
    R::Matrix{Float64} = zeros(nrows,ncols)
    U::Matrix{Float64} = zeros(nrows,nrows)
    V::Matrix{Float64} = zeros(ncols,ncols)
    R .= X[1:nrows,1:ncols]
    U .= X[1:nrows,ncols+1:ncols+nrows]
    V .= X[nrows+1:nrows+ncols,1:ncols]

    printmat(A,5,"Original matrix:\n")
    printmat(R,5,"Singular Values:\n")
    printmat(transpose(U)*U,5,"Is U orthogonal?:\n")
    printmat(transpose(V)*V,5,"Is V orthogonal?:\n")
    printmat(U'*R*V',5,"U'*R*V':\n")
    printmat(A,5,"A")
end

#------------------------------------------------------
#Begin execution here
import Pkg; Pkg.add("LinearAlgebra")
using Random, LinearAlgebra
include("CommandLine.jl")
include("Givens.jl")
include("QR.jl")
if occursin("SVD.jl",PROGRAM_FILE)
    println("ARGS = $ARGS")
    SVDmain(ARGS)
else
  if isinteractive()
    print("enter command line: ")
    cmd = readline()
    SVD_main(map(string,split(cmd)))
  end
end 


