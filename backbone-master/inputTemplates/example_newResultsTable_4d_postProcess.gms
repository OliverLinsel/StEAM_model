
* 4d_postProcess.gms is read after calculating the default results and
* it is the last place to adjust anything before writing the result file.
* This is a template file giving an example how this can be used to expand the result file

* Declaring a new result table: sum of unit VOM costs
Parameter
        r_cost_unitVOMCost_u(unit) "Sum of unit VOM costs"
;


* Calculating the values for the new result table.
* See further examples from 4b_outputInvariant.gms
r_cost_unitVOMCost_u(unit)
    = sum(gnu(grid, node, unit),
            + r_cost_unitVOMCost_gnu(grid, node, unit)
      ); // END sum(gnu)
      
