set bnd to ship:bounds.


function has_parachutes {
    if not ship:body:atm:exists {
        return -1. // parachutes won't help here
    }
    set minalt to 10000.
    for p in ship:partsdubbedpattern("chute") {
        if p:name:contains("drogue") {
            set minalt to min(minalt,2500).
        } else {
            set minalt to min(minalt,1000).
        }
    }
    return minalt.
}
set chute_min_alt to has_parachutes().

vertical_suicide_main().

function get_stage_thrust {
	list engines in engs.
	local force is 0.
    set slp to 0.
    if ship:body:atm:exists {
        set slp to ship:body:atm:sealevelpressure.
    }
	for eng in engs {
		if eng:ignition {
			set force to force + eng:possiblethrustat(slp).
		}
	}
	return force.
}

function burn_height {
    if chute_min_alt = 1000 {
        return 50.
    }
    if chute_min_alt = 2500 {
        return 500.
    }
    local radial_height is altitude+body:radius.
    local gravity is ship:mass*body:mu/(radial_height^2).
    local drag is addons:far:aeroforce:mag.

    set currthrust to get_stage_thrust()*cos(vang(up:vector,ship:facing:vector)).
    set currthrust to max(currthrust,0).
    local height is verticalSpeed^2*ship:mass/(2*(currthrust + drag/4 - gravity)).
    // print "est. dist. to burn: " + (bnd:bottomaltradar-height).
    return height.
}

function limit_twr {
    set weight to ship:mass*ship:body:mu/((ship:body:radius + ship:altitude)^2).
    set twr to get_stage_thrust()/weight.
    list engines in engs.
    for eng in engs {
        if eng:ignition {
            set eng:thrustlimit to 2*eng:thrustlimit/twr.
        }
    }
    
}

function touchdown {
	if bnd:bottomaltradar/10 > airspeed {
		return 0.01.
	}
    set radaralt to bnd:bottomaltradar.
    if radaralt < 0 {
        set radaralt to 0.
    }
	return (airspeed-1-(bnd:bottomaltradar/10)).
}

function unlock_all_tanks {
    for p in ship:parts {
        for r in p:resources {
            if r:TOGGLEABLE {
                set r:enabled to true.
            }
        }
    }
}

function vertical_suicide_main {

    // for n in ship:suffixnames {
    //     print n.
    //     wait .5.
    // }
    sas off.
    lock steering to srfretrograde.
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.

    unlock_all_tanks().

    wait until altitude < 10000.

    when stage:deltav:current <= 0.0 and stage:ready and stage:number > 0 then{
        stage.
        return true.
    }

    when (vang(up:vector,ship:srfretrograde:vector) < 1) or ((verticalspeed > -10) and (verticalSpeed < 0)) then {
        lock steering to (up:vector + .5*srfRetrograde:vector).
        set bnd to ship:bounds.
        set steeringManager:rollpid:kp to 0.
        set steeringManager:rollpid:ki to 0.
    }

    lock tti to -bnd:bottomaltradar/verticalSpeed.
    // lock burn_height to burn_height().
    until verticalSpeed < 0 {
        print "est. time to impact: " + tti.
        wait 0.001.
        clearscreen.
    }

    until (bnd:bottomaltradar < burn_height() - .001*verticalSpeed) or (bnd:bottomalt < burn_height() - 0.001*verticalSpeed) {
        print "est. time to impact: " + tti.
        print "bnd:bottomaltradar: " + bnd:bottomaltradar.
        print "bnd:bottomalt: " + bnd:bottomalt.
        print "burn_height: " + burn_height().
        wait 0.001.
        clearscreen.
    }
    lock throttle to 1.
    until abs(verticalSpeed) < alt:radar/10 {
        clearScreen.
        print "est. time to impact: " + tti.
        wait 0.001.
    }
    gear on.
    limit_twr().
    lock throttle to touchdown().
    until not (ship:status = "flying") {
        clearScreen.
        print "est. time to impact: " + tti.
        wait 0.001.
    }
    lock throttle to 0.
    wait 1.
    set ship:control:neutralize to true.
    set ship:control:pilotmainthrottle to 0.
    unlock all.
    sas on.
}