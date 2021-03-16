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
  defaults = Dict{String,Any}("nstates"=>64, "dim"=>5,"ndata"=>0, "file_dir" => ".",
                              "data_file"=>"sim_data.txt","model_file"=>"","out_file"=>"predictions.txt")
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
  stream = tryopen(data_file)
  all_lines = readlines(stream)
  if(ndata == 0)
    ndata = length(all_lines)
  end
  rnd = my_round(3)
  all_data = fill(0.0,ndata,dim)
  for i in 1:ndata
    field = map(string,split(all_lines[i])) # split the ith line
    all_data[i,:] = [myparse(Float64,field[j+1]) for j in 1:dim] # save the floats 
  end
#  println("all_data: $(map(rnd,all_data))")
  # OK, we've read in the data and parsed it
  model = Array{Float64,3}(undef,nstates,dim,dim+1)
  omega = Vector{Float64}(undef,nstates)
  W = Welford(dim)

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

    stream = occursin(".gz",model_file) ? GZip.open(model_file) : open(model_file)
    nrecs = 0;
    model_data = readlines(stream)
    println("read ", length(model_data)," lines")
    close(stream)
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
  Sigma_11_inv = Array{Float64,3}(undef,nstates,dim1,dim1) # covariance matrix of the predictors
  Sigma_21 = Array{Float64,2}(undef,nstates,dim1)
  mu_1 = Array{Float64,2}(undef,nstates,dim1)
  mu_2 = Array{Float64,1}(undef,nstates)
  mu_bar = Array{Float64,1}(undef,nstates)
  odds = Array{Float64,1}(undef,nstates)
  Sigma_bar = Array{Float64,1}(undef,nstates)

  for j in 1:nstates
    mu = model[j,:,dim+1] # get the last column
    # notation follows Wikipedia: 'Multivariate Normal Distributions' with 1 & 2 interchanged
    mu_1[j,:] = mu[1:dim1] # mean threat predictors (everything but the threat)
    mu_2[j] = mu[dim] # mean observed threat
    Sigma = model[j,:,1:dim] # full covariance matrix
    Sigma_11 = Sigma[1:dim1,1:dim1] # covariance matrix of the predictors
    Sigma_11_inv[j,:,:] = inv(Sigma_11)
    Sigma_21[j,:] = Sigma[dim,1:dim1]
    Sigma_bar[j] = sqrt(Sigma[dim,dim] - transpose(Sigma_21[j,:])*Sigma_11_inv[j,:,:]*Sigma_21[j,:])
  end
  #Now make a prediction and score it
  #NOTE:  this is how to initialize an array.
  state_score = fill(0.0,nstates) # a separate score for each state
  sigmage = fill(0.0,nstates)
  sq_error = fill(0.0,nstates)
  score = 0
  for i in 1:ndata
    data = all_data[i,:]
    pred = data[1:dim1] # threat predictors 
    avg_odds = 0
    
    for j in 1:nstates
      mu_bar[j] = mu_2[j] + transpose(Sigma_21[j,:])*Sigma_11_inv[j,:,:]*(pred - mu_1[j,:])
      if mu_bar[j] < 0
        mu_bar[j] = 0
      elseif mu_bar[j] > 1
        mu_bar[j] = 1
      end
      sig = abs(data[dim]-mu_bar[j])/Sigma_bar[j]
      sigmage[j] += sig
      sq_error[j] += (data[dim] - mu_bar[j])*(data[dim] - mu_bar[j])
      if sq_error[j] > ndata
        println("sq_error[$j] = $(sq_error[j]) = ($(data[dim]) - $(mu_bar[j]))^2 at line $nlines")
        exit(0)
      end
     
      # The conditional threat distribution given a and state j is \N(mu_bar,sigma_bar) 
      d = Normal(mu_bar[j], Sigma_bar[j])
      odds[j] = pdf(d,data[dim])/(cdf(d,1)-cdf(d,0))
      # let r = data[dim].  r is the fractional rank of the given threat, fr(threat) for this flowset.
      # mu_bar[j] is the predicted value of r based on the model and data[1:dim1]
      # If dx is the length of a small interval I around r, then prob_jdx is the conditional
      # probability that the fractional threat lies in I given that it lies in [0,1] and that the true state is j.
      # the random probability is just dx, so odds[j] is the odds over random that fr(threat) lies in I in state j 
      
      avg_odds += omega[j]*odds[j] # weighted average over states
      if odds[j] <= 0
        println("odds_$j at line $nlines: $odds[j]")
        continue
      end
      state_score[j] += log(odds[j])
      log_odds = log(odds[j])
      true_mu = sum(pred)/dim1
      println("\ndata $i: log_odds = $(rnd(log_odds)). mu_bar = $(rnd(mu_bar[j])), Sigma_bar = $(rnd(Sigma_bar[j])), mu = $(rnd(data[dim])), true_mu = $(rnd(true_mu)), sigmage = $(rnd(sig))")
    end
    if avg_odds <= 0
      println("avg odds at line $nlines: $avg_odds")
    else
      score += log(avg_odds) # log (marginal density of fr(threat) given model and predictors)
    end
  end

  avg_sigmage = 0
  mean_sq_error = 0;
  max_d = max_s = 0
  for j in 1:nstates
    avg_sigmage += omega[j]*sigmage[j]
    mean_sq_error += omega[j]*sq_error[j]
  end
  max_d = argmax(state_score)
  min_s = argmin(sigmage)
  println("min_s = $min_s")
  println("processed $ndata observations from $data_file")
  score = round(score/(ndata*log(2)),digits=3)
  avg_sigmage = round(avg_sigmage/ndata,digits = 3)
  rms_error = round(sqrt(mean_sq_error/ndata),digits = 3)
  max_state_score = round(state_score[max_d]/(ndata*log(2)),digits=3)
  min_sigmage = round(sigmage[min_s]/ndata,digits=3)
  println("score = $score bits/obs., avg_sigmage = $avg_sigmage, rms error: $rms_error")
  println("max state score = $(max_state_score) bits/obs. at state $max_d, min_sigmage = $min_sigmage at state $min_s")
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


