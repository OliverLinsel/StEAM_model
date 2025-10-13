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

//test for modeling horizon through MainInput.xlsx:                 //while this works fine starting in the middle of the data via model_date.csv makes all units unavailable atm... should be configured dynamically as well if need be ## to do ##
//$call gdxxrw.exe ..\PythonScripts\TEMP\MainInput.xlsx output=bb_model_date.gdx index=bb_index!
//Scalar steam_model_duration;
//Scalar steam_model_start;
//$gdxin bb_model_date.gdx
//$load steam_model_duration
//$load steam_model_start
//$gdxin

sGroup('s000','fuelGroup') = yes; // this connects our (time) sample to the fuelGroup which is handling the CO2 emissionCap parameter

* =============================================================================
* --- Model Definition - Invest -----------------------------------------------
* =============================================================================

if (mType('invest'),
    m('invest') = yes; // Definition, that the model exists by its name

* --- Define Key Execution Parameters in Time Indeces -------------------------

    // Define simulation start and end time indeces
    mSettings('invest', 't_start') = 1;  // First time step to be solved, 1 corresponds to t000001 (t000000 will then be used for initial status of dynamic variables)
    mSettings('invest', 't_end') = 8760+1; // Last time step to be included in the solve (may solve and output more time steps in case t_jump does not match)

    // Define simulation horizon and moving horizon optimization "speed"
    mSettings('invest', 't_horizon') = 8760+1;    // How many active time steps the solve contains (aggregation of time steps does not impact this, unless the aggregation does not match)
    mSettings('invest', 't_jump') = 8760+1;          // How many time steps the model rolls forward between each solve

    // Define 24 of data for proper circulation
    mSettings('invest', 'dataLength') = 8760;
* =============================================================================
* --- Model Time Structure ----------------------------------------------------
* =============================================================================

* --- Define Samples ----------------------------------------------------------

* --- Define Samples ----------------------------------------------------------

    // Number of samples used by the model
    mSettings('invest', 'samples') = 1;

    // Define Initial and Central samples
    ms_initial('invest', 's000') = yes;
    ms_central('invest', 's000') = yes;

    // Define time span of samples
	msStart('invest', 's000') = 6721;
	msEnd('invest', 's000') = 6745;


    // Define the probability (weight) of samples
    p_msProbability('invest', s) = 0;
	p_msProbability('invest', 's000') = 1;

    p_msWeight('invest', s) = 0;
	p_msWeight('invest', 's000') = 365.000000;

    p_msAnnuityWeight('invest', s) = 0;
    p_msAnnuityWeight('invest', 's000') = 8760.000000/8760;

* --- Define Time Step Intervals ----------------------------------------------

    // Define the duration of a single time-step in hours
    mSettings('invest', 'stepLengthInHours') = 1;

    // Define the time step intervals in time-steps
    mInterval('invest', 'stepsPerInterval', 'c000') = 1;
    mInterval('invest', 'lastStepInIntervalBlock', 'c000') = 8760+1;

* --- z-structure for superpositioned nodes ----------------------------------

    // number of candidate periods in model
    // please provide this data
    mSettings('invest', 'candidate_periods') = 365;//0;

    // add the candidate periods to model
    // no need to touch this part
    mz('invest', z) = no;
    loop(z$(ord(z) <= mSettings('invest', 'candidate_periods') ),
       mz('invest', z) = yes;
    );

    // Mapping between typical periods (=samples) and the candidate periods (z).
    // Assumption is that candidate periods start from z000 and form a continuous
    // sequence.
    // please provide this data
    zs(z,s) = no;
    //zs('z000','s000') = yes;
    //zs('z001','s000') = yes;
    //zs('z002','s001') = yes;
    //zs('z003','s001') = yes;
    //zs('z004','s002') = yes;
    //zs('z005','s003') = yes;
    //zs('z006','s004') = yes;
    //zs('z007','s002') = yes;
    //zs('z008','s002') = yes;
    //zs('z009','s004') = yes;
    
	zs('z000','s000') = yes;
	zs('z001','s000') = yes;
	zs('z002','s000') = yes;
	zs('z003','s000') = yes;
	zs('z004','s000') = yes;
	zs('z005','s000') = yes;
	zs('z006','s000') = yes;
	zs('z007','s000') = yes;
	zs('z008','s000') = yes;
	zs('z009','s000') = yes;
	zs('z010','s000') = yes;
	zs('z011','s000') = yes;
	zs('z012','s000') = yes;
	zs('z013','s000') = yes;
	zs('z014','s000') = yes;
	zs('z015','s000') = yes;
	zs('z016','s000') = yes;
	zs('z017','s000') = yes;
	zs('z018','s000') = yes;
	zs('z019','s000') = yes;
	zs('z020','s000') = yes;
	zs('z021','s000') = yes;
	zs('z022','s000') = yes;
	zs('z023','s000') = yes;
	zs('z024','s000') = yes;
	zs('z025','s000') = yes;
	zs('z026','s000') = yes;
	zs('z027','s000') = yes;
	zs('z028','s000') = yes;
	zs('z029','s000') = yes;
	zs('z030','s000') = yes;
	zs('z031','s000') = yes;
	zs('z032','s000') = yes;
	zs('z033','s000') = yes;
	zs('z034','s000') = yes;
	zs('z035','s000') = yes;
	zs('z036','s000') = yes;
	zs('z037','s000') = yes;
	zs('z038','s000') = yes;
	zs('z039','s000') = yes;
	zs('z040','s000') = yes;
	zs('z041','s000') = yes;
	zs('z042','s000') = yes;
	zs('z043','s000') = yes;
	zs('z044','s000') = yes;
	zs('z045','s000') = yes;
	zs('z046','s000') = yes;
	zs('z047','s000') = yes;
	zs('z048','s000') = yes;
	zs('z049','s000') = yes;
	zs('z050','s000') = yes;
	zs('z051','s000') = yes;
	zs('z052','s000') = yes;
	zs('z053','s000') = yes;
	zs('z054','s000') = yes;
	zs('z055','s000') = yes;
	zs('z056','s000') = yes;
	zs('z057','s000') = yes;
	zs('z058','s000') = yes;
	zs('z059','s000') = yes;
	zs('z060','s000') = yes;
	zs('z061','s000') = yes;
	zs('z062','s000') = yes;
	zs('z063','s000') = yes;
	zs('z064','s000') = yes;
	zs('z065','s000') = yes;
	zs('z066','s000') = yes;
	zs('z067','s000') = yes;
	zs('z068','s000') = yes;
	zs('z069','s000') = yes;
	zs('z070','s000') = yes;
	zs('z071','s000') = yes;
	zs('z072','s000') = yes;
	zs('z073','s000') = yes;
	zs('z074','s000') = yes;
	zs('z075','s000') = yes;
	zs('z076','s000') = yes;
	zs('z077','s000') = yes;
	zs('z078','s000') = yes;
	zs('z079','s000') = yes;
	zs('z080','s000') = yes;
	zs('z081','s000') = yes;
	zs('z082','s000') = yes;
	zs('z083','s000') = yes;
	zs('z084','s000') = yes;
	zs('z085','s000') = yes;
	zs('z086','s000') = yes;
	zs('z087','s000') = yes;
	zs('z088','s000') = yes;
	zs('z089','s000') = yes;
	zs('z090','s000') = yes;
	zs('z091','s000') = yes;
	zs('z092','s000') = yes;
	zs('z093','s000') = yes;
	zs('z094','s000') = yes;
	zs('z095','s000') = yes;
	zs('z096','s000') = yes;
	zs('z097','s000') = yes;
	zs('z098','s000') = yes;
	zs('z099','s000') = yes;
	zs('z100','s000') = yes;
	zs('z101','s000') = yes;
	zs('z102','s000') = yes;
	zs('z103','s000') = yes;
	zs('z104','s000') = yes;
	zs('z105','s000') = yes;
	zs('z106','s000') = yes;
	zs('z107','s000') = yes;
	zs('z108','s000') = yes;
	zs('z109','s000') = yes;
	zs('z110','s000') = yes;
	zs('z111','s000') = yes;
	zs('z112','s000') = yes;
	zs('z113','s000') = yes;
	zs('z114','s000') = yes;
	zs('z115','s000') = yes;
	zs('z116','s000') = yes;
	zs('z117','s000') = yes;
	zs('z118','s000') = yes;
	zs('z119','s000') = yes;
	zs('z120','s000') = yes;
	zs('z121','s000') = yes;
	zs('z122','s000') = yes;
	zs('z123','s000') = yes;
	zs('z124','s000') = yes;
	zs('z125','s000') = yes;
	zs('z126','s000') = yes;
	zs('z127','s000') = yes;
	zs('z128','s000') = yes;
	zs('z129','s000') = yes;
	zs('z130','s000') = yes;
	zs('z131','s000') = yes;
	zs('z132','s000') = yes;
	zs('z133','s000') = yes;
	zs('z134','s000') = yes;
	zs('z135','s000') = yes;
	zs('z136','s000') = yes;
	zs('z137','s000') = yes;
	zs('z138','s000') = yes;
	zs('z139','s000') = yes;
	zs('z140','s000') = yes;
	zs('z141','s000') = yes;
	zs('z142','s000') = yes;
	zs('z143','s000') = yes;
	zs('z144','s000') = yes;
	zs('z145','s000') = yes;
	zs('z146','s000') = yes;
	zs('z147','s000') = yes;
	zs('z148','s000') = yes;
	zs('z149','s000') = yes;
	zs('z150','s000') = yes;
	zs('z151','s000') = yes;
	zs('z152','s000') = yes;
	zs('z153','s000') = yes;
	zs('z154','s000') = yes;
	zs('z155','s000') = yes;
	zs('z156','s000') = yes;
	zs('z157','s000') = yes;
	zs('z158','s000') = yes;
	zs('z159','s000') = yes;
	zs('z160','s000') = yes;
	zs('z161','s000') = yes;
	zs('z162','s000') = yes;
	zs('z163','s000') = yes;
	zs('z164','s000') = yes;
	zs('z165','s000') = yes;
	zs('z166','s000') = yes;
	zs('z167','s000') = yes;
	zs('z168','s000') = yes;
	zs('z169','s000') = yes;
	zs('z170','s000') = yes;
	zs('z171','s000') = yes;
	zs('z172','s000') = yes;
	zs('z173','s000') = yes;
	zs('z174','s000') = yes;
	zs('z175','s000') = yes;
	zs('z176','s000') = yes;
	zs('z177','s000') = yes;
	zs('z178','s000') = yes;
	zs('z179','s000') = yes;
	zs('z180','s000') = yes;
	zs('z181','s000') = yes;
	zs('z182','s000') = yes;
	zs('z183','s000') = yes;
	zs('z184','s000') = yes;
	zs('z185','s000') = yes;
	zs('z186','s000') = yes;
	zs('z187','s000') = yes;
	zs('z188','s000') = yes;
	zs('z189','s000') = yes;
	zs('z190','s000') = yes;
	zs('z191','s000') = yes;
	zs('z192','s000') = yes;
	zs('z193','s000') = yes;
	zs('z194','s000') = yes;
	zs('z195','s000') = yes;
	zs('z196','s000') = yes;
	zs('z197','s000') = yes;
	zs('z198','s000') = yes;
	zs('z199','s000') = yes;
	zs('z200','s000') = yes;
	zs('z201','s000') = yes;
	zs('z202','s000') = yes;
	zs('z203','s000') = yes;
	zs('z204','s000') = yes;
	zs('z205','s000') = yes;
	zs('z206','s000') = yes;
	zs('z207','s000') = yes;
	zs('z208','s000') = yes;
	zs('z209','s000') = yes;
	zs('z210','s000') = yes;
	zs('z211','s000') = yes;
	zs('z212','s000') = yes;
	zs('z213','s000') = yes;
	zs('z214','s000') = yes;
	zs('z215','s000') = yes;
	zs('z216','s000') = yes;
	zs('z217','s000') = yes;
	zs('z218','s000') = yes;
	zs('z219','s000') = yes;
	zs('z220','s000') = yes;
	zs('z221','s000') = yes;
	zs('z222','s000') = yes;
	zs('z223','s000') = yes;
	zs('z224','s000') = yes;
	zs('z225','s000') = yes;
	zs('z226','s000') = yes;
	zs('z227','s000') = yes;
	zs('z228','s000') = yes;
	zs('z229','s000') = yes;
	zs('z230','s000') = yes;
	zs('z231','s000') = yes;
	zs('z232','s000') = yes;
	zs('z233','s000') = yes;
	zs('z234','s000') = yes;
	zs('z235','s000') = yes;
	zs('z236','s000') = yes;
	zs('z237','s000') = yes;
	zs('z238','s000') = yes;
	zs('z239','s000') = yes;
	zs('z240','s000') = yes;
	zs('z241','s000') = yes;
	zs('z242','s000') = yes;
	zs('z243','s000') = yes;
	zs('z244','s000') = yes;
	zs('z245','s000') = yes;
	zs('z246','s000') = yes;
	zs('z247','s000') = yes;
	zs('z248','s000') = yes;
	zs('z249','s000') = yes;
	zs('z250','s000') = yes;
	zs('z251','s000') = yes;
	zs('z252','s000') = yes;
	zs('z253','s000') = yes;
	zs('z254','s000') = yes;
	zs('z255','s000') = yes;
	zs('z256','s000') = yes;
	zs('z257','s000') = yes;
	zs('z258','s000') = yes;
	zs('z259','s000') = yes;
	zs('z260','s000') = yes;
	zs('z261','s000') = yes;
	zs('z262','s000') = yes;
	zs('z263','s000') = yes;
	zs('z264','s000') = yes;
	zs('z265','s000') = yes;
	zs('z266','s000') = yes;
	zs('z267','s000') = yes;
	zs('z268','s000') = yes;
	zs('z269','s000') = yes;
	zs('z270','s000') = yes;
	zs('z271','s000') = yes;
	zs('z272','s000') = yes;
	zs('z273','s000') = yes;
	zs('z274','s000') = yes;
	zs('z275','s000') = yes;
	zs('z276','s000') = yes;
	zs('z277','s000') = yes;
	zs('z278','s000') = yes;
	zs('z279','s000') = yes;
	zs('z280','s000') = yes;
	zs('z281','s000') = yes;
	zs('z282','s000') = yes;
	zs('z283','s000') = yes;
	zs('z284','s000') = yes;
	zs('z285','s000') = yes;
	zs('z286','s000') = yes;
	zs('z287','s000') = yes;
	zs('z288','s000') = yes;
	zs('z289','s000') = yes;
	zs('z290','s000') = yes;
	zs('z291','s000') = yes;
	zs('z292','s000') = yes;
	zs('z293','s000') = yes;
	zs('z294','s000') = yes;
	zs('z295','s000') = yes;
	zs('z296','s000') = yes;
	zs('z297','s000') = yes;
	zs('z298','s000') = yes;
	zs('z299','s000') = yes;
	zs('z300','s000') = yes;
	zs('z301','s000') = yes;
	zs('z302','s000') = yes;
	zs('z303','s000') = yes;
	zs('z304','s000') = yes;
	zs('z305','s000') = yes;
	zs('z306','s000') = yes;
	zs('z307','s000') = yes;
	zs('z308','s000') = yes;
	zs('z309','s000') = yes;
	zs('z310','s000') = yes;
	zs('z311','s000') = yes;
	zs('z312','s000') = yes;
	zs('z313','s000') = yes;
	zs('z314','s000') = yes;
	zs('z315','s000') = yes;
	zs('z316','s000') = yes;
	zs('z317','s000') = yes;
	zs('z318','s000') = yes;
	zs('z319','s000') = yes;
	zs('z320','s000') = yes;
	zs('z321','s000') = yes;
	zs('z322','s000') = yes;
	zs('z323','s000') = yes;
	zs('z324','s000') = yes;
	zs('z325','s000') = yes;
	zs('z326','s000') = yes;
	zs('z327','s000') = yes;
	zs('z328','s000') = yes;
	zs('z329','s000') = yes;
	zs('z330','s000') = yes;
	zs('z331','s000') = yes;
	zs('z332','s000') = yes;
	zs('z333','s000') = yes;
	zs('z334','s000') = yes;
	zs('z335','s000') = yes;
	zs('z336','s000') = yes;
	zs('z337','s000') = yes;
	zs('z338','s000') = yes;
	zs('z339','s000') = yes;
	zs('z340','s000') = yes;
	zs('z341','s000') = yes;
	zs('z342','s000') = yes;
	zs('z343','s000') = yes;
	zs('z344','s000') = yes;
	zs('z345','s000') = yes;
	zs('z346','s000') = yes;
	zs('z347','s000') = yes;
	zs('z348','s000') = yes;
	zs('z349','s000') = yes;
	zs('z350','s000') = yes;
	zs('z351','s000') = yes;
	zs('z352','s000') = yes;
	zs('z353','s000') = yes;
	zs('z354','s000') = yes;
	zs('z355','s000') = yes;
	zs('z356','s000') = yes;
	zs('z357','s000') = yes;
	zs('z358','s000') = yes;
	zs('z359','s000') = yes;
	zs('z360','s000') = yes;
	zs('z361','s000') = yes;
	zs('z362','s000') = yes;
	zs('z363','s000') = yes;
	zs('z364','s000') = yes;

    

    // Make H2 nodes-state nodes
    //loop(gn('h2',node),
    //    gn_state('h2', node) = yes;
    //    p_gn('h2', node, 'energyStoredPerUnitOfState') = 1;
    //    p_gn('h2', node, 'nodeBalance') = 1;
    //);
    

    // Cyclic condition for short term storage (atm all nodes with states) (for single sample)
    loop(s$(ord(s) <= mSettings('invest', 'samples')),
        gnss_bound(gn_state(grid, node),s , s ) =yes;
        sGroup(s,'fuelGroup') = yes; // this connects our (time) sample to the fuelGroup which is handling the CO2 emissionCap parameter

    );

    // Cyclic condition for long term storage (H2, Hydro) (for complete modeling horizon)
    //loop(gn(grid,node)${sameas(grid, 'hydro') or sameas(grid, 'pumped') or sameas(grid, 'H2')},
    //gnss_bound(grid,node,'s000','s001') = yes;
    //gnss_bound(grid,node,'s001','s002') = yes;
    //gnss_bound(grid,node,'s002','s003') = yes;
    //gnss_bound(grid,node,'s003','s004') = yes;
    //gnss_bound(grid,node,'s004','s005') = yes;
    //gnss_bound(grid,node,'s005','s006') = yes;
    //gnss_bound(grid,node,'s006','s000') = yes;

*    gnss_bound(grid,node,'s006','s007') = yes;
*    gnss_bound(grid,node,'s007','s000') = yes;
//);

    node_superpos(node ) =no;
    //Superposition state for all nodes with states
    loop(gn_state(grid, node),      // unclear if superpositioning in general is needed or how it impacts performance and results
        node_superpos(node ) =yes;
    );

    
    
    
    loop(gnu_output(grid, node, unit),
        if(p_gnu_io(grid, node, unit, 'input', 'conversionCoeff')  = 0.0001,
           p_gnu_io(grid, node, unit, 'input', 'conversionCoeff') = Eps;
          ) ;
        if(p_gnu_io(grid, node, unit, 'output', 'capacity')  = 0.0001,
           p_gnu_io(grid, node, unit, 'output', 'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'capacity')  = 0.0001,
           p_gnu(grid, node, unit,'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'conversionCoeff')  = 0.0001,
           p_gnu(grid, node, unit,'conversionCoeff') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'InvCosts')  = 0.0001,
           p_gnu(grid, node, unit,'InvCosts') = Eps;
          ) ;

    );
    loop(gnu_input(grid, node, unit),
        if(p_gnu_io(grid, node, unit, 'input', 'conversionCoeff')  = 0.0001,
           p_gnu_io(grid, node, unit, 'input', 'conversionCoeff') = Eps;
          ) ;
        if(p_gnu_io(grid, node, unit, 'output', 'capacity')  = 0.0001,
           p_gnu_io(grid, node, unit, 'output', 'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'capacity')  = 0.0001,
           p_gnu(grid, node, unit,'capacity') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'conversionCoeff')  = 0.0001,
           p_gnu(grid, node, unit,'conversionCoeff') = Eps;
          ) ;
        if(p_gnu(grid, node, unit,  'InvCosts')  = 0.0001,
           p_gnu(grid, node, unit,'InvCosts') = Eps;
          ) ;
          
    );
$ontext
loop() for ## quick fix nuclear no invest

bb_dim_1_relationship_dtype_str.loc[((bb_dim_1_relationship_dtype_str['Object names'].str.contains('Nuclear')) & \
                                     (bb_dim_1_relationship_dtype_str['Parameter names'] == 'maxUnitCount')), 'Parameter values'] = eps
bb_dim_2_p_groupPolicyEmission = pd.DataFrame({
    'Relationship class names':'group__emission',
    'Object class names 1':'group',
    'Object class names 2':'emission',
    'Object names 1':'fuelGroup',
    'Object names 2':df_CO2_melt['Regional_emissions_budget'],
    'Parameter names':'emissionCap',
    'Alternative names':df_CO2_melt['Alternative names'],
    'Parameter values':df_CO2_melt['Parameter_value']})

bb_dim_2_p_groupPolicyEmission.loc[bb_dim_2_p_groupPolicyEmission['Parameter values'] ==0,'Parameter values'] = eps
$offtext

* =============================================================================
* --- Model Forecast Structure ------------------------------------------------
* =============================================================================

    // Define the number of forecasts used by the model
    mSettings('invest', 'forecasts') = 0;

    // Define forecast properties and features
    mSettings('invest', 't_forecastStart') = 0;                // At which time step the first forecast is available ( 1 = t000001 )
    mSettings('invest', 't_forecastLengthUnchanging') = 0;     // Length of forecasts in time steps - this does not decrease when the solve moves forward (requires forecast data that is longer than the horizon at first)
    mSettings('invest', 't_forecastLengthDecreasesFrom') = 0;  // Length of forecasts in time steps - this decreases when the solve moves forward until the new forecast data is read (then extends back to full 24)
    mSettings('invest', 't_forecastJump') = 0;                 // How many time steps before new forecast is available

    // Define Realized and Central forecasts
    mf_realization('invest', f) = no;
    mf_realization('invest', 'f00') = yes;
    mf_central('invest', f) = no;
    mf_central('invest', 'f00') = yes;

    // Define forecast probabilities (weights)
    p_mfProbability('invest', f) = 0;
    p_mfProbability(mf_realization('invest', f)) = 1;

    // Define active model features
    active('invest', 'storageValue') = yes;

* =============================================================================
* --- Model Features ----------------------------------------------------------
* =============================================================================

* --- Define Reserve Properties -----------------------------------------------

    // Lenght of reserve horizon
    mSettingsReservesInUse('invest', resType, up_down) = no;
    // Lenght of reserve horizon
    //mSettingsReservesInUse('invest', 'primary', 'up') = no;
    //mSettingsReservesInUse('invest', 'primary', 'down') = no;
    //mSettingsReservesInUse('invest', 'secondary', 'up') = no;
    //mSettingsReservesInUse('invest', 'secondary', 'down') = no;
    //mSettingsReservesInUse('invest', 'tertiary', 'up') = no;
    //mSettingsReservesInUse('invest', 'tertiary', 'down') = no;

* --- Define Unit Approximations ----------------------------------------------

    // Define the last time step for each unit aggregation and efficiency level (3a_periodicInit.gms ensures that there is a effLevel until t_horizon)
    mSettingsEff('invest', 'level1') = inf;

    // Define the horizon when start-up and shutdown trajectories are considered
    mSettings('invest', 't_trajectoryHorizon') = 0;

* --- Define output settings for results --------------------------------------

    // Define the 24 of the initialization period. Results outputting starts after the period. Uses ord(t) > t_start + t_initializationPeriod in the code.
    mSettings('invest', 't_initializationPeriod') = 0;  // r_state_gnft and r_online_uft are stored also for the last step in the initialization period, i.e. ord(t) = t_start + t_initializationPeriod

* --- Define the use of additional constraints for units with incremental heat rates

    // How to use q_conversionIncHR_help1 and q_conversionIncHR_help2
    mSettings('invest', 'incHRAdditionalConstraints') = 0;
    // 0 = use the constraints but only for units with non-convex fuel use
    // 1 = use the constraints for all units represented using incremental heat rates

* --- Control the solver ------------------------------------------------------

    // Control the use of advanced basis
    mSettings('invest', 'loadPoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve
    mSettings('invest', 'savePoint') = 0;  // 0 = no basis, 1 = latest solve, 2 = all solves, 3 = first solve

); // END if(mType)


