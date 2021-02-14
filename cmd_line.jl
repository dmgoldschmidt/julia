#! /home/david/julia-1.5.3/bin/julia
"""
command line(s) parses s = Array{String} whose entries are strings that we call fields.
The default argument is ARGS, which gives the command line by which the enclosing julia 
program was invoked.  

Fields beginning with the character '-' are called "options", all other fields are called 
"values" with two exceptions:
  1. negative numbers
  2. the one-character substring "-"
which are also values. 

The second character of an option may also be '-', in which case the remainder of the field is 
the option name which cannot include the character '='. A field of the form "--option=value" is equivalent
to the pair of consecutive fields "--option",  "value".  

If the second field character is a letter, that character becomes the option
name and the remainder of the field, if it is non-empty, becomes the value 
associated to that option. 
 
command_line returns an instance of the struct cmd_line below, consisting of two Array{String}
arrays of the same length.  This creates a pairing (option[i],value[i])
meaning that option[i] has immediately preceded value[i] in the input s.
However, if two options (resp. values) occur in sequence, the first option
(resp. second value) is given the value "".  This allows maximum flexibility
for the input, as the input array can have options and values in any order as long as the value associated
with an option (if any) follows the option immediately.  The caller doesn't need to know anything about
the order of the inputs and just receives a pair of String Arrays.  Or the caller can use the convenience
function "get_val(option)" which returns the value associated to option, or "" if there is none, or it
returns the nothing value if the requested option was not present.

However, there is an ambiguous parse, namely when, e.g., the
parser encounters "-f file" it means that the option "f" has the value "file",
alothough it might mean (but doesn't) that the option "f" has no associated value and the
value "file" has no associated option because both can legally appear as singletons. 
It is up to the user to disambiguate these two cases.

There is a convenience function get_val which finds the longest matching prefix to a requested string 
in the command line options.  This allows the programmer to specify long options while the user only 
needs to type a unique prefix.  For example, the programmer can ask for the value of the option "xaxis" 
and the user can type -x3.4 (or -x 3.4, or
--x 3.4 or --x=3.4) 
"""

 

struct CommandLine
  option::Array{String}
  value::Array{String}
#  cmd_line(option,value) = new(String["b"],String["a"])
end

  
  

function isnumber(s)
  if tryparse(Int64,s) != nothing || tryparse(Float64,s) != nothing || tryparse(ComplexF64,s) != nothing
    return true
  else
    return false
  end
end

#function (c::CommandLine)(s::Array{String} = ARGS)
function command_line(s::Array{String} = ARGS)
  c = CommandLine([],[])
  last_was_option::Bool = false
  item_no = 0
  if length(s) == 0; return c;end
  for item in s
    item_no += 1
#    println("item no $item_no: ")
    if item[1] == '-'
      if length(item) == 1 || isnumber(item)
        # special case: it's the value '-'  or a negative number
        if !last_was_option #two values in a row
          push!(c.option,"")
        end
        push!(c.value,item)
        last_was_option = false
        continue
      end
      # general case:  it's an option
      if last_was_option # more than one option in a row
#        println("two options in a row at item no ",item_no," = ",item)
        push!(c.value,"") # previous option has no corresponding value
      end
      last_was_option = true
      if item[2] == '-' # long style --option
        x = findall("=",item) # NOTE: item[3:end] returns "" if length == 2 
        if(length(x) > 0) # it's of the form --option=value
          i = x[1][1] # combined format option=value in one string
#          println("i = $i")
          push!(c.option,item[3:i-1])
          push!(c.value,item[i+1:end])
          last_was_option = false
        else # no value 
          push!(c.option,item[3:end])
          last_was_option = true
        end
      else # single letter option 
        push!(c.option,string(item[2]))
        if length(item) > 2 # value follows immediately with no intervening space
          push!(c.value,item[3:end])
          last_was_option = false
        else
          #push!(c.value,"") #option only
          last_was_option = true
        end
      end
    else #it's a value
#      println(item," is a value")
      if !last_was_option
#        println("pushing blank option for item_no $item_no: $item")
        push!(c.option,"") # two values in a row so this value has no option
      end
      last_was_option = false
      if item == ""; println("pushing blank value at item_no ",item_no);end
      push!(c.value,item)
    end
  end
  if last_was_option # last item was an option with no value
    push!(c.value,"")
  end
  return c
end

function get_vals(defaults::Array{Array{Any,1},1}, c::CommandLine)
#function get_val!(option::String, return_value::Array{String}, c::CommandLine, s::Array{String} = ARGS)
  # get the value of option from the command line NOTE: return_value is a 1-element Array to enable call by reference
  if length(c.option) == 0 && length(c.value) == 0
    c = command_line(s)
  end
  for pair in defaults
    i = 0
    best_match = Int64[0,0]
    for opt in c.option
      i += 1
      m = match(Regex("^"*opt),pair[1]) # is opt a prefix of pair[1]? 
      if m != nothing
        if length(m.match) > best_match[1] #this is the longest match so far 
          best_match[1] = length(m.match)
          best_match[2] = i 
        end
      end
    end
    if best_match[1] != 0
      println("returning $(c.value[best_match[2]])")
      if typeof(pair[2]) == String
        pair[2] = c.value[best_match[2]]
      elseif typeof(pair[2]) == Bool
        pair[2] = true
      else
        value = tryparse(typeof(pair[2]),c.value[best_match[2]])
        if value != nothing
          pair[2] = value
          # don't replace the value if we can't parse the string ( or if we didn't find the prefix given in pair[1]
        end
      end
    end
  end
end

# function test(x)
#   println("type of x[]: ",typeof(x[]))
#   x = Ref("reset")
# end

# s = "set"
# r = Ref(s)
# test(r)
# println("now s = ",r[])
# exit(0)
 c = command_line()
println("options: ",c.option)
println("values: ",c.value)
println("\n")
r = 3.5
s = 5
t = "tee"  
defaults = [["x",1.0],["v",false],["t",t]]
println("defaults: ",defaults)
get_vals(defaults,c)
println("defaults are now: $defaults")
println("r,s,t = $r,$s,$t")
exit(0)

