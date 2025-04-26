parameter desiredapo.
parameter inc is 0.

parameter peri is "none".
parameter pitchingairspeed is 45.

set desiredapo to desiredapo * 1000.
if body:atm:exists {
	if desiredapo < body:atm:height {
		set desiredapo to body:atm:height + 1000.
	}
}

if not (peri = "none") {
	set peri to peri*1000.
	if peri < 0 {
		set peri to desiredapo.
	}
	if body:atm:exists {
		if peri < body:atm:height {
			set peri to body:atm:height + 1000.
		}
	}
} else {
	set peri to desiredapo.
}

set pitchangle to 5.
set timetoapo to 30.
set circtol to 1000.
set currtwr to 1.

main().

function main {
	clearscreen.
	countdown().

	when eta:apoapsis > 25 then {
		when eta:apoapsis < 25 then {
			list engines in engs.
			for eng in engs {
				if eng:ignition {
					set eng:thrustlimit to 100.
				}
			}
		}
	}

	on abort {
		return 1/0.
	}
	set goon to liftoff().
	limit_twr().
	if goon {
		print "we have liftoff.".
		ascention().
		circularization().
	}
	if abs(apoapsis - desiredapo) < 1000 and abs(periapsis - peri) < 1000 {
		save_alt_pitchingairspeed().
	}
}

function save_alt_pitchingairspeed {
	set alt_pitches_path to "archive:/boot/alt_pitches.json".
	if addons:available("RT") {
		set remoteTech to addons:RT.
		if not remoteTech:haskscconnection(ship) {
			// need to warp to where the ksc is...
			print "warping one minute at a time until KSC connection is found.".
			until remoteTech:haskscconnection(ship) {
				kuniverse:timewarp:warpto(time:seconds + 60).
				wait until kuniverse:timewarp:issettled.
				wait until kuniverse:timewarp:rate = 1.
				wait until kuniverse:timewarp:issettled.
			}
		}
	}
	print "in save_apas".
	// wait 1.
	if exists(alt_pitches_path) {
		print "  path found".
		// wait 1.
		set l to readJson(alt_pitches_path).
		if l:haskey(ship:name) {
			print "   " + ship:name + " found in lexicon".
			// wait 1.
			set l[ship:name] to "run orbit("+desiredapo/1000+","+inc+","+peri+","+pitchingairspeed+").".
		} else {
			print "   " + ship:name + " not found in lexicon".
			// wait 1.
			print "   adding to lexicon...".
			// wait 1.
			l:add(ship:name,"run orbit("+desiredapo/1000+","+inc+","+peri+","+pitchingairspeed+").").
		}
		print "  saving lexicon...".
		// wait 1.
		writeJson(l,alt_pitches_path).
	} else {
		print "  path not found. creating lexicon.".
		// wait 1.
		set l to lexicon().
		l:add(ship:name,pitchingairspeed).
		writeJson(l,alt_pitches_path).
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
	if orbit_alt > 100000 {
		set orbit_alt to 100000.
	}

    local shipLat is ship:latitude.
    if abs(inclination) < abs(shipLat) {
        set inclination to shipLat.
    }

    local head is arcsin(cos(inclination) / cos(shipLat)).
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
	set n to engs:length.
	stage.
	list engines in engs.
	if not engs:length = n { return false. } // an engine blew up, and would not be counted below 
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
		list engines in engs.
		if not engs:length = n { return false. }
		print "stage activated".
		wait 0.75.
	}
	return true.
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

function heading_bug {
	set prg_delta to 0.
	if altitude > 36000 {
		set prgrd to prograde:vector.
		if eta:apoapsis < 30 {
			set prg_delta to 30 - eta:apoapsis.
		} else if eta:apoapsis > eta:periapsis {
			set prg_delta to 30.
		}
	} else {
		set prgrd to srfprograde:vector.
	}
	set prograde_pitch to max(pitch_for(prgrd),0) + prg_delta.
	return heading(az, prograde_pitch, -90).
}

function get_stage_thrust {
	list engines in engs.
	local force is 0.
    set slp to 0.
    if ship:body:atm:exists {
        set slp to ship:body:atm:sealevelpressure.
    }
	for eng in engs {
		if eng:ignition {
			set force to force + eng:maxthrustat(slp).
		}
	}
	return force.
}

function limit_twr {
	parameter desiredtwr is 1.34.
    set weight to ship:mass*ship:body:mu/((ship:body:radius + ship:altitude)^2).
	set twr to get_curr_thrust()/weight.
	print "old twr: " + twr.
    set twr to get_stage_thrust()/weight.
	
    list engines in engs.
    for eng in engs {
        if eng:ignition {
            set eng:thrustlimit to desiredtwr*100/twr.
        }
    }
	wait 0.01.
	set twr to get_curr_thrust()/weight.
	print "new twr: " + twr.
}

function ascention {
	until airspeed > pitchingairspeed {
		needstage().
		wait 0.001.
	}
	// clearscreen.
	print "pitching airspeed achieved.".
	print "beginning pitching maneuver.".

	pitch().
	// clearscreen.
	print "pitching angle achieved. locking to prograde.".
	lock steering to heading_bug().

	set Kp to 1.
	set Ki to 0.01.
	set Kd to 0.1.
	set min_thrott to 0.07.
	set max_thrott to 1.0.
	set throttpid to pidloop(Kp, Ki, Kd, min_thrott, max_thrott).

	set throttpid:setpoint to 60.
	set mythrot to 1.0.
	lock throttle to mythrot.

	until altitude > 50000 {
		needstage().
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		if pitch_for() < 0 {
			toggle abort.
		}
		wait 0.001.
	}
	print "staging fairing on AG10.".
	toggle ag10. // will stage the fairing
	until ship:dynamicpressure = 0 or apoapsis > desiredapo{
		needstage().
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}

	until apoapsis > desiredapo {
		// set stagenum to stage:number.
		needstage().
		set mythrot to max(throttpid:update(time:seconds, eta:apoapsis),mythrot).
		if pitch_for() < 0 {
			force_exept().
		}
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
		if (eng:flameout or stage:deltav:current = 0.0) and stage:ready {
			stage.
			// for eng in engs {
			// 	if eng:ignition {
			// 		set eng:thrustlimit to 100.
			// 	}
			// }
			wait until stage:ready.
			check_eng_failure().
			until stage:deltav:current > 0 {
				wait until stage:ready.
				stage.
			}
			print "actual current twr: " + currtwr.
			limit_twr(currtwr*1.01).
			return.
		}
	}
	local currthrust to get_curr_thrust().
	if (currthrust < 0.001) or (stage:deltav:current < 10) {return.}
	local weight to ship:mass*ship:body:mu/((ship:body:radius + ship:altitude)^2).
	set currtwr to currthrust/weight.
	clearscreen.
	print "current twr: " + currtwr.
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
	print "self-destructing...".
	wait .5.
	set goodbye to 1/0.
}

function circ_apo {
	// TODO: make this more robust (the normal component seems to break when the node is on the opposite side of the planet)
	local apo_time is eta:apoapsis.
    set circnode to node(timespan(apo_time), 0 ,0, 0).
	set r1 to periapsis + body:radius.
	set r2 to apoapsis + body:radius.
	if not (peri = "none") {
		set r3 to peri+body:radius.
		set circnode:prograde to sqrt(body:mu/r2)*(1-sqrt(2*r1/(r1+r2))) - sqrt(body:mu/r2)*(1-sqrt(2*r3/(r3+r2))). // needs to include the desired periapsis
	} else { 
		set circnode:prograde to sqrt(body:mu/r2)*(1-sqrt(2*r1/(r1+r2))).
	}
	add circnode.
}

function circularization {
	print "waiting for circularization.".
	// kuniverse:timewarp:warpto(time:seconds + eta:apoapsis - 60).
	wait until ship:dynamicpressure = 0.
	until apoapsis > desiredapo {
		needstage().
		set mythrot to throttpid:update(time:seconds, eta:apoapsis).
		wait 0.001.
	}
	lock throttle to 0.
	circ_apo().
	print "deploying deployables.".
	toggle lights.
	wait 1.
	toggle ag9. // deploying all deployables
	wait 3.
	toggle ag8.
	wait 1.
	print "beginning circularization.".
	set nodedv to nextNode:burnvector:mag.
	// until stage:deltav:current > nodedv/10 or stage:number = 0 {
	// 	wait until stage:ready.
	// 	stage.
	// }
	if stage:deltav:current < nodedv {
		print "current stage cannot perform maneuver".
		set n to stage:number-1.
		print "checking stage " + n.
		until ship:stagedeltav(n):current > 0  or n = 0 {
			print "stage " + n + "has 0 dv".
			set n to n - 1.
			print "checking stage " + n.
		}
		if ship:stagedeltav(n):current > 0 {
			print "stage " + n + "has positive dv".
		} else {
			print "stage 0 reached with 0 dv".
		}
		if ship:stagedeltav(n):current >= nodedv {
			stage.
			until stage:deltav:current > 0 {
				wait until stage:ready.
				stage.
			}
		} else {
			print "next stage with positive dv cannot perform burn".
		}
	}
	runPath("reaper","w").
}