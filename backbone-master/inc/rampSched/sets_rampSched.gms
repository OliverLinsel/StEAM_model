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

* External time
Sets
    rampNotchTime(t) "Time periods that may contain ramp notch"
    rampSearchTime(t) "Time periods that will be searched for the highest ramp notch"
    rStarts "Start times for sorting time series" /r0000*r2000/
    ramp "Ramping periods for searchRamp" /ramp000*ramp999/
    notch "Set of possible notches" /notch000*notch999/
;

alias(ramp, ra);
alias(notch, notch_, notch__);
