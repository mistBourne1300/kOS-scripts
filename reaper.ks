// will execute the next maneuver node
// it cannot handle staging events, as the burn time calculation is too difficult.
parameter dowarp is "n".

reaper_main().

function reaper_main {
	print "performing quicksave.".
	if kuniverse:canquicksave{
		kuniverse:quicksave().
	} else {
		print "quicksaving failed.".
	}
	sas off.
	if not hasnode {
		print "this vessel has no node to execute.".
		return.
	}
	set mynode to nextnode.
	set burn_time to calculate_burn_time().
	set start_burn_at to 0.
	if stage:deltav:current < mynode:deltav:mag {
		print "cannot perform maneuver on current stage".
		print "you'll have to control the throttle yourself".
		print "we will stage for you, as well as stop the throttle.".
		print "burn time: ~" + burn_time.
		node_assist().
		return.
	} else {
		print "burn time: " + burn_time.

	}
	
	if dowarp = "w" {
		if mynode:time - 600 - burn_time/2 > time:seconds {
			kuniverse:timewarp:warpto(mynode:time - 600 - burn_time/2).
			wait until kuniverse:timewarp:issettled.
			wait until kuniverse:timewarp:rate = 1.
			wait until kuniverse:timewarp:issettled.
		}
	}
	lock steering to mynode:deltav.
	print "steering to burn vector".
	wait until (vang(ship:facing:vector, mynode:deltav) < 1) and ((ship:angularvel:mag < 0.005) or (mynode:time - 10 - burn_time/2 > time:seconds)).
	if dowarp = "w" {
		if mynode:time - 300 - burn_time/2 > time:seconds {
			kuniverse:timewarp:warpto(mynode:time - 300 - burn_time/2).
			wait until kuniverse:timewarp:issettled.
			wait until kuniverse:timewarp:rate = 1.
			wait until kuniverse:timewarp:issettled.
			wait until (vang(ship:facing:vector, mynode:deltav) < 1) and ((ship:angularvel:mag < 0.005) or (mynode:time - 60 - burn_time/2 > time:seconds)).
			wait 1.
		}

		if mynode:time - 60 - burn_time/2 > time:seconds {
			kuniverse:timewarp:warpto(mynode:time - 60 - burn_time/2).
			wait until kuniverse:timewarp:issettled.
			wait until kuniverse:timewarp:rate = 1.
			wait until kuniverse:timewarp:issettled.
			wait until (vang(ship:facing:vector, mynode:deltav) < 1) and ((ship:angularvel:mag < 0.005) or (mynode:time - 10 - burn_time/2 > time:seconds)).
			wait 1.
		}
		
		if mynode:time - 10 - burn_time/2 > time:seconds {
			kuniverse:timewarp:warpto(mynode:time - 10 - burn_time/2).
			wait until kuniverse:timewarp:issettled.
			wait until kuniverse:timewarp:rate = 1.
			wait until kuniverse:timewarp:issettled.
			wait until (vang(ship:facing:vector, mynode:deltav) < 1).
		}
	}
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

function get_stage_thrust_reaper {
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
	local F is get_stage_thrust_reaper().
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
	// set start to time:seconds.
	// set reduce_throttle_at to 1.
	set remaining_burn to calculate_burn_time().
	until remaining_burn < 1{
		set remaining_burn to calculate_burn_time().
		clearScreen.
		print "remaining burn: " + remaining_burn.
		wait 0.01.
	}
	print "reducing throttle".
	// set change_variables to time:seconds.
	// lock throttle to (-0.9/reduce_throttle_at)*(time:seconds - change_variables) + 1.
	// wait until time:seconds - change_variables > reduce_throttle_at.
	// set checkanglevec to mynode:deltav:vec.
	// lock throttle to mynode:deltav:mag/burnvec:mag+0.1.
	lock throttle to calculate_burn_time() + 0.1.
	print "finalizing burn".
	wait until vang(ship:facing:forevector, mynode:deltav:vec) > 10 and mynode:deltav:mag < 10.
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	unlock all.
}

function node_assist {
	lock steering to mynode:deltav.
	unlock throttle.
	
	until mynode:deltav:mag < 10 {
		needstage().
		wait 0.001.
	}
	set burnvec to mynode:deltav:vec.
	lock throttle to mynode:deltav:mag/10 + .001.
	until vang(burnvec,mynode:deltav) > 5 {
		needstage.
		wait 0.001.
	}
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
}

function needstage {
	list engines in engs.
	for eng in engs {
		if (eng:flameout or stage:deltav:current = 0.0) and stage:ready {
			set num_parts to ship:parts:length.
			stage.
			wait until stage:ready.
			wait 0.1.
			if ship:parts:length < num_parts {
				check_eng_failure().
			}	
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
	// wait 1.
	print "it doesn't know how to handle.".
	// wait 1.
	print "(likely a high-altitude engine failure).".
	// wait 1.
	print "switching to manual control".
	unlock steering.
	sas on.
	// wait 1.
	print "this script is now self-destructing.".
	// wait 10.
	set goodbye to 1/0.
	print goodbye.
}