* =============================================================================
* --- Save investments results in .inc files to be used in other models -------
* =============================================================================

* Output file streams for static data
file f_changes /'%output_dir%\changes.inc'/;

// Field width of set label output, default in GAMS is 12, increase as needed
f_changes.lw = 40;

// Number of characters that may be placed on a single row of the page, default
// in GAMS is 255, increase as needed
f_changes.pw = 500;

put f_changes

* --- Update investment data in the subsequent models -------------------------

// Number of subunits
put "* Update the number of subunits in the subsequent models"/;
loop(unit${r_invest_unitCount_u(unit)},
    // subunits rounded to the nearest integer
    tmp = round(r_invest_unitCount_u(unit), 0);
    put "p_unit('", unit.tl, "', 'unitCount') = p_unit('", unit.tl,
        "', 'unitCount') + ", tmp, ";"/;
);

// Unit capacities
put /;
put "* Update unit capacities in the subsequent models"/;
loop(gnu(grid, node, unit)${r_invest_unitCount_u(unit)},
    // subunits rounded to the nearest integer
    tmp = p_gnu(grid, node, unit, 'unitSize')
        * round(r_invest_unitCount_u(unit), 0);
    tmp_ = Eps + p_gnu(grid, node, unit, 'capacity') + tmp;
    if(tmp_ > 0,
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
// NOTE: this assumes a constant initial limit and a multiplier of one.
put /;
put "* Update storage investments in the subsequent models"/;
loop(gnu(grid, node, unit)
    ${r_invest_unitCount_u(unit)
        and p_gnu(grid, node, unit, 'upperLimitCapacityRatio')},
    // subunits rounded to the nearest integer
    tmp = p_gnu(grid, node, unit, 'upperLimitCapacityRatio')
        * round(r_invest_unitCount_u(unit), 0)
        * p_gnu(grid, node, unit, 'unitSize');
    put "p_gnBoundaryPropertiesForStates('", grid.tl, "', '", node.tl,
        "', 'upwardLimit', 'constant')"/;
    put "    =  p_gnBoundaryPropertiesForStates('",
        grid.tl, "', '", node.tl, "', 'upwardLimit', 'constant') + ", tmp,
        ";"/;
);

*$ontext
// Transfer capacity
// NOTE: this assumes a single investment time step in the beginning of the
// simulation. In the case of investment time steps in the middle of the
// simulation, activate similar code block in f_loop_changes.
put /;
put "* Update transfer capacities in the subsequent models"/;
loop(gn2n_directional(grid, node, node_)
    ${sum(t_invest,
        r_invest_transferCapacity_gnn(grid, node, node_, t_invest))},
    tmp = p_gnn(grid, node, node_, 'transferCap');
    tmp_ = p_gnn(grid, node_, node, 'transferCap');
    tmp__ = sum(t_invest,
        r_invest_transferCapacity_gnn(grid, node, node_, t_invest));
    tmp = tmp + tmp__;
    tmp_ = tmp_ + tmp__;
    put "p_gnn('", grid.tl, "', '", node.tl, "', '", node_.tl,
        "', 'transferCap')"/;
    put "    = ", tmp, ";"/;
    put "p_gnn('", grid.tl, "', '", node_.tl, "', '", node.tl,
        "', 'transferCap')"/;
    put "    = ", tmp_, ";"/;
);
*$offtext

* --- Update online group constraints in the subsequent models ----------------

// Limit the number of online units to the largest unitCount in the group
// Intended especially for limiting simultaneous charging and discharging
// The groups and uGroups for these constraints should be defined already in
// the investment model data - just without parameter values.
put /;
put "* Update online group constraints in the subsequent models"/;
$onempty
set online_group(group) / /; // Note! Update this set manually
$offempty
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


$ontext
// NOTE: this block handles transfer investments in the case of investment time
// steps in the middle of the simulation. It is currently deactived with ontext
// comments. Deactivate similar block of code from above and activate this if
// running investment runs with investment time steps in the middle of the
// simulation.

* Output file streams for data to be read in the loop
file f_loop_changes /'%output_dir%\loop_changes.inc'/;

// Field width of set label output, default in GAMS is 12, increase as needed
f_loop_changes.lw = 40;

// Number of characters that may be placed on a single row of the page, default
// in GAMS is 255, increase as needed
f_loop_changes.pw = 500;

put f_loop_changes

* --- Update investment data in the subsequent models -------------------------

// Transfer capacity
put "* Update transfer capacities in the subsequent models"/;
loop(gn2n_directional(grid, node, node_)
    ${sum(t_invest,
        r_invest_transferCapacity_gnn(grid, node, node_, t_invest))},
    tmp = p_gnn(grid, node, node_, 'transferCap');
    tmp_ = p_gnn(grid, node_, node, 'transferCap');
    loop(t_invest(t),
        tmp = tmp + r_invest_transferCapacity_gnn(grid, node, node_, t);
        tmp_ = tmp_ + r_invest_transferCapacity_gnn(grid, node, node_, t);
        put "if(ord(t_solve) >= ", ord(t), " - 1,"/;
        put "    p_gnn('", grid.tl, "', '", node.tl, "', '", node_.tl,
            "', 'transferCap')"/;
        put "        = ", tmp, ";"/;
        put "    p_gnn('", grid.tl, "', '", node_.tl, "', '", node.tl,
            "', 'transferCap')"/;
        put "        = ", tmp_, ";"/;
        put ");"/;
    );
);

putclose;

$offtext
