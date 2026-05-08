# include("utils.jl")
set_units_base_system!(sys, "NATURAL_UNITS")
@info "---- Adding Storage Units ----"
for row in eachrow(storage_data)
    storage_bus = get_component(ACBus, sys, "new_bus")
    cap_pu  = Float64(row["nameplate_capacity"]) / 100.0
    mwh_pu  = Float64(row["nameplate_mwh"])      / 100.0
    make_storage(
        sys,
        String(row["plant"]),
        100.0,                              # base_power = system base
        storage_bus,
        (min = 0.0, max = cap_pu),          # per unit of 100 MVA
        (min = 0.0, max = cap_pu),
        mwh_pu,                             # per unit
        1.0,
        1.0,
        Float64(row["nameplate_capacity"]), # rating in MW (absolute)
        0.0,
        1
    )
end
set_units_base_system!(sys, "SYSTEM_BASE")