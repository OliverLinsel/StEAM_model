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

* --- Parameters for sorting time series
Parameters
    s_rampStarts(rStarts)
    s_sortCount
    s_rampLengthAve
    s_rampWindow
    s_rampSegments
    s_rampExcludeFromSearchLength
    s_maxSegmentLengthWithoutNotch
    s_segmentLengthFound
    s_segmentLengthCurrent
    s_currentMax
    s_currentMaxPos
    s_stop
    s_previousHourOrd
    s_notchCount
    s_notchPos
    s_netLoadChanged
    s_rampWindowPrev
    s_rampSegmentsPrev
    s_maxSegmentLengthWithoutNotchPrev
    s_rampExcludeFromSearchLengthPrev
    s_netLoadAtNotch

    ts_netLoad(node, t) "net load time series"
    ts_netLoadRamp(node, t) "net load ramp time series"
    ts_netLoadRampAve(notch, notch) "net load ramp averages"
    ts_netLoadCur(t) "net load time series for current node/year"
    ts_netLoadRampWindow(node, t) "averaging window for net load ramp"
    ts_netLoad2ndDer(node, t) "net load 2nd derivative time series"
    ts_netLoadRampNotches(node, t) "possible notches"
    ts_netLoadRampResult(node, t) "net load ramps with reduced time series"
    ts_notchPos(notch) "position of the possible notches"
    ts_segmentErrorSquared(notch, notch_) "precalculated error penalties for selectable ramp segments"
    ts_sortIndex(node, t) "sort rank for time series"
    ts_sortedNetLoad(node, t) "sorted net load time series"
;

s_rampWindow = 8760;
s_rampSegments = 70;
s_rampExcludeFromSearchLength = 10;
s_maxSegmentLengthWithoutNotch = 25;

s_rampWindowPrev = 0;
s_rampSegmentsPrev = 0;
s_maxSegmentLengthWithoutNotchPrev = 0;
s_rampExcludeFromSearchLengthPrev = 0;
