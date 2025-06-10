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

ts_netLoad(node, hour) =
    sum(load$load_in_hub(load, node), ts_elecLoad(load, hour)) -
    sum(unit_flow$unit_in_hub(unit_flow, node),
        ts_fluctuation(unit_flow, hour) * p_data(unit_flow, 'max_power')
    );

for (w_sortCount = 0 to (floor(card(hour) / RAMP_LENGTH)),
    w_rampStarts(rStarts)$(ord(rStarts) = w_sortCount + 1) = w_sortCount * RAMP_LENGTH + 1;
);


loop(rStarts$(w_rampStarts(rStarts) > 0 and ord(rStarts) < w_sortCount ),
    ts_sortIndex(h, node)$(simYear(year) and ord(h) >= w_rampStarts(rStarts) and ord(h) < w_rampStarts(rStarts + 1) ) =
        sum(hour$(ord(hour) >= w_rampStarts(rStarts)
            and ord(hour) < w_rampStarts(rStarts + 1)
            and ts_netLoad(node, hour) > ts_netLoad(h, node) )
            , 1
        )
    ;
);

loop((node, hour)$simYear(year),
    loop(h$(ord(h) = ts_sortIndex(node, hour) + 1 + floor((ord(hour)-1) / RAMP_LENGTH) * RAMP_LENGTH ),
        ts_sortedNetLoad(h, node) = ts_netLoad(node, hour);
    );
);


execute_unload 'ts_netload.gdx', ts_netLoad, ts_sortIndex, ts_sortedNetLoad;



