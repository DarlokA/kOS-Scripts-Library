ClearScreen.

GLOBAL hLock TO false.
GLOBAL exit to false.

LOCAL APM_NONE 			TO 0.
LOCAL APM_PRELAUNCH 	TO 1.
LOCAL APM_VTLAUNCH 		TO 2.
LOCAL APM_HTLAUNCH 		TO 3.

GLOBAL apm TO APM_NONE.
GLOBAL ap_stage TO 0.

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
	
		process_horizontal_lock().
		
		if ap_stage = 0
		{
			BRAKES ON.
			set SHIP:control:pilotmainthrottle to 0.
			set ap_stage to 1.
			HUDTEXT("WAITING BRAKES.", 10, 2, 30, GREEN, TRUE).
		}
			
			if ap_stage = 1 
			{
				if SHIP:VELOCITY:SURFACE:MAG < 1
				{
					for _e in MTs{ SET _e:THRUSTLIMIT TO 0. }
					for _e in VTOLs{ SET _e:THRUSTLIMIT TO 100.}
					set SHIP:control:pilotmainthrottle to 1.
					SET ap_stage to 2.
					HUDTEXT("WAIT FOR TAKE OFF.", 10, 2, 30, GREEN, TRUE).
				}
			}
		
		if ap_stage = 2
		{
			if SHIP:VERTICALSPEED > 0.1
			{
				local f to true.
				for _e in VTOLs
				{
					if f {
						local zThrust to _e:THRUST / _e:POSSIBLETHRUST * 100.
						HUDTEXT("TAKE OFF THRUST = " + ROUND(zThrust) + "%", 10, 2, 30, GREEN, TRUE).
						set SHIP:control:pilotmainthrottle to (zThrust+10) / 100.
						set f to false.
					}				
				}
				SET ap_stage to 3.
				HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR: 20m", 10, 2, 30, GREEN, TRUE).
			}
		}
		if ap_stage = 3 
		{
			if SHIP:BOUNDS:BOTTOMALTRADAR > 20
			{
				HUDTEXT("ACTIVATE MAIN ENGINE", 10, 2, 30, GREEN, TRUE).
				for _e in MTs
				{
					SET _e:THRUSTLIMIT TO 100.
				}
				SET ap_stage to 4.
				HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR 100m", 10, 2, 30, GREEN, TRUE).
				HUDTEXT("WAITING FOR SPEED TO CLIMB 80m/s", 10, 2, 30, GREEN, TRUE).
			}
		}
		
		if ap_stage = 4
		{
			if SHIP:VELOCITY:SURFACE:MAG > 80 and SHIP:BOUNDS:BOTTOMALTRADAR > 100
			{
				SET ap_stage TO 0.
				SET apm TO APM_NONE.
				HUDTEXT("DEACTIVATE HOVER ENGINE", 10, 2, 30, GREEN, TRUE).
				for _e in VTOLs{ 
					SET _e:THRUSTLIMIT TO 0.
				}
				HUDTEXT("VERTICAL LAUNCH COMPLETE", 10, 2, 30, GREEN, TRUE).
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
	local pitchA to get_pitch().
	local rollA to get_roll().
	local cp to -pitchA*0.3.
	local cr to  -rollA*0.3.
	set w to false.
	if ABS (pitchA) > 0.01
	{
		set SHIP:control:PITCH to cp.
		set w to true.
	}
	
	if ABS (rollA) > 0.01
	{
		set SHIP:control:ROLL to cr.
		set w to true.
	}
	if w {
		wait 0.05.
	}
	set SHIP:CONTROL:NEUTRALIZE TO TRUE.
}








