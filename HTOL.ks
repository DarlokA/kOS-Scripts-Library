ClearScreen.

local G is 0.
lock G to SHIP:BODY:MU / ((SHIP:BODY:RADIUS+SHIP:ALTITUDE)^2).

local mTimeS to TIME:SECONDS.
local mDTimeS to 0.

local mRoll to get_roll().
local mPitch to get_pitch().

local mRollSpeed to 0.
local mPitchSpeed to 0.

local mDPitchSpeed to 0.
local mDRollSpeed to 0.

local FRPitch to 0.
local FRRoll to 0.

local FAPitch to 0.
local FARoll to 0.

local tgt_pitch TO get_pitch().
local tgt_roll TO get_roll().


GLOBAL hLock TO false.

GLOBAL hLockStagePitch to 0.
GLOBAL hLockStageRoll to 0.

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
	
	if hLock process_horizontal_lock().
	
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
	set tgt_pitch to 0.
	process_horizontal_lock().
	
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

function process_lockRotate{
	parameter vParams, current, tgt.
	lock _hLockStage to vParams:X.
	set _mSpeed to vParams:Y.
	lock _control to vParams:Z.
	if _hLockStage = 0 {
		if _mSpeed > 0.1{
			set _control to -0.2.
			set _hLockStage to -2.
		}else if _mSpeed < -0.1{
			set _control to 0.2.
			set _hLockStage to 2.
		}else{
			set _control to 0.0.
			if  tgt - current > 0.1 {
				set _control to 0.2.
				set _hLockStage to 1.
			}else if tgt - current < -0.1 {
				set _control to -0.2.
				set _hLockStage to -1.
			}else{
				set _hLockStage to 0.
			}
		}
	}
	if _hLockStage = -2{
		
	}else if _hLockStage = 2{
		
	}else if _hLockStage = -2{
	}else if _hLockStage = 1{
	}else if _hLockStage = -1{
	}
	return _hLockStage.
	
}

function process_horizontal_lock{
	if SHIP:CONTROL:PILOTPITCH  <> 0 { 
		set hLockStagePitch to 0. 
		set SHIP:control:PITCH to SHIP:CONTROL:PILOTPITCH.
	}
	else{ 
		set params to V(hLockStagePitch, mPitchSpeed, SHIP:control:PITCH).
		set hLockStagePitch to process_lockRotate(params, mPitch, tgt_pitch).
		set SHIP:control:PITCH to params:Z.
	}
	if SHIP:CONTROL:PILOTROLL  <> 0 { 
		set hLockStageRoll to 0. 
		set SHIP:control:ROLL to SHIP:CONTROL:PILOTROLL.
	}
	else{ 
		set params to V(hLockStageRoll, mRollSpeed, SHIP:control:ROLL).
		set hLockStageRoll to process_lockRotate(params, mRoll, tgt_roll).
		set SHIP:control:ROLL to params:Z.
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
	set mDTimeS to TIME:SECONDS - mTimeS.
	set mTimeS to TIME:SECONDS.
	set nRoll to get_roll().
	set nPitch to get_pitch().
	set nRollSpeed to (nRoll - mRoll) / mDTimeS.
	set nPitchSpeed to (nPitch - mPitch) / mDTimeS.
	
	set mPitch to nPitch.
	set mRoll to nRoll.
	
	set DPitchSpeed to nPitchSpeed - mPitchSpeed.
	set DRollSpeed to nRollSpeed - mRollSpeed.
	
	local ra to ABS(DRollSpeed). 
	local pa to ABS(DPitchSpeed).
	local _P to ABS(SHIP:control:PITCH + SHIP:control:PILOTPITCH).
	local _R to ABS(SHIP:control:ROLL + SHIP:control:PILOTROLL).
	
	if pa <> 0{
		if _P = 0 {
			set FRPitch to pa.
		}else{
			set FAPitch to pa / _P.
		}
	}
	if ra <> 0{
		if _R = 0 {
			set FRRoll to ra.
		}else{
			set FARoll to ra / _R.
		}
	}
	
	set mRollSpeed to nRollSpeed.
	set mPitchSpeed to nPitchSpeed.
	
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
		PRINT "           " AT(13,5). PRINT "         " AT(35,5).//5
		PRINT "     /     " AT(7,6). PRINT "     /     " AT(29,6).//6
		PRINT ROUND(mPitchSpeed, 3) AT(13,5). PRINT ROUND(mRollSpeed, 3) AT(35,5).//5
		PRINT ROUND(mPitch,1) AT(7,6). PRINT  "/" + ROUND(tgt_pitch,1) AT(12,6). PRINT ROUND(mRoll,1) AT(29,6). PRINT "/" + ROUND(tgt_roll,1) AT(34,6).//6
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






