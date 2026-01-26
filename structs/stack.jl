if !isdefined(@__MODULE__, :_PRELVS_STACK_JL_)
const _PRELVS_STACK_JL_ = true

struct CustomStack{T}
    items::Vector{T}

    function CustomStack{T}() where T
        new(Vector{T}())
    end
end

# Push an element onto the stack
function push_stack!(stack::CustomStack, item)
    push!(stack.items, item)
end

# Pop an element off the stack
function pop_stack!(stack::CustomStack)
    isempty(stack.items) && error("Stack is empty")
    pop!(stack.items)
end

# Check if the stack is empty
function is_empty_stack(stack::CustomStack)
    isempty(stack.items)
end

end # include guard
