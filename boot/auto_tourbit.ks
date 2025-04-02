parameter desiredapo is 80.
parameter pitchingairspeed is 60.
parameter inc is 0.
set desiredapo to desiredapo * 1000.

set pitchangle to 5.
set timetoapo to 30.
set circtol to 1000.

main().

function main {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
	clearscreen.
	countdown().

	set goon to liftoff().
	if goon {
		print "we have liftoff.".
		ascention().
		circularization().
	}
	clearscreen.
    set n to nextNode.
    remove n.
    sas off.
    lock steering to retrograde.
    print "deorbiting.".
	wait 10.
    lock throttle to 1.
    wait until periapsis < 0.
    lock throttle to 0.
	lock steering to north.
	print "placing landing.".
	wait 10.
	lock throttle to 1.
	wait 10.
	lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    //kuniverse:pause.
    wait 1.
    print "warping to atmosphere".
    set kuniverse:timewarp:rate to 50.
    wait until altitude < 70000.
	lock steering to srfprograde.
	until stage:number = 0 {if stage:ready{stage.} wait 1.}
	wait 1.
	print "entered atmosphere. prepare for physics warp.".
    wait until vang(ship:facing:vector, srfprograde:vector)<5.
	set kuniverse:timewarp:mode to "physics".
    set kuniverse:timewarp:rate to 4.
	// print "waiting to jettison heat shield.".
	wait until altitude < 18000.
    kuniverse:timewarp:cancelwarp().
	print "waiting for parachute deployment.".
    wait until altitude < 16500.
	print "parachutes deployed. warping".
    set kuniverse:timewarp:rate to 4.
    wait until alt:radar < 1300.
    kuniverse:timewarp:cancelwarp().
	wait until kuniverse:timewarp:issettled.
	wait 1.
	toggle ag8.
	print "heat shield jettisoned.".
    unlock steering.
    wait until vang(ship:facing:vector, up:vector) < 5.
	wait 3.
	print "warping to splashdown.".
    set kuniverse:timewarp:rate to 4.
    wait until alt:radar < 40.
	print "splashdown imminent.".
    set kuniverse:timewarp:rate to 3.
    wait until alt:radar < 30.
    set kuniverse:timewarp:rate to 2.
    wait until alt:radar < 20.
	print "brace for impact.".
    kuniverse:timewarp:cancelwarp().
	print "Program Terminated Successfully.".
}
	
function countdown {
	print "T minus".
	from {local count is 5.} until count = 0 step {set count to count - 1.} do {
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


// unused
function angle {
	// print arctan((desiredapo - altitude)/100000).
	return 1.432*10^(-25)*(altitude^6) - 2.549*10^(-20)*(altitude^5) + 1.725*10^(-15)*(altitude^4) - 5.840*10^(-11)*(altitude^3) + 1.083*10^(-6)*(altitude^2) - 1.149*10^(-2)*(altitude) + 9.680*10.
}

// unused
function twr {
	// calculates the desired twr for each stage of the ascenct.
	// until apoapsis is greater than 30 sec away, it is 1.
	// from there, we want to keep it just under a minute away (~45 sec)
	// once apoapsis reaches it's desired height, this function is never called again

}

// unused
function get_weight {
	return body:mu*ship:mass/((altitude + body:radius)^2).
}

// unused
function control_throttle {
	// calculates the desired throttle level for each stage of the ascenct.
	// until apoapsis is greater than 45 sec away, it is 1.
	// from there, we want to keep it just under a minute away (~45 sec)
	// once apoapsis reaches it's desired height, this function is never called again
	if eta:apoapsis < 45 {
		return 1.
	} else if eta:apoapsis > 60 {
		return 0.01.
	} else {
		return (-.99/15)*(eta:apoapsis - 60) + 0.01.
	}
}

function east_for{
	parameter ves is ship.
	return vcrs(ves:up:vector, ves:north:vector).
}

function pitch_for {
	parameter pointing is ship:facing:forevector.
	return 90 - vang(ship:up:vector,pointing).
}

function compass_for{
	parameter pointing is ship:facing:forevector.
	local east is east_for(ship).

	local trig_x is vdot(ship:north:vector, pointing).
	local trig_y is vdot(east, pointing).

	local result is arcTan2(trig_y, trig_x).
	if result < 0 {
		return 360 + result.
	} else {
		return result.
	}
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

function get_heading {
	set head to 90 - inclination.
	if ship:dynamicpressure = 0 {
		if inclination > 0 {
			set head to head - (abs(inclination) - orbit:inclination).
		} else {
			set head to head + (abs(inclination) - orbit:inclination).
		}
	}
	return head.
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

// unused.
// function get_yaw {
// 	set roll to roll_for().
// 	if roll < 5 {
// 		return 0.
// 	} if roll > 90 {
// 		return 0.
// 	}
// 	set cosine to cos(roll).
// 	set retrun to get_compass_delta().
// 	set retrun to cosine*retrun.
// 	print "dyaw: " + retrun.
// 	return retrun.
// }

function ascention {
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

	// if exists("0:/altlog.csv"){
	// 	deletepath("0:/altlog.csv").
	// 	create("0:/altlog.csv").
	// 	log "time,altitude,airspeed,angle" to "0:/altlog.csv".
	// } else {
	// 	create("0:/altlog.csv").
	// 	log "time,altitude,airspeed,angle" to "0:/altlog.csv".
	// }
	// lock steering to heading(90,angle()) + r(0,0,-90).
	
	
	
	// lock throttle to control_throttle().
	set Kp to 0.1.
	set Ki to 0.1.
	set Kd to 0.1.
	set min_thrott to 0.07.
	set max_thrott to 1.0.
	set throttpid to pidloop(Kp, Ki, Kd, min_thrott, max_thrott).

	set throttpid:setpoint to 60.
	set mythrot to 1.0.
	lock throttle to mythrot.
	
	// lock prevthrust to needstage(prevthrust).
	// until altitude > 40000 {
	// 	clearScreen.
	// 	needstage().
	// 	set mythrot to throttpid:update(time:seconds, eta:apoapsis).
	// 	wait 0.001.
	// }
	until altitude > 57000 {
		needstage().
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}
	print "staging fairing on AG10.".
	toggle ag10. // will stage the fairing
	until ship:dynamicpressure = 0 or apoapsis > desiredapo{
		needstage().
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
		needstage().
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
		// set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}
	lock throttle to 0.
	// clearscreen.
	print "MECO".
}

function get_curr_thrust {
	list engines in engs.
	local curr_thrust is 0.
	for eng in engs {
		set curr_thrust to curr_thrust + eng:thrust.
	}
	return curr_thrust.
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
		if eng:flameout and stage:ready {
			stage.
			wait until stage:ready.
			wait 0.1.
			check_eng_failure().
			return.
		}
	}
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
	wait 1.
	print "it doesn't know how to handle.".
	wait 1.
	print "(likely a high-altitude engine failure).".
	wait 1.
	print "switching to manual control".
	unlock steering.
	sas on.
	wait 1.
	print "this script will self-destruct".
	print "in 10 seconds.".
	wait 10.
	set goodbye to 1/0.
	print goodbye.
}

function circthrottle {
	needstage().
	set tminus to eta:apoapsis.
	set etaperi to eta:periapsis.
	if tminus > etaperi{
		return 1.
	} else if tminus < timetoapo {
		return (timetoapo - tminus)/timetoapo + 0.01.
	} else {
		return 0.01.
	}
}

// unused
function circdpitch {
	set tminus to eta:apoapsis.
	set etaperi to eta:periapsis.
	set dpitch to (desiredapo - apoapsis)/1000.
	if dpitch > 10 {
		set dpitch to 10.
	} else if dpitch < 0 {
		set dpitch to dpitch * 5.
	}
	if dpitch < -10{
		set dpitch to 0.
	}
	if tminus > etaperi {
		set dpitch to abs(dpitch).
	}
	return dpitch.
}

function circ_apo {
	// TODO: make this more robust (the normal component seems to break when the node is on the opposite side of the planet)
	local apo_time is eta:apoapsis.
    set circnode to node(timespan(apo_time), 0 ,0, 0).
	set r1 to periapsis + body:radius.
	set r2 to apoapsis + body:radius.
	set circnode:prograde to sqrt(body:mu/r2)*(1-sqrt(2*r1/(r1+r2))).
    add circnode.
    // until circnode:orbit:eccentricity < 0.0002 and abs(circnode:orbit:inclination - abs(inclination)) < 0.1 {
    //     if circnode:orbit:eccentricity > 0.0002 {
	// 		set circnode:prograde to circnode:prograde + 5*circnode:orbit:eccentricity.
	// 	}
	// 	if abs(circnode:orbit:inclination - abs(inclination)) > 0.1 {
	// 		if inclination > 0{
	// 			set circnode:normal to circnode:normal + (inclination - circnode:orbit:inclination).
	// 		} else {
	// 			set circnode:normal to circnode:normal - (abs(inclination) - circnode:orbit:inclination).
	// 		}
	// 	}
	// }
}

function circularization {
	print "waiting for circularization.".
	// kuniverse:timewarp:warpto(time:seconds + eta:apoapsis - 60).
	wait until ship:dynamicpressure = 0.
	kuniverse:timewarp:cancelwarp().
	circ_apo().
	print "deploying deployables.".
	toggle lights.
	wait 1.
	toggle ag9. // stages all deployables
	print "beginning circularization.".
	reaper().
}

function reaper {
	sas off.
	if not hasnode {
		print "this vessel has no node to execute.".
		return.
	}
	set mynode to nextnode.
	set burn_time to calculate_burn_time().
	if stage:deltav:current < mynode:deltav:mag {
		print "cannot perform maneuver on current stage".
		print "you'll have to control the throttle yourself".
		print "we will stage for you, as well as stop the throttle.".
		node_assist().
		return.
	} else {
		print "burn time: " + burn_time.
	}
	lock steering to mynode:deltav.
	print "steering to burn vector".
	wait until vang(ship:facing:vector, mynode:deltav) < 1.
	kuniverse:timewarp:warpto(mynode:time - 10 - burn_time/2).
	execute().
	sas on.
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

function get_stage_thrust {
	list engines in engs.
	local force is 0.
	for eng in engs {
		if eng:ignition {
			set force to force + eng:availablethrust.
		}
	}
	return force.
}

function calculate_burn_time {
	local mynodedv is mynode:deltav:mag.
	local g is constant():g0.
	local m0 is ship:mass.
	local F is get_stage_thrust().
	local Isp is get_stage_ISP().
	local e is constant():e.

	return (g*m0*Isp/F) * (1 - e^(-mynodedv/(g*Isp))).



}

function execute {
	wait until time:seconds > mynode:time - burn_time/2 - 30.
	print "burn in 30 sec".
	wait until time:seconds > mynode:time - burn_time/2 - 10.
	print "burn in 10 sec".
	wait until time:seconds > mynode:time - burn_time/2 - 5.
	print "5...".
	wait until time:seconds > mynode:time - burn_time/2 - 4.
	print "4...".
	wait until time:seconds > mynode:time - burn_time/2 - 3.
	print "3...".
	wait until time:seconds > mynode:time - burn_time/2 - 2.
	print "2...".
	wait until time:seconds > mynode:time - burn_time/2 - 1.
	print "1...".
	set burnvec to mynode:deltav:vec.
	wait until time:seconds > mynode:time - burn_time/2.
	print "burn!".
	lock throttle to 1.
	wait until mynode:deltav:mag < 10.
	print "reducing throttle".
	lock throttle to mynode:deltav:mag/10+0.05.
	wait until vang(burnvec, mynode:deltav:vec) > 5.
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	unlock all.
}

function node_assist {
	unlock throttle.
	lock steering to mynode:deltav.
	set burnvec to mynode:deltav:vec.
	until mynode:deltav:mag < 10 {
		needstage().
		wait 0.001.
	}
	lock throttle to mynode:deltav:mag/10.
	until vang(burnvec,mynode:deltav) > 5 {
		needstage.
		wait 0.001.
	}
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	print "press backspace to quit.".
	wait until terminal:input:getchar() = terminal:input:backspace.
}