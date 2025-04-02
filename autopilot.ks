parameter deshead is 90.
parameter desalt is 7000.
parameter desairspd is 200.

set pathalt to 0.
set slalt to desalt.
set km to 1000.

main().


function main {
	set deshead to abs(mod(deshead,360)).
	sas off.
	clearscreen.

	list engines in engs.

	// initialize throttle pid
	set throtkp to 0.1.
	set throtki to 0.01.
	set throtkd to 0.1.
	set minthrot to 0.0.
	set maxthrot to 1.0.
	set throtpid to pidloop(throtkp, throtki, throtkd, minthrot, maxthrot).
	set throtpid:setpoint to desairspd.
	set throt to 1.0.
	lock throttle to throt.

	// initialize pitch angle loop
	set pitchangkp to 0.5.
	set pitchangki to 0.01.
	set pitchangkd to 1.0.
	set minpitchang to -5.
	set maxpitchang to 30.
	set pitchang to pidloop(pitchangkp, pitchangki, pitchangkd, minpitchang, maxpitchang).
	set pitchang:setpoint to desalt.


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
	set yawkd to 0.05.
	set minyaw to -1.
	set maxyaw to 1.
	set yawcontrol to pidloop(yawkp, yawki, yawkd, minyaw, maxyaw).
	set yawtakeover to 5.
	// set yawcontrol:setpoint to deshead.


	
	lock curcomp to compass_for().
	lock yaw_ang to ang_dist().
	lock curpitch to pitch_for().
	lock curroll to roll_for().

	// if not exists("0:autopilot_log.csv"){
	// 	create("0:autopilot_log.csv").
	// } else {
	// 	deletepath("0:autopilot_log.csv").
	// 	create("0:autopilot_log.csv").
	// }

	// log "heading,altitude,airspeed" to "0:autopilot_log.csv".

	if ship:status = "landed" or ship:status = "prelaunch" {
		if stage:deltav:current = 0 { // we're on the runway without having staged.
			clearscreen.
			print "runway takoff".
			// set temphead to deshead.
			// set deshead to 90.
			brakes off.
			stage.
			set tempairspeed to desairspd.
			set desairspd to 1.
			until abs(anglediff(90,curcomp)) < yawtakeover{
				lock wheelsteering to 90.
				lock throttle to 0.01*(1 - airspeed).
				wait 0.001.
			}
			lock throttle to throt.
			set desairspd to tempairspeed.
			
			until ship:status = "flying" {
				set throt to throtpid:update(time:seconds, airspeed).
				set angle to pitchang:update(time:seconds, altitude).
				set pitchcontrol:setpoint to angle.
				set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			set ship:control:neutralize to true.
			toggle gear.
			until alt:radar > 10 {
				set throt to throtpid:update(time:seconds, airspeed).
				set angle to pitchang:update(time:seconds, altitude).
				set pitchcontrol:setpoint to angle.
				set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			printinfo().
			// set deshead to temphead.
		} else {
			print "steering to takeoff".
			brakes off.
			set tempairspeed to desairspd.
			set desairspd to 1.
			until abs(yaw_ang) < yawtakeover {
				lock wheelsteering to deshead.
				lock throttle to 0.01*(1 - airspeed).
				wait 0.001.
			}
			lock throttle to throt.
			lock throttle to 1.
			set desairspd to tempairspeed.
			until ship:status = "flying" {
				set throt to throtpid:update(time:seconds, airspeed).
				set angle to pitchang:update(time:seconds, altitude).
				set pitchcontrol:setpoint to angle.
				set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			set ship:control:neutralize to true.
			printinfo().
			toggle gear.
		}
	} else if not ship:status = "flying" {
		print "status " + ship:status + " unrecognized.".
		print "terminating.".
		brakes on.
		unlock all.
		sas on.
		set ship:control:pilotmainthrottle to 0.
		lock throttle to 0.
		return.
	}
	clearScreen.
	printinfo().
	until test_flameout(){
		// calc_terrain_height_path(). // before I use this, I should get it to actually work.
		update_loops().
		wait 0.001.
	}
	print "releasing controls.".
	set ship:control:neutralize to true.
	sas on.
}

function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			return wp.
		}
	}
	return false.
}

function ang_dist {
	local wp is has_waypoint().
	if wp:istype("waypoint") {
		set deshead to wp:geoPosition:heading.
		if wp:name = "KSC" and (wp:position - ship:position):mag < 100*km{
			if deshead < 90 {
				set deshead to deshead - 2*abs(anglediff(deshead,90)).
			} else if deshead < 180 {
				set deshead to deshead + 2*abs(anglediff(deshead,90)).
			} else if deshead < 270 {
				set deshead to deshead - 2*abs(anglediff(deshead,270)).
			} else {
				set deshead to deshead + 2*abs(anglediff(deshead,270)).
			}
			printinfo().
		}
	}
	return anglediff(deshead, curcomp).
}

function test_flameout {
	for eng in engs {
		if eng:flameout{
			print "encountered engine flameout".
			print "pausing game. control will be released at game unpause.".
			kuniverse:pause().
			set ship:control:neutralize to true.
			sas on.
			// return 1/0.
		}
	}
	if terminal:input:haschar {
		set c to terminal:input:getchar().
		if c = "q" {
			print "program quit by user".
			set ship:control:neutralize to true.
			sas on.
			return 1/0.
		} else if c = "a" {
			print "enter desired altitude:".
			set c to terminal:input:getchar().
			set newdesalt to "".
			until c = terminal:input:return {
				set newdesalt to newdesalt + c.
				print newdesalt.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set slalt to newdesalt:tonumber(desalt).
			set desalt to slalt.
			set pitchang:setpoint to desalt.
		} else if c = "s" {
			print "set desired airspeed:".
			set c to terminal:input:getchar().
			set newspeed to "".
			until c = terminal:input:return {
				set newspeed to newspeed + c.
				print newspeed.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set desairspd to newspeed:tonumber(desairspd).
			set throtpid:setpoint to desairspd.
		} else if c = "h" {
			print "set desired heading:".
			set c to terminal:input:getchar().
			set newheading to "".
			until c = terminal:input:return {
				set newheading to newheading + c.
				print newheading.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set deshead to abs(mod(newheading:tonumber(deshead),360)).
			// the ang dist function will be able to read this and adjust accordingly.
		}
		printinfo().
		// if exists("0:autopilot_log.csv") {
		// 	deletepath("0:autopilot_log.csv").
		// 	create("0:autopilot_log.csv").
		// } else {
		// 	create("0:autopilot_log.csv").
		// }
		// log "heading,altitude,airspeed" to "0:autopilot_log.csv".
	}
	if (not (ship:control:pilotpitch=0)) or (not (ship:control:pilotyaw=0)) or (not (ship:control:pilotroll=0)) {
		unlock throttle.
		set ship:control:neutralize to true.
		sas on. 
		print "waiting for pilot to release control".
		wait until ship:control:pilotpitch=0 and ship:control:pilotyaw=0 and ship:control:pilotroll=0.
		sas off.
		lock throttle to throt.
		clearscreen.
		printinfo.
	}
	return False.
}

function printinfo {
	clearscreen.
	print "heading: " + deshead.
	print "slalt: " + slalt.
	print "pathalt: " + pathalt.
	print "true alt: " + desalt.
	print "speed: " + desairspd.
	print "press 'a' to edit altitude".
	print "press 's' to edit speed".
	print "press 'h' to edit heading".
	print "press q to quit".
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

function update_loops {
	set throt to throtpid:update(time:seconds, airspeed).
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
}