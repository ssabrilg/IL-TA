include("utils.jl")
# load_buses = get_number.(get_bus.(get_components(StandardLoad, sys)))
# all_buses = get_number.(get_components(ACBus, sys))
zones_in_demand_time_series = names(demand_time_series)[1:end]

# @info "--Removing Negative Loads used to model Generation--"
# for g in collect(get_components(StandardLoad, sys))
#     bus = get_bus(g)
#     bus_no = get_number(bus)
#     bus_name = get_name(bus)
#     if  get_max_active_power(g) < eps() 
#         @warn("Removing Load Bus No: $(bus_no) Bus Name: $(bus_name) since it corresponds to a generator")
#         remove_component!(sys, g)
#         continue
#     end
# end

@info "----Adding StandardLoads to system----"
for row in eachrow(demand_data)
    name = string(row[:name])
    bus = new_bus
    load = make_loads(
        sys,
        bus,
        name,
    )
end

         

@info "----Adding Time Series To Loads----"
assigned_time_series = []
for g in collect(get_components(StandardLoad, sys))
    bus = get_bus(g)
    bus_no = get_number(bus)
    bus_name = get_name(g)
    # zone_name = parse(Int, get_name(get_load_zone(bus)))
    # if zone_name ∉ zones_in_demand_time_series
    #     if  get_max_active_power(g) > 0
    #         @error("Zone Bus $(zone_name), $(get_max_active_power(g)*100.0) MW does not exist in the load time series data.")
    #     end
    #     continue
    # end
    @show bus_no
    @show bus_name
    #@show size(dates)[1]
    #@show size(demand_data[demand_data.name.== bus_name, :PDF].*demand_time_series[!, string(zone_name)])[1]
    # data_60 = TimeArray(dates, demand_data[demand_data.name.== bus_name, :PDF].*demand_time_series[!, string(bus_name)])
    data_60 = TimeArray(dates, demand_time_series[:, bus_name])
    max_power_ts = maximum(values(data_60))
    max_ap = get_max_active_power(g)*100.0
    if max_ap > max_power_ts
        @warn("PowerFlow case has larger load than time series data. Using PowerFlow case as peak load")
        max_power_ts = max_ap
    end
    if max_power_ts > max_ap
        @assert max_power_ts > 0
    end
    @info("$(bus_no): max_time_series_value: $(max_power_ts), max_active_power_psse: $(max_ap)")
    get_ext(g)["original_power_psse"] = max_ap
    set_max_constant_active_power!(g, max_power_ts/100.0)
    set_constant_active_power!(g, max_power_ts/100.0)
    if isapprox(max_power_ts, 0.0)
        max_power_ts = 1.0
    end
    input_data = data_60./max_power_ts
    @assert all(isfinite.(values(input_data)))
    demand_curve = SingleTimeSeries("max_active_power", input_data)
    push!(assigned_time_series, bus_no)
    add_time_series!(sys, g, demand_curve)
end
 