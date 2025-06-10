* the model reads changes.inc after input data gdx and after 1e_scenchanges.gms
* changes.inc can be used for may uses, e.g. modifying input data or reading second input file


* Converting all invest units with directLP to directOff
* Note: Excluding flow units as those should not have efficiency parameters
* Note: The model should work as intended even if these extra parameters are given to flow units
loop(unit${ not unit_flow(unit) },
    if(p_unit(unit, 'maxUnitCount')>0,
        effLevelGroupUnit(effLevel, 'directOnLP', unit) = no;

        effLevelGroupUnit('level1', 'directOff', unit) = yes;
        effLevelGroupUnit('level2', 'directOff', unit) = yes;
        effLevelGroupUnit('level3', 'directOff', unit) = yes;
    );
);




* Adjusting emissionPrice based on value in changes.inc 
* Note: example uses hard coded names which must match input data.
ts_emissionPriceChange('CO2', 'CO2group', 't000001') = 40;



* Adjusting emissionPrice based on command line parameter. 
* After this, user can easily script scenarios by giving --emissionsPrice=40  as a run parameter
* Note: example uses hard coded names which must match input data.

* Setting default value to avoid crash if user forgets to give this parameter
$if not set emissionPrice $set emissionPrice '40'

* setting emission price to user given value  
ts_emissionPriceChange('CO2', 'CO2group', 't000001') = %emissionPrice%;



