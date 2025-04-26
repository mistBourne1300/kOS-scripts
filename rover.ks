parameter deshead is 0.
parameter despeed is 5.
parameter max_error is 1.

main().

function main {
    set wheelthrotkp to 1.
	set wheelthrotki to 0.01.
	set wheelthrotkd to 1.
	set minwheelthrot to -1.0.
	set maxwheelthrot to 1.0.
	set wheelthrotpid to pidloop(wheelthrotkp, wheelthrotki, wheelthrotkd, minwheelthrot, maxwheelthrot).
	set wheelthrotpid:setpoint to despeed.
	set wheelthrot to 0.
    lock wheelthrottle to wheelthrot.

	set wheelsteerkp to .1/despeed.
	set wheelsteerki to 0.
	set wheelsteerkd to 0.
	set minsteer to -1.
	set maxsteer to 1.
	set wheelsteerpid to pidLoop(wheelsteerkp,wheelsteerki,wheelsteerkd,minsteer,maxsteer).

	sas off.

    // lock wheelsteering to update_heading().
    printinfo().
    set start to time:seconds.
	// set sasrestart to time:seconds.

    until test_finished() {
        set wheelthrot to wheelthrotpid:update(time:seconds, airspeed).
		set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), update_heading())).
		if abs(airspeed) - despeed > max_error {
			brakes on.
		} else {
			brakes off.
		}
        if time:seconds - start > 1 {
            // will only print info every few seconds.
            printinfo().
            set start to time:seconds.
        }
		// if time:seconds - sasrestart > 30 {
		// 	// restart sas every 30 seconds
		// 	sas off.
		// 	set sasrestart to time:seconds.
		// 	sas on.
		// }
        wait 0.001.
    }
	brakes on.
	until airspeed <= 0.01 {
		set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), update_heading())).
	}
    set ship:control:neutralize to true.
    unlock all.
    brakes on.
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

function update_heading {
	local wp is has_waypoint().
	// print(wp).
	if wp:istype("waypoint") {
		set deshead to wp:geoPosition:heading.
	}
    // print anglediff(compass_for(),deshead).
	return deshead.
}

function printinfo {
    clearscreen.
    print "heading: " + round(deshead).
    print "speed: " + despeed.
    local wp is has_waypoint().
    if wp:istype("waypoint") {
        print " ".
        print "dist: " + round((wp:position - ship:position):mag).
    }
    print " ".
    print "press h to change heading.".
    print "press s to change speed.".
    print "press q to quit.".
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

function test_finished {
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
			set wheelthrotpid:setpoint to despeed.
			set wheelsteerpid:kp to .1/despeed.
		} else if c = "h" {
			print "set desired heading:".
			set c to terminal:input:getchar().
			set newheading to "".
			until c = terminal:input:return {
				set newheading to newheading + c.
                print "set desired heading:".
				print newheading.
				set c to terminal:input:getchar().
				clearscreen.
			}
			set deshead to abs(mod(newheading:tonumber(deshead),360)).
			lock wheelSteering to update_heading().
			// the ang dist function will be able to read this and adjust accordingly.
		}
		
		printinfo().
	}
	if (not (ship:control:pilotpitch=0)) or (not (ship:control:pilotyaw=0)) or (not (ship:control:pilotroll=0)) {
		unlock all.
        unlock wheelthrottle.
        unlock wheelsteering.
		set ship:control:neutralize to true.
		sas on. 
		print "waiting for pilot to release control".
		wait until ship:control:pilotpitch=0 and ship:control:pilotyaw=0 and ship:control:pilotroll=0.
		sas off.
		lock wheelThrottle to wheelthrot.
		// lock wheelSteering to update_heading().
		clearscreen.
	}
    local wp is has_waypoint().
    if wp:istype("waypoint") {
        if (wp:position - ship:position):mag < 100 {
            return true.
        }
    }
	if (pitch_for() < -10) or (abs(roll_for()) > 10) {
		print pitch_for().
		print roll_for().
		return true.
	}
	return False.
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

function east_for{
	parameter ves is ship.
	return vcrs(ves:up:vector, ves:north:vector).
}