import GZip
stream = GZip.open("../Bridgery/07-01.1M.gz")
nlines = 0
#data = []
netident = Dict{String,Int64}()
netident["dummy"] = -1
for line in eachline(stream)
  global nlines += 1
#  println("nlines = ",nlines)
  field = split(line,'|')
  id = field[4]*"|"*field[6]*"|"*field[9]
#  println("id = ",id)
  if !haskey(netident,id) #it's a new connection
    netident[id] = 1
  else
    netident[id] += 1
  end
end
println("found ",length(netident)," distict netidents")
exit(0)
