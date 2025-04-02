parameter desiredapo.
parameter pitchingairspeed.
parameter inc is 0.
set desiredapo to desiredapo * 1000.

set pitchangle to 5.

main().

function main {
    clearscreen.
    countdown().

    set goon to liftoff().
	if goon {
		print "we have liftoff.".
		ascent_stage().
        peg().
		circularization().
	}
}

function countdown {
	print "T minus".
	from {local count is 10.} until count = 0 step {set count to count - 1.} do {
		print "..." + count.
		if count = 5 {
			print "calculating azimuth".
			set az to azimuth(inc, desiredapo).
		}
		else if count = 4{
			print "azimuth: " + az.
		}
		if count = 3 {
			print "pointing rocket up.".
			sas off.
			lock steering to up + r(0,0,180).
		} else if count = 2 {
			print "locking throttle to full.".
			lock throttle to 1.
		} else if count = 1 {
			print "light this candle!".
		}
		wait 1.
	}
}

function azimuth {
    local parameter inclination.
    parameter orbit_alt.
    parameter auto_switch is false.

    local shipLat is ship:latitude.
    if abs(inclination) < abs(shipLat) {
        set inclination to shipLat.
    }

    local head is arcsin(cos(inclination) / cos(shipLat)).
    // if auto_switch {
    //     if angleToBodyDescendingNode(ship) < angleToBodyAscendingNode(ship) {
    //         set head to 180 - head.
    //     }
    // }
	// if the above if statement is active, the below one is an if-else
    if inclination < 0 {
        set head to 180 - head.
    }
    local vOrbit is sqrt(body:mu / (orbit_alt + body:radius)).
    local vRotX is vOrbit * sin(head) - vdot(ship:velocity:orbit, heading(90, 0):vector).
    local vRotY is vOrbit * cos(head) - vdot(ship:velocity:orbit, heading(0, 0):vector).
    set head to 90 - arctan2(vRotY, vRotX).
    return mod(head + 360, 360).
}

function has_clamps {
	list parts in partlist.
	for p in partlist {
		if p:name = "launchClamp1"{
			return true.
		}
	}
	return false.
}

function liftoff {
	list engines in engs.
	stage.
	print "stage activated".
	wait until stage:ready.
	until not has_clamps() {
		for eng in engs {
			if eng:flameout {
				print "engine failure. aborting.".
				return false.
			}
		}
		wait until stage:ready.
		stage.
		print "stage activated".
	}
	return true.
}

function pitch_for {
	parameter pointing is ship:facing:forevector.
	return 90 - vang(ship:up:vector,pointing).
}

function heading_bug {
	if altitude > 40000 {
		set prgrd to prograde:vector.
	} else {
		set prgrd to srfprograde:vector.
	}
	set prograde_pitch to pitch_for(prgrd).
	return heading(az, prograde_pitch, -90).
}

function ascent_stage {
	until airspeed > pitchingairspeed {
		needstage().
		wait 0.001.
	}
	clearscreen.
	print "pitching airspeed achieved.".
	print "beginning pitching maneuver.".

	pitch().
	clearscreen.
	print "pitching angle achieved. locking to prograde.".
	lock steering to heading_bug().

	set Kp to 0.1.
	set Ki to 0.1.
	set Kd to 0.1.
	set min_thrott to 0.07.
	set max_thrott to 1.0.
	set throttpid to pidloop(Kp, Ki, Kd, min_thrott, max_thrott).

	set throttpid:setpoint to 60.
	set mythrot to 1.0.
	lock throttle to mythrot.
	
	until altitude > 57000 {
		if needstage() {return.}
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}
	print "staging fairing on AG10.".
	toggle ag10. // will stage the fairing
	until ship:dynamicpressure = 0 or apoapsis > desiredapo{
		if needstage() {return.}
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}
	set des_twr to get_curr_thrust()/get_weight().
	if apoapsis < desiredapo {
		print "reached space. locking throttle.".
		print "des twr: " + des_twr.
	}
	until apoapsis > desiredapo {
		set stagenum to stage:number.
		if needstage() {return.}
		if not (stage:number = stagenum) {
			print "adjusting throttle.".
			lock curr_twr to get_curr_thrust()/get_weight().
			until curr_twr >= des_twr{
				set mythrot to mythrot + 0.05.
				if mythrot > 1 {
					set mythrot to 1.
					break.
				}
			} 
		}
		wait 0.001.
	}
	lock throttle to 0.
	print "MECO".
    stage.
}

function pitch {
	set start to time:seconds.
	until time:seconds > start + 5 {
		lock steering to heading(az, 90-(pitchangle/5)*(time:seconds - start)) + r(0,0,-90).
		needstage().
		wait 0.001.
	}
	lock steering to heading(az,90-pitchangle) + r(0,0,-90).
	until time:seconds > start + 15 {
		needstage().
		wait 0.001.
	}
}

function needstage {
	list engines in engs.
	for eng in engs {
		if (eng:flameout or stage:deltav:current = 0.0) and stage:ready {
			stage.
			wait until stage:ready.
			wait 0.1.
			check_eng_failure().
			return true.
		}
	}
    return false.
}

function check_eng_failure {
	list engines in engs.
	for eng in engs {
		if eng:flameout {
			if altitude < 20000 {
				print "engine failure, aborting.".
				toggle abort.
				force_exept().
			} else {
				force_exept().
			}
		}
	}
}

function force_exept {
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	print "automatic control encountered a situation".
	wait .5.
	print "it doesn't know how to handle.".
	wait .5.
	print "(likely a high-altitude engine failure).".
	wait .5.
	print "switching to manual control".
	unlock all.
	sas on.
	wait .5.
	print "this script will self-destruct".
	print "in 10 seconds.".
	wait 10.
	set goodbye to 1/0.
	print goodbye.
}

function peg {
    set r_T to desiredapo + body:radius.
    set r_dot_T to 0.
    set h_T to sqrt(constant:G * body:mass/r_T).
    set T to 1000.

    lock r_vec to -ship:body:position.
    lock v_vec to ship:velocity - ship:body:position.
    lock r_hat to r_vec/r_vec:mag.
    lock h_vec to vcrs(r_vec,v_vec).
    lock h_hat to h_vec/h_vec:mag.
    lock theta_vec to vcrs(h_vec, r_vec).
    lock theta_hat to theta_vec/theta_vec:mag.
    lock f_vec to -(ship:facing:forevector - ship:body:position). // if everything goes wrong, use -ship:facing:forevector as the first check
    lock f_hat to f_vec/f_vec:mag.
    lock omega to vDot(v_vec,theta_hat)/r_vec:mag.

    lock r_dot to vdot(r_vec, v_vec)/r_vec:mag.

    set Isp to get_stage_ISP().
    set v_e to Isp*constant:g0.
    lock a to ship:availableThrust/ship:mass.
    lock tau to v_e/a.
    function a_t {
        parameter t.
        return a/(1 - t/tau).
    }

    lock b0 to stage:deltav:current.
    lock b0 to -v_e*ln(1- T/tau)
    
}

function get_stage_ISP {
	list engines in engs.
	local numer is 0.
	local denom is 0.
	for eng in engs {
		if eng:ignition {
			set numer to numer + eng:availablethrust.
			set denom to denom + eng:availablethrust/eng:isp.
		}
	}
	return numer/denom.
}