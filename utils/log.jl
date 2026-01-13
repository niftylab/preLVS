
include("../structs/new_metal.jl")


function log_connected_sets(connected_sets::Dict{String, Set{MVector}}, merged_mdata::MData, log_dir::String)
    # Print the connected sets
    open("$(log_dir)/$(merged_mdata.cellname).txt", "w") do io
        # Print the connected sets
        for (netname, mset) in connected_sets
            println(io, "Netname: $netname")
            println(io, "Connected MVectors: ")
            for mv in mset
                println(io, mv)
            end
            println(io)
        end

        println(io, "Unconnected MVectors:")
        for (layer, mlayer) in merged_mdata.metals
            for (pc, mvlist) in mlayer.metals
                for mv in mvlist
                    if mv.netname === nothing
                        println(io, "MVector $mv has no netname")
                    elseif mv.netname == "OBSTACLE"
                        println(io, "MVector $mv has netname OBSTACLE")
                    end
                end
            end
        end
    end
end


