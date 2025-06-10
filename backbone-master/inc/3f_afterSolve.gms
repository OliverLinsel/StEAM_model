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

* =============================================================================
* --- Optional manipulation after solve ---------------------------------------
* =============================================================================

$ontext
// Release some fixed values

// Release BoundEnd for the last time periods in the previous solve
v_state.up(grid, node, ft(f, t))${   ft_lastSteps(f, t)
                                    and p_gn(grid, node, 'boundEnd')
                                }
    = p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'constant')
        * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');

// BoundEnd to a time series value
v_state.fx(grid, node, ft(f, t))${   ft_lastSteps(f, t)
                                    and p_gn(grid, node, 'boundEnd')
                                    and p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'useTimeSeries')
                                }
    = ts_node_(grid, node, 'reference', f, t)
        * p_gnBoundaryPropertiesForStates(grid, node, 'reference', 'multiplier');
$offtext
