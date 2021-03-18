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
  defaults = Dict{String,Any}("nstates"=>64, "dim"=>5,"ndata"=>0, "file_dir" => "../Bridgery/wsa/07-01",
                              "data_file"=>"rare_cdf.txt","model_file"=>"model.out","out_file"=>"predictions.txt")
  cl = get_vals(defaults,cmd_line) # replace defaults with command line values
  println("parameters: $defaults")
  nstates = defaults["nstates"] # size of model to use
  dim = defaults["dim"] # dimension
  ndata = defaults["ndata"] # defaults to zero for reading the entire data file
  file_dir = defaults["file_dir"] # directory for all i/o files
  data_file = defaults["data_file"] # input features
  model_file = defaults["model_file"] # input model
  out_file = defaults["out_file"] #  output
  if file_dir != "."
    out_file = file_dir*"/"*out_file
    data_file = file_dir*"/"*data_file
    model_file = file_dir*"/"*model_file
  end
  stream = tryopen(data_file) # this is from util.jl
  all_lines = readlines(stream)
  if(ndata == 0)
    ndata = length(all_lines)
  end
  rnd = my_round(3)
  all_data = fill(0.0,ndata,dim)
  for i in 1:ndata
    field = map(string,split(all_lines[i])) # split the ith line
    all_data[i,:] = [myparse(Float64,field[j+1]) for j in 1:dim] # save the floats (col.s 2 -> 2+dim) 
  end
#  println("all_data: $(map(rnd,all_data))")
  # OK, we've read in the data and parsed it
  model = Array{Float64,3}(undef,nstates,dim,dim+1)
  omega = Vector{Float64}(undef,nstates)
  W = Welford(dim) #online mean/covariance computation (util.jl)

  if model_file == "" # build a 1-state model from the data
    for i in 1:ndata
      update(W,all_data[i,:])
    end
    covar = covariance(W)
    ss_mean = mean(W)
    println("single_state_mean: ", [(rnd(ss_mean[j]),"+-",rnd(sqrt(covar[j,j]))) for j in 1:dim])
    nstates = 1
    omega[1] = 1
    model[1,:,dim+1] = mean(W)
    model[1,:,1:dim] = covariance(W)
    
  else # read the model from model_file

    stream = tryopen(model_file)
    nrecs = 0;
    model_data = readlines(stream)
    println("read ", length(model_data)," lines")
    close(stream)
    # now look for the correct model (the file generally contains multiple models)
    found = false
    i = 0
    while i < length(model_data)
      i += 1
      if occursin("state",model_data[i])
        row = map(string,split(model_data[i]))
        if myparse(Int64,row[1]) != nstates; continue; end
        found = true
        break
      end
    end
    if !found
      println(nstates,"-state model not found.  Bailing out.\n")
      exit(1)
    end
    
    # OK, we have found the right model.  Now read it in
    i += 1
    row = map(string,split(model_data[i])) #the first record is omega
    omega = [parse(Float64,field) for field in row]
    for j in 1:nstates
      for k in 1:dim
        i += 1
        row = map(string,split(model_data[i]))
        rowf = [parse(Float64,field) for field in row]
        for l in k:dim+1 #note: the last column is the mean!
          model[j,k,l] = round(rowf[l-k+1],digits=3) # the first dim col.s are the UT part of the inverse cholesky
        end
        for l in k+1:dim
          model[j,l,k] = 0 # the LT zeros are not stored in the model file
        end
      end
      Cinv = Matrix{Float64}(model[j,1:dim,1:dim]) # inverse cholesky 
      model[j,:,1:dim] = inv(Cinv*transpose(Cinv)) # reconstruct the covariance matrix. Last col. is still the mean
    end
  end
  # OK, we now have model[:,:,:] either from the model file or we have a 1-state model directly from data
  # Now compute the conditional distributions
  dim1::Int64 = dim - 1
  Sigma_11_inv = Array{Float64,3}(undef,nstates,dim1,dim1) # inverse marginal covariance matrix of the predictors
  Sigma_21 = Array{Float64,2}(undef,nstates,dim1)
  mu_1 = Array{Float64,2}(undef,nstates,dim1) # mean training predictor
  mu_2 = Array{Float64,1}(undef,nstates) # mean goal (threat)
  mu_bar = Array{Float64,1}(undef,nstates) # conditional mean prediction for a given set of predictors
  Sigma_bar = Array{Float64,1}(undef,nstates) # conditional variance
  sqrt_det_Sigma_11 = Array{Float64,1}(undef,nstates) # the name says it
  for j in 1:nstates
    mu = model[j,:,dim+1] # get the last column
    # notation follows Wikipedia: 'Multivariate Normal Distributions' with 1 & 2 interchanged
    mu_1[j,:] = mu[1:dim1] # mean threat predictors (everything but the threat)
    mu_2[j] = mu[dim] # mean training  threat
    Sigma = model[j,:,1:dim] # full covariance matrix
    Sigma_11 = Sigma[1:dim1,1:dim1] # covariance matrix of the marginal distribution of the predictors
    Sigma_11_inv[j,:,:] = inv(Sigma_11)
    Sigma_21[j,:] = Sigma[dim,1:dim1]
    Sigma_bar[j] = Sigma[dim,dim] - transpose(Sigma_21[j,:])*Sigma_11_inv[j,:,:]*Sigma_21[j,:]
    # sigma_bar is the conditional variance which, unlike mu_bar is independent of the actual predictor values 
    sqrt_det_Sigma_11[j] = sqrt(det(Sigma_11)) 
  end
  #Now make a prediction and score it
  #NOTE:  this is how to initialize an array.
  best_state_score = 0
  score = 0
  weight = Array{Float64,1}(undef,nstates)
  for i in 1:ndata
    data = all_data[i,:]
    pred = data[1:dim1] # threat predictors 
    tot_weight = 0
    best_state::Int64 = 1
    avg_mu_bar::Float64 = 0
    avg_Sigma_bar::Float64 = 0
    for j in 1:nstates
      temp = Sigma_11_inv[j,:,:]*(pred-mu_1[j,:])
      mu_bar[j] = mu_2[j] + transpose(Sigma_21[j,:])*temp
      weight[j] = exp(-.5*(transpose(pred-mu_1[j,:])*temp))/sqrt_det_Sigma_11[j]
      # weight[j] is proportional to the  marginal density of pred.  It measures how well pred matches the model
      tot_weight += weight[j]
      if weight[j] > weight[best_state]; best_state = j ; end
      if mu_bar[j] < 0
        mu_bar[j] = 0
      elseif mu_bar[j] > 1
        mu_bar[j] = 1
      end
      avg_mu_bar += weight[j]*mu_bar[j]
      avg_Sigma_bar += weight[j]*Sigma_bar[j]
    end
    avg_mu_bar /= tot_weight
    avg_Sigma_bar /= tot_weight
    d_avg = Normal(avg_mu_bar,sqrt(avg_Sigma_bar))
    # the (weighted) average conditional distribution for this data point

    best_mu = mu_bar[best_state]
    best_Sigma = Sigma_bar[best_state]
    d_best = Normal(best_mu, sqrt(best_Sigma))
    # the conditional distribution of the best state for this data point
    
    # End prediction section.  Begin scoring section
    # This is where we trot out data[dim], the quantity we're trying to predict
    
    best_odds = pdf(d_best,data[dim])/(cdf(d_best,1)-cdf(d_best,0))
    avg_odds = pdf(d_avg,data[dim])/(cdf(d_avg,1)-cdf(d_avg,0))

    # explanation:
      # let r = data[dim].  r is the fractional rank of the given threat, fr(threat) for this flowset.
      # mu is the predicted value of r based on the model and data[1:dim1]
      # If dx is the length of a small interval I around r, then odds*dx is the conditional
      # probability that the fractional threat lies in I given that it lies in [0,1].
      # the random probability is just dx, so odds is the odds over random that fr(threat) lies in I

    score += log(avg_odds) # log (marginal density of fr(threat) given model and predictors)
    best_state_score += log(best_odds)
  end # main data loop
  
  score /= ndata*log(2)
  best_state_score /= ndata*log(2)
  println("processed $ndata observations from $data_file")
  println("score = $(rnd(score)) bits/obs, best_state_score = $(rnd(best_state_score)) bits/obs.")
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


