#! /home/david/julia-1.5.3/bin/julia

stack = Float64[0]
entry = ""
while entry != "quit"
  top = length(stack)
  print("rpn> ")
  global entry = readline()
  x = tryparse(Float64,entry)
  if(x != nothing)
    push!(stack,x)
#    println("entry is floating point ")
    #    println("stack has ",length(stack)," elements")
    top += 1
  elseif entry == "+"
    temp = pop!(stack)
#    println("add: temp = ",temp)
    #    println("stack: ",stack," has length ",length(stack))
    top -= 1
    stack[top] += temp
  elseif entry == "-"
    temp = pop!(stack)
    top -= 1
    stack[top] -= temp
  elseif entry == "*"
    temp = pop!(stack)
    top -= 1
    stack[top] *= temp
  elseif entry == "/"
    temp = pop!(stack)
    top -= 1
    stack[top] /= temp
  elseif entry == "r"
    if stack[top] == 0
      println("error")
    else
      stack[top] = 1/stack[top]
    end
  elseif entry == "chs"
    stack[top] = -stack[top]
  elseif entry == "sqrt"
    if stack[top] < 0
      println("error")
    else 
      stack[top] = sqrt(stack[top])
    end
  elseif entry == "pi"
    push!(stack,4*atan(1))
    top += 1
  elseif entry == "sin"
    stack[top] = sin(stack[top])
  elseif entry == "cos"
    stack[top] = cos(stack[top])
  elseif entry == "tan"
    stack[top] = tan(stack[top])
  elseif entry == "" #duplicate the top of the stack
    push!(stack,stack[top])
    top += 1
  elseif entry == "pop"
    if(top > 1)
      pop!(stack);
      top -= 1;
    end
  elseif entry == "list"
    println(stack[2:top])
    continue
  end
  println(stack[top])
end
  


