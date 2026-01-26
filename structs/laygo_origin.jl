if !isdefined(@__MODULE__, :_PRELVS_LAYGO_ORIGIN_JL_)
const _PRELVS_LAYGO_ORIGIN_JL_ = true

# LaygoOrigin: 원본 메탈의 출처를 저장하는 구조체
mutable struct LaygoOrigin
    traceback::String
end

# LaygoOrigin 객체의 동일성 정의
function Base.isequal(a::LaygoOrigin, b::LaygoOrigin)
    return isequal(a.traceback, b.traceback)
end

# LaygoOrigin 객체의 해시 값 정의 (Set, Dict에서 사용)
function Base.hash(lo::LaygoOrigin, h::UInt)
    return hash(lo.traceback, h)
end

end # include guard