if !isdefined(@__MODULE__, :_STRUCT_STACK_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_STACK_JL_ = true

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

end #endif