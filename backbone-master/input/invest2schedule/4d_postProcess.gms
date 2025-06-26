* =============================================================================
* --- Save investments results in invest_results.inc file to be used in child setups -
* =============================================================================

* Output file streams
file f_changes /'output/invest_results.inc'/;
f_changes.lw = 40; f_changes.pw = 500

put f_changes

* --- Update investment data in the subsequent models -------------------------

// Number of subunits
put "* Update the number of subunits in the subsequent models"/;
loop(unit${r_invest_unitCount_u(unit)},
    // subunits rounded to the nearest integer
    tmp = round(r_invest_unitCount_u(unit), 0)
    put "p_unit('", unit.tl, "', 'unitCount') = p_unit('", unit.tl,
        "', 'unitCount') + ", tmp, ";"/;
);

// Unit capacities
put /;
put "* Update unit capacities in the subsequent models"/;
put "* Set 'becomeUnavailable' if no existing capacity and no investments" /;
loop(gnu(grid, node, unit)${unit_investLP(unit) or unit_investMIP(unit)},
    // subunits rounded to the nearest integer
    tmp = Eps + p_gnu(grid, node, unit, 'unitSize') * round(r_invest_unitCount_u(unit), 0);
    if(tmp > 0,
        if(gnu_output(grid, node, unit),
            put "p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
                "', 'output', 'capacity')"/;
            put "    = p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
                "', 'output', 'capacity') + ", tmp, ";"/;
        );
        if(gnu_input(grid, node, unit),
            put "p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
                "', 'input', 'capacity')"/;
            put "    = p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
                "', 'input', 'capacity') + ", tmp, ";"/;
        );
    );

);

// Unit availabilities
put /;
put "* Set 'becomeUnavailable' if no existing capacity and no investments"/;
loop(unit${unit_invest(unit)},
    // subunits rounded to the nearest integer
    tmp = p_unit(unit, 'unitCount') + round(r_invest_unitCount_u(unit), 0);
    if(tmp = 0,
        put "utAvailabilityLimits('", unit.tl,
            "', t, 'becomeAvailable') = no;" /;
        put "utAvailabilityLimits('", unit.tl,
            "', t, 'becomeUnavailable') = no;" /;
        put "utAvailabilityLimits('", unit.tl,
            "', 't000001', 'becomeUnavailable') = yes;" /;
    );
);

// Storage limits
put /;
put "* Update storage upper bounds for the subsequent models"/;
loop(gnu(grid, node, unit)
    ${r_invest_unitCount_u(unit) and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')},
    // subunits rounded to the nearest integer
    tmp = p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
        * round(r_invest_unitCount_u(unit), 0) * p_gnu(grid, node, unit, 'unitSize');
    put "p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'upwardLimit', 'constant')"/;
    put "    =  p_gnBoundaryPropertiesForStates('",
        grid.tl, "', '", node.tl, "', 'upwardLimit', 'constant') + ", tmp, ";"/;
);
put "* Update storage (pumped storage, hydro, H2) reference level for the subsequent models"/;
loop(gn(grid, node)
    ${(p_gnBoundaryPropertiesForStates(grid, node, 'upwardLimit', 'constant')
    or sum(unit, (r_invest_unitCount_u(unit) and p_gnu(grid, node, unit, 'upperLimitCapacityRatio'))))
        and (sameas(grid, 'storage'))},
    put "p_gn('", grid.tl, "', '", node.tl,
        "', 'boundStart') = 1;"/;
    put "p_gn('", grid.tl, "', '", node.tl,
        "', 'boundSumOverInterval') = 1;"/;
    put "p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'reference', 'useConstant') = 0;"/;
    put "p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'reference', 'useTimeseries') = 1;"/;
    put "ts_node('", grid.tl, "', '", node.tl,
        "', 'reference', 'f00', 't000000')"/;
    put "    =  0.5 * p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'upwardLimit', 'constant');"/;
    put "ts_node('", grid.tl, "', '", node.tl,
        "', 'reference', 'f00', 't008736')"/;
    put "    =  0.5 * p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'upwardLimit', 'constant');"/;
);

// Transfer capacity
put "* Update transfer capacities in the subsequent models"/;
loop(gn2n_directional(grid, node, node_)
    ${sum(t_invest, r_invest_transferCapacity_gnn(grid, node, node_, t_invest))},
    tmp = 0;
    tmp_ = 0;
    loop(t_invest(t),
        tmp = p_gnn(grid, node, node_, 'transferCap') + tmp
            + r_invest_transferCapacity_gnn(grid, node, node_, t);
        tmp_ = p_gnn(grid, node_, node, 'transferCap') + tmp_
            + r_invest_transferCapacity_gnn(grid, node, node_, t);
        put "p_gnn('", grid.tl, "', '", node.tl, "', '", node_.tl,
            "', 'transferCap')"/;
        put "        = ", tmp, ";"/;
        put "p_gnn('", grid.tl, "', '", node_.tl, "', '", node.tl,
            "', 'transferCap')"/;
        put "        = ", tmp_, ";"/;
    );
);


* --- Update online group constraints in the subsequent models ----------------

// Limit the number of online units to the largest unitCount in the group
// Intended especially for limiting simultaneous charging and discharging
// The groups and uGroups for these constraints should be defined already in
// the investment model data - just without parameter values.
put /;
put "* Update online group constraints in the subsequent models"/;
set online_group(group) / /; // Note! Update this set manually
loop(online_group(group),
    loop(uGroup(unit, group),
        put "p_groupPolicyUnit('", group.tl,
            "', 'constrainedOnlineMultiplier', '", unit.tl, "') = 1;"/;
    );
    put "p_groupPolicy('", group.tl, "', 'constrainedOnlineTotalMax')"/;
    put "    = smax(uGroup(unit, '", group.tl,
        "'), p_unit(unit, 'unitCount'));"/;
);

* --- Do not allow investments in the subsequent models -----------------------
* This section can be omitted if the input data of the subsequent models
* already disables investments and enables constant upwardLimit for storage.

*$ontext
// Units
put /;
put "* Do not allow unit investments in the subsequent models"/;
loop(unit,
    put "p_unit('", unit.tl, "', 'maxUnitCount') = 0;"/;
    put "p_unit('", unit.tl, "', 'minUnitCount') = 0;"/;
);

// Transfer links
put /;
put "* Do not allow transfer link investments in the subsequent models"/;
loop(gn2n_directional(grid, node, node_),
    put "p_gnn('", grid.tl, "', '", node.tl, "', '", node_.tl,
        "', 'transferCapInvLimit') = 0;"/;
    put "p_gnn('", grid.tl, "', '", node_.tl, "', '", node.tl,
        "', 'transferCapInvLimit') = 0;"/;
);

// Storage
put /;
put "* Do not allow storage investments in the subsequent models"/;
loop(gnu(grid, node, unit)$p_gnu(grid, node, unit, 'upperLimitCapacityRatio'),
    if(gnu_output(grid, node, unit),
        put "p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
            "', 'output', 'upperLimitCapacityRatio') = 0;"/;
    );
    if(gnu_input(grid, node, unit),
        put "p_gnu_io('", grid.tl, "', '", node.tl, "', '", unit.tl,
            "',  'input', 'upperLimitCapacityRatio') = 0;"/;
    );
    put "p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'upwardLimit', 'useConstant') = 1;"/;
);
*$offtext



putclose;
