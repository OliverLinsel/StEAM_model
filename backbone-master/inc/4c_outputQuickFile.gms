$ontext
This file is part of Backbone.

Backbone is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Backbone is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with Backbone.  If not, see <http://www.gnu.org/licenses/>.

For further information, see https://gitlab.vtt.fi/backbone/backbone/-/wikis/home

$offtext

put f_info
put "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"/;
put "¤ MODEL RUN DETAILS                                                   ¤"/;
put "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"/;
loop(metadata,
    put metadata.tl:20, metadata.te(metadata) /;
); // END loop(metadata)
put /;
put "time (s)":> 25 /;
put "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"/;
put "Compilation", system.tcomp:> 14 /;
put "Execution  ", system.texec:> 14 /;
put "Total      ", system.elapsed:> 14 /;
put /;
put "dummies":> 25 /;
put "¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨¨"/;
put "qCapacity      ", sum((grid, node, f, t), r_qCapacity_ft(grid, node, f, t)):> 10  /;
put "qGen           ", sum((inc_dec, grid), r_qGen_g(inc_dec, grid)):> 10  /;
put "qReserveDemand ", sum(restypeDirectionGroup, r_qReserveDemand(restypeDirectionGroup)):> 10  /;
put "qReserveMissing", sum(restypeDirectionGroup, r_qReserveMissing(restypeDirectionGroup)):> 10  /;
put "qUnitConstraint", sum((inc_dec, unitConstraint(unit, constraint)), r_qUnitConstraint_u(inc_dec, constraint, unit)):> 10  /;
put /;
put /;
put "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"/;
put "¤ MODEL FEATURES                                                      ¤"/;
put "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"/;
loop(m,
put "Model: ", m.tl:0/;
put "-----------------------------------------------------------------------"/;
*put "Threads: ", m.threads:0:0 /;
put "Active features:"/;
* search key: activeFeatures
loop(active(m, feature),
    put feature.tl:20, feature.te(feature):0 /;
); // END loop(active)
put /;
f_info.nd = 0; // Set number of decimals to zero
put "Start time:                 ", mSettings(m, 't_start')/;
put "Last time step for results: ", mSettings(m, 't_end')/;
put "Model horizon:              ", mSettings(m, 't_horizon')/;
put "Model jump between solves   ", mSettings(m, 't_jump')/;
put "Number of forecasts:        ", mSettings(m, 'forecasts')/;
put "Length of forecasts:        ", mSettings(m, 't_forecastLengthUnchanging')/;
put "Number of samples:          ", mSettings(m, 'samples')/;
put /;
); // END loop(m)
putclose;
* -----------------------------------------------------------------------------
