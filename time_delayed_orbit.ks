parameter desiredapo.
parameter pitchingairspeed.
set desiredapo to desiredapo * 1000.

set pitchangle to 5.
// set pitchingairspeed to 50.
set timetoapo to 30.
set circtol to 1000.
set timedelay to 20.

main().

function main {
	clearscreen.
	countdown().
	liftoff().
	print "we have liftoff.".
	ascention().
	circularization().
}
	
function countdown {
	lock throttle to 1.
	print "T minus".
	from {local count is 10.} until count = 0 step {set count to count - 1.} do {
		print "..." + count.
		wait 1.
	}
}

function liftoff {
	until maxthrust > 0 {
		wait 0.1.
		print "stage activated.".
		stage.
	}
	lock steering to up + r(0,0,180).
}

function angle {
	// print arctan((desiredapo - altitude)/100000).
	return 1.432*10^(-25)*(altitude^6) - 2.549*10^(-20)*(altitude^5) + 1.725*10^(-15)*(altitude^4) - 5.840*10^(-11)*(altitude^3) + 1.083*10^(-6)*(altitude^2) - 1.149*10^(-2)*(altitude) + 9.680*10.
}

function twr {
	// calculates the desired twr for each stage of the ascenct.
	// until apoapsis is greater than 30 sec away, it is 1.
	// from there, we want to keep it just under a minute away (~45 sec)
	// once apoapsis reaches it's desired height, this function is never called again

}

function get_weight {
	return body:mu*ship:mass/(body:radius^2).
}

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

function ascention {
	wait until airspeed > pitchingairspeed.
	clearscreen.
	print "pitching airspeed achieved.".
	print "beginning pitching maneuver.".

	pitch().
	clearscreen.
	print "pitching angle achieved. locking to prograde.".
	lock steering to srfprograde + r(0,0,-90).

	// if exists("0:/altlog.csv"){
	// 	deletepath("0:/altlog.csv").
	// 	create("0:/altlog.csv").
	// 	log "time,altitude,airspeed,angle" to "0:/altlog.csv".
	// } else {
	// 	create("0:/altlog.csv").
	// 	log "time,altitude,airspeed,angle" to "0:/altlog.csv".
	// }
	// lock steering to heading(90,angle()) + r(0,0,-90).
	
	set updates to queue().
	set start to time:seconds.
	
	// lock throttle to control_throttle().
	set Kp to 0.1.
	set Ki to 0.1.
	set Kd to 0.1.
	set min_thrott to 0.001.
	set max_thrott to 1.0.
	set throttpid to pidloop(Kp, Ki, Kd, min_thrott, max_thrott).

	set throttpid:setpoint to 60.
	set mythrott to 1.0.
	lock throttle to mythrott.

	until time:seconds-start > timedelay or altitude > 40000{
		needstage().
		updates:push(throttpid:update(time:seconds, eta:apoapsis)).
		wait 0.001.
	}
	
	// lock prevthrust to needstage(prevthrust).
	until altitude > 40000 {
		needstage().
		set newthrott to throttpid:update(time:seconds, eta:apoapsis).
		updates:push(newthrott).
		clearscreen.
		print "desired:" + newthrott.
		print "actual: " + updates:peek().
		set mythrott to updates:pop().
		wait 0.001.
	}
	lock steering to prograde + r(0,0,-90).
	until apoapsis > desiredapo {
		needstage().
		set newthrott to throttpid:update(time:seconds, eta:apoapsis).
		updates:push(newthrott).
		clearscreen.
		print "desired:" + newthrott.
		print "actual: " + updates:peek().
		set mythrott to updates:pop().
		wait 0.001.
	}
	lock throttle to 0.
	lock steering to prograde + r(0,0,-90).
	// clearscreen.
	print "MECO".
}
	
	

function pitch {
	lock steering to heading(90, 90-pitchangle/5) + r(0,0,-90).
	wait 1.
	lock steering to heading(90, 90-pitchangle*2/5) + r(0,0,-90).
	wait 1.
	lock steering to heading(90, 90-pitchangle*3/5) + r(0,0,-90).
	wait 1.
	lock steering to heading(90, 90-pitchangle*4/5) + r(0,0,-90).
	wait 1.
	lock steering to heading(90, 90-pitchangle) + r(0,0,-90).
	wait 10.
}

function needstage {
	list engines in engs.
	for eng in engs {
		if eng:flameout and stage:ready {
			stage.
		}
	}
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

function circularization {
	// TODO: fix this to work with kerbalism
	print "waiting for circularization.".
	// kuniverse:timewarp:warpto(time:seconds + eta:apoapsis - 60).
	lock steering to prograde + r(0,0,-90).
	wait until eta:apoapsis < 35.
	print "beginning circularization.".
	set Kp to 0.1.
	set Ki to 0.5.
	set Kd to 0.1.
	set min_thrott to 0.001.
	set max_thrott to 1.0.
	set throttpid to pidloop(Kp, Ki, Kd, min_thrott, max_thrott).

	set throttpid:setpoint to timetoapo.
	set mythrott to min_thrott.


	lock throttle to mythrott.
	lock steering to prograde + r(0,0,-90).

	set updates to queue().
	set start to time:seconds.
	until time:seconds-start > timedelay or periapsis > 0{
		needstage().
		updates:push(throttpid:update(time:seconds, eta:apoapsis)).
	}

	until periapsis > 0{
		needstage().
		set newthrott to throttpid:update(time:seconds, eta:apoapsis).
		updates:push(newthrott).
		clearscreen.
		print "desired:" + newthrott.
		print "actual: " + updates:peek().
		set mythrott to updates:pop().
		wait 0.001.
	}

	lock timetoapo to (-10/desiredapo)*(periapsis) + 10.
	lock throttle to circthrottle().
	wait until (apoapsis - periapsis) < circtol or (periapsis > 70000 and (apoapsis - desiredapo) > 10*circtol).
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	// until (apoapsis - periapsis) < circtol or periapsis > desiredapo{
	// 	set tminus to eta:apoapsis.
	// 	set etaperi to eta:periapsis.
		
	// 	// throttle control based on time to apoapsis
	// 	// TODO: once periapsis is positive, we can start allowing ourselves to move closer to apoapsis node. 

	// 	if tminus > etaperi{
	// 		lock throttle to 1.
	// 	} else if tminus < timetoapo {
	// 		lock throttle to (timetoapo - tminus)/timetoapo + 0.01.
	// 	} else {
	// 		lock throttle to 0.01.
	// 	}

	// 	// pitch control based on apoapsis
	// 	set dpitch to (desiredapo - apoapsis)/1000.
	// 	if dpitch > 10 {
	// 		set dpitch to 10.
	// 	} else if dpitch < 0 {
	// 		set dpitch to dpitch * 5.
	// 	}
	// 	if dpitch < -10{
	// 		set dpitch to 0.
	// 	}
	// 	if tminus > etaperi {
	// 		set dpitch to abs(dpitch).
	// 	}
	// 	lock steering to heading(90,0) + r(0,dpitch,0).

	// 	// stage if necessary
	// 	needstage().
	// }
}