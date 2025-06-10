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
$offtext

* rampSchedTimeSeries_rampSearch segments netLoad of each node based on ramps
* It tries to find the least square error for a certain number of segments.
* It cannot use all possible combinations, as it would take too much time to iterate
* all possible combinations of ramps.
* Therefore an algorithm first tries to find candidates for 'notches' in the netLoad
* Please note, that if you change the algorithms, make sure that it runs the code (it will not, if data or parameters haven't changed)

$include 'inc/rampSched/sets_rampSched.gms'
$include 'inc/rampSched/parameters_rampSched.gms'
$include 'inc/rampSched/variables_rampSched.gms'
$include 'inc/rampSched/equations_rampSched.gms'

execute_load 'ts_netload.gdx', ts_netLoad;


* Check if there is a change in netLoad
s_netLoadChanged = 0;
loop(gn(grid,node),
        loop(t$(ord(t) = 1),
            if (ts_netLoad(node, t) <>
                // Calculates a moving window for net load using linearly increasing/decreasing weighting
                sum((fRealization(f), t_)$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12),
                    (ts_energyDemand(grid, node, s, f, t_) -
                        sum(unit_flow(flow, unit_flow)$nu(unit_flow, node),
                          ts_cf(flow, node, f, t) *
                          p_data2d(grid, unit_flow, 'capacity')
                          *[
                            + p_unit(unit_flow, 'availability')${not p_unit(unit_flow, 'useTimeseriesAvailability')}
                            + ts_unit_(unit_flow, 'availability', f, t)${p_unit(unit_flow, 'useTimeseriesAvailability')}
                            ]
                        )
                    ) * (13 - abs(ord(t) - ord(t_)))  // Weighting
                )  /
                sum(t_$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12), (13 - abs(ord(t) - ord(t_))) ) ,
                put log;
                put 'Net load changed in node: ' node.tl;
                putclose;
                s_netLoadChanged = 1;
            )
        )
);


* If net load has changed, then recalculate
if (s_netLoadChanged = 1,
    put log;
    put 'Calculating smoothed net load...';
    ts_netLoad(node, t) =
        sum((fRealization(f), gn(grid, node), t_)$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12),
            (ts_energyDemand(grid, node, s, f, t_) -
                sum(unit_flow(flow, unit_flow)$nu(unit_flow, node),
                   ts_cf(flow, node, f, t) *
                   p_data2d(grid, unit_flow, 'capacity') *
                   *[
                      + p_unit(unit_flow, 'availability')${not ts_unit(unit_flow, 'availability', f, t)}
                      + ts_unit_(unit_flow, 'availability', f, t)${ts_unit(unit_flow, 'availability', f, t) and unit_timeseries(unit_flow)}
                      ]
                )
            ) * (13 - abs(ord(t) - ord(t_)))
        )  /
        sum(t_$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12), (13 - abs(ord(t) - ord(t_))) );
    put ' ...done'/;

    put 'Calculating net load ramps...';
    ts_netLoadRamp(node, t)$(ord(t) > 1) = ts_netLoad(node, t) - ts_netload(node, t-1);
    ts_netLoadRampWindow(node, t)$(ord(t) > 1) =
        sum(t_$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12),
            ts_netLoadRamp(node, t) * (13 - abs(ord(t) - ord(t_)))
        )  /
        sum(t_$(ord(t_) > ord(t) - 12 and ord(t_) <= ord(t) + 12), (13 - abs(ord(t) - ord(t_))) );
    ts_netLoad2ndDer(node, t)$(ord(t) > 2) = ts_netLoadRampWindow(node, t) - ts_netloadRampWindow(node, t-1);
    put ' ...done';
    putclose;
    execute_unload 'ts_netload.gdx', ts_netLoad, ts_netLoadRamp, ts_netLoad2ndDer;
else
    execute_load 'ts_netload.gdx', ts_netLoadRamp, ts_netLoad2ndDer;
);


execute_load 'ts_rampResults.gdx', s_maxSegmentLengthWithoutNotchPrev, s_rampSegmentsPrev, s_rampWindowPrev, s_rampExcludeFromSearchLengthPrev;

// Set solve options for the searchRamp
options
    sparseopt = fast
;
searchRamp.optca = 0;
searchRamp.optcr = 0;
searchRamp.reslim = 10000;
searchRamp.threads = 0;
searchRamp.optfile = 1;

    loop(node$(ord(node) = 1),
        if (s_netLoadChanged or (s_maxSegmentLengthWithoutNotch <> s_maxSegmentLengthWithoutNotchPrev) or (s_rampWindow <> s_rampWindowPrev) or (s_rampExcludeFromSearchLength <> s_rampExcludeFromSearchLengthPrev),
            put log;
            ts_netLoadCur(t) = ts_netLoad2ndDer(node, t);
            rampNotchTime(t) = no;
            rampSearchTime(t) = yes;
            s_segmentLengthFound = s_rampWindow;
            // find largest changes in the netLoad and make these candidate notches
            while (s_segmentLengthFound > s_maxSegmentLengthWithoutNotch,
                s_currentMax = 0;
                // find the largest remaining change
                loop(t$(rampSearchTime(t) and ord(t) <= s_rampWindow),
                    if(abs(ts_netLoadCur(t)) > s_currentMax,
                        s_currentMax = abs(ts_netLoadCur(t));
                        s_currentMaxPos = ord(t);
                    )
                );
                // mark the largest remaining change as a candidate notch
                rampNotchTime(t)$(ord(t) = s_currentMaxPos) = yes;

                // don't search those hours any longer that are close to the notch that was just found
                loop(t$(ord(t) >= s_currentMaxPos - s_rampExcludeFromSearchLength and ord(t) <= s_currentMaxPos + s_rampExcludeFromSearchLength ),
                    rampSearchTime(t) = no;
                );

                // Rest of the while loop will calculate the longest stretch where there are no notches and check if while can be terminated
                s_previousHourOrd = 0;
                s_segmentLengthFound = 0;
                s_segmentLengthCurrent = 1;
                // loop through hours that are not candidate notches
                loop(t$(not rampNotchTime(t) and ord(t) <= s_rampWindow),
                    // check if the hour is adjacent with the previous hour
                    if(ord(t) = s_previousHourOrd + 1,   // if yes, then increment counter
                        s_segmentLengthCurrent = s_segmentLengthCurrent + 1;
                    else    // if not, then check if the segment was longer than longest so far
                        if (s_segmentLengthCurrent > s_segmentLengthFound,
                            // updating new longest segment
                            s_segmentLengthFound = s_segmentLengthCurrent;
                        );
                        s_segmentLengthCurrent = 1; // start segment length counter from one
                    );
                    s_previousHourOrd = ord(t)  // update the position of the previous hour for the next loop
                );

                put 's_segmentLengthFound = ' s_segmentLengthFound;
                put '  s_CurrentMaxPos = ' s_CurrentMaxPos;
                put /;
            );
            // Mark notch positions also to a time series (helps with checking the results)
            s_notchCount = 1;
            ts_notchPos(notch)$(ord(notch) = s_notchCount) = 1;
            loop(t$(rampNotchTime(t) and ord(t) <= s_rampWindow ),
                s_notchCount = s_notchCount + 1;
                ts_notchPos(notch)$(ord(notch) = s_notchCount ) = ord(t);
            );
            s_notchCount = s_notchCount + 1;
            ts_notchPos(notch)$(ord(notch) = s_notchCount) = s_rampWindow;
            put 'Number of segments: ' s_notchCount;
            putclose;

            loop(notch$(ord(notch) <= s_notchCount ),
                // Calculate the average ramp rate for the segments (only those segments that are relevant)
                ts_netLoadRampAve(notch, notch_)$(ord(notch_) > ord(notch) and ord(notch_) <= s_notchCount and ord(notch_) <= ord(notch) + (s_notchCount - s_rampSegments) ) =
                    sum(t$(ord(t) > 1 and ord(t) >= ts_notchPos(notch) and ord(t) <= ts_notchPos(notch_) ), ts_netLoadRamp(node, t) ) /
                    sum(t$(ord(t) > 1 and ord(t) >= ts_notchPos(notch) and ord(t) <= ts_notchPos(notch_) ), 1 );

                // Calculate the squared error penalty for using a particular segment
                s_netLoadAtNotch = sum(t_$(ord(t_) = ts_notchPos(notch) ), ts_netLoad(node, t_) );
                ts_segmentErrorSquared(notch, notch_)$(ord(notch_) > ord(notch) and ord(notch_) <= s_notchCount and ord(notch_) <= ord(notch) + (s_notchCount - s_rampSegments) ) =
                    sum(t$(ord(t) > ts_notchPos(notch) and ord(t) < ts_notchPos(notch_) ),
                        // Squared difference between actual netLoad and netLoad calculated from average ramp over the segment
                        (ts_netLoad(node, t) -
                            (s_netLoadAtNotch + (ord(t) - ts_notchPos(notch) ) * ts_netLoadRampAve(notch, notch_) ) ) *
                        (ts_netLoad(node, t) -
                            (s_netLoadAtNotch + (ord(t) - ts_notchPos(notch) ) * ts_netLoadRampAve(notch, notch_) ) )
                    );
                if (ord(notch) < s_notchCount,
                    put log;
                    put 'segment: ' ord(notch);
                    putclose;
                );
            );
            // prevent from going backwards
            v_rampNotch.fx(notch, notch_)$(ord(notch) <= s_notchCount and ord(notch_) <= ord(notch) and ord(notch_) <= s_notchCount ) = 0;
            // preclude an area, which cannot be reached
            v_rampNotch.fx(notch, notch_)$(ord(notch_) > ord(notch) + (s_notchCount - s_rampSegments) ) = 0;
        else
            execute_load 'ts_rampResults.gdx', ts_segmentErrorSquared, ts_notchPos;
        );

        // If parameters or data have changed, resolve notches and segments
        if ((s_rampWindow <> s_rampWindowPrev) or s_netLoadChanged or (s_maxSegmentLengthWithoutNotch <> s_maxSegmentLengthWithoutNotchPrev) or (s_rampWindow <> s_rampWindowPrev) or (s_rampExcludeFromSearchLength <> s_rampExcludeFromSearchLengthPrev),

            solve searchRamp using MIP minimizing v_searchRampObj;

            s_notchCount = 2;
            // Mark all empty (using EPS, zero will not provide full time series)
            ts_netLoadRampResult(node, t) = EPS;
            ts_netLoadRampNotches(node, t) = EPS;
            loop(t$(rampNotchTime(t) and ord(t) <= s_rampWindow ),
                ts_netLoadRampNotches(node, t) = ts_netLoad(node, t);
                loop(notch_$(ord(notch_) = s_notchCount),
                    if (sum(notch, v_rampNotch.l(notch, notch_) = 1 ),
                        ts_netLoadRampResult(node, t) = ts_netLoad(node, t);
                    );
                );
                s_notchCount = s_notchCount + 1;
            );
            s_rampWindowPrev = s_rampWindow;
            s_rampSegmentsPrev = s_rampSegments;
            s_maxSegmentLengthWithoutNotchPrev = s_maxSegmentLengthWithoutNotch;
            s_rampExcludeFromSearchLengthPrev = s_rampExcludeFromSearchLength;

            execute_unload 'ts_rampResults.gdx', ts_netLoadRampAve, ts_netLoadRampResult, ts_segmentErrorSquared, ts_netLoadRampNotches, ts_notchPos,
                v_rampNotch, v_rampSegment, v_searchRampObj, rampNotchTime, rampSearchTime,
                s_maxSegmentLengthWithoutNotchPrev, s_rampSegmentsPrev, s_rampWindowPrev, s_rampExcludeFromSearchLengthPrev;
        else
            execute_load 'ts_rampResults.gdx', ts_netLoadRampResult, ts_netLoadRampNotches,
                v_rampNotch, v_rampSegment, v_searchRampObj;
        );
    );


$include 'inc/rampSched/killStuff.gms'
