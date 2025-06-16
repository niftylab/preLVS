struct Stack{T}
    items::Vector{T}

    function Stack{T}() where T
        new(Vector{T}())
    end
end

# Push an element onto the stack
function push_stack!(stack::Stack, item)
    push!(stack.items, item)
end

# Pop an element off the stack
function pop_stack!(stack::Stack)
    isempty(stack.items) && error("Stack is empty")
    pop!(stack.items)
end

# Check if the stack is empty
function is_empty_stack(stack::Stack)
    isempty(stack.items)
end

