#! /home/david/julia-1.5.3/bin/julia
struct cmd_line
  option::Array{String}
  value::Array{String}
#  cmd_line(option,value) = new(String["b"],String["a"])
end

function command_line(s::Array{String} = ARGS)
  c = cmd_line([],[])
  last_was_option::Bool = false
  item_no = 0
  if length(s) == 0; return c;end
  for item in s
    item_no += 1
    if item[1] == '-'
      if last_was_option # more than one option in a row
        println("two options in a row at item no ",item_no," = ",item)
        push!(c.value,"") # previous option has no value
      end
      last_was_option = true
      if length(item) >= 2 && item[2] == '-' # long style --option
        x = findall("=",item[3:end])
        if(length(x) > 0) # --option=value
          for i in x
            push!(c.option,item[3:i])
            push!(c.value,item[i+1:end])
          end
        else # no =value 
          push!(c.option,item[3:end])
        end
      else # single letter option followed immediately by value
        push!(c.option,string(item[2]))
        push!(c.value,item[3:end])
        last_was_option = false
      end
    else #it's a value
      println(item," is a value")
      if !last_was_option
        println("pushing blank option for item = ",item)
        push!(c.option,"") # two values in a row so this value has no option
      end
      last_was_option = false
      if item == ""; println("pushing blank value at item_no ",item_no);end
      push!(c.value,item)
    end
  end
  return c
end

function get_arg(s::String)
  c = command_line()
  i = 0
  r = ""
  for opt in c.option
    i += 1
    if opt == s
      if length(opt) == 1 && c.value[i] == "" && length(c.value) >= i+1 && c.option[i+1] == ""
        r = c.value[i+1] # this is the ambiguous case. If it looks like e.g. "-f value" return value
      else
        r = c.value[i]
      end
    end
  end
  return r 
end

    

c = command_line()
println("options: ",c.option)
println("values: ",c.value)
r = ""
r = get_arg(ARGS[1])
if r != ""
  println("found ",ARGS[1], ", arg = ",r)
else
  println(ARGS[1]," not found")
end

exit(0)

