function main {
	lock throttle to 1.
	set desalt to altitude.
	list engines in engs.

	// set up desired pitch angle loop
	set pitchangkp to 0.5.
	set pitchangki to 0.001.
	set pitchangkd to 1.
	set minpitchang to 0.
	set maxpitchang to 5.
	set pitchang to pidloop(pitchangkp, pitchangki, pitchangkd, minpitchang, maxpitchang).
	set pitchang:setpoint to desalt.

	// set up roll angle loop
	set rakp to 0.3.
	set raki to 0.5.
	set rakd to 1.
	set maxroll to 45.
	set minroll to 0.
	set rollangle to pidloop(rakp, raki, rakd, minroll, maxroll).

	// set up roll control loop
	set rollkp to 0.05.
	set rollki to 0.01.
	set rollkd to 0.01.
	set minroll to -1.
	set maxroll to 1.
	set rollcontrol to pidloop(rollkp, rollki, rollkd, minroll, maxroll).
	set rollcontrol:setpoint to -90.


	lock curroll to roll_for().
	lock curpitch to pitch_for().
	sas off.
	until curroll < -10 {
		set ship:control:roll to rollcontrol:update(time:seconds, curroll).
	}
	print "press backspace to quit".
	until test_flameout() {
		set ship:control:pitch to 1.
		set despitch to pitchang:update(time:seconds, altitude).
		set rollangle:setpoint to despitch.
		set desired to rollangle:update(time:seconds, curpitch)-90.
		set rollcontrol:setpoint to desired.
		set ship:control:roll to rollcontrol:update(time:seconds, curroll).
		print "desalt: " + desalt.
		print "despitch: " + despitch.
		print "curpitch: " + curpitch.
		print "desroll: " + desired.
		print "curroll: " + curroll.
		wait 0.01.
		clearscreen.
	}
	print "releasing controls.".
	set ship:control:neutralize to true.
	sas on.
}

main().


function test_flameout {
	for eng in engs {
		if eng:flameout{
			print "encountered engine flameout".
			return True.
		}
	}
	if terminal:input:haschar {
		if terminal:input:getchar() = terminal:input:backspace {
			print "program quit by user".
			return True.
		}
	}
	if (not (ship:control:pilotpitch=0)) or (not (ship:control:pilotyaw=0)) or (not (ship:control:pilotroll=0)) {
		unlock throttle.
		set ship:control:neutralize to true.
		sas on. 
		print "waiting for pilot to release control".
		wait until ship:control:pilotpitch=0 and ship:control:pilotyaw=0 and ship:control:pilotroll=0.
		sas off.
		lock throttle to 1.
		set desalt to altitude.
		set rollangle:setpoint to altitude.
		// set deshead to compass_for().
		// set desalt to altitude.
		// set pitchcontrol:setpoint to desalt.
		// set yawcontrol:setpoint to deshead.
		// set desairspd to airspeed.
	}
	return False.
}

function roll_for {
	parameter ves is ship.
	local pointing is ves:facing.
	local trig_x is vdot(pointing:topvector, ves:up:vector).
	if abs(trig_x) < 0.0035 {
		return 0.
	} else {
		local vec_y is vcrs(ves:up:vector, pointing:forevector).
		local trig_y is vdot(pointing:topvector, vec_y).
		return arctan2(trig_y, trig_x).
	}
}

function pitch_for {
	parameter ves is ship.
	local pointing is ves:facing:forevector.
	return 90 - vang(ves:up:vector,pointing).
}