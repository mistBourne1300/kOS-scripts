parameter head is 90.
parameter despeed is 5.
parameter max_error is 5.

main().

function main {
    set throtkp to 0.1.
	set throtki to 0.01.
	set throtkd to 0.
	set minthrot to 0.0.
	set maxthrot to 1.0.
	set throtpid to pidloop(throtkp, throtki, throtkd, minthrot, maxthrot).
	set throtpid:setpoint to despeed.
	set throt to 0.
	lock throttle to throt.

    list engines in engs.

    set yawkp to .1/despeed.
	set yawki to 0.
	set yawkd to 0.
	set minyaw to -1.
	set maxyaw to 1.
	set yawcontrol to pidloop(yawkp, yawki, yawkd, minyaw, maxyaw).

    lock yaw_ang to ang_dist().
    lock curcomp to compass_for().

    sas off.

	printinfo().
	set printtimer to time:seconds.

    until test_flameout() {
        set throt to throtpid:update(time:seconds, airspeed).
        set ship:control:wheelsteer to yawcontrol:update(time:seconds, yaw_ang).
        if airspeed > despeed + max_error{
            brakes on.
        } else {
            brakes off.
        }
		if time:seconds - printtimer > 1 {
			printinfo().
			set printtimer to time:seconds.
		}
    }
    set ship:control:neutralize to true.
    unlock throttle.
    brakes on.
    set ship:control:pilotmainthrottle to 0.
	sas on.
}

function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			set vectowp to wp:position - ship:position.
			if vectowp:mag < 10 {
				set ship:control:neutralize to true.
				brakes on.
				sas on.
				print "arrived at wp".
				print "quitting program in 5 sec.".
				wait 5.
				return 1/0.
			}
			return wp.
		}
	}
	return false.
}

function ang_dist {
	local wp is has_waypoint().
	if wp:istype("waypoint") {
		set head to wp:geoPosition:heading.
	}
	return anglediff(curcomp, head).
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

function test_flameout {
	// for eng in engs {
	// 	if eng:flameout{
	// 		print "encountered engine flameout".
	// 		print "pausing game. control will be released at game unpause.".
	// 		kuniverse:pause().
	// 		set ship:control:neutralize to true.
	// 		sas on.
	// 		return true.
	// 	}
	// }
	if terminal:input:haschar {
		set c to terminal:input:getchar().
		if c = "q" {
			print "program quit by user".
			set ship:control:neutralize to true.
			sas on.
			return true.
		} else if c = "s" {
            clearscreen.
			print "set desired speed:".
			set c to terminal:input:getchar().
			set newspeed to "".
			until c = terminal:input:return {
				set newspeed to newspeed + c.
                print "set desired speed:".
				print newspeed.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set despeed to newspeed:tonumber(despeed).
			set throtpid:setpoint to despeed.
			set yawcontrol:kp to .1/despeed.
		} else if c = "h" {
			print "set desired heading:".
			set c to terminal:input:getchar().
			set newhead to "".
			until c = terminal:input:return {
				set newhead to newhead + c.
                print "set desired head:".
				print newhead.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set head to abs(mod(newhead:tonumber(head),360)).
			// the ang dist function will be able to read this and adjust accordingly.
		}
		
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
		printinfo().
	}
	return False.
}

function printinfo {
	clearscreen.
	print "heading: " + round(head).
	print "speed: " + despeed.
}