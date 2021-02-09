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

"""

 

struct cmd_line
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


function parse(s::Array{String} = ARGS)
  c = cmd_line([],[])
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

function get_val(option::String, s::Array{String} = ARGS) # get the value of option from the command line
  c = parse(s)
  i = 0
  r = nothing
  for opt in c.option
    i += 1
    if opt == option
      r = c.value[i]
      break; #NOTE: if there is a duplicated option, the first one is chosen
    end
  end
  return r 
end

    

c = parse()
println("options: ",c.option)
println("values: ",c.value)
println("\n")
r = ""
r = get_val(ARGS[1])
if r != nothing
  println("found $(ARGS[1]) = $r")
else
  println(ARGS[1]," not found")
end

exit(0)

