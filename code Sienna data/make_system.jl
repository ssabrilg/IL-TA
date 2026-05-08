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

storage_data = []

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

include("generation_data.jl")
include("load_data.jl")
# include("AS_data.jl")
# include("interface_data.jl")
include("storage_data.jl")