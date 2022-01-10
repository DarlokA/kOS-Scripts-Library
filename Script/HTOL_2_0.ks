ClearScreen.

local G is 0.
lock G to SHIP:BODY:MU / ((SHIP:BODY:RADIUS+SHIP:ALTITUDE)^2).

GLOBAL start_time TO TIME:SECONDS.
DELETE "0:/pitchPID.csv".

GLOBAL hLock TO false.
GLOBAL exit to false.

LOCAL APM_NONE 			TO 0.
LOCAL APM_PRELAUNCH 	TO 1.
LOCAL APM_VTLAUNCH 		TO 2.
LOCAL APM_HTLAUNCH 		TO 3.

GLOBAL apm TO APM_NONE.
GLOBAL ap_stage TO 0.
GLOBAL tgt_pitch TO -1.

PRINT "HTOL 1.0".
PRINT "Exit (X)".


WHEN TERMINAL:INPUT:HASCHAR THEN{
	LOCAL newChar IS TERMINAL:INPUT:GETCHAR().
	if newChar = "x"{
		set loop to true.
	}
	PRESERVE.
}

function vec_drw{
	parameter __vector to ship:up:vector, __start to V(0, 0, 0), __color to RGB(1, 1, 1).
	local drw to vecdraw().
	set drw:start to __start.
	set drw:vec to __vector.
	set drw:color to __color.
	set drw:show to TRUE.
	return drw.
}

HUDTEXT("Ship status: "+SHIP:STATUS, 10, 2, 30, GREEN, TRUE).

local VTOLs to SHIP:partsdubbed("vtol").
local MTs to SHIP:partsdubbed("mt").

local _pitchPID is PIDLoop(0.04, 0.00792, 0.1333333, -10, 10).
set _pitchPID:SETPOINT to 0.

local _rollPID is PIDLoop(0.02, 0.01538461538, 0.01716, -45, 45). //без перерегулирования 
set _rollPID:SETPOINT to 0.

until exit
{
	if apm = APM_NONE
	{
		local vt to not is_engines_cut_off(VTOLs).
		local mt to not is_engines_cut_off(MTs).
		if is_landed() and not mt and not vt
		{ 
			SET apm TO APM_PRELAUNCH.
			HUDTEXT("Ship status: "+ SHIP:STATUS, 10, 2, 30, GREEN, TRUE).
			HUDTEXT("Activate VTOL engine(s) for VERTICAL LAUNCH", 10, 2, 30, GREEN, TRUE).
			HUDTEXT("Activate MAIN engine(s) for HORIZONTAL LAUNCH", 10, 2, 30, GREEN, TRUE).
		}
	}
	
	if apm = APM_PRELAUNCH
	{
		wait 1.
		local mt to not is_engines_cut_off(MTs).
		local vt to not is_engines_cut_off(VTOLs).
		if vt 
		{
			SET apm TO APM_VTLAUNCH.
			HUDTEXT("PROCESS VERTICAL LAUNCH", 10, 2, 30, GREEN, TRUE).
		}else if mt
		{
			SET apm TO APM_HTLAUNCH.
			HUDTEXT("PROCESS HORIZONTAL LAUNCH", 10, 2, 30, GREEN, TRUE).
		}		
	}	
	
	
	if apm = APM_VTLAUNCH{
	
		//if SHIP:BOUNDS:BOTTOMALTRADAR > 0 
		process_horizontal_lock(_pitchPID, _rollPID, tgt_pitch, 0).
		
		if ap_stage = 0
		{
			SET tgt_pitch to 0.
			BRAKES ON.
			set SHIP:control:pilotmainthrottle to 0.
			set ap_stage to 1.
			HUDTEXT("WAITING BRAKES.", 10, 2, 30, GREEN, TRUE).
		}
			
			if ap_stage = 1 
			{
				if SHIP:VELOCITY:SURFACE:MAG < 1
				{
					for _e in VTOLs{ SET _e:THRUSTLIMIT TO 100.}
					set SHIP:control:pilotmainthrottle to ThrottleToTWR(2, VTOLs).
					SET ap_stage to 2.
					BRAKES OFF.
					HUDTEXT("WAIT FOR TAKE OFF.", 10, 2, 30, GREEN, TRUE).
				}
			}
		
		if ap_stage = 2
		{
			if SHIP:BOUNDS:BOTTOMALTRADAR > 1
			{
				set SHIP:control:pilotmainthrottle to ThrottleToTWR(1.5, VTOLs).
				SET ap_stage to 3.
				HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR: 20m", 10, 2, 30, GREEN, TRUE).
			}
		}
		if ap_stage = 3 
		{
			if SHIP:BOUNDS:BOTTOMALTRADAR > 20
			{
				HUDTEXT("ACTIVATE MAIN ENGINE", 10, 2, 30, GREEN, TRUE).
				for _e in VTOLs
				{
					SET _e:THRUSTLIMIT TO ThrottleToTWR(1.0, VTOLs) * 100.
				}
				SET ap_stage to 4.
				SET tgt_pitch to 5.
				HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR 100m", 10, 2, 30, GREEN, TRUE).
				HUDTEXT("WAITING FOR SPEED TO CLIMB 80m/s", 10, 2, 30, GREEN, TRUE).
			}
		}
		
		if ap_stage = 4
		{
			for _e in VTOLs{ 
				SET _e:THRUSTLIMIT TO ThrottleToTWR(max(1, min(50 - SHIP:GROUNDSPEED/50, 0)), VTOLs) * 100.
			}
			if SHIP:VELOCITY:SURFACE:MAG > 80 and SHIP:BOUNDS:BOTTOMALTRADAR > 100
			{
				//SET tgt_pitch to 10.
				SET ap_stage TO 0.
				SET apm TO APM_NONE.
				HUDTEXT("DEACTIVATE HOVER ENGINE", 10, 2, 30, GREEN, TRUE).
				for _e in VTOLs{ 
					SET _e:THRUSTLIMIT TO 0.
				}
				HUDTEXT("VERTICAL LAUNCH COMPLETE", 10, 2, 30, GREEN, TRUE).
				SET tgt_pitch to 0.
				set SHIP:CONTROL:NEUTRALIZE TO TRUE.
			}
		}		
		
	}
}

clearvecdraws().


function is_landed
{
	if SHIP:STATUS = "LANDED" { return true.}
	if SHIP:STATUS = "SPLASHED" { return true.}
	if SHIP:STATUS = "PRELAUNCH" { return true.}
	return false.
}

function is_engines_cut_off{
	parameter _engines.
	
	for _e in _engines
	{
		if _e:FUELFLOW > 0.00001 { return false.}
	}
	return true.
}

function get_roll{
  local trig_x is vdot(ship:facing:topvector,ship:up:vector).
  if abs(trig_x) < 0.0035 {//this is the dead zone for roll when within 0.2 degrees of vertical
    return 0.
  } else {
    local vec_y is vcrs(ship:up:vector,ship:facing:forevector).
    local trig_y is vdot(ship:facing:topvector,vec_y).
    return arctan2(trig_y,trig_x).
  }
}

function get_pitch{
	return 90-VANG(ship:up:vector, ship:facing:forevector).
}

function process_horizontal_lock{
	parameter _pitchPID, _rollPID, _tgt_pitch, _tgt_roll.
	
	set magP to 1.
	set magR to 1.
	
	if SHIP:VELOCITY:SURFACE:MAG > 5
	{
		set magP to 0.8.
		set magR to 0.8.
	}
	if SHIP:VELOCITY:SURFACE:MAG > 20
	{
		set magP to 0.6.
		set magR to 0.6.
	}
	
	
	
	local pitchA to get_pitch() - _tgt_pitch.
	local rollA to get_roll() - _tgt_roll.
	local cp to -pitchA*magP.
	local cr to  -rollA*magR.
	set w to false.
	
	set cp to _pitchPID:Update(TIME:SECONDS, pitchA).
	set cr to _rollPID:Update(TIME:SECONDS, rollA).
	
	local log_txt to ROUND(TIME:SECONDS-start_time,3) + "	"  + ROUND(pitchA, 2) + "	" + ROUND(cp,2).
	LOG  log_txt:REPLACE(".", ",") TO "0:/pitchPID.csv".
	
	if ABS (pitchA) > 0.1
	{
		set SHIP:control:PITCH to cp.//max(limitP, min(cp, -limitP)).
		set w to true.
	}
	
	if ABS (rollA) > 0.1
	{
		set SHIP:control:ROLL to cr.///max(limitR, min(cr, -limitR)).
		set w to true.
	}
	if not w {
		wait 0.01.
	}
	//set SHIP:CONTROL:NEUTRALIZE TO TRUE.
}


function TWR {
	local m is SHIP:MASS.
	local t is THROTTLE * SHIP:AVAILABLETHRUST.
	return t/(ship:mass*G).
}
function ThrottleToTWR {
	parameter targetTWR, _engines.
	if targetTWR < 0.005 return 0.
	local m is SHIP:MASS.
	local ath to 0.
	for _e in _engines
	{
		SET ath to ath + _e:AVAILABLETHRUST.
	}
	if ath < 0.005 return 1.
	return min((targetTWR*m*G)/ath, 1.0).
}







