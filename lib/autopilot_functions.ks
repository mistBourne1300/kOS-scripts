parameter deshead is 90.
parameter desalt is 7000.
parameter desairspd is 200.
parameter vsmax is 100.

set km to 1000.

initialize().

function initialize {
	// this takes a lot of computing power...
	set config:ipu to 1000.

    list engines in engs. // is used to check whether an engine has flamed out

    // initialize throttle pid
	set throtkp to 0.1.
	set throtki to 0.01.
	set throtkd to 0.1.
	set minthrot to 0.0.
	set maxthrot to 1.0.
	set throtpid to pidloop(throtkp, throtki, throtkd, minthrot, maxthrot).
	set throtpid:setpoint to desairspd.
	set throt to 0.0.
	lock throttle to throt.

	// initialize vertical speed loop
	set vskp to .3.
	set vski to 0.
	set vskd to 0.2.
	set vspid to pidloop(vskp,vski,vskd,-vsmax,vsmax).
	set vspid:setpoint to desalt.

	// initialize pitch angle loop
	// this loop is mostly for fine-tuned adjustments to the vertical speed
	// the heavy lifting of that is taken care of with an arcsin in the update_loops() funcion
	// hence the kp of 0
	set pitchangkp to 0.
	set pitchangki to 0.0.
	set pitchangkd to 0.3.
	set minpitchang to -3.
	set maxpitchang to 10.
	set pitchang to pidloop(pitchangkp, pitchangki, pitchangkd, minpitchang, maxpitchang).
	set pitchang:setpoint to 0.


	// initialize roll control loop
	set rollkp to 0.01.
	set rollki to 0.0.
	set rollkd to 0.02.
	set minroll to -1.
	set maxroll to 1.
	set rollcontrol to pidloop(rollkp, rollki, rollkd, minroll, maxroll).
	set rollcontrol:setpoint to 0.
	
	// initialize pitch control pid 
	// different from the pitch angle pid, 
	// this one actually controls the pitch control surfaces
	set pitchkp to 0.03.
	set pitchki to 0.002.
	set pitchkd to 0.01.
	set minpitch to -0.5.
	set maxpitch to 1.
	set pitchcontrol to pidloop(pitchkp, pitchki, pitchkd, minpitch, maxpitch).

	// initialize yaw control pid
	set yawkp to 0.03.
	set yawki to 0.0.
	set yawkd to 0.005.
	set minyaw to -1.
	set maxyaw to 1.
	set yawcontrol to pidloop(yawkp, yawki, yawkd, minyaw, maxyaw).
	set yawtakeover to 3.

	// this will minimize sideslip
	// since ki is 0, it has no way to "learn" what yaw control
	// should be input to arrive at 0 sideslip angle
	// this is intentional, as 
	// a) we shouldn't need it and
	// b) we don't want to interfere with the yaw control loop above
	// (too much)
	set sideslipkp to 0.1.
	set sideslipki to 0.0.
	set sideslipkd to 0.05.
	set sideslipcontrol to pidloop(sideslipkp, sideslipki, sideslipkd, minyaw, maxyaw).

	// dampening control as we increase airspeed
	// seen in the update_loops() function
	set full_control_q to 10.
	lock sqrt_q to sqrt(ship:q)/5.

	// these constants are used under waypoint navigation,
	// and will pause the game once we get close to the current waypoint
	set wp_delta to 250^2.
	set wp_pause_dist to 1000.//sqrt(desalt^2 + wp_delta).

	// this is used in the ang_dist() function when navigating to a runway.
	// this is the maximum angle the plane is allowed to make 
	// with the runway's waypoint
	set min_angle_diff to 85.

	// compass heading and pitch, yaw and roll values
	lock curcomp to compass_for().
	lock curpitch to pitch_for().
	lock yaw_ang to ang_dist().
	lock curroll to roll_for().

	// this is the vector projection of the velocity vector onto the plane
	// defined by ship:facing:vector and ship:facing:topvector
	lock facing_vec_proj_top to (ship:velocity:surface*ship:facing:vector)*ship:facing:vector + (ship:velocity:surface*ship:facing:topvector)*ship:facing:topvector.
	// gets the angle of attack of the ship
	lock aoa to max(min(vang(ship:facing:vector, facing_vec_proj_top),10),0).
	set angle to 0.

	// this is the vector projection of the velocity vector onto the plane
	// defined by ship:facing:vector and ship:facing:starvector
	lock facing_vec_proj_star to (ship:velocity:surface*ship:facing:vector)*ship:facing:vector + (ship:velocity:surface*ship:facing:starvector)*ship:facing:starvector.
	// gets the sideslip angle
	lock sideslip to sign(vdot(vcrs(facing_vec_proj_star, ship:facing:vector),ship:facing:topvector))*vang(ship:facing:vector, facing_vec_proj_star).
}

function sign {
	parameter num.
	return num/abs(num).
}

function check_status {
	print "waiting for pilot to release control".
	wait until  (ship:control:pilotpitch=0) and (ship:control:pilotyaw=0) and (ship:control:pilotroll=0).
	clearScreen.

    if ship:status = "landed" or ship:status = "prelaunch" {
		if stage:deltav:current = 0 { // we're on the runway without having staged.
			clearscreen.
			print "runway takoff".

			// lower flaps
			toggle ag3.
			wait 1.
			toggle ag3.
			wait 1.
			toggle ag3.

			brakes off.
			sas off.
			stage.
			set tempairspeed to desairspd.
			set desairspd to 1.
			set wheelsteerkp to .1/desairspd.
			set wheelsteerki to 0.
			set wheelsteerkd to 0.
			set minsteer to -1.
			set maxsteer to 1.
			set wheelsteerpid to pidLoop(wheelsteerkp,wheelsteerki,wheelsteerkd,minsteer,maxsteer).
			until abs(anglediff(90,curcomp)) < yawtakeover{
				set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), 90)).
				lock throttle to 0.01*(1 - airspeed).
				wait 0.001.
			}
			lock throttle to throt.
			set desairspd to tempairspeed.
			set pitchang:setpoint to desalt.

			set ship:control:pitch to 0.
			// lock throttle to 1.
			
			until ship:status = "flying" {
				if airspeed > 50 {
					set ship:control:pitch to .01*(airspeed-50).
				}
				set wheelsteerpid:kp to .1/airspeed.
				set throt to throtpid:update(time:seconds, airspeed).
				set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), 90)).
				// set angle to pitchang:update(time:seconds, altitude).
				// set pitchcontrol:setpoint to max(angle,5).
				// set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).

				wait 0.001.
			}
			lock throttle to throt.
			toggle gear.
			until alt:radar > 50 {
				set throt to throtpid:update(time:seconds, airspeed).
				// set angle to pitchang:update(time:seconds, altitude).
				// set pitchcontrol:setpoint to max(angle,5).
				// set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			set ship:control:neutralize to true.
			lock throttle to throt.
			sas on.
			toggle ag2.
			wait 0.5.
			toggle ag2.
			wait 0.5.
			toggle ag2.
			sas off.
			printinfo().
		} else {
			print "steering to takeoff".
			
			// lower flaps
			brakes on.
			toggle ag3.
			wait 1.
			toggle ag3.
			wait 1.
			toggle ag3.

			brakes off.
			sas off.
			set tempairspeed to desairspd.
			set desairspd to 5.
			set wheelsteerkp to .1/desairspd.
			set wheelsteerki to 0.
			set wheelsteerkd to 0.
			set minsteer to -1.
			set maxsteer to 1.
			set wheelsteerpid to pidLoop(wheelsteerkp,wheelsteerki,wheelsteerkd,minsteer,maxsteer).
			until abs(yaw_ang) < yawtakeover {
				set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), deshead)).
				lock throttle to 0.1*(5 - airspeed).
				wait 0.001.
			}
			lock throttle to 1.
			set ship:control:pitch to 0.
			set desairspd to tempairspeed.
			set pitchang:setpoint to desalt.
			until ship:status = "flying" {
				set ship:control:pitch to .01*airspeed.
				set wheelsteerpid:kp to .1/airspeed.
				set ship:control:wheelsteer to wheelsteerpid:update(time:seconds, anglediff(compass_for(), deshead)).
				// set throt to throtpid:update(time:seconds, airspeed).
				// set angle to pitchang:update(time:seconds, altitude).
				// set pitchcontrol:setpoint to max(angle,5).
				// set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			printinfo().
			toggle gear.
			until alt:radar > 50 {
				// set throt to throtpid:update(time:seconds, airspeed).
				// set angle to pitchang:update(time:seconds, altitude).
				// set pitchcontrol:setpoint to max(angle,5).
				// set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
				wait 0.001.
			}
			
			set ship:control:neutralize to true.
			lock throttle to throt.
			sas on.
			toggle ag2.
			wait 0.5.
			toggle ag2.
			wait 0.5.
			toggle ag2.
			sas off.
			printinfo().
		}
	} else if not ship:status = "flying" {
		print "status " + ship:status + " unrecognized.".
		print "terminating.".
		brakes on.
		set ship:control:neutralize to true.
		sas on.
		set ship:control:pilotmainthrottle to 0.
		lock throttle to 0.
		return false.
	}
	return true.
}

function printinfo {
	clearscreen.
	print "heading: " + deshead.
	print "alt: " + vspid:setpoint.
	print "speed: " + throtpid:setpoint.
	print "vsmax: " + vsmax.
	print "vs: " + vspid:output.
	print "pitchang: " + pitchang:output.
	print "pitch: " + pitchcontrol:output.
	print "aoa: " + aoa.
	print "angle: " + angle.

	// print "sideslip: " + sideslip.

	print "press 'a' to edit altitude".
	print "press 's' to edit speed".
	print "press 'h' to edit heading".
	print "press 'v' to change vsmax".
	print "press q to quit".
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
		set vectowp to wp:position - ship:position.
		if vectowp:mag < wp_pause_dist {
			return angleDiff(deshead,curcomp).
		}
		set deshead to wp:geoPosition:heading.
		if vectowp:mag < 25*km and vectowp:mag > 2*km{// and vdot(ship:facing:vector,vectowp)>0{
			if wp:name = "KSC" or wp:name = "Island Airfield" {
				if deshead < 90 {
					set deshead to deshead - min(3*abs(anglediff(deshead,90)),min_angle_diff).
				} else if deshead < 180 {
					set deshead to deshead + min(3*abs(anglediff(deshead,90)),min_angle_diff).
				} else if deshead < 270 {
					set deshead to deshead - min(3*abs(anglediff(deshead,270)),min_angle_diff).
				} else {
					set deshead to deshead + min(3*abs(anglediff(deshead,270)),min_angle_diff).
				}
				// printinfo().
			} else if wp:name = "Dessert Airfield" {
				if deshead < 90 { // these are all wrong, the sign needs to change
					set deshead to deshead + min(3*abs(anglediff(deshead,90)),min_angle_diff).
				} else if deshead < 180 {
					set deshead to deshead - min(3*abs(anglediff(deshead,90)),min_angle_diff).
				} else if deshead < 270 {
					set deshead to deshead + min(3*abs(anglediff(deshead,270)),min_angle_diff).
				} else {
					set deshead to deshead - min(3*abs(anglediff(deshead,270)),min_angle_diff).
				}
			}
		}
	}
	return anglediff(deshead, curcomp).
}

function test_flameout {
	for eng in engs {
		if eng:flameout{
			print "encountered engine " + eng:name + " flameout".
			print "pausing game. control will be released at game unpause.".
			set ship:control:neutralize to true.
			sas on.
			kuniverse:pause().
			return true.
			// return 1/0.
		}
	}
	// no engine has flamed out, so we may safely check to see if the stage has 0 dv
	// if it does, we stage.
	if stage:deltav:current <= 0 and throt >= 0.5{
		if stage:number > 0 {
			stage.
		}
	}

	if terminal:input:haschar {
		set c to terminal:input:getchar().
		if c = "q" {
			print "program quit by user".
			set ship:control:neutralize to true.
			sas on.
			return true.
		} else if c = "a" {
			print "enter desired altitude:".
			set curr_throt to throttle.
    		set ship:control:neutralize to true.
    		set ship:control:pilotmainthrottle to curr_throt.
			sas on.
			set c to terminal:input:getchar().
			set newdesalt to "".
			until c = terminal:input:return {
				set newdesalt to newdesalt + c.
				print newdesalt.
				set c to terminal:input:getchar().
				// clearscreen.
			}
			sas off.
			lock throttle to throt.
			set desalt to newdesalt:tonumber(desalt).
			set vspid:setpoint to desalt.
			set wp_pause_dist to sqrt(desalt^2 +wp_delta).
		} else if c = "s" {
			print "set desired airspeed:".
			set curr_throt to throttle.
    		set ship:control:neutralize to true.
    		set ship:control:pilotmainthrottle to curr_throt.
			sas on.
			set c to terminal:input:getchar().
			set newspeed to "".
			until c = terminal:input:return {
				set newspeed to newspeed + c.
				print newspeed.
				set c to terminal:input:getchar().
				// clearscreen.
			}
			sas off.
			lock throttle to throt.
			set desairspd to newspeed:tonumber(desairspd).
			set throtpid:setpoint to desairspd.
		} else if c = "h" {
			print "set desired heading:".
			set curr_throt to throttle.
    		set ship:control:neutralize to true.
    		set ship:control:pilotmainthrottle to curr_throt.
			sas on.
			set c to terminal:input:getchar().
			set newheading to "".
			until c = terminal:input:return {
				set newheading to newheading + c.
				print newheading.
				set c to terminal:input:getchar().
				// clearscreen.
			}
			sas off.
			lock throttle to throt.
			set deshead to abs(mod(newheading:tonumber(deshead),360)).
			// the ang dist function will be able to read this and adjust accordingly.
		} else if c = "v" {
			print "set desired max vertical speed:".
			set curr_throt to throttle.
    		set ship:control:neutralize to true.
    		set ship:control:pilotmainthrottle to curr_throt.
			sas on.
			set c to terminal:input:getchar().
			set newvs to "".
			until c = terminal:input:return {
				set newvs to newvs + c.
				print newvs.
				set c to terminal:input:getchar().
				// clearscreen.
			}
			sas off.
			lock throttle to throt.
			set vsmax to newvs:tonumber(vsmax).
			set vspid:maxoutput to vsmax.
			set vspid:minoutput to -vsmax.
		} else if c = "r" {
			// we want to run airspeed of the 
			print "performing quicksave.".
			if kuniverse:canquicksave{
				kuniverse:quicksave().
			} else {
				print "quicksaving failed.".
			}
			print "airspeed program active.".
			set ship:control:neutralize to true.
			sas on.
			lock throttle to throt.
			until alt:radar < 10 {
        		set throt to throtpid:update(time:seconds, airspeed).
        		wait 0.001.
    		}
			set ship:control:pilotmainthrottle to 0.
			return true.
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
		set curr_throt to throttle.
		set ship:control:neutralize to true.
		set ship:control:pilotmainthrottle to curr_throt.
		sas on. 
		print "waiting for pilot to release control".
		wait until ship:control:pilotpitch=0 and ship:control:pilotyaw=0 and ship:control:pilotroll=0.
		sas off.
		lock throttle to throt.
		clearscreen.
		printinfo().
	}
	// if stage:deltav:current <= 0.0 {
	// 	print "current stage has 0 deltav, pausing for human decision.".
	// 	print "upon resume you will have 5 seconds before script resumes.".
	// 	unlock throttle.
	// 	set ship:control:neutralize to true.
	// 	sas on.
	// 	kuniverse:pause.
	// 	wait 5.
	// 	lock throttle to throt.
	// 	sas off.
	// }
	return False.
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

// TODO: maybe instead of using e.g. ship:control:pitch
// we use ship:control:pilotpitch, as this will unlock after program termination
// allowing the pilot to control the plane without 
// needing to set ship:control:neutralize to true.
// I wonder if that's even how that works???
function update_loops {
	if ship:q > full_control_q {
		set rollcontrol:kp to full_control_q*rollkp/sqrt_q.
		set rollcontrol:ki to full_control_q*rollki/sqrt_q.
		set rollcontrol:kd to full_control_q*rollkd/sqrt_q.

		set pitchcontrol:kp to full_control_q*pitchkp/sqrt_q.
		set pitchcontrol:ki to full_control_q*pitchki/sqrt_q.
		set pitchcontrol:kd to full_control_q*pitchkd/sqrt_q.
		
		set yawcontrol:kp to full_control_q*yawkp/sqrt_q.
		set yawcontrol:ki to full_control_q*yawki/sqrt_q.
		set yawcontrol:kd to full_control_q*yawkd/sqrt_q.
	} else {
		set rollcontrol:kp to rollkp.
		set rollcontrol:ki to rollki.
		set rollcontrol:kd to rollkd.

		set pitchcontrol:kp to pitchkp.
		set pitchcontrol:ki to pitchki.
		set pitchcontrol:kd to pitchkd.
		
		set yawcontrol:kp to yawkp.
		set yawcontrol:ki to yawki.
		set yawcontrol:kd to yawkd.
	}

	// update throttle
	set throt to throtpid:update(time:seconds, airspeed).
	// change vertical speed derivative term depending on the altitude error
	// I found that a kd term of 2.5 is about right once our error is large,
	// but we want to make that smaller once our error gets smaller
	// or we start to get some weird oscillations
	set vspid:kd to min(2,abs(vspid:error)/25) + 1.
	// get desired vertical speed
	set vspid:maxoutput to min(airspeed/3,vsmax).
	set vertupdate to vspid:update(time:seconds, altitude).
	// this pitch angle only handles how much to adjust the pitch angle. 
	// i.e. the  arcSin(vertupdate/airspeed) below handles what angle to go to
	// this first line only handles the fine-tuning
	set pitchang:setpoint to vertupdate.
	set angle to pitchang:update(time:seconds, verticalSpeed) + aoa.
	if abs(airspeed) >= abs(vertupdate) {
		// if the airspeed is less than the vertical update, arcsin will throw an error.
		// additionally, we don't want to have an angle larger than 25 (arbitrarily chosen)
		set angle to min(angle + arcSin(vertupdate/airspeed),25).
	} else {
		if vertupdate < 0{
			set angle to angle - 15.
		} else {
			set angle to angle + 15.
		}
	}
	
	// get the desired pitch angle and update the plane's pitch control accordingly.
	set pitchcontrol:setpoint to angle.
	set ship:control:pitch to pitchcontrol:update(time:seconds, curpitch).
	if ship:control:pitch > 0 {
		// banking maneuver, with a maximum bank angle of 55.
		// this maximum angle can be changed, but the -(55/15) constant
		// will probably need to be changed as well...
		if yaw_ang > 0 {
			// roll left, set maximum
			set rollcontrol:setpoint to max(-55,-(55/15)*(yaw_ang)).
		} else {
			// roll right, set minimum
			set rollcontrol:setpoint to min(55, -(55/15)*(yaw_ang)).
		}
	} else {
		// if the plane's pitch control is pushing nose-down
		// this would reverse the action of a roll,
		// so in this case, we just say no roll until
		// the pitch is back above 0.
		// I guess the hidden assumption here is that
		// even at level flight, some pitch up control
		// will be necessary to maintain that.
		set rollcontrol:setpoint to curroll.
	}
	if abs(yaw_ang) > yawtakeover{
		// if we're too far away from our set heading, let the roll control handle it
		set ship:control:yaw to sideslipcontrol:update(time:seconds, sideslip).
	} else {
		// now we're close enough that yaw control can contribute to aligning the heading.
		set ship:control:yaw to yawcontrol:update(time:seconds, yaw_ang) + sideslipcontrol:update(time:seconds, sideslip).
	}
	set ship:control:roll to rollcontrol:update(time:seconds, curroll).
}

