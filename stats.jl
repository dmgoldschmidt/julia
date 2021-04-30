float_min = 1.0e-100
epsilon = 1.0 + float_min


function gammln(xx::Float64)  #from NR
  j::Int64 = 0
  x::Float64 = 0;
  cof = [57.1562356658629235,-59.5979603554754912,14.1360979747417471,-0.491913816097620199,.339946499848118887e-4,.465236289270485756e-4,-.983744753048795646e-4,.158088703224912494e-3,-.210264441724104883e-3,.217439618115212643e-3,-.164318106536763890e-3,.844182239838527433e-4,-.261908384015814087e-4,.368991826595316234e-5]
  if xx <= 0
    println(stderr,"bad arg in gammln.  Bailing out.")
    exit(1)
  end
  
  y=x=xx
  tmp = x+5.24218750000000000
  tmp = (x+0.5)*log(tmp)-tmp
  ser = 0.999999999999997092

  for j in 1:14
    y += 1
    ser += cof[j]/y
  end
  return tmp+log(2.5066282746310005*ser/x)
end

function gser(a::Float64, x::Float64) 
  gln = gammln(a)
  ap = a
  del = sum = 1.0/a
  while true
    ap += 1.0
    del *= x/ap
    sum += del
    if abs(del) < abs(sum)*epsilon 
      return sum*exp(-x+a*log(x)-gln)
    end
  end
end

function gcf(a::Float64, x::Float64) 
  gln = gammln(a)
  b = x+1.0-a
  c = 1.0/float_min
  d = 1.0/b
  h = d
  i = 1
  while true
    an = -i*(i-a)
    b += 2.0
    d=an*d+b
    if abs(d) < float_min; d=float_min; end
    c=b+an/c
    if abs(c) < float_min; c=float_min; end
    d=1.0/d
    del=d*c
    h *= del
    if abs(del-1.0) <= epsilon
      break
    end
  end
  return exp(-x+a*log(x)-gln)*h
end

function gammq(a::Float64, x::Float64) # incomplete gamma function (chi-square distr.)
  if x < 0.0 || a <= 0.0 || a > 100
    println(stderr,"bad args in gammq.  Bailing out.")
    exit(1)
  end
  # NOTE:  NR uses Gaussian quadrature for a > 100 ( a = deg. of freedom)
  if x == 0.0; return 1.0
  elseif x < a+1.0; return 1.0-gser(a,x)
  else return gcf(a,x)
  end
end 

function pks(z::Float64) # Kolmogorov-Smirnov distribution
  if z < 0
    println(stderr,"bad z in KSdist. Bailing out.")
    exit(1)
  end
  if z < 0.042; return 0.; end
  if z < 1.18 
    y = exp(-1.23370055013616983/(z*z))
    return 2.25675833419102515*sqrt(-log(y))
      *(y + y^9 + y^25 + y^49)
  else 
    x = exp(-2.0*z*z)
    return 1. - 2.0*(x - x^4 + x^9)
  end
end

function qks(z::Float64) 
  if z < 0.
    println(stderr,"bad z in KSdist. Bailing out.")
    exit(1)
  end
  if z == 0.; return 1.; end
  if (z < 1.18); return 1.0 - pks(z); end
  x = exp(-2.0*z*z)
  return 2.0*(x - x^4 + x^9)
end
