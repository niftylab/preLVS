if !isdefined(@__MODULE__, :_STRUCT_RECT_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _STRUCT_RECT_JL_ = true

include("metal_v2.jl")
include("label_v2.jl")
include("via_v2.jl")

struct RectData
    metal_data::MData
    label_data::LData{String}
    via_data::VData
end

end #endif