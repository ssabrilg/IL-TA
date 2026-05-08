# # ── Extract wind and solar from raw data (before transformation) ──────────────
# wind_data = filter(row -> row.generator_type == "Wind", generator_data)
# solar_data = filter(row -> row.generator_type == "Solar", generator_data)

# wind_out = DataFrame(
#     "name"             => wind_data.name,
#     "lat"              => wind_data.lat,
#     "lon"              => wind_data.lon,
#     "prime_mover_type" => wind_data.prime_mover_type,
# )

# solar_out = DataFrame(
#     "name"             => solar_data.name,
#     "lat"              => solar_data.lat,
#     "lon"              => solar_data.lon,
#     "prime_mover_type" => solar_data.prime_mover_type,
# )

# CSV.write("illinois_wind.csv",  wind_out;  transform=(col, val) -> something(val, missing))
# CSV.write("illinois_solar.csv", solar_out; transform=(col, val) -> something(val, missing))
# println("Wind generators:  $(nrow(wind_out))")
# println("Solar generators: $(nrow(solar_out))")


# include("utils.jl")


function parse_cost(cost_str::Union{String, Missing})
    ismissing(cost_str) && return (0.0, 0.0)
    m = match(r"LinearCurve\(([0-9eE.+-]+),\s*([0-9eE.+-]+)\)", cost_str)
    isnothing(m) && return (0.0, 0.0)
    fuel_rate = tryparse(Float64, m.captures[1])
    fuel_cost = tryparse(Float64, m.captures[2])
    return (something(fuel_cost, 0.0), something(fuel_rate, 0.0))
end


bus_counter = Dict{String, Int}()
function next_id(bus_name::String)
    bus_counter[bus_name] = get(bus_counter, bus_name, 0) + 1
    return bus_counter[bus_name]
end

n = nrow(generator_data)

bus_numbers  = Vector{Any}(undef, n)
ids          = Vector{Any}(undef, n)
names_       = Vector{String}(undef, n)
bus_names    = Vector{Any}(undef, n)
types_       = Vector{String}(undef, n)
base_powers  = Vector{Any}(undef, n)
max_ap       = Vector{Any}(undef, n)
min_ap       = Vector{Any}(undef, n)
ts_names     = Vector{Any}(undef, n)
fuel_costs   = Vector{Float64}(undef, n)
fuel_rates   = Vector{Float64}(undef, n)
modeled_load = Vector{String}(undef, n)
available    = Vector{String}(undef, n)
prime_movers = Vector{Any}(undef, n)
fuels        = Vector{Any}(undef, n)

for i in 1:n
    row = generator_data[i, :]
    bus_numbers[i]  = 1          # copper plate — single bus
    ids[i]          = 1          # copper plate — single bus
    names_[i]       = row.name
    bus_names[i]    = "new_bus"  # copper plate — single bus
    types_[i]       = row.generator_type
    base_powers[i]  = row.base_power
    max_ap[i]       = row.active_power_limits_max
    min_ap[i]       = row.active_power_limits_min
    ts_names[i]     = row.ts_column_name
    fc, fr          = parse_cost(row.operation_cost)
    fuel_costs[i]   = fc
    fuel_rates[i]   = fr
    modeled_load[i] = "FALSE"
    available[i]    = uppercase(string(row.available))
    prime_movers[i] = row.prime_mover_type
    fuels[i]        = row.fuel
end
 
generator_data = DataFrame(
    "Bus Number"                 => bus_numbers,
    "ID"                         => ids,
    "Name"                       => names_,
    "Bus Name"                   => bus_names,
    "Type"                       => types_,
    "Base Power"                 => base_powers,
    "Max Active Power"           => max_ap,
    "Min Active Power"           => min_ap,
    "TS column name"             => ts_names,
    "Fuel Cost"                  => fuel_costs,
    "Fuel Rate"                  => fuel_rates,
    "Generation Modeled_as_load" => modeled_load,
    "Available"                  => available,
    "Prime Mover"                => prime_movers,
    "fuel"                       => fuels,
)

# EIA Illinois hydro generators
# (Moline skipped per decision)
eia_hydro = DataFrame(
    "Bus Number"                 => 1,
    "ID"                         => 1,
    "Name"                       => [
        # Rockton (903)
        "Rockton-1", "Rockton-2",
        # Upper Sterling (7474)
        "UpperSterling-1", "UpperSterling-2",
        # Dayton (10520)
        "Dayton-1", "Dayton-2", "Dayton-3",
        # Lockport (10903)
        "Lockport-1GEN", "Lockport-2GEN",
        # Kankakee (54525)
        "Kankakee-1", "Kankakee-2", "Kankakee-3",
        # Dixon (54969)
        "Dixon-1", "Dixon-2", "Dixon-3", "Dixon-4", "Dixon-5",
        # Peru (68750)
        "Peru-HC1", "Peru-HC2", "Peru-HC3", "Peru-HC4",
    ],
    "Bus Name"                   => "new_bus",
    "Type"                       => "Hydro",
    "Base Power"                 => [
        0.6, 0.5,           # Rockton
        1.1, 1.1,           # Upper Sterling
        1.6, 1.0, 1.0,      # Dayton
        8.0, 8.0,           # Lockport
        0.4, 0.4, 0.4,      # Kankakee
        0.6, 0.6, 0.6, 0.6, 0.6,  # Dixon
        1.9, 1.9, 1.9, 1.9, # Peru
    ],
    "Max Active Power"           => [
        0.6, 0.5,
        1.1, 1.1,
        1.6, 1.0, 1.0,
        8.0, 8.0,
        0.4, 0.4, 0.4,
        0.6, 0.6, 0.6, 0.6, 0.6,
        1.9, 1.9, 1.9, 1.9,
    ],
    "Min Active Power"           => 0.0,
    "TS column name"             => [
        # each generator gets its plant's TS column name
        "Rockton", "Rockton",
        "Upper Sterling", "Upper Sterling",
        "Dayton", "Dayton", "Dayton",
        "Lockport Powerhouse", "Lockport Powerhouse",
        "Kankakee Hydro Facility", "Kankakee Hydro Facility", "Kankakee Hydro Facility",
        "Dixon", "Dixon", "Dixon", "Dixon", "Dixon",
        "Peru", "Peru", "Peru", "Peru",
    ],
    "Fuel Cost"                  => 0.0,
    "Fuel Rate"                  => 0.0,
    "Generation Modeled_as_load" => "FALSE",
    "Available"                  => "TRUE",
    "Prime Mover"                => "HY",
    "fuel"                       => "Water",
)

generator_data = filter(r -> r.Type != "Hydro", generator_data)
generator_data = vcat(generator_data, eia_hydro)

println("Final generator_data: $(nrow(generator_data)) rows")
println("Hydro generators: ", nrow(filter(r -> r["Type"] == "Hydro", generator_data)))

set_units_base_system!(sys, "NATURAL_UNITS")
@info "---- Creating Generation Time Series Information for non Hydro ----"
tolerance_Pmax     = 0.85
reserves_factor    = 1.015
# Pplants_reserves_v = unique(as_units[:,"Primaria"])
names_as_adj       = []

generation_time_series_map = Dict()
for row in eachrow(generator_data)

    if row["Max Active Power"]*tolerance_Pmax > row["Base Power"] || row["Max Active Power"]*(2-tolerance_Pmax) < row["Base Power"]
        @warn "The Base Power = $(row["Base Power"]) of Generator $(row["Name"]) its outside the range Max active Power = $(row["Max Active Power"]) +/- $(100*(1-tolerance_Pmax))% "
    end
    
    if row["TS column name"] != "NO_TS" 
        max_ap = 1.0*maximum(Float64.(generation_time_series[!, "$(row["TS column name"])"]))
        if max_ap <= eps() 
            max_ap = 1.0
        end

        n_units     = Float64( size(filter(r -> contains(r["TS column name"], row["TS column name"]), generator_data))[1] )
        Pmax_plant  = sum( filter(r -> r["TS column name"] == row["TS column name"], generator_data)[!,"Max Active Power"] )  #row["Max Active Power"] * n_units
        Pmin_plant  = sum( filter(r -> r["TS column name"] == row["TS column name"], generator_data)[!,"Min Active Power"] )
        Pbase_plant = sum( filter(r -> r["TS column name"] == row["TS column name"], generator_data)[!,"Base Power"] )  
        factor      = Float64(row["Min Active Power"]/row["Max Active Power"])

        if row["TS column name"] == "viento_generico" || row["TS column name"] == "solar_generico"
            data_60  = TimeArray( dates, Float64.(generation_time_series[!, "$(row["TS column name"])"]) )
        else
            if !( max_ap > Pbase_plant * tolerance_Pmax ) && max_ap < Pbase_plant
                @warn "The maximum value of $(row["TS column name"]) time series $max_ap is inferior to $tolerance_Pmax * (Plant Max Active Power)=$(tolerance_Pmax*Pbase_plant)"
            elseif max_ap > Pbase_plant*1.05
                @warn "The maximum value of $(row["TS column name"]) time series $max_ap exceeds the Plant (Max Active Power)=$(Pbase_plant)+5%"
            end

            ts_v = Float64.(generation_time_series[!, "$(row["TS column name"])"]) ./ Pmax_plant

            # if contains(row["Type"], "Hydro") && any(x -> x == row["Name"], Pplants_reserves_v)
            #     push!(names_as_adj, row["Name"])
            #     for i in eachindex(ts_v)
            #         ts_v[i] = get_availablepower_adjusted_reserves(ts_v[i], reserves_factor, 1.0 )
            #     end
            # end  
            data_60  = TimeArray( dates, ts_v )

        end
        
    else
        data_60 = TimeArray(dates, ones(8760))
        max_ap = 1.0
    end

    ts_data = SingleTimeSeries("max_active_power", data_60)
    generation_time_series_map[row["TS column name"]] = ts_data
end


@info "---- Adding Generators to the System ----"

for row in eachrow(generator_data)
    ts_data = get(generation_time_series_map, row["TS column name"], nothing)
    gen = FUEL_MAP[row["Type"]](
        sys,
        row["Name"],
        Float64(row["Base Power"]),
        new_bus,
        (min = row["Min Active Power"]/row["Base Power"], max = row["Max Active Power"]/row["Base Power"]),
        (min = 0.0, max = 0.0),
        ts_data,
        Float64(row["Fuel Rate"]),   # still needed as fallback
        Float64(row["Fuel Cost"]),   # still needed as fallback
        1,
        row[:fuel],
        row[:"Prime Mover"]
    )
end


# for (bus, gens) in gen_buses
#     bus_no = get_number(bus)
#     gen_data = generator_data[generator_data[!, "Bus Number"] .== bus_no, :]
#     sort!(gen_data, ["Base Power"])
#     sort!(gens, by = x -> get_base_power(x))
#     for (ix, row) in enumerate(eachrow(gen_data))
#         @info "Added $(row["Type"]) Generator $(row["Name"]) to the System at Bus $bus_no"
#         if ix <= length(gens)
#             g = gens[ix]
#         else
#             @warn "Bus $bus_no has more generators in the data than the PSSe file"
#             g = gens[end]
#         end
#         gen = FUEL_MAP[row["Type"]](
#             sys,
#             replace(String(row["Name"]), " " => ""),
#             row["Base Power"],
#             get_bus(g),
#             (min = row["Min Active Power"]/row["Base Power"], max = row["Max Active Power"]/row["Base Power"]),
#             (min = get_reactive_power_limits(g).min, max = get_reactive_power_limits(g).max),
#             generation_time_series_map[row["TS column name"]],
#             Float64(row["Fuel Rate"]),
#             Float64(row["Fuel Cost"]),
#             row["Available"]
#         )
#     end
# end
# bus_map = Dict(get_number(x) => x for x in get_components(ACBus, sys))
# for row in eachrow(neg_load_generator_data)
#     gen = FUEL_MAP[row["Type"]](
#         sys,
#         String(row["Name"]),
#         row["Base Power"],
#         bus_map[row["Bus Number"]],
#         (min = row["Min Active Power"]/row["Base Power"], max = row["Max Active Power"]/row["Base Power"]),
#         (min = 0.0, max = 0.0),
#         generation_time_series_map[row["TS column name"]],
#         Float64(row["Fuel Rate"]),
#         Float64(row["Fuel Cost"]),
#         Int(row["Available"])
#     )
#     @info "Added $(row["Type"]) Generator $(row["Name"]) to the System at Bus $(row["Bus Number"])"
# end

# for row in eachrow(interconnection_data)
#     gen = FUEL_MAP[row["Type"]](
#         sys,
#         String(row["Name"]),
#         row["Base Power"],
#         bus_map[row["Bus Number"]],
#         (min = row["Min Active Power"]/row["Base Power"], max = row["Max Active Power"]/row["Base Power"]),
#         (min = 0.0, max = 0.0),
#         generation_time_series_map[row["TS column name"]],
#         Float64(row["Fuel Rate"]),
#         Float64(row["Fuel Cost"]),
#         row["Available"]
#     )
#     @info "Added $(row["Type"]) Generator $(row["Name"]) to the System at Bus $(row["Bus Number"])"
# end



set_units_base_system!(sys, "SYSTEM_BASE")