* --- Additions to input data --------------------------------------------------




* Load invest results from another file if exists
$ifthen exist '%input_dir%/invest_results.inc'
   $$include '%input_dir%/invest_results.inc'
$endif




* deactivating investment options

p_unit(unit, 'maxUnitCount') = 0;
p_unit(unit, 'minUnitCount') = 0;

p_gnn(grid, from_node, to_node, 'transferCapInvLimit') = 0;
t_invest(t) = no;

p_gn(grid, node, 'capacityMargin') = 0;