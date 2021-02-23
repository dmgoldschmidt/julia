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
 
command_line returns an instance of the struct CommandLine below, consisting of two Array{String}
arrays of the same length.  This creates a pairing (option[i],value[i])
meaning that option[i] has immediately preceded value[i] in the input s.
However, if two options (resp. values) occur in sequence, the first option
(resp. second value) is given the value "".  This allows maximum flexibility
for the input, as the input array can have options and values in any order as long as the value associated
with an option (if any) follows the option immediately.  The caller doesn't need to know anything about
the order of the inputs and just receives a pair of String Arrays.  Or the caller can use the convenience
function "get_vals" (see below).

However, there is an ambiguous parse, namely when, e.g., the
parser encounters "-f file" it means that the option "f" has the value "file",
alothough it might mean (but doesn't) that the option "f" has no associated value and the
value "file" has no associated option because both can legally appear as singletons. 
It is up to the user to disambiguate these two cases.

There is a convenience function get_vals which accepts a Dict{String,Any} of default (option,value) pairs
and for each option a)chooses the longest matching prefix on the command line, and b) replaces the default 
value with the corresponding command line value.  If no match is found, the default value is left unchanged.
If a match is found, but the corresponding value cannot be parsed, the default value is replaced by nothing.
Thus the programmer can specify long options while the user only needs to type a unique prefix.  For example, 
the programmer can ask for the value of the option "xaxis" and the user can type -x3.4 (or -x 3.4, or --x 3.4 
or --xaxis=3.4) 
"""
CommandLine_loaded = true

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
const StringType = Union{String,SubString{String}}
function get_vals(defaults::Dict{String,Any}, s::Array = ARGS, c::CommandLine=CommandLine([],[]))
  if length(c.option) == 0 && length(c.value) == 0
    c = command_line(s)
  end
  for option in keys(defaults)
    i = 0
    best_match = Int64[0,0]
    for opt in c.option
      i += 1
      m = match(Regex("^"*opt),option) # is opt a prefix of option? 
      if m != nothing
        if length(m.match) > best_match[1] #this is the longest match so far
          println("matched $opt with $option, length $(length(m.match))")
          best_match[1] = length(m.match)
          best_match[2] = i 
        end
      end
    end
    if best_match[1] != 0
#      println("returning $(c.value[best_match[2]])")
#      println("parsing for type $(typeof(defaults[option]))")
      if typeof(defaults[option]) == String
        defaults[option] = c.value[best_match[2]]
      elseif typeof(defaults[option]) == Bool
        Detaults[option] = true
      else
        defaults[option] = tryparse(typeof(defaults[option]),c.value[best_match[2]])
        # NOTE: value = nothing if we find a match to option but can't parse the string 
      end
    end
  end
  return c
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
function test_cmd_line()
#  c = command_line()
  defaults = Dict{String,Any}("int" => 1, "float" => 2.0, "file" => "none")
  println("defaults: ",defaults)
  c = get_vals(defaults,CommandLine([],[]),["-f","--g","-h"])
  println("options: ",c.option)
  println("values: ",c.value)
  println("\n")
  println("defaults are now: $defaults")
end

