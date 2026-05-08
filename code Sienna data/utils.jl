using PowerSystems
const PSY = PowerSystems

function make_thermal(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::NamedTuple,
    reactive_power_limits::NamedTuple,
    ::Union{SingleTimeSeries, Nothing},
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int,
    fuel::String31,
    prime_mover::String3)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for thermal gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = ThermalStandard(
        name=strip(name),
        status=true,
        bus=bus,
        available= available,
        active_power=max(0.3, active_power_limits.min),
        reactive_power=0.0,
        rating=1.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=nothing,
        operation_cost = ThermalGenerationCost(;
           variable = FuelCurve(; value_curve = LinearCurve(fuel_rate), fuel_cost = fuel_cost),
           fixed = 0,
           start_up = 1000.0,
           shut_down = 1000.0,
       ),
        #operation_cost = ThermalGenerationCost(;
        #    variable = CostCurve(LinearCurve(cost)),
        #    fixed = 0.0,
        #    start_up = cost/10.0,
        #    shut_down = 0.0,
        #),
        base_power = capacity,
        time_limits=nothing,
        must_run=false,
        prime_mover_type=prime_mover_dict[prime_mover],
        fuel=fuel_dict[fuel],
    )
    add_component!(sys, device)
end

function make_thermal_mts(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::NamedTuple,
    reactive_power_limits::NamedTuple,
    ::Union{SingleTimeSeries, Nothing},
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int,
    fuel::String31,
    prime_mover::String3)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for thermal gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = ThermalMultiStart(
        name=strip(name),
        status=true,
        bus=bus,
        available= available,
        active_power=max(0.3, active_power_limits.min),
        reactive_power=0.0,
        rating=1.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=nothing,
        power_trajectory = nothing,
        start_time_limits = nothing,
        start_types = 1,
        operation_cost = ThermalGenerationCost(;
           variable = FuelCurve(; value_curve = LinearCurve(fuel_rate), fuel_cost = fuel_cost),
           fixed = 0,
           start_up = 1000.0,
           shut_down = 1000.0,
       ),
        #operation_cost = ThermalGenerationCost(;
        #    variable = CostCurve(LinearCurve(cost)),
        #    fixed = 0.0,
        #    start_up = cost/10.0,
        #    shut_down = 0.0,
        #),
        base_power = capacity,
        time_limits=nothing,
        must_run=false,
        prime_mover_type=prime_mover_dict[prime_mover],
        fuel=fuel_dict[fuel],
    )
    add_component!(sys, device)
end

function make_biomass(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::PowerSystems.MinMax,
    reactive_power_limits::PowerSystems.MinMax,
    generation_time_series::SingleTimeSeries,
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for thermal gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = RenewableNonDispatch(
        name=strip(name),
        available= available,
        bus=bus,
        base_power=capacity,
        active_power=0.3,
        reactive_power=0.0,
        rating=1.0,
        power_factor = 1.0,
        prime_mover_type=PrimeMovers.ST,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, generation_time_series)
end

function make_interconnect(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::PowerSystems.MinMax,
    reactive_power_limits::PowerSystems.MinMax,
    generation_time_series::SingleTimeSeries,
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int)
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    if fuel_cost > 0.0
        start_cost = fuel_cost*0.5
        fuel = ThermalFuels.NATURAL_GAS
    else
        start_cost = 0.0
        fuel = ThermalFuels.OTHER
    end
    device = ThermalStandard(
        name=strip(name),
        status=false,
        available=available,
        bus=bus,
        active_power=0.0,
        reactive_power=0.0,
        rating=1.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=nothing,
        #operation_cost = ThermalGenerationCost(;
        #   variable = FuelCurve(; value_curve = LinearCurve(fuel_rate), fuel_cost = fuel_cost),
        #   fixed = 0,
        #   start_up = start_cost,
        #   shut_down = start_cost*0.2,
       #),
        operation_cost=ThermalGenerationCost(;
        variable = CostCurve(LinearCurve(abs(fuel_cost))),
            fixed = 0.0,
            start_up = start_cost,
            shut_down = start_cost*0.2,
        ),
        base_power=capacity,
        time_limits=nothing,
        must_run=false,
        prime_mover_type=PrimeMovers.IC,
        fuel=fuel,
    )
    add_component!(sys, device)
end

function make_geothermal(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::PowerSystems.MinMax,
    reactive_power_limits::PowerSystems.MinMax,
    generation_time_series::SingleTimeSeries,
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for thermal gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = ThermalStandard(
        name=strip(name),
        status=true,
        available=available,
        bus=bus,
        active_power=active_power_limits.max,
        reactive_power=0.0,
        rating=1.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=(up = 0.0001, down = 0.0001),
        operation_cost= ThermalGenerationCost(;
            variable = CostCurve(LinearCurve(-1.5)),
            fixed = 0.0,
            start_up = 1000.0,
            shut_down = 1000.0,
        ),
        base_power=capacity,
        time_limits=(up = 100.0, down = 100.0),
        must_run=true,
        prime_mover_type=PrimeMovers.ST,
        fuel=ThermalFuels.GEOTHERMAL,
    )
    add_component!(sys, device)
end

function make_hydrodispatch(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::NamedTuple,
    reactive_power_limits::NamedTuple,
    ts_data::Union{SingleTimeSeries, Nothing},
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int,
    fuel::AbstractString,
    prime_mover::AbstractString)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for hydro gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = HydroDispatch(
        name=strip(name),
        available=available,
        bus=bus,
        active_power=max(0.3, active_power_limits.min),
        reactive_power=max(0.0, reactive_power_limits.min),
        rating=1.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=nothing,
        operation_cost=HydroGenerationCost(
            variable = CostCurve(LinearCurve(-4.5)), #variable = CostCurve(LinearCurve(fuel_cost)),
            fixed = 0.0,
        ),
        base_power=capacity,
        time_limits=nothing,
        prime_mover_type=PrimeMovers.HY,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, ts_data)
end

function make_hydroreservoir(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::PowerSystems.MinMax,
    reactive_power_limits::PowerSystems.MinMax,
    generation_time_series::SingleTimeSeries,
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for hydro gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = HydroEnergyReservoir(
        name=strip(name),
        available=available,
        bus=bus,
        active_power=max(0.3, active_power_limits.min) + 0.1,
        reactive_power=max(0.0, reactive_power_limits.min),
        rating=1.0,
        storage_capacity = 0.0,
        inflow = 0.0,
        initial_storage = 0.0,
        active_power_limits=active_power_limits,
        reactive_power_limits=reactive_power_limits,
        ramp_limits=nothing,
        operation_cost=HydroGenerationCost(
            variable = CostCurve(LinearCurve(-10)),
            fixed = 0.0,
        ),
        base_power=capacity,
        time_limits=nothing,
        prime_mover_type=PrimeMovers.HY,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, generation_time_series)
end

function make_wind(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::NamedTuple,
    reactive_power_limits::NamedTuple,
    ts_data::Union{SingleTimeSeries, Nothing},
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int,
    fuel::String31,
    prime_mover::String3)
    device = RenewableDispatch(
        name=strip(name),
        available=available,
        bus=bus,
        active_power=max(0.3, active_power_limits.min),
        reactive_power=max(0.0, reactive_power_limits.min),
        rating=1.0,
        power_factor=1.0,
        operation_cost=RenewableGenerationCost(
            variable = CostCurve(LinearCurve(1))),
        reactive_power_limits=reactive_power_limits,
        base_power=capacity,
        prime_mover_type=PrimeMovers.WT,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, ts_data)
end

function make_solar(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::NamedTuple,
    reactive_power_limits::NamedTuple,
    ts_data::Union{SingleTimeSeries, Nothing},
    fuel_rate::Float64,
    fuel_cost::Float64,
    available::Int,
    fuel::String31,
    prime_mover::String3)
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = RenewableDispatch(
        name=strip(name),
        available=available,
        bus=bus,
        active_power=max(0.3, active_power_limits.min),
        reactive_power=max(0.0, reactive_power_limits.min),
        rating=1.0,
        power_factor=1.0,
        reactive_power_limits=reactive_power_limits,
        base_power=capacity,
        operation_cost=RenewableGenerationCost(;
            variable = CostCurve(LinearCurve(1.2))),
        prime_mover_type=PrimeMovers.PVe,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, ts_data)
end

function make_storage(
    sys::System,
    name::String,
    base_power::Number,
    bus::PSY.ACBus,
    input_active_power_limits::PowerSystems.MinMax,
    output_active_power_limits::PowerSystems.MinMax,
    storage_capacity::Number,
    ch_efficiency::Float64,
    dis_efficiency::Float64,
    max_ch_power::Float64,
    cost::Float64,
    available::Int)
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = EnergyReservoirStorage(
        name=strip(name),
        available=available,
        bus=bus,
        prime_mover_type = PrimeMovers.BA,   #::PrimeMovers: Prime mover technology according to EIA 923. Options are listed here
        storage_technology_type = StorageTech.OTHER_CHEM,   #StorageTech.OTHER_CHEM =::StorageTech: Storage Technology Complementary to EIA 923. Options are listed here
        storage_capacity = storage_capacity,           #::Float64: Maximum storage capacity (can be in units of, e.g., MWh for batteries or liters for hydrogen), validation range: (0, nothing)
        storage_level_limits = (min=0.05, max=0.98),       #::MinMax: Minimum and maximum allowable storage levels [0, 1], which can be used to model derates or other restrictions, such as state-of-charge restrictions on battery cycling, validation range: (0, 1)
        initial_storage_capacity_level = 0.7,  #::Float64: Initial storage capacity level as a ratio [0, 1.0] of storage_capacity, validation range: (0, 1)
        rating = max_ch_power,   #::Float64: Maximum output power rating of the unit (MVA)************
        active_power = max_ch_power*0.1, #Initial active power set point of the unit in MW. For power flow, this is the steady state operating point of the system. For production cost modeling, this may or may not be used as the initial starting point for the solver, depending on the solver used
        input_active_power_limits = input_active_power_limits,  #::MinMax: Minimum and maximum limits on the input active power (i.e., charging), validation range: (0, nothing)
        output_active_power_limits = output_active_power_limits,   #::MinMax: Minimum and maximum limits on the output active power (i.e., discharging), validation range: (0, nothing)
        efficiency = (in = ch_efficiency, out = dis_efficiency),   #(CSolar)-efficiency::NamedTuple{(:in, :out), Tuple{Float64, Float64}}: Average efficiency [0, 1] in (charging/filling) and out (discharging/consuming) of the storage system, validation range: (0, 1)
        reactive_power=0.0,
        reactive_power_limits = (min=0.0, max=0.0),   #::Union{Nothing, MinMax}: Minimum and maximum reactive power limits. Set to Nothing if not applicable
        base_power = base_power,   #::Float64: Base power of the unit (MVA) for per unitization, validation range: (0, nothing)
        operation_cost=StorageCost(
            charge_variable_cost = CostCurve(LinearCurve(cost)),
            discharge_variable_cost = CostCurve(LinearCurve(cost)),
            ),
        conversion_factor =1,
        storage_target =0.0,   #::Float64: (default: 0.0) Storage target at the end of simulation as ratio of storage capacity
        cycle_limits   = 5000, #::Int: (default: 1e4) Storage Maximum number of cycles per year
        services = [],
        dynamic_injector=nothing,
    )
    add_component!(sys, device)
end


function make_hydrofix(
    sys::System,
    name::String,
    capacity::Float64,
    bus::PSY.ACBus,
    active_power_limits::PowerSystems.MinMax,
    reactive_power_limits::PowerSystems.MinMax,
    generation_time_series::SingleTimeSeries,
    cost::Float64,
    available::Int)
    if active_power_limits.min > active_power_limits.max
        error("incorrect active power limits for thermal gen $name")
    end
    if get_bustype(bus) == ACBusTypes.ISOLATED
        @warn("Generator $name connected to isolated bus $(get_number(bus)) changed to ACBusTypes.PV")
        set_bustype!(bus, ACBusTypes.PV)
    end
    device = RenewableNonDispatch(
        name=strip(name),
        available= available,
        bus=bus,
        base_power=capacity,
        active_power=0.3,
        reactive_power=0.0,
        rating=1.0,
        power_factor = 1.0,
        prime_mover_type=PrimeMovers.HY,
    )
    add_component!(sys, device)
    add_time_series!(sys, device, generation_time_series)
end

#=const FUEL_MAP = Dict(
    "Biomasicas" => make_biomass,
    "Termica" => make_thermal,
    "Eolica" => make_wind,
    "Solar" => make_solar,
    "Hidro Grande" => make_hydroreservoir,
    "HydroFilo" => make_hydrodispatch,
    "Hidro Pequena" => make_hydrofix,
    "Geotermica" => make_geothermal,
    "Storage" => make_storage,
    "InterConnection" => make_interconnect,
)=#

function make_loads(
    sys::System,
    bus::PSY.ACBus, 
    name::String3,            
    device = StandardLoad(
        name = name,
        available = true, 
        bus = bus, 
        base_power = 100, 
        constant_active_power = 0.0,
        constant_reactive_power= 0.0,
        impedance_active_power= 0.0,
        impedance_reactive_power= 0.0,
        current_active_power= 0.0,
        current_reactive_power= 0.0,
        max_constant_active_power= 0.0,
        max_constant_reactive_power= 0.0,
        max_impedance_active_power= 0.0,
        max_impedance_reactive_power= 0.0,
        max_current_active_power= 0.0,
        max_current_reactive_power= 0.0,
    ))
    add_component!(sys, device)
end


const FUEL_MAP = Dict(
    "Biomass" => make_biomass,
    "ThermalStandard" => make_thermal,
    "ThermalMultiStart" => make_thermal_mts,
    "Wind" => make_wind,
    "Solar" => make_solar,
    "Hydro" => make_hydrodispatch,
    "HydroFilo" => make_hydrodispatch,
    "HydroFix" => make_hydrofix,
    "Geothermal" => make_geothermal,
    "Storage" => make_storage,
    "InterConnection" => make_interconnect,
)


const AS_DIRECTION_MAP = Dict(
    "Up" => ReserveUp,
    "Down" => ReserveDown
)

const fuel_dict = Dict(
    "NATURAL_GAS" => ThermalFuels.NATURAL_GAS,
    "DISTILLATE_FUEL_OIL" => ThermalFuels.DISTILLATE_FUEL_OIL,
    "AG_BIPRODUCT" => ThermalFuels.AG_BYPRODUCT,
    "COAL" => ThermalFuels.COAL,
    "OTHER" => ThermalFuels.OTHER,   
    "NUCLEAR" => ThermalFuels.NUCLEAR,
    "MUNICIPAL_WASTE" => ThermalFuels.MUNICIPAL_WASTE,
    "WOOD_WASTE" => ThermalFuels.OTHER,
)

const prime_mover_dict = Dict(
    "CT" => PrimeMovers.CT,
    "CA" => PrimeMovers.CA,
    "GT" => PrimeMovers.GT,
    "OT" => PrimeMovers.OT,
    "ST" => PrimeMovers.ST,
    "CC" => PrimeMovers.CC,
    "IC" => PrimeMovers.IC,
    "HY" => PrimeMovers.HY,
    "WT" => PrimeMovers.WT,
    "PVe" => PrimeMovers.PVe,
    "BA" => PrimeMovers.BA,
)


# COST_MAP = Dict(
#     "cost_linear" => CSV.read(joinpath(COST_DATA_FOLDER_PATH, "cost_linear.csv"), DataFrame),
#     "cost_quadratic" => CSV.read(joinpath(COST_DATA_FOLDER_PATH, "cost_quadratic.csv"), DataFrame),
#     "fuel_linear" => CSV.read(joinpath(COST_DATA_FOLDER_PATH, "fuel_linear_cost.csv"), DataFrame),
#     "fuel_quadratic" => CSV.read(joinpath(COST_DATA_FOLDER_PATH, "fuel_quadratic_cost.csv"), DataFrame),
#     "cost_piecewise" => CSV.read(joinpath(COST_DATA_FOLDER_PATH, "fuel_piecewise_cost.csv"), DataFrame),
# )

#TODO parse the operation cost string to call the correct function with the cost dictionary

function make_linear_cost(row::DataFrame)
    value_curve = LinearCurve(row.proportional_term[], row.constant_term[])
    vom_cost = LinearCurve(row.vom_proportional_term[], row.vom_constant_term[])
    variable = CostCurve(value_curve, vom_cost)
    cost_function = ThermalGenerationCost(variable = variable, fixed = 0.0, start_up = 0, shut_down = 0)
    return cost_function
end

function make_quadratic_cost(row::DataFrame)
    value_curve = QuadraticCurve(row.quadratic_term[], row.proportional_term[], row.constant_term[])
    vom_cost = LinearCurve(row.vom_proportional_term[], row.vom_constant_term[])
    variable = CostCurve(value_curve, vom_cost)
    cost_function = ThermalGenerationCost(variable = variable, fixed = 0.0, start_up = 0, shut_down = 0)
    return cost_function
end

function make_linear_fuel(row::DataFrame)
    value_curve = LinearCurve(row.proportional_term[], row.constant_term[])
    variable = FuelCurve(value_curve, row.fuel_cost[])
    cost_function = ThermalGenerationCost(variable = variable, fixed = 0.0, start_up = 0, shut_down = 0)
    return cost_function
end

function make_quadratic_fuel(row::DataFrame)
    value_curve = LinearCurve(row.quadratic_term[], row.proportional_term[], row.constant_term[])
    variable = FuelCurve(value_curve, row.fuel_cost[])
    cost_function = ThermalGenerationCost(variable = variable, fixed = 0.0, start_up = 0, shut_down = 0)
    return cost_function
end

function make_piecewise_cost(row::DataFrame)
    # Helper function for parsing x or y coords
    parse_coords(val) =
    if isa(val, AbstractVector{<:Real})
        Float64.(val)
    elseif isa(val, AbstractString)
        cleaned = replace(val, "[" => "", "]" => "")   # strip brackets
        parse.(Float64, strip.(split(cleaned, ",")))
    else
        throw(ArgumentError("Expected a comma-separated string or vector of reals, got $(typeof(val))"))
    end

    x_coords = parse_coords(row.x[])
    y_coords = parse_coords(row.y[])

    value_curve = PiecewiseIncrementalCurve(row.initial_input[], x_coords, y_coords)
    variable = FuelCurve(value_curve, row.fuel_cost[])
    cost_function = ThermalGenerationCost(
        variable = variable,
        fixed = 0.0,
        start_up = row.start_up[],
        shut_down = row.shut_down[],
    )
    return cost_function
end

cost_function_dict = Dict(
    "cost_linear" => make_linear_cost,
    "cost_quadratic" => make_quadratic_cost,
    "fuel_linear" => make_linear_fuel,
    "fuel_quadratic" => make_quadratic_fuel,
    "cost_piecewise" => make_piecewise_cost
)