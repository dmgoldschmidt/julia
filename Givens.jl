#= Compute the Cholesky matrix C = UA of the normal matrix AtA = C^tC  given the matrix A row-by-row
where U is orthonormal.
=#

include("/home/parallels/code/julia/util.jl")

mutable struct Givens
   sin_t::Float64 
   cos_t::Float64 
    # these are computed by reset below
   Givens() = new(0.0,0.0) 

end

function reset(g::Givens, a0::Float64,b0::Float64)
    println("Givens: reset to a0 = $a0, b0 = $b0")
    if(a0 == 0)
        if(b0 == 0)return
        end
    end
    a = a0*a0
    b = b0*b0
    c0::Float64 = abs(b < a ? a0*sqrt(1+b/a) : b0*sqrt(1+a/b)) # numerical hygene for c = sqrt(a+b)
    println("c0 =$c0")
    g.sin_t = b0/c0
    g.cos_t = a0/c0
    println("exit Givens reset with g = $g, g.sin_t = $(g.sin_t), g.cos_t = $(g.cos_t)")
#    exit()
end

# function rotate(g::Givens,x::Ref{Float64}, y::Ref{Float64}) #NOTE: arguments passed by reference
#     x0 = g.cos_t*x[] + g.sin_t*y[]
#     y[] = -g.sin_t*x[] + g.cos_t*y[]
#     x[] = x0
# end

function rotate(g::Givens,start::Int64,u_a::Vector{Float64}, u_b::Vector{Float64})
    @assert(length(u_a) == length(u_b))
#    println("Begin Givens rotate with u_a:$u_a\nu_b:$u_b\n cos_t = $(g.cos_t),  sin_t = $(g.sin_t)")
    for i in start:length(u_a)
#       println("i = $i")
        x = g.cos_t*u_a[i] + g.sin_t*u_b[i]
#        println("x:$x")
        u_b[i] = -g.sin_t*u_a[i] + g.cos_t*u_b[i]
        u_a[i] = x
 #       exit()
    end
#    println("after Givens rotate we get u_a:$u_a\nu_b:$u_b")
    return u_a, u_b
end

function rotate1(g::Givens, u_a::Vector{Float64}, u_b::Vector{Float64})
    @assert(length(u_a) == length(u_b))
    println("g.rotate1: u_a, u_b = $u_a, $u_b")
    x = [g.cos_t * u_a[j] + g.sin_t * u_b[j] for j in 1:length(u_a)] 
    y = [-g.sin_t * u_a[j] + g.cos_t * u_b[j] for j in 1:length(u_b)]
    println("g.rotate1: x = $(g.cos_t) * $u_a + $(g.sin_t) * $u_b\ny = $(-g.sin_t) * $u_a + $(g.cos_t) * $u_b")
    return x,y
end

# a = 1.0
# b = 2.0
# reset(g,a,b)
# println("After reset: $g")
# t = atan(2.0) 
# s = sin(t)
# c = cos(t)
# println("Check: s = $s, c = $c")
# v = Float64[3.0,4.0]
# u = Float64[1.0,2.0]
# println("Before rotation: v = $v,  u = $u")
# rotate(g,u,v)
# println("After rotation: v = $v, u = $u")



