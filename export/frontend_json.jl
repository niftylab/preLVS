if !isdefined(@__MODULE__, :_PRELVS_FRONTEND_JSON_JL_)
const _PRELVS_FRONTEND_JSON_JL_ = true

using Dates

# ============================================================================
# Frontend LVS JSON Export
#
# Exports LVS connectivity results as a JSON file that the frontend can
# consume for net highlighting. Maps connected component IDs back to raw
# (pre-merge) metal geometry so the frontend can match elements by exact
# integer coordinates.
# ============================================================================

"""
    build_raw_to_component_map(mdata, modata, component_infos) -> Dict{MVector, Int}

Map each raw metal (MVector) to its connected component ID by spatial
containment matching against merged metals (MOVector).

A raw metal at (layer, p_coord) with s_range [a, b] belongs to the merged
metal at the same (layer, p_coord) whose s_range fully contains [a, b].
"""
function build_raw_to_component_map(
    mdata::MData,
    modata::MOData,
    component_infos::Vector{ComponentInfo}
)::Dict{MVector, Int}

    # Step 1: Build MOVector.idx → component_id lookup
    idx_to_component = Dict{Int, Int}()
    for comp in component_infos
        for mo in comp.nodes
            idx_to_component[mo.idx] = comp.number
        end
    end

    # Step 2: For each raw metal, find the merged metal that contains it
    raw_to_component = Dict{MVector, Int}()

    for (layer, mlayer) in mdata.metals
        if !haskey(modata.metals, layer)
            continue
        end
        mo_layer = modata.metals[layer]

        for (p_coord, raw_metals) in mlayer.metals
            if !haskey(mo_layer.metals, p_coord)
                continue
            end
            merged_metals = mo_layer.metals[p_coord]

            for raw in raw_metals
                raw_start = min(raw.points[1].s_coord, raw.points[2].s_coord)
                raw_end = max(raw.points[1].s_coord, raw.points[2].s_coord)

                for merged in merged_metals
                    merged_start = min(merged.points[1].s_coord, merged.points[2].s_coord)
                    merged_end = max(merged.points[1].s_coord, merged.points[2].s_coord)

                    if raw_start >= merged_start && raw_end <= merged_end
                        comp_id = get(idx_to_component, merged.idx, nothing)
                        if !isnothing(comp_id)
                            raw_to_component[raw] = comp_id
                        end
                        break  # A raw metal is contained in exactly one merged metal
                    end
                end
            end
        end
    end

    return raw_to_component
end

"""
    build_via_to_component_map(component_infos) -> Dict{VPoint, Int}

Map each VPoint to its connected component ID.
Direct extraction from ComponentInfo.vias.
"""
function build_via_to_component_map(
    component_infos::Vector{ComponentInfo}
)::Dict{VPoint, Int}

    via_to_component = Dict{VPoint, Int}()
    for comp in component_infos
        for vp in comp.vias
            via_to_component[vp] = comp.number
        end
    end
    return via_to_component
end

"""
    mvector_to_json_dict(mv, orientation_list, component_id, net) -> Dict

Convert a raw MVector to JSON-compatible dictionary format.
Reconstructs [[x0,y0],[x1,y1]] from (p_coord, s_range) using layer orientation.
"""
function mvector_to_json_dict(
    mv::MVector,
    orientation_list::Vector{String},
    component_id::Union{Int, Nothing},
    net::Union{String, Nothing}
)::Dict{String, Any}

    s_start = min(mv.points[1].s_coord, mv.points[2].s_coord)
    s_end = max(mv.points[1].s_coord, mv.points[2].s_coord)

    if orientation_list[mv.layer] == "VERTICAL"
        # p_coord is x, s_coord is y
        xy = [[mv.p_coord, s_start], [mv.p_coord, s_end]]
    else
        # p_coord is y, s_coord is x
        xy = [[s_start, mv.p_coord], [s_end, mv.p_coord]]
    end

    origin = isnothing(mv.laygo_origin) ? nothing : mv.laygo_origin.traceback

    return Dict{String, Any}(
        "layer" => "M$(mv.layer)",
        "xy" => xy,
        "p_coord" => mv.p_coord,
        "s_range" => [s_start, s_end],
        "width" => mv.width,
        "component_id" => component_id,
        "net" => net,
        "laygo_origin" => origin
    )
end

"""
    vpoint_to_json_dict(vp, component_id, net) -> Dict

Convert a VPoint to JSON-compatible dictionary format.
"""
function vpoint_to_json_dict(
    vp::VPoint,
    component_id::Union{Int, Nothing},
    net::Union{String, Nothing}
)::Dict{String, Any}

    origin = isnothing(vp.laygo_origin) ? nothing : vp.laygo_origin.traceback

    return Dict{String, Any}(
        "layer" => vp.layer,
        "xy" => vp.xy,
        "extension" => vp.extension,
        "component_id" => component_id,
        "net" => net,
        "laygo_origin" => origin
    )
end

"""
    export_lvs_frontend_json(
        libname, cellname, mdata, vdata, modata,
        component_infos, error_infos, error_cnt,
        orientation_list, output_path
    ) -> String

Export LVS results as a JSON file for frontend net connectivity highlighting.

Maps connected component IDs back to raw (pre-merge) metals so the frontend
can match elements by exact integer geometry.

Returns the output file path.
"""
function export_lvs_frontend_json(
    libname::String,
    cellname::String,
    mdata::MData,
    vdata::VData,
    modata::MOData,
    component_infos::Vector{ComponentInfo},
    error_infos::Vector{ErrorInfo},
    error_cnt::Dict{String, Int},
    orientation_list::Vector{String},
    output_path::String
)::String

    # Build mappings: raw element → component_id
    raw_to_comp = build_raw_to_component_map(mdata, modata, component_infos)
    via_to_comp = build_via_to_component_map(component_infos)

    # Build component_id → netname lookup
    comp_id_to_net = Dict{Int, Union{String, Nothing}}()
    for comp in component_infos
        comp_id_to_net[comp.number] = comp.netname
    end

    # === Metadata ===
    passed = error_cnt["total"] == 0
    metadata = Dict{String, Any}(
        "library" => libname,
        "cell" => cellname,
        "timestamp" => Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"),
        "passed" => passed,
        "version" => "1.0.0"
    )

    # === Components ===
    components_json = [
        Dict{String, Any}(
            "id" => comp.number,
            "net" => comp.netname,
            "is_consistent" => comp.is_consistent
        )
        for comp in component_infos
    ]

    # === Metals (raw, pre-merge, with component assignment) ===
    metals_json = Dict{String, Any}[]
    for (layer, mlayer) in mdata.metals
        if layer > length(orientation_list)
            continue
        end
        for (_, raw_metals) in mlayer.metals
            for mv in raw_metals
                comp_id = get(raw_to_comp, mv, nothing)
                net = isnothing(comp_id) ? nothing : get(comp_id_to_net, comp_id, nothing)
                push!(metals_json, mvector_to_json_dict(mv, orientation_list, comp_id, net))
            end
        end
    end

    # === Vias (with component assignment) ===
    vias_json = Dict{String, Any}[]
    for (_, vlist) in vdata.vlists
        for vp in vlist.vpoints
            comp_id = get(via_to_comp, vp, nothing)
            net = isnothing(comp_id) ? nothing : get(comp_id_to_net, comp_id, nothing)
            push!(vias_json, vpoint_to_json_dict(vp, comp_id, net))
        end
    end

    # === Errors ===
    errors_json = Dict{String, Any}[]
    for err in error_infos
        error_dict = Dict{String, Any}(
            "type" => string(err.type),
            "component_id" => err.number,
            "message" => get_error_string(err)
        )
        # Add extra fields per error type
        if err.type == SHORT
            error_dict["nets"] = filter(!isnothing, [err.actual_netname, err.expected_netname])
        elseif err.type == OPEN
            error_dict["net"] = err.expected_netname
        end
        push!(errors_json, error_dict)
    end

    # === Summary ===
    summary = Dict{String, Any}(
        "total_components" => length(component_infos),
        "total_metals" => length(metals_json),
        "total_vias" => length(vias_json),
        "shorts" => error_cnt["short"],
        "opens" => error_cnt["open"],
        "floating" => error_cnt["floating"],
        "passed" => passed
    )

    # === Assemble and write ===
    result = Dict{String, Any}(
        "metadata" => metadata,
        "components" => components_json,
        "metals" => metals_json,
        "vias" => vias_json,
        "errors" => errors_json,
        "summary" => summary
    )

    mkpath(dirname(output_path))
    open(output_path, "w") do io
        JSON.print(io, result, 2)
    end

    @info "LVS frontend JSON exported" path=output_path metals=length(metals_json) vias=length(vias_json) components=length(component_infos)

    return output_path
end

end # include guard
