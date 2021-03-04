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
using LinearAlgebra
using Random
using Distributions

function predict_main(cmd_line = ARGS)    
  defaults = Dict{String,Any}("nstates"=>64, "dim"=>5,"file_dir" => "../Bridgery/wsa/07-01",
                              "data_file"=>"rare_cdf.txt","model_file"=>"model.out","out_file"=>"predictions.txt")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  nstates = defaults["nstates"] # size of model to use
  dim = defaults["dim"] # dimension 
  file_dir = defaults["file_dir"] # directory for all i/o files
  data_file = defaults["data_file"] # input features
  model_file = defaults["model_file"] # input model
  out_file = defaults["out_file"] #  output
  if file_dir != "."
    out_file = file_dir*"/"*out_file
    data_file = file_dir*"/"*data_file
    model_file = file_dir*"/"*model_file
  end
  stream = occursin(".gz",model_file) ? GZip.open(model_file) : open(model_file)
  nrecs = 0;
  model = Array{Float64,3}(undef,nstates,dim,dim+1)
  omega = Vector{Float64}(undef,nstates)
  data = readlines(stream)
  println("read ", length(data)," lines")
  close(stream)
  found = false
  i = 0
  while i < length(data)
    i += 1
    if occursin("state",data[i])
      row = map(string,split(data[i]))
      if parse(Int64,row[1]) != nstates; continue; end
      found = true
      break
    end
  end
  if !found
    println(nstates,"-state model not found.  Bailing out.\n")
    exit(1)
  end
  # OK, we have the right model
  
  i += 1
  row = map(string,split(data[i]))
  omega = [parse(Float64,field) for field in row]
  dim1 = dim-1
  Sigma_21 = Matrix{Float64}(undef,nstates,dim1)
  Sigma_11_inv = Array{Float64,3}(undef,nstates,dim1,dim1)
  Sigma_bar = Vector{Float64}(undef,nstates)
  mu_1 = Matrix{Float64}(undef,nstates,dim1)
  mu_2 = Vector{Float64}(undef,nstates)
  mu_bar = Vector{Float64}(undef,nstates)
  for j in 1:nstates
    for k in 1:dim
      i += 1
      row = map(string,split(data[i]))
      rowf = [parse(Float64,field) for field in row]
      for l in k:dim+1 #note: the last column is the mean!
        model[j,k,l] = round(rowf[l-k+1],digits=3)
      end
      for l in k+1:dim
        model[j,l,k] = 0 # the zeros are not stored in the model file
      end
    end
    mean = Vector{Float64}(model[j,:,dim+1])
    mu_1[j,:] = mean[1:dim1]
    mu_2[j] = mean[dim]
    Cinv = Matrix{Float64}(model[j,1:dim,1:dim]) # inverse cholesky 
    Sigma = inv(Cinv*transpose(Cinv)) # covariance matrix
    Sigma_11 = Sigma[1:dim1,1:dim1]
    # notation follows Wikipedia: "Multivariate Normal Distributions" with 1 & 2 interchanged
    Sigma_11_inv[j,:,:] = inv(Sigma_11)
    Sigma_21[j,:] = Sigma[dim,1:dim1]
    Sigma_bar[j] = sqrt(Sigma[dim,dim] - transpose(Sigma_21[j,:])*Sigma_11_inv[j,:,:]*Sigma_21[j,:])
    # if j == 2
    #   println("\nstate $j:\nmean: $mean")
    #   print("Sigma:\n", Sigma,"\n")
    #   print("Sigma_11_inv:\n", Sigma_11_inv[j,:,:],"\n")
    #   print("Sigma_21:\n", Sigma_21[j,:],"\n")
    #   print("Sigma_bar: $(Sigma_bar[j])\n")
    # end
  end
  #Now read in the data
  stream = occursin(".gz",data_file) ? GZip.open(data_file) : open(data_file)
  score::Float64 = 0
  nlines::Int64 = 0
  avg_sigmage = 0
  for line in eachline(stream)
    field = map(string,split(line)) # split the ith line
    data = [parse(Float64,field[j+1]) for j in 1:dim] # save the floats 
    a = data[1:dim1] # everything but the threat
    density = 0
    sigmage = 0
    for j in 1:nstates
      mu_bar[j] = mu_2[j] + transpose(Sigma_21[j,:])*Sigma_11_inv[j,:,:]*(a - mu_1[j,:])
      if mu_bar[j] < 0
        mu_bar[j] = 0
      elseif mu_bar[j] > 1
        mu_bar[j] = 1
      end
      sigmage += omega[j]*abs(data[dim]-mu_bar[j])/Sigma_bar[j]
      # The conditional threat distribution given a and state j is \N(mu_bar,sigma_bar) 
      d = Normal(mu_bar[j], Sigma_bar[j])
      density += omega[j]*pdf(d,data[dim])/(cdf(d,1)-cdf(d,0))
              # cond density of actual thread given a,j,and interval = [0,1]
      # if nlines < 10
      #   println("d = $d")
      #   println("mu-bar = $(mu_bar[j]), Sigma_bar = $(Sigma_bar[j])")
      #   println("pdf = $(pdf(d,data[dim])), cdf(1) = $(cdf(d,1)), cdf(0) = $(cdf(d,0))\n")
      # else
      #   exit(0)
      # end
    end
    avg_sigmage += sigmage
    score += log(density) #NOTE: log(density) is the log odds over random in a unit interval
    # if density < 1.0
    #   println("density at line $nlines: $density")
    # end
    nlines += 1
  end
  println("processed $nlines observations from $data_file")
  score = round(score/(nlines*log(2)),digits=3)
  avg_sigmage = round(avg_sigmage/nlines,digits = 3)
  println("prediction score = $score bits per observation, avg sigmage = $avg_sigmage")
end

# execute main iff
# a) it's being run from a file containing the string "predict.jl", or
# b) it's being run from the REPL
if occursin("predict.jl",PROGRAM_FILE)
  include("CommandLine.jl")
  predict_main(ARGS)
else
  if isinteractive()
    include("CommandLine.jl")
    print("enter command line: ")
    cmd = readline()
    predict_main(map(string,split(cmd)))
  end
end # to execute directly from command line: ./predict.jl <ARGS>


