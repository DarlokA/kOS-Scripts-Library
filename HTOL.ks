ClearScreen.

local G is 0.
lock G to SHIP:BODY:MU / ((SHIP:BODY:RADIUS+SHIP:ALTITUDE)^2).

local oldTimeS to TIME:SECONDS.

local oldRoll to get_roll().
local oldPitch to get_pitch().

local RollSpeed to 0.
local PitchSpeed to 0.

local tgt_pitch TO get_pitch().
local tgt_roll TO get_roll().


GLOBAL hLock TO false.
GLOBAL exit to false.

GLOBAL APM_NONE 			TO 0.
GLOBAL APM_PRELAUNCH 		TO 1.
GLOBAL APM_VTLAUNCH 		TO 2.
GLOBAL APM_HTLAUNCH 		TO 3.

GLOBAL apm TO APM_NONE.
GLOBAL ap_stage TO 0.



WHEN TERMINAL:INPUT:HASCHAR THEN{
	LOCAL newChar IS TERMINAL:INPUT:GETCHAR().
	if newChar = "x"{
		set loop to true.
	}
	if newChar = "h"{
		on_holdHE().
	}
	if newChar = "n"{
		on_holdHD().
	}
	PRESERVE.
}

HUDTEXT("Ship status: "+SHIP:STATUS, 10, 2, 30, GREEN, FALSE).

local VTOLs to SHIP:partsdubbed("vtol").
local MTs to SHIP:partsdubbed("mt").

ON_APM_NONE(true).

UI(true).

until exit
{
	updateState().
	
	if apm = APM_NONE ON_APM_NONE(false).
	
	if SHIP:CONTROL:PILOTFORE > 0.5	on_holdHE().
	if SHIP:CONTROL:PILOTFORE < -0.5 on_holdHD().
	
	if hLock process_horizontal_lock(tgt_pitch, 0).
	
	if apm = APM_PRELAUNCH ON_APM_PRELAUNCH().
		
	if apm = APM_VTLAUNCH ON_APM_VTLAUNCH().
}

clearvecdraws().

//FUNCTIONS====================================================================

function ON_APM_NONE{
	PARAMETER showHUD.
	if showHUD
	{
		local vt to not is_engines_cut_off(VTOLs).
		local mt to not is_engines_cut_off(MTs).
		if is_landed() and not mt and not vt
		{ 
			SET apm TO APM_PRELAUNCH.
			HUDTEXT("Ship status: "+ SHIP:STATUS, 10, 2, 30, GREEN, FALSE).
			HUDTEXT("Activate VTOL engine(s) for VERTICAL LAUNCH", 10, 2, 30, GREEN, FALSE).
			HUDTEXT("Activate MAIN engine(s) for HORIZONTAL LAUNCH", 10, 2, 30, GREEN, FALSE).
		}
	}
}

function ON_APM_PRELAUNCH{
	local mt to not is_engines_cut_off(MTs).
	local vt to not is_engines_cut_off(VTOLs).
	if vt 
	{
		SET apm TO APM_VTLAUNCH.
		HUDTEXT("PROCESS VERTICAL LAUNCH", 10, 2, 30, GREEN, FALSE).
	}else if mt
	{
		SET apm TO APM_HTLAUNCH.
		HUDTEXT("PROCESS HORIZONTAL LAUNCH", 10, 2, 30, GREEN, FALSE).
	}
}

function ON_APM_HTLAUNCH{
	if SHIP:VELOCITY:SURFACE:MAG > 80 and SHIP:BOUNDS:BOTTOMALTRADAR > 100
	{
		HUDTEXT("HORIZONTAL LAUNCH COMPLETE", 10, 2, 30, GREEN, FALSE).
		SET ap_stage TO 0.
		SET apm TO APM_NONE.
		set SHIP:CONTROL:NEUTRALIZE TO TRUE.
	}
}

function ON_APM_VTLAUNCH{
	set tgt_pitch to oldPitch.
	process_horizontal_lock(tgt_pitch, 0).
	
	if ap_stage = 0
	{
		SET tgt_pitch to 0.
		BRAKES ON.
		set SHIP:control:pilotmainthrottle to 0.
		set ap_stage to 1.
		HUDTEXT("WAITING BRAKES.", 10, 2, 30, GREEN, FALSE).
	}
		
		if ap_stage = 1 
		{
			if SHIP:VELOCITY:SURFACE:MAG < 1
			{
				for _e in VTOLs{ SET _e:THRUSTLIMIT TO 100.}
				set SHIP:control:pilotmainthrottle to ThrottleToTWR(2, VTOLs).
				SET ap_stage to 2.
				BRAKES OFF.
				HUDTEXT("WAIT FOR TAKE OFF.", 10, 2, 30, GREEN, FALSE).
			}
		}
	
	if ap_stage = 2
	{
		if SHIP:BOUNDS:BOTTOMALTRADAR > 1
		{
			set SHIP:control:pilotmainthrottle to ThrottleToTWR(1.5, VTOLs).
			SET ap_stage to 3.
			HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR: 20m", 10, 2, 30, GREEN, FALSE).
		}
	}
	if ap_stage = 3 
	{
		if SHIP:BOUNDS:BOTTOMALTRADAR > 20
		{
			HUDTEXT("ACTIVATE MAIN ENGINE", 10, 2, 30, GREEN, FALSE).
			for _e in VTOLs
			{
				SET _e:THRUSTLIMIT TO ThrottleToTWR(1.0, VTOLs) * 100.
			}
			SET ap_stage to 4.
			SET tgt_pitch to 5.
			HUDTEXT("WAITING FOR A SAFE ALTITUDE ON THE RADAR 100m", 10, 2, 30, GREEN, FALSE).
			HUDTEXT("WAITING FOR SPEED TO CLIMB 80m/s", 10, 2, 30, GREEN, FALSE).
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
			HUDTEXT("DEACTIVATE HOVER ENGINE", 10, 2, 30, GREEN, FALSE).
			for _e in VTOLs{ 
				SET _e:THRUSTLIMIT TO 0.
			}
			HUDTEXT("VERTICAL LAUNCH COMPLETE", 10, 2, 30, GREEN, FALSE).
			SET tgt_pitch to 0.
			set SHIP:CONTROL:NEUTRALIZE TO TRUE.
		}
	}		
}

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
	parameter _tgt_pitch, _tgt_roll.
	
	
	local magP to 0.05.
	local magR to 0.05.
	
	local pitchA to get_pitch() - _tgt_pitch.
	local rollA to get_roll() - _tgt_roll.
	local cp to -pitchA * magP.
	local cr to  -rollA * magR.
	set wp to true.
	set wr to true.
	
	local pP to cp.
	local pR to cr.
	
	if ABS (pitchA) > 0.1
	{
		set SHIP:control:PITCH to cp.
		set wp to false.
	}
	
	if ABS (rollA) > 0.1
	{
		set SHIP:control:ROLL to cr.
		set wr to false.
	}
	
	wait 0.01.
	set pitchA to get_pitch() - _tgt_pitch.
	set cp to -pitchA*magP.
	set rollA to get_roll() - _tgt_roll.
	set cr to  -rollA*magR.
	
	set dp to ABS(cp - pp).
	set dr to ABS(cr - pr).
	
	set mP to 1.
	set mR to 1.
	
	set pP to cp.
	set pR to cr.
	
	local startT to TIME:SECONDS.
	until wp and wr{
		
		set pitchA to get_pitch() - _tgt_pitch.
		set cp to -pitchA*magP.
		set rollA to get_roll() - _tgt_roll.
		set cr to  -rollA*magR.
		
		set dpN to ABS(cp - pp).
		set drN to ABS(cr - pr).
		
		if dp > 0.00001 {set mP to dpN / dp.}else{ set mP to 2.}
		if dr > 0.00001 {set mR to drN / dr.}else{ set mR to 2.}
		
		set dp to dpN.
		set dr to drN.
		
		set pP to cp.
		set pR to cr.
		
		set SHIP:control:PITCH to cp*mP.
		set SHIP:control:ROLL to cr*mR.
		if (ABS(pitchA) < 0.05) set wp to true.
		if (ABS(rollA) < 0.05) set wr to true.
	}
	if wp and wr { set SHIP:CONTROL:NEUTRALIZE TO TRUE.}
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


function on_holdHE{
	if not hLock { on_holdH(). }
}

function on_holdHD{
	if hLock{ on_holdH(). }
}


function on_holdH{
	if apm = APM_NONE 
	{
		set SHIP:CONTROL:NEUTRALIZE TO TRUE.
		local changed to false.
		if not is_landed() or hLock {
			set hLock to not hLock.
			set changed to true.
		}
		
		if changed {
			if hLock{
				set tgt_pitch to get_pitch().
				HUDTEXT("Activate HOLD Horizontal PITCH " + ROUND(tgt_pitch, 1), 10, 2, 30, GREEN, FALSE).
			}else{
				set tgt_pitch to 1.
				HUDTEXT("Deactivate HOLD Horizontal PITCH", 10, 2, 30, GREEN, FALSE).
			}
		}
	}
}

function updateState{
	set timeS to TIME:SECONDS - oldTimeS.
	set oldTimeS to TIME:SECONDS.
	set nRoll to get_roll().
	set nPitch to get_pitch().
	set RollSpeed to (nRoll - oldRoll) / timeS.
	set PitchSpeed to (nPitch - oldPitch) / timeS.
	set oldPitch to nPitch.
	set oldRoll to nRoll.
	UI(false).
}

function UI{
	parameter with_clear.
	if (with_clear){
		ClearScreen.
		PRINT "HTOL 1.0".//0
		PRINT "Exit (X)".//1
		PRINT "Activate Hold Horizontal PITCH (H)".//2
		PRINT "Deactivate Hold Horizontal PITCH (N)".//3
		PRINT "----------------------------------------".//4
		PRINT "PitchSpeed:  00000      RollSpeed: 00000".//5
		PRINT "Pitch: 00000/00000      Roll 00000/00000".//6
	}else{
		PRINT "           " AT(13,5). PRINT "         " AT(36,5).//5
		PRINT "     /     " AT(7,6). PRINT "     /     " AT(29,6).//6
		PRINT ROUND(PitchSpeed, 3) AT(13,5). PRINT ROUND(RollSpeed, 3) AT(36,5).//5
		PRINT ROUND(oldPitch,1) AT(7,6). PRINT  "/" + ROUND(tgt_pitch,1) AT(12,6). PRINT ROUND(oldRoll,1) AT(29,6). PRINT "/" + ROUND(tgt_roll,1) AT(34,6).//6
	}
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






