if !isdefined(@__MODULE__, :_STRUCT_EVENT_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_EVENT_JL_ = true

@enum EPosition START END
@enum EType METAL LABEL VIA NET # NET is not used for sweepline. Only for ErrorEvents
@enum ErrorType WARNING SHORT OPEN FLOATING
include("structure.jl")
include("tree.jl")
# struct Event
#     etype::EType
#     position::EPosition
#     layer::Int
#     xy::SVector{2, Int}
#     range::SVector{2, Int}
#     idx::Int
#     master::Ref{TreeNode{CellData}}
# end
struct Event
    etype::EType
    position::EPosition
    layer::Int
    xy::SVector{2, Int}
    range::SVector{2, Int}
    idx::Int
    master::Tuple{String, String, Int} # (libname, cellname, inst_idx)
end

struct ErrorEvent
    errorType::ErrorType
    event_type::EType
    rect_ref::Int
    rect_encounter::Int
    msg::String

    function ErrorEvent(errorType::ErrorType, event_type::EType, rect_ref::Int)
        return new(errorType, event_type, rect_ref, -1, "")
    end
    
    function ErrorEvent(errorType::ErrorType, event_type::EType, rect_ref::Int, rect_encounter::Int, msg::String)
        return new(errorType, event_type, rect_ref, rect_encounter, msg)
    end
    function ErrorEvent(errorType::ErrorType, event_type::EType, rect_ref::Int, rect_encounter::Int)
        return ErrorEvent(errorType, event_type, rect_ref, rect_encounter, "")
    end
end

function ErrorEvent(; errorType::ErrorType, event_type::EType, rect_ref::Int, rect_encounter::Int)
    return ErrorEvent(errorType, event_type, rect_ref, rect_encounter, "")
end

# mutable struct MRect
#     layer::Int
#     xy::SMatrix{2, 2, Int}
# end

# mutable struct VRect
#     type::String
#     layer::SVector{2,Int}
#     xy::SVector{2,Int}
# end

# mutable struct Label{NT}
#     netname_origin::NT
#     netname::NT
#     xy::SMatrix{2, 2, Int}
#     layer::Int
#     is_pin::Bool
# end


function event_sort_priority(event::Event)
    """
    Example:
    events = Vector{Event}
    sort!(events, by=event_sort_priority)
    for event in events
        println(event)
    end
    """
    # xy[1] 값을 첫 번째 정렬 기준으로 사용
    primary_key = event.xy[1]

    # (EType, EPosition) 조합에 따른 우선순위 값 정의
    secondary_priority = Dict(
        (METAL, START) => 1,
        (LABEL, START) => 2,
        (VIA, START)   => 3,
        (VIA, END)     => 4,
        (LABEL, END)   => 5,
        (METAL, END)   => 6
    )

    # 두 번째 정렬 기준은 우선순위 딕셔너리에서 가져옴
#    secondary_key = get(secondary_priority, (event.type, event.position))
    secondary_key = secondary_priority[(event.etype, event.position)]
    return (primary_key, secondary_key)
end

end #endif