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

equations  // For ramp search
    q_searchRampObj "Objective function for searching the ramps"
    q_notchCount
    q_initialNotch(notch)
    q_intermediateNotches(notch)
    q_lastNotch(notch)
;


q_searchRampObj ..
  + v_searchRampObj
  =E=
  + sum(notch$(ord(notch) <= s_notchCount),
        sum(notch_$(ord(notch_) <= s_notchCount),
            v_rampNotch(notch, notch_) * ts_segmentErrorSquared(notch, notch_)
        )
    );

q_notchCount ..
  + sum(notch$(ord(notch) <= s_notchCount ),
        sum(notch_$(ord(notch_) <= s_notchCount ),
            v_rampNotch(notch_, notch)
        )
    )
  =E=
  + s_rampSegments;


q_initialNotch(notch)$(ord(notch) = 1 ) ..
  + sum(notch_$(ord(notch_) <= s_notchCount ), v_rampNotch(notch, notch_) )
  =E=
  1
;

q_intermediateNotches(notch)$(ord(notch) > 1 and ord(notch) < s_notchCount ) ..
  + sum(notch_$(ord(notch_) <= s_notchCount ), v_rampNotch(notch, notch_) )
  =E=
  + sum(notch__$(ord(notch__) <= s_notchCount ), v_rampNotch(notch__, notch) )
;

q_lastNotch(notch)$(ord(notch) = s_notchCount ) ..
  + sum(notch_$(ord(notch_) <= s_notchCount ), v_rampNotch(notch_, notch) )
  =E=
  1
;


model searchRamp
/
q_searchRampObj
q_notchCount
q_initialNotch
q_intermediateNotches
q_lastNotch
/;

