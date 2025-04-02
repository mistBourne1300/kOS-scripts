parameter deshead.
parameter desalt.
parameter desairspd. 

set timedelay to .5.

main().


function main {
	set deshead to abs(mod(deshead,360)).
	sas off.
	clearscreen.
	print "heading: " + deshead.
	print "altitude: " + desalt.
	print "speed: " + desairspd.
	print "press 'a' to edit altitude".
	print "press 's' to edit speed".
	print "press 'h' to edit heading".
	print "press backspace to quit".

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

	// initialize compdir pid loop
	// set compdirkp to 0.1.
	// set compdirki to 0.1.
	// set compdirkd to 0.1.
	// set compdirpdi to pidloop(compdirkp, compdirki, compdirkd).
	// set compdirpid:setpoint to 0.

	// initialize pitch angle loop
	set pitchangkp to 0.5.
	set pitchangki to 0.01.
	set pitchangkd to 1.
	set minpitchang to -15.
	set maxpitchang to 15.
	set pitchang to pidloop(pitchangkp, pitchangki, pitchangkd, minpitchang, maxpitchang).
	set pitchang:setpoint to desalt.


	// initialize roll control loop
	set rollkp to 0.05.
	set rollki to 0.01.
	set rollkd to 0.01.
	set minroll to -1.
	set maxroll to 1.
	set rollcontrol to pidloop(rollkp, rollki, rollkd, minroll, maxroll).
	set rollcontrol:setpoint to 0.
	
	// initialize pitch control pid
	set pitchkp to 0.05.
	set pitchki to 0.005.
	set pitchkd to 0.01.
	set minpitch to -1.
	set maxpitch to 1.
	set pitchcontrol to pidloop(pitchkp, pitchki, pitchkd, minpitch, maxpitch).

	// initialize yaw control pid
	set yawkp to 0.05.
	set yawki to 0.0.
	set yawkd to 0.01.
	set minyaw to -1.
	set maxyaw to 1.
	set yawcontrol to pidloop(yawkp, yawki, yawkd, minyaw, maxyaw).
	set yawtakeover to 10.
	// set yawcontrol:setpoint to deshead.


	
	lock curcomp to compass_for().
	lock yaw_ang to ang_dist().
	lock curpitch to pitch_for().
	lock curroll to roll_for().

	if not exists("0:autopilot_log.csv"){
		create("0:autopilot_log.csv").
	} else {
		deletepath("0:autopilot_log.csv").
		create("0:autopilot_log.csv").
	}

	log "heading,altitude,airspeed" to "0:autopilot_log.csv".
	set updates to queue().
	reset_delay().
	set delayed to true.
	until test_flameout(){
		if delayed {
			delayed_update_loops().
		} else {
			update_loops().
		}
		wait 0.001.
	}
	print "releasing controls.".
	set ship:control:neutralize to true.
	sas on.
}

function update_loops {
	set throt to throtpid:update(time:seconds, airspeed).
	set angle to pitchang:update(time:seconds, altitude).
	set pitchcontrol:setpoint to angle.
	set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
	if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
		set ship:control:yaw to 0.
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
	log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
}

function reset_delay {
	set start to time:seconds.
	set updates to queue().
	until time:seconds - start > timedelay{
		set newupdate to list().
		newupdate:add(throtpid:update(time:seconds, airspeed)).
		
		set angle to pitchang:update(time:seconds, altitude).
		set pitchcontrol:setpoint to angle.
		newupdate:add(pitchcontrol:update(time:seconds, pitch_for())).
		if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
			newupdate:add(0).
			if yaw_ang > 0 {
				// roll left, set maximum
				set rollcontrol:setpoint to max(-55,-(60/40)*(yaw_ang - 5) -15).
			} else {
				set rollcontrol:setpoint to min(55, -(70/60)*(yaw_ang + 5) + 15).
			}
		} else {
			set rollcontrol:setpoint to 0.
			newupdate:add(yawcontrol:update(time:seconds, yaw_ang)).
		}
		newupdate:add(rollcontrol:update(time:seconds, curroll)).
		updates:push(newupdate).
		log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
		wait 0.001.
	}
}

function ang_dist {
	set left to curcomp - deshead.
	if left < 0 {
		set left to left + 360.
	}
	set right to deshead - curcomp.
	if right < 0 {
		set right to right + 360.
	}
	if right < left {
		return -1*right.
	} else {
		return left.
	}
}

function test_flameout {
	for eng in engs {
		if eng:flameout{
			print "encountered engine flameout".
			return True.
		}
	}
	if terminal:input:haschar {
		set c to terminal:input:getchar().
		if c = terminal:input:backspace {
			print "program quit by user".
			return True.
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
			set desalt to newdesalt:tonumber(desalt).
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
		} else if c = "T" {
			autotune().
		} else if c = "D" {
			clearscreen.
			if delayed {
				print "delay off".
				set delayed to false.
			} else {
				print "delay on: " + timedelay + " sec".
				set delayed to true.
				reset_delay().
			}
		}
		printinfo().
		if exists("0:autopilot_log.csv") {
			deletepath("0:autopilot_log.csv").
			create("0:autopilot_log.csv").
		} else {
			create("0:autopilot_log.csv").
		}
		log "heading,altitude,airspeed" to "0:autopilot_log.csv".
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
	print "heading: " + deshead.
	print "altitude: " + desalt.
	print "speed: " + desairspd.
	print "press 'a' to edit altitude".
	print "press 's' to edit speed".
	print "press 'h' to edit heading".
	print "press backspace to quit".
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

function autotune {
	// delay roll only
	set pupdates to queue().
	set start to time:seconds.
	until time:seconds - start > timedelay {
		set throt to throtpid:update(time:seconds, airspeed).
		set angle to pitchang:update(time:seconds, altitude).
		set angle to pitchang:update(time:seconds, altitude).
		set pitchcontrol:setpoint to angle.
		set ship:control:pitch to pitchcontrol:update(time:seconds, pitch_for()).
		if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
			set ship:control:yaw to 0.
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
		pupdates:push(rollcontrol:update(time:seconds, curroll)).
		log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
	}

	tune_control().

	function release {
		if terminal:input:haschar {
			set c to terminal:input:getchar().
			if c = terminal:input:backspace {
				print "releasing to undelayed control".
				set delayed to false.
				return true.
			}
		}
		return false.
	}

	// reset log file for new control scheme
	if not exists("0:autopilot_log.csv"){
		create("0:autopilot_log.csv").
	} else {
		deletepath("0:autopilot_log.csv").
		create("0:autopilot_log.csv").
	}
	print "press backspace to release to undelayed control".

	until release() {
		set throt to throtpid:update(time:seconds, airspeed).
		set angle to pitchang:update(time:seconds, altitude).
		set pitchcontrol:setpoint to angle.
		set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
		if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
			set ship:control:yaw to 0.
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
		pupdates:push(rollcontrol:update(time:seconds, curroll)).
		set ship:control:roll to pupdates:pop().
		log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
	}
}

function average {
	parameter liszt is list.
	local sum is 0.
	for i in liszt {
		set sum to sum + i.
	}
	return sum / liszt:length.
}

function variance {
	parameter liszt is list.
	if liszt:length = 1{
		return 1000.
	}
	local mean is average(liszt).
	local sumsofsquares is 0.
	for i in liszt {
		set sumsofsquares to sumsofsquares + (i-mean)^2.
	}
	return sumsofsquares/(liszt:length - 1).
	
}

function differences {
	parameter liszt is list.
	local diffs is list().
	local i is 0.
	print "getting differences " + liszt:length.
	until i = liszt:length - 1 {
		print i.
		diffs:add(liszt[i+1] - liszt[i]).
		set i to i + 1.
	}
	return diffs.
}

function is_oscillating {
	parameter liszt is list. // a list of the times that the pitch went from increasing to decreasing
	// calculate variance of the differences
	if liszt:length < 5 {
		print liszt:length.
		return false.
	}
	local diffs is differences(liszt).
	local var is variance(diffs).
	print "diff variance: " + var.
	return var < 0.01.
}

function delayed_update_loops {
	// time delayed control
	set oldupdate to updates:pop().
	set throt to oldupdate[0].
	set ship:control:pitch to oldupdate[1].
	set ship:control:yaw to oldupdate[2].
	set ship:control:roll to oldupdate[3].



	set newupdate to list().
	newupdate:add(throtpid:update(time:seconds, airspeed)).
	
	set angle to pitchang:update(time:seconds, altitude).
	set pitchcontrol:setpoint to angle.
	newupdate:add(pitchcontrol:update(time:seconds, pitch_for())).
	if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
		newupdate:add(0).
		if yaw_ang > 0 {
			// roll left, set maximum
			set rollcontrol:setpoint to max(-55,-(60/40)*(yaw_ang - 5) -15).
		} else {
			set rollcontrol:setpoint to min(55, -(70/60)*(yaw_ang + 5) + 15).
		}
	} else {
		set rollcontrol:setpoint to 0.
		newupdate:add(yawcontrol:update(time:seconds, yaw_ang)).
	}
	newupdate:add(rollcontrol:update(time:seconds, curroll)).
	updates:push(newupdate).
	wait 0.001.
	log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
}

function tune_control { // only tunes the pitch loop and only the pitch loop is delayed
	local loopid is rollcontrol.
	local deltakp is 0.005*timedelay. // this was 0.001, quintupled the deltakp since we doubled the updating time as well (don't want to crach cause we don't update fast enough)
	set loopid:kp to deltakp.
	set loopid:ki to 0.
	set loopid:kd to 0.
	local signsofthetimes to list().
	local prev to loopid:pterm.
	local wasincreasing is true.
	local timeincrease is 10*timedelay. // doubled this to make room for settling once it get updated
	local prevtime is time:seconds.
	local lisztlength is 10.
	local done is false.
	local dontchecktoooften is 0.5. // added this term so we don't check for this many seconds after an update
	local dctot is time:seconds.
	local failcount is 0.
	until done {
		clearscreen.
		local curr to loopid:pterm.
		print "loop kp: " + loopid:kp.
		print "prev: " + prev.
		print "curr: " + curr.
		print "triggered: " + prev < curr.
		print "increasing: " + wasincreasing.
		print "len: " + signsofthetimes:length.
		print "fails: " + failcount.
		
		if prev >= curr {

			if wasincreasing and time:seconds - dctot > dontchecktoooften {
				signsofthetimes:add(time:seconds).
				until signsofthetimes:length <= lisztlength {
					signsofthetimes:remove(0).
				}
				set done to is_oscillating(signsofthetimes).
				if not done {
					set failcount to failcount + 1.
				}
				set prevtime to time:seconds.
			}
			set wasincreasing to false.
		} else {
			set wasincreasing to true.
		}
		set prev to curr.
		if time:seconds - prevtime > timeincrease or failcount > 20{
			set loopid:kp to loopid:kp + deltakp.
			set prevtime to time:seconds.
			set dctot to time:seconds.
			set failcount to 0.
		}
		set throt to throtpid:update(time:seconds, airspeed).
		set angle to pitchang:update(time:seconds, altitude).
		set pitchcontrol:setpoint to angle.
		set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
		if abs(yaw_ang) > yawtakeover { // TODO: check where pitch control is going. if it's negative, we need to flip all these values. actually, do we need to do that? its pretty quick at finding the pitch angle, so maybe we just assume it's always pitching up.
			set ship:control:yaw to 0.
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
		pupdates:push(rollcontrol:update(time:seconds, curroll)).
		set ship:control:roll to pupdates:pop().
		log yaw_ang+","+(desalt-altitude)+","+(desairspd-airspeed) to "0:autopilot_log.csv".
		wait 0.001.
	}
	set ku to loopid:kp.
	set tu to abs(average(differences(signsofthetimes))).
	print "ku " + ku.
	print "tu " + tu.

	// Zeigler-Nichols Tuning
	// set loopid:kp to 0.6*ku.
	// set loopid:ki to 1.2*ku/tu.
	// set loopid:kd to 3*ku*tu/40.

	// Pessen integral Rule
	// set loopid:kp to 0.7*ku.
	// set loopid:ki to 1.75*ku/tu.
	// set loopid:kd to 0.105*ku*tu.

	// some overshoot
	// set loopid:kp to ku/3.
	// set loopid:ki to (2/3)*ku/tu.
	// set loopid:kd to ku*tu/9.

	// no overshoot
	// set loopid:kp to 0.2*ku.
	// set loopid:ki to 0.4*ku/tu.
	// set loopid:kd to ku*tu/15.

	// Tyreus-Luyben Tuning
	set loopid:kp to ku/2.2.
	set loopid:ki to 2.2*tu.
	set loopid:kd to tu/6.3.

	// custom tuning
	// set loopid:kp to 0.2*ku.
	// set loopid:ki to 0.2*ku.
	// set loopid:kd to ku*tu*1.5.
}