* --- Additions to input data --------------------------------------------------






* listing aggregator units. Normally not listed in invest run.
unitAggregator_unit(unit, unit_)$sum(effLevel, unitUnitEffLevel(unit, unit_, effLevel)) = yes;
unit_aggregator(unit)${ sum(unit_, unitAggregator_unit(unit, unit_)) } = yes; 

* disabling aggregator units in invest run
utAvailabilityLimits(unit_aggregator, t, 'becomeUnavailable') = no;
utAvailabilityLimits(unit_aggregator, t, 'becomeAvailable') = no;
utAvailabilityLimits(unit_aggregator, 't000001', 'becomeUnavailable') = yes;