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

function limit_twr {
    parameter des_twr is 2.
    set weight to ship:mass*ship:body:mu/((ship:body:radius + ship:altitude)^2).
    set twr to get_stage_thrust()/weight.
    list engines in engs.
    for eng in engs {
        if eng:ignition {
            set eng:thrustlimit to des_twr*eng:thrustlimit/twr.
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

function get_time_of_impact {
    local now is time:seconds.
    local body_position is ship:body:position.
    local body_radius is ship:body:radius.
    
    local deltat is 1.
    local future_pos_vec is positionAt(ship, now+deltat).
    local future_geopos is ship:body:geopositionof(future_pos_vec).
    local future_terrain_height is future_geopos:terrainheight.
    local future_altitude is ((future_pos_vec - body_position):mag - body_radius) - future_terrain_height.
    until future_altitude < 0 or deltat > eta:periapsis {
        // clearscreen.
        set deltat to deltat + 1.
        // print "checking T+" + deltat.
        set future_pos_vec to positionAt(ship, now+deltat).
        set future_geopos to ship:body:geopositionof(future_pos_vec).
        // print "lat: " + future_geopos:lat.
        // print "long: " + future_geopos:lng.
        set future_terrain_height to future_geopos:terrainheight.
        // print "future terrain height: " + future_terrain_height.
        set future_altitude to ((future_pos_vec - body_position):mag - body_radius) - future_terrain_height.
        // print "future altitude: " + future_altitude.
    }
    if future_altitude > 0 {
        return now - 1.
    }

    // binary search the deltat
    local first_deltat is deltat-1.
    local second_deltat is deltat+1.
    
    until second_deltat-first_deltat < .001 {
        // clearscreen.
        // print "first_deltat: " + first_deltat.
        // print "second_deltat: " + second_deltat.
        set deltat to (second_deltat+first_deltat)/2.
        // print "checking T+" + deltat.
        set future_pos_vec to positionAt(ship, now+deltat).
        set future_geopos to ship:body:geopositionof(future_pos_vec).
        set future_terrain_height to future_geopos:terrainheight.
        // print "lat: " + future_geopos:lat.
        // print "long: " + future_geopos:lng.
        // print "future terrain height: " + future_terrain_height.
        set future_altitude to ((future_pos_vec - body_position):mag - body_radius) - future_terrain_height.
        // print "future altitude: " + future_altitude.
        if future_altitude > 0 {
            // print "moving forward".
            set first_deltat to deltat.
        } else {
            // print "moving backward".
            set second_deltat to deltat.
        }
        // wait 3.
    }

    return now + deltat. 
}


function time_cancel_speed {
    parameter speed.
    local g is constant():g0.
	local m0 is ship:mass.
    // local sinangle is sin(vang(up:vector,ship:facing:vector)).
    // if sinangle < .03 {
    //     return 0.
    // }
	local F is get_stage_thrust().
	local Isp is get_stage_ISP().
	local e is constant():e.

	return (g*m0*Isp/F) * (1 - e^(-speed/(g*Isp))).
}

function suicide_main {
    sas off.
    lock steering to srfretrograde.
    wait until vang(ship:facing:vector, ship:srfretrograde:vector) < 1.
    print "calculating time to impact (toi)".
    set toi to get_time_of_impact().

    if time:seconds > toi {
        print "no impact time found! cannot perform suicide burn!".
        return.
    }

    set impact_velocity to velocityAt(ship, toi).
    set impact_speed to impact_velocity:surface:mag.
    print "impact speed: " + impact_speed.
    // set ttchs to time_to_cancel_horizontal_speed().
    // set ttcvs to time_to_cancel_vertical_speed(toi - time:seconds).
    // clearScreen.
    // print "toi: " + toi.
    // print "tti: " + (toi - time:seconds).
    // print "horz: " + ttchs.
    // print "vert: " + ttcvs.
    // wait 0.01.
    set suicide_burn_duration to time_cancel_speed(impact_speed).
    print "suicide burn duration: " + suicide_burn_duration.
    set time_of_burn to (toi - time:seconds).
    set time_to_burn to time_of_burn -suicide_burn_duration.
    print "time to burn: " + time_to_burn.

    set last_recalculate_time to time:seconds.

    until time_to_burn < 0 {
        clearScreen.
        // recalculate time of impact every 5 seconds, unless the time to burn is less than 10 seconds away
        if time:seconds - last_recalculate_time > 5 and time_to_burn > 1 {
            print "recalculating toi".
            set toi to get_time_of_impact().
            set last_recalculate_time to time:seconds.
            clearscreen.
        }
        set impact_velocity to velocityAt(ship, toi).
        set impact_speed to impact_velocity:surface:mag.
        print "impact speed: " + impact_speed.
        set suicide_burn_duration to time_cancel_speed(impact_speed).
        print "suicide burn duration: " + suicide_burn_duration.
        set time_of_burn to (toi - time:seconds).
        set time_to_burn to time_of_burn - suicide_burn_duration.
        print "time to burn: " + time_to_burn.
        wait 0.01.
    }
    lock throttle to 1.
    when (vang(up:vector,ship:srfretrograde:vector) < 1) or ((airspeed < 10) and (verticalSpeed < 0)) then {
        lock steering to (up:vector + .5*srfRetrograde:vector).
        set bnd to ship:bounds.
        set steeringManager:rollpid:kp to 0.
        set steeringManager:rollpid:ki to 0.
    }
    until (abs(airspeed) < alt:radar/10 and suicide_burn_duration < 1) or vang(ship:facing:vector, ship:srfretrograde:vector) > 5 {
        clearScreen.
        if time:seconds - last_recalculate_time > 1 and suicide_burn_duration > 1 {
            print "recalculating toi".
            set toi to get_time_of_impact().
            set last_recalculate_time to time:seconds.
            clearscreen.
        }
        set impact_velocity to velocityAt(ship, toi).
        set impact_speed to impact_velocity:surface:mag.
        set suicide_burn_duration to time_cancel_speed(impact_speed).
        print "tti :" + (toi - time:seconds).
        print "suicide burn: " + suicide_burn_duration.
        wait 0.001.
    }
    when alt:radar < 10 then {
        limit_twr().
    }
    gear on.
    lock throttle to touchdown().
    until not (ship:status = "flying" or ship:status = "sub_orbital") {
        clearScreen.
        print "altitude: " + alt:radar.
        print "speed: " + airspeed.
        wait 0.001.
    }
    lock throttle to 0.
    wait 1.
    set ship:control:neutralize to true.
    set ship:control:pilotmainthrottle to 0.
    unlock all.
    sas on.
}

suicide_main().