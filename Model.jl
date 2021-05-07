Model_loaded = true
include("util.jl")
using LinearAlgebra

mutable struct Model
  nstates::Int64
  dim::Int64
  omega::Vector{Float64}
  mean::Array{Float64,2}
  inv_cov::Array{Float64,3}
end
Model(nstates,dim) = Model(nstates,dim,zeros(nstates),zeros(nstates,dim),
                           zeros(nstates,dim,dim))
function write_model(model::Model, stream = stdout, ndigits = 3)
  rnd = my_round(ndigits)
  println(stream,"nstates: $(model.nstates), dim: $(model.dim)")
  mean1 = map(rnd,model.mean)
  cov1 = map(rnd,model.inv_cov);
  for i in 1:model.nstates
    println(stream,"\nstate $i:")
    println(stream,"mean: $(mean1[i,:])")
    println(stream,"\ninverse cholesky:")
    for j in 1:model.dim
      for k in 1:model.dim
        print(stream,cov1[i,j,k]," ")
      end
      print("\n")
    end
  end
end

function read_model(nstates::Int64,dim::Int64,fname::String)
  stream = tryopen(fname)
#  println("nstates = $nstates, dim = $dim, fname = $fname")
  found = false
  for line in eachline(stream)
    fields = split(line)
    f1 = tryparse(Int64,string(fields[1]))
     if nstates != f1
      continue;
    else
      found = true;
      break
    end
  end
  if(!found)
    println(stderr,"file $fname has no $nstates state model. Bailing out.")
    exit(1)
  end
# OK, we found the model
  model = Model(nstates,dim)
  line = readline(stream)
  fields = map(string,split(line))
  l = length(fields)
  if l < nstates
    println(stderr,"read_model: no. of states is $l < $nstates.  Resetting nstates to $l.")
    nstates = model.nstates = l;
  end
              
  model.omega = [myparse(Float64,fields[j]) for j in 1:nstates]
  for i in 1:nstates
    for j in 1:dim
      line = readline(stream)
      fields = map(string,split(line))
      for k in 1:dim-j+1
        model.inv_cov[i,k,k+j-1] = myparse(Float64,fields[k]) 
      end
      model.mean[i,j] = myparse(Float64,fields[dim-j+2])
    end
  end
  return model
end

function prob(model::Model, v::Vector{Float64})
  if(length(v) != model.dim)
    println(stderr,"Model.prob: input vector does not have length $(model.dim). Returning probability zero.")
    return zeros(model.nstates)
  end
  p = zeros(model.nstates)
  sum = 0;
  for s in 1:model.nstates
    x = transpose(model.mean[s,:] - v)
    y = x*model.inv_cov[s,:,:]
    p[s] = exp(-.5*dot(y,y))*det(model.inv_cov[s,:,:])
    sum += p[s]
  end
  for s in 1:model.nstates; p[s] /= sum; end
  return p
end

# model = read_model(2,8,"model.out")
# write_model(model)
# v = model.mean[1,:]
# rnd = my_round(3)
# p = map(rnd,prob(model,v))
# println("prob: $p")


