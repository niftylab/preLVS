if !isdefined(@__MODULE__, :_UTIL_VISUAL_JL_)
    # 가드 상수를 현재 모듈 스코프에 직접 정의
    # @eval 없이 const를 직접 사용. 모듈의 top-level에서 include될 때 동작합니다.
    const _UTIL_VISUAL_JL_ = true
# using Pkg
# Pkg.add("JSON3")
using JSON3
using Plots

function visualize_metals(cellname, input_path, output_path)

    # Metal 별 색상 정의
    metal_colors = Dict(
        "Metal1" => :blue,
        "Metal2" => :red,
        "Metal3" => :green,
        "Metal4" => :pink
    )

    # JSON 파일
    data = JSON3.read(open(input_path, "r"), Dict)

    # Initialize the plot
    plot(title="$(cellname) Metal Visualization", xlabel="x", ylabel="y", aspect_ratio=:equal)

    # Iterate over each metal type and its coordinates
    for (metal, coords) in data
        # Metal의 번호가 짝수인지 홀수인지 확인
        metal_number = parse(Int, replace(metal, "Metal" => ""))
        is_even = metal_number % 2 == 0

        # 색상 정의
        color = get(metal_colors, metal, :black)  # Default to black if metal not found in colors
        
        # Plot each segment based on whether it's even (horizontal) or odd (vertical)
        for (key, segments) in coords
            _coord = parse(Int, key)

            for segment in segments
                # Each segment is a list of `START` and `END` points
                start_point = segment[1]
                end_point = segment[2]
                
                if is_even
                    # Even metals: y-coordinate is the key, x-coordinates are in the segment
                    x_start, x_end = start_point["coord"], end_point["coord"]
                    plot!([x_start, x_end], [_coord, _coord], label="", linewidth=2, color=color)
                else
                    # Odd metals: x-coordinate is the key, y-coordinates are in the segment
                    y_start, y_end = start_point["coord"], end_point["coord"]
                    plot!([_coord, _coord], [y_start, y_end], label="", linewidth=2, color=color)
                end
            end
        end
    end

    savefig(output_path)  # Saves the plot as a PNG file
    println("\nPlot saved as $(output_path)")

end



function visualize_vias(cellname, input_path, output_path; scale_factor=1.0)
    # Example color map for different via types
    via_colors = Dict(
        "via_M1_M2_0" => :cyan,
        "via_M1_M2_1" => :magenta,
        "via_M2_M3_0" => :orange,
        "via_M2_M3_1" => :purple,
        "via_M3_M4_0" => :yellow,
        "via_M3_M4_1" => :brown,
        "via_M4_M5_0" => :green,
        "via_M4_M5_1" => :blue
    )

    # Read JSON file into a Dict
    data = JSON3.read(open(input_path, "r"), Dict)

    # Initialize a new plot
    plot(
        title        = "$(cellname) Via Visualization",
        xlabel       = "x",
        ylabel       = "y",
        aspect_ratio = :equal  # Ensures square-like proportions
    )

    # Iterate over each via key and its data
    for (via_name, via_info) in data
        # Figure out a color for this via. Default to black if not in `via_colors`.
        color = get(via_colors, via_info["type"], :black)

        # Each via has a list of "vpoints"
        for vpoint in via_info["vpoints"]
            # Unpack the center coordinate
            x, y = vpoint["xy"]  # xy is [x, y]
            # Unpack the extension, which is half-width (ex) and half-height (ey)
            ex, ey = vpoint["extension"]

            # Scale the extension if desired
            ex_scaled = ex * scale_factor
            ey_scaled = ey * scale_factor

            # Calculate corners of the rectangle
            x1, x2 = x - ex_scaled, x + ex_scaled
            y1, y2 = y - ey_scaled, y + ey_scaled

            # Draw the rectangle as a polygon
            plot!(
                [x1, x2, x2, x1, x1],
                [y1, y1, y2, y2, y1],
                seriestype = :shape,
                fillalpha  = 0.25,   # A bit of transparency
                color      = color,
                label      = ""
            )
        end
    end

    # Finally, save the figure
    savefig(output_path)
    println("\nVia plot saved as $(output_path)")
end

end #endif