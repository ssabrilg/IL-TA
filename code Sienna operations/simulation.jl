using Pkg
cd(@__DIR__)
#include("code Sienna data/file_pointers.jl")
#Pkg.activate("/Users/sabrilg/Documents/GitHub/TA_repo/AR/code Sienna Operations")
Pkg.activate(".")
#Pkg.instantiate()
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using StorageSystemsSimulations
using Logging

using Dates
using CSV
using DataFrames

include("utils_sim.jl")
#include("validation_plots_f.jl")

using HiGHS
mip_gap = 0.0125
optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                #"parallel" => "on",
                "mip_rel_gap" => mip_gap)

sys = System("il_system.json") # Load system 

batteries_v =  get_components( x -> x.rating > 0.0, EnergyReservoirStorage, sys )
number_bess = length( collect( batteries_v ) )
if number_bess == 0
    rating_cap_str = "_0_0"
else
    rating_cap_str = get_complete_bess_str( sys )
    rating_cap_str = rating_cap_str * "-$(number_bess)bess"
end

#UNCOMMENT FOR LOOP IN LINE 133 OF make_system.jl IF YOU WANT TO CONSIDER STORAGE IN RESERVE SERVICES!

#include("check_system.jl")

transform_single_time_series!(sys, Hour(48), Day(1))#

template_uc =
    ProblemTemplate(
        NetworkModel(CopperPlatePowerModel;
        use_slacks = true,
        ),
    );

#UNCOMMENT FOR LOOPS IN LINES 142 OF make_system.jl AND THE RESPECTIVE .CSV FILE TO ADD FUEL TIME SERIES.
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
set_device_model!(template_uc, StandardLoad, StaticPowerLoad)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver) #HydroDispatchRunOfRiver



if rating_cap_str != "_0_0" #Set BESS model if there are BESS in the system
    storage_model = DeviceModel(
        EnergyReservoirStorage,
        StorageDispatchWithReserves;
        attributes=Dict(
            "reservation" => false,
            "cycling_limits" => false,
            "energy_target" => false,
            "complete_coverage" => false,
            "regularization" => true
        ),
    )
    set_device_model!(template_uc, storage_model)
end


model = DecisionModel(
    template_uc,
    sys;
    name = "UC",
    optimizer = optimizer,
    #system_to_file = false,
    initialize_model = true,
    check_numerical_bounds = false,
    optimizer_solve_log_print = true,
    direct_mode_optimizer = false,
    rebuild_model = false,
    store_variable_names = true,
    calculate_conflict = true,
);

models = SimulationModels(
    decision_models = [model],
);

DA_sequence = SimulationSequence(
    models = models,
    ini_cond_chronology = InterProblemChronology(),
);

initial_date = "2019-01-01"
steps_sim    = 364
current_date = string( today() )
sim = Simulation(
    name = current_date * "_IL" * "_" * rating_cap_str * "_" * string(steps_sim) * "steps",
    steps = steps_sim,
    models = models,
    initial_time = DateTime(string(initial_date,"T00:00:00")),
    sequence = DA_sequence,
    simulation_folder = "."#".",  use "tempdir()" if you dont want to store simulation data
);

build!(sim)

execute!(sim)

results = SimulationResults(sim);
uc      = get_decision_problem_results(results, "UC");

uc_variable_keys   = list_variable_names(uc)
uc_expression_keys = list_expression_names(uc)
uc_parameter_keys  = list_parameter_names(uc)

slack_keys = filter(k -> occursin("Slack", k), uc_variable_keys)
# Check for slacks
using Statistics
for key in slack_keys
    @info "Slack variable: $key"
    res_slack = read_realized_variable(uc, key)
    vals = res_slack.value
    nz = count(!=(0), vals) 
    nz_pct = 100 * nz / length(vals)
    @info "$key Statistics:"
    @info("  Mean: $(mean(vals))")
    @info("  Median: $(median(vals))")
    @info("  Min: $(minimum(vals))")
    @info("  Max: $(maximum(vals))")
    @info("  Std: $(std(vals))")
    @info("  Non-zero count: $nz")
    @info("  Non-zero %: $(nz_pct)%")
end

#### Power Graphics Plots #################

Pkg.activate("sienna_analytics")
# Pkg.add(url="https://github.com/NREL-Sienna/PowerGraphics.jl", rev="claude/replace-plots-cairomakie-AjArg")
#=
pkg> rm PowerGraphics
pkg> add PowerGraphics
pkg> precompile
=#

using PowerGraphics
using PowerAnalytics
using PlotlyLight
using YAML
using CairoMakie
using Statistics
using StatsPlots

# execute_validation_plots( sys, uc )
gen = get_generation_data(uc)
#plot_powerdata(gen, stack=false)
plot_powerdata(gen; label_fn = label -> split(label, "__")[end])

fuel_mapping = YAML.load_file("/Users/sabrilg/Documents/GitHub/TA_repo/AR/sienna_analytics/generator_mapping.yaml")
palette = load_palette("/Users/sabrilg/Documents/GitHub/TA_repo/AR/sienna_analytics/color-palette.yaml")
plot = plot_fuel(
    uc;
    generator_mapping_file = "/Users/sabrilg/Documents/GitHub/TA_repo/AR/sienna_analytics/generator_mapping.yaml",
    #bar = true,
    stack = true,
    title = "Total Energy Produced by Fuel",
    palette = palette, 
    set_display = true,
    variables = [:generation],
    slacks = false,
    curtailment = false,
    load = false,
    y_label = "Energy (MWh)"
)



thermals = collect(get_components(x -> get_available(x) == true, ThermalStandard, sys))
thermal_multistart = collect(get_components(x -> get_available(x) == true, ThermalMultiStart, sys)) 
hydros   = collect(get_components(x -> get_available(x) == true, HydroDispatch, sys)) 
renewable_dispatch = collect(get_components(x -> get_available(x) == true, RenewableDispatch, sys)) 
renewable_nondispatch = collect(get_components(x -> get_available(x) == true, RenewableNonDispatch, sys)) 
storage = collect(get_components(x -> get_available(x) == true, EnergyReservoirStorage, sys))
set_units_base_system!(sys, "NATURAL_UNITS")



unique([g.fuel for g in thermals])
unique([g.fuel for g in thermal_multistart])
unique(g.prime_mover_type for g in renewable_dispatch)
unique(g.prime_mover_type for g in renewable_nondispatch)
unique(g.prime_mover_type for g in hydros)


capacity = Dict{String, Float64}()
capacity["Natural Gas"]      = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.NATURAL_GAS) + sum(g.active_power_limits.max * g.base_power for g in thermal_multistart if g.fuel == ThermalFuels.NATURAL_GAS)
capacity["AG_ByProduct"]     = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.AG_BYPRODUCT)
capacity["Other"]            = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.OTHER)
capacity["Municipal_Waste"]  = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.MUNICIPAL_WASTE)
capacity["Petroleum"]        = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.DISTILLATE_FUEL_OIL)
capacity["Coal"]             = sum(g.active_power_limits.max * g.base_power for g in thermals if g.fuel == ThermalFuels.COAL) + sum(g.active_power_limits.max * g.base_power for g in thermal_multistart if g.fuel == ThermalFuels.COAL)
capacity["Wind"]             = sum(g.rating * g.base_power for g in renewable_dispatch    if g.prime_mover_type == PrimeMovers.WT)
capacity["Solar"]             = sum(g.rating * g.base_power for g in renewable_dispatch    if g.prime_mover_type == PrimeMovers.PVe)
capacity["Hydropower"]       = sum(g.rating * g.base_power for g in hydros if g.prime_mover_type == PrimeMovers.HY)
capacity["Nuclear"]          = sum(g.active_power_limits.max * g.base_power for g in thermal_multistart if g.fuel == ThermalFuels.NUCLEAR)

println("\nCapacity by technology (MW):")
for (k, v) in sort(collect(capacity), by = x -> x[2], rev = true)
    println("  $(rpad(k, 20)) $(round(v, digits=1)) MW")
end
println("\nTotal: ", round(sum(values(capacity)), digits=1), " MW")
labels = collect(keys(capacity))

using PlotlyJS
palette = YAML.load_file("sienna_analytics/color-palette.yaml")
get_color(name) = haskey(palette, name) ? palette[name]["RGB"] : "grey"
# Sort labels by palette order
labels_sorted = sort(
    collect(keys(capacity)),
    by = k -> haskey(palette, k) ? palette[k]["order"] : 999
)

mw     = [capacity[label] for label in labels_sorted]
colors = [get_color(label) for label in labels_sorted]  # Use palette colors

trace = PlotlyJS.bar(
    x = labels_sorted,
    y = mw,
    marker_color = colors
)

layout = PlotlyJS.Layout(
    title = "Installed Generation Capacity by Technology",
    yaxis_title = "Installed Capacity (MW)",
    xaxis_title = "Generation Type"
)

PlotlyJS.plot(trace, layout)

gen_count = Dict{String, Int}()
gen_count["Natural Gas"]     = count(g -> g.fuel == ThermalFuels.NATURAL_GAS, thermals) + count(g -> g.fuel == ThermalFuels.NATURAL_GAS, thermal_multistart)
gen_count["AG_ByProduct"]    = count(g -> g.fuel == ThermalFuels.AG_BYPRODUCT, thermals)
gen_count["Other"]           = count(g -> g.fuel == ThermalFuels.OTHER, thermals)
gen_count["Municipal_Waste"] = count(g -> g.fuel == ThermalFuels.MUNICIPAL_WASTE, thermals)
gen_count["Petroleum"]       = count(g -> g.fuel == ThermalFuels.DISTILLATE_FUEL_OIL, thermals)
gen_count["Coal"]            = count(g -> g.fuel == ThermalFuels.COAL, thermals) + count(g -> g.fuel == ThermalFuels.COAL, thermal_multistart)
gen_count["Wind"]            = count(g -> g.prime_mover_type == PrimeMovers.WT, renewable_dispatch)
gen_count["Solar"]           = count(g -> g.prime_mover_type == PrimeMovers.PVe, renewable_dispatch)
gen_count["Hydropower"]      = count(g -> g.prime_mover_type == PrimeMovers.HY, hydros)
gen_count["Nuclear"]         = count(g -> g.fuel == ThermalFuels.NUCLEAR, thermal_multistart)
gen_count["Storage"]         = length(storage)

println("\nGenerator count by technology:")
for (k, v) in sort(collect(gen_count), by = x -> x[2], rev = true)
    println("  $(rpad(k, 20)) $(v) units")
end
println("\nTotal generators: ", sum(values(gen_count)))

# ── Helper to filter zeros and sort by palette order ──────────────────────────
# Convert palette Vector to Dict for easy lookup
palette = load_palette("sienna_analytics/color-palette.yaml")

# Use .category for name, .RGB for color string, .order for ordering
palette_dict = Dict(entry.category => entry for entry in palette)

function make_pie(data_dict, palette_dict, title)
    labels_sorted = sort(
        [k for (k, v) in data_dict if v > 0],
        by = k -> haskey(palette_dict, k) ? palette_dict[k].order : 999
    )
    values_sorted = [data_dict[k] for k in labels_sorted]
    colors_sorted = [haskey(palette_dict, k) ? palette_dict[k].RGB : "grey" for k in labels_sorted]

    trace = PlotlyJS.pie(
        labels = labels_sorted,
        values = values_sorted,
        marker = PlotlyJS.attr(colors = colors_sorted),
        textinfo = "label+percent",
        hovertemplate = "%{label}<br>%{value:.1f}<br>%{percent}<extra></extra>"
    )
    layout = PlotlyJS.Layout(
        title = title,
        showlegend = true
    )
    return PlotlyJS.plot(trace, layout)
end

capacity_pie = make_pie(capacity, palette_dict, "Installed Generation Capacity by Technology (MW)")
display(capacity_pie)

count_pie = make_pie(gen_count, palette_dict, "Number of Generators by Technology")
display(count_pie)