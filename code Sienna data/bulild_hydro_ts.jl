using CSV, DataFrames, Dates

hydro_ts_dir = "/Users/sabrilg/Documents/GitHub/IL-TA/Data/hydro_ts"

function monthly_to_hourly(df::DataFrame, year::Int)
    df_year = filter(r -> Dates.year(Date(r.datetime, dateformat"m/d/yyyy")) == year, df)
    
    if nrow(df_year) != 12
        error("Expected 12 months for year $year, got $(nrow(df_year))")
    end
    
    # Sort by month to ensure correct order
    sort!(df_year, :datetime, by = d -> Date(d, dateformat"m/d/yyyy"))
    
    hourly = Float64[]
    for row in eachrow(df_year)
        append!(hourly, fill(row.p_avg, row.n_hours))
    end
    
    println("  $(length(hourly)) hours generated")
    return hourly
end

year = 2012

plant_ts_files = Dict(
    "Dayton"                  => "Dayton.csv",
    "Rockton"                 => "Rockton.csv",
    "Upper Sterling"          => "Upper Sterling.csv",
    "Lockport Powerhouse"     => "Lockport Powerhouse.csv",
    "Kankakee Hydro Facility" => "Kankakee Hydro Facility.csv",
    "Dixon"                   => "Dixon.csv",
    "Peru"                    => "Peru.csv",
)

plant_hourly = Dict{String, Vector{Float64}}()
for (plant, fname) in plant_ts_files
    println("Processing $plant...")
    df = CSV.read(joinpath(hydro_ts_dir, fname), DataFrame)
    hourly = monthly_to_hourly(df, year)
    plant_hourly[plant] = hourly
end


#normalizing
plant_max_mw = Dict(
    "Rockton"                 => 0.6 + 0.5,          # 1.1 MW
    "Upper Sterling"          => 1.1 + 1.1,           # 2.2 MW
    "Dayton"                  => 1.6 + 1.0 + 1.0,    # 3.6 MW
    "Lockport Powerhouse"     => 8.0 + 8.0 ,         # 16 MW 
    "Kankakee Hydro Facility" => 0.4 + 0.4 + 0.4,    # 1.2 MW
    "Dixon"                   => 0.6 * 5,             # 3.0 MW
    "Peru"                    => 1.9 * 4,             # 7.6 MW
)

# Normalize and check for values > 1
hydro_ts_df = DataFrame()
for (plant, hourly_mw) in plant_hourly
    pmax = plant_max_mw[plant]
    normalized = hourly_mw ./ pmax
    over1 = sum(normalized .> 1.0)
    if over1 > 0
        @warn "$plant has $over1 hours > 1.0 (max=$(round(maximum(normalized), digits=3))), capping at 1.0"
        normalized = min.(normalized, 1.0)
    end
    hydro_ts_df[!, plant] = normalized
    println("$plant: max=$(round(maximum(normalized), digits=3)), min=$(round(minimum(normalized), digits=3))")
end

println("\nhydro_ts_df: $(nrow(hydro_ts_df)) rows x $(ncol(hydro_ts_df)) cols")

# Jan=744, Feb 1-28=672 hours, so Feb 29 starts at hour 1417
feb29_start = 744 + 672 + 1
feb29_end   = feb29_start + 23

keep_hours  = vcat(1:(feb29_start-1), (feb29_end+1):8784)
hydro_ts_df = hydro_ts_df[keep_hours, :]

println("After dropping Feb 29: $(nrow(hydro_ts_df)) rows")
resources_ts = hcat(resources_ts, hydro_ts_df)
println("resources_ts: $(nrow(resources_ts)) rows x $(ncol(resources_ts)) cols")

CSV.write(
    "/Users/sabrilg/Documents/GitHub/IL-TA/code Sienna data/Data for simulation/resources_ts.csv",
    resources_ts
)
println("Saved.")