include("file_pointers.jl")
using Pkg
Pkg.activate(CODE_SIENA_DATA_FOLDER_PATH)
#Pkg.instantiate()
using CSV
using DataFrames
using TimeSeries
using Dates
using PowerSystems

# using PlotlyJS
using Logging
include("utils.jl")
logger = configure_logging(
    file_level=Logging.Info,
    console_level=Logging.Info,
    filename="il_system.log")

#sys = System(DATA_FOR_SIMULATION_FOLDER_PATH * "RAW_FILE_NAME.raw")
sys = System(100)
bus_name_formatter = x -> string(x["name"] * "-" * string(x["index"]))
set_name!(sys, "Illinois")
sys
demand_data = CSV.read(DEMAND_DATA_FILE_PATH, DataFrame, typemap=Dict(String7 => Float64))
demand_time_series = CSV.read(DEMAND_TS_FILE_PATH, DataFrame, typemap=Dict(String7 => Float64))

generator_data = CSV.read(GENERATOR_DATA_FILE_PATH, DataFrame)
generation_time_series = CSV.read(GENERATION_TS_FILE_PATH, DataFrame, typemap=Dict(String7 => Float64))

dates = range(DateTime("2019-01-01T00:00:00"), step=Hour(1), length=8760)

storage_data = CSV.read(STORAGE_DATA_FILE_PATH, DataFrame)


@info "---- Adding Buses to system ----"
new_bus = ACBus(;
    number = 1,
    name = "new_bus",
    available = true,
    bustype = ACBusTypes.REF,
    angle = nothing, 
    magnitude = nothing, 
    voltage_limits = nothing,
    base_voltage = 100, 
    area = nothing,
);
add_component!(sys, new_bus)
raw_for_costs = CSV.read(GENERATOR_DATA_FILE_PATH, DataFrame)
cost_map = Dict{String, NamedTuple}()
n_parsed = 0
n_nothing = 0
for row in eachrow(raw_for_costs)
    c = parse_operation_cost(row.operation_cost)
    if !isnothing(c)
        cost_map[String(row.name)] = c
        n_parsed += 1
    else
        n_nothing += 1
    end
end
println("Parsed: $n_parsed, Nothing: $n_nothing")
println("cost_map size: ", length(cost_map))

# Check the first thermal row manually
thermal_rows = filter(r -> r.generator_type == "ThermalStandard", raw_for_costs)
println("\nFirst thermal operation_cost:")
println(thermal_rows[1, :operation_cost])
println("Type: ", typeof(thermal_rows[1, :operation_cost]))
c = parse_operation_cost(thermal_rows[1, :operation_cost])
println("Parsed result: ", c)
@info "Parsed costs for $(length(cost_map)) generators"

include("generation_data.jl")
include("load_data.jl")
# include("AS_data.jl")
# include("interface_data.jl")
include("storage_data.jl")

to_json(sys, joinpath("/Users/sabrilg/Documents/GitHub/IL-TA/code Sienna operations/il_system.json"); force=true)
@info "System saved!"