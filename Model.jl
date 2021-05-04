Model_loaded = true
include("util.jl")

mutable struct Model
  nstates::Int64
  dim::Int64
  omega::Vector{Float64}
  mean::Array{Float64,2}
  inv_cov::Array{Float64,3}
end
Model(nstates,dim) = Model(nstates,dim,zeros(nstates),zeros(nstates,dim),
                           zeros(nstates,dim,dim))
function read_model(nstates::Int64,dim::Int64,fname::String)
  stream = tryopen(fname)
  println("nstates = $nstates, dim = $dim, fname = $fname")
  found = false
  for line in eachline(stream)
    fields = split(line)
    f1 = tryparse(Int64,string(fields[1]))
    println("field 1: $f1")
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
model = read_model(1,8,"model.out")
rnd = my_round(3)
mean1 = map(rnd,model.mean)
cov1 = map(rnd,model.inv_cov)
println("mean: $mean1, \ncov: $cov1")
