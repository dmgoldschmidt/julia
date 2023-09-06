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
parser encounters "-f file" or "--f file", it means that the option "f" has the value "file",
alothough it might mean (but doesn't) that the option "f" has no associated value and the
value "file" has no associated option because both can legally appear as singletons. 
It is up to the user to disambiguate these two cases.

There is a convenience function get_vals which accepts a Dict{String,Any} of default (option,value) pairs
and for each option:
a) chooses the longest matching prefix of an option name found on the command line, and 
b) replaces the default value with the corresponding command line value.  If no match is found, the 
default value is left unchanged.
If a match is found, but the corresponding value cannot be parsed, the default value is replaced by nothing.
Thus the programmer can specify long options while the user only needs to type a unique prefix.  For example, 
the programmer can ask for the value of the option "xaxis" and the user can type -x3.4 (or -x 3.4, or --x 3.4 
or --xaxis=3.4). 
Dictionary entries can themselves be Vectors.  A typical entry might be "A"=>FLoat64[].  To
get command line values into a Vector A, you would just space them out immediately following "--A" like this: 
"--A 1.0 2.3 3.4".  Then if your dictionary is named defaults, the julia code A = defaults["A"] would set A = 
[1.0, 2.3, 3.4].   In general, if a command line option is matched to a dictionary key (say "A")  whose default value is
an Array, all optionless values immediately following "--A" on the command line, up to either another option or
the end of the command line are parsed as eltype(A) and pushed into the given default Array.
"""
CommandLine_loaded = true
include("/home/parallels/code/julia/util.jl")

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
    println("begin command_line with s = $s")
    for item in s
        println("next item in s: $item")
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

function get_vals(defaults::Dict{String,Any}, s::Array = ARGS, c::CommandLine=CommandLine([],[]))
    if length(c.option) == 0 && length(c.value) == 0
         c = command_line(s)
    end
    println("begin get_vals with c.option = $(c.option), c.value = $(c.value)")
    println("keys(defaults) = $(keys(defaults))")
    key::String = ""
    for key in keys(defaults)
        println("\nIs there a match for key $key?")
        opt::String = ""
        i = 0
        best_match = Int64[0,0]
        for opt in c.option
            println("trying to match $opt with $key")
            i += 1
            m = match(Regex("^"*opt),key) # is opt a prefix of key? 
            if m == nothing
                println(" $opt is not a prefix of $key")
                continue
            else 
                if length(m.match) > best_match[1] #this is the longest match so far
                    best_match[1] = length(m.match)
                    best_match[2] = i 
                end #if length ..
            end #if m == nothing
            println("best match for option $opt  is with $key.")
        end # for opt
        if best_match[2] == 0
            println("No match was found for key $key.\n")
            continue; 
        else #we got a match
            value = c.value[best_match[2]]
            println("best match for key $key is with option $opt\n")
            println("parsing $key for type $(typeof(defaults[key]))")
            if typeof(defaults[key]) == String
                defaults[key] = c.value[best_match[2]]
            elseif typeof(defaults[key]) == Bool
                defaults[key] = true
            elseif typeof(defaults[key]) <: Array
                j = best_match[2]
                println("defaults[$key] at $j: ",defaults[key])
                while true # load successive optionless values into the Array
                    push!(defaults[key], myparse(eltype(defaults[key]),c.value[j]))
                    j += 1
                    println("testing option[$j]")
                    if j > length(c.option) || c.option[j] != ""; break;end  # if the next option isn't blank, we're done
                end #while true
                println("defaults[$key]: ",defaults[key]) #print the given Array values
            else
                println("trying to parse $value as type $(typeof(defaults[key]))")
                defaults[key] = tryparse(typeof(defaults[key]),value)
                # NOTE: value = nothing if we find a match to option but can't parse the string 
            end #else
        end #if best_match[1] != 0
    end # for key in keys(defaults)
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
function test_cmd_line(s)
  A = [];
  defaults = Dict{String,Any}("int" => 1, "float" => 2.0, "file" => "none", "Array" => A)
  println("defaults: ",defaults)
  c = get_vals(defaults, s)
  println("options: ",c.option)
  println("values: ",c.value)
  println("\n")
  int = defaults["int"]; float = defaults["float"]; file = defaults["file"];A = defaults["Array"]
  println("defaults are now: $int, $float, $file, $A")
end

