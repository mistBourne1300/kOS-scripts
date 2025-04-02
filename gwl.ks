main().

function main {
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.

    // initialize pitch angle loop
	set pitchangkp to 0.5.
	set pitchangki to 0.01.
	set pitchangkd to 1.0.
	set minpitchang to -15.
	set maxpitchang to 45.
	set pitchang to pidloop(pitchangkp, pitchangki, pitchangkd, minpitchang, maxpitchang).
	set pitchang:setpoint to 0.


	// initialize roll control loop
	set rollkp to 0.01.
	set rollki to 0.0.
	set rollkd to 0.01.
	set minroll to -1.
	set maxroll to 1.
	set rollcontrol to pidloop(rollkp, rollki, rollkd, minroll, maxroll).
	set rollcontrol:setpoint to 0.
	
	// initialize pitch control pid
	set pitchkp to 0.05.
	set pitchki to 0.005.
	set pitchkd to 0.01.
	set minpitch to -0.5.
	set maxpitch to 1.
	set pitchcontrol to pidloop(pitchkp, pitchki, pitchkd, minpitch, maxpitch).

	// initialize yaw control pid
	set yawkp to 0.07.
	set yawki to 0.05.
	set yawkd to 0.1.
	set minyaw to -1.
	set maxyaw to 1.
	set yawcontrol to pidloop(yawkp, yawki, yawkd, minyaw, maxyaw).
	set yawtakeover to 5.

    lock curcomp to compass_for().
    set deshead to compass_for().
	lock yaw_ang to ang_dist().
	lock curpitch to pitch_for().
	lock curroll to roll_for().
    
    // decide landing zone

    // control glide to zone

    // assuming we are over the water,
    // we can wait until the altitude is less than 100m
    // then... set desalt to glide speed?

    sas off.
    clearScreen.
    print "gliding to 1000m alt.".
    until altitude < 1000 {
        update_loops().
        wait 0.001.
    }
    print "altitude < 1000, setting altitude to airspeed.".
    until altitude < 500 {
        set pitchang:setpoint to airspeed.
        update_loops().
        wait 0.001.
    }
    gear on.
    brakes on.
    until not (ship:status = "flying") {
        set pitchang:setpoint to airspeed/2 + 5.
        update_loops().
        wait 0.001.
    }
    set ship:control:neutralize to true.
    set ship:control:pilotmainthrottle to 0.
}

function update_loops {
	set angle to pitchang:update(time:seconds, altitude).
	set pitchcontrol:setpoint to angle.
	set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
	if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
		set ship:control:yaw to 0.
		set yawcontrol:ki to 0.
		if yaw_ang > 0 {
			// roll left, set maximum
			set rollcontrol:setpoint to max(-55,-(60/40)*(yaw_ang - 5) -15).
		} else {
			set rollcontrol:setpoint to min(55, -(70/60)*(yaw_ang + 5) + 15).
		}
	} else {
		set rollcontrol:setpoint to 0.
		set ship:control:yaw to yawcontrol:update(time:seconds, yaw_ang).
	}
	set ship:control:roll to rollcontrol:update(time:seconds, curroll).
	// log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
}

function ang_dist {
	return anglediff(deshead, curcomp).
}

function east_for{
	parameter ves is ship.
	return vcrs(ves:up:vector, ves:north:vector).
}

function compass_for{
	parameter ves is ship.
	local pointing is ves:facing:forevector.
	local east is east_for(ves).

	local trig_x is vdot(ves:north:vector, pointing).
	local trig_y is vdot(east, pointing).

	local result is arcTan2(trig_y, trig_x).
	if result < 0 {
		return 360 + result.
	} else {
		return result.
	}
}

function pitch_for {
	parameter ves is ship.
	local pointing is ves:facing:forevector.
	return 90 - vang(ves:up:vector,pointing).
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