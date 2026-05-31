set bnd to ship:bounds.
set do_landing to False.
ps_main().

function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			return wp.
		}
	}
	return false.
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
			set force to force + eng:possiblethrustat(slp).
		}
	}
	return force.
}

function burn_height {
    // TODO: change to use trajectories (if available) and find the impact speed.

    local radial_height is altitude+body:radius.
    local gravity is ship:mass*body:mu/(radial_height^2).
    local drag is addons:far:aeroforce:mag.
    // local alpha is drag/(airspeed^2).
    // local alpha1 is addons:far:cd.
    // print (alpha - alpha1).
    // print gravity.
    // return 1/0.
    // if not exists("drag.csv") {
    //     create("drag.csv").
    // }
    // log airspeed+","+drag to drag.csv.
    // local thrust is get_stage_thrust().
    // print "thrust" + thrust.
    if vang(up:vector,ship:facing:vector) > 60 {
        return alt:radar.
    }
    set currthrust to get_stage_thrust()*cos(vang(up:vector,ship:facing:vector)).
    set currthrust to max(currthrust,0).
    local height is verticalSpeed^2*ship:mass/(2*(currthrust + drag/4 - gravity)).
    // print "est. dist. to burn: " + (bnd:bottomaltradar-height).
    return bnd:bottomaltradar - height.
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
    // redo this
    set radaralt to max(bnd:bottomaltradar,0).
    set northvec to heading(0,0):vector:normalized.
    set eastvec to heading(90,0):vector:normalized.
    set wp_vec to ship:position - wp:position.
    set ground_proj_vec to vDot(wpvec,northvec)*northvec + vDot(wpvec,eastvec)*eastvec.
    set ground_dist to ground_proj_vec:mag.
    // print vectowp:mag.
    if ground_dist < 5 or ship:deltav:current < 300 {
        set do_landing to true.
    } else {
        set do_landing to false.
    }
    if not do_landing or groundspeed > 1 {
        set radaralt to radaralt - 50.
    }


    if radaralt < 0 {
        set radaralt to 0.
    }
    // print radaralt.
    // print verticalSpeed.
	return max((-verticalSpeed-1-(radaralt/10)),.01).
}

function ps_main {
    if not addons:tr:available {
        print "trajectories not found.".
        wait 1.
        runpath("suicide.ks").
        return.
    }
    set wp to has_waypoint().
    if not wp:istype("waypoint") {
        print "wp not active, setting wp to KSC.".
        // wait .5.
        set wp to waypoint("KSC").
    }

    if not addons:tr:hastarget {
        print "target not found, setting target to wp.".
        // wait .5.
        addons:tr:settarget(wp:geoposition).
    }

    // for n in ship:suffixnames {
    //     print n.
    //     wait .5.
    // }

    
    if ship:status = "prelaunch" {
        print "in prelaunch, running test.".
        wait .5.
        sas off.
        lock steering to up.
        lock throttle to 1.
        stage.
        print "liftoff.".
        wait until airspeed > 10.
        wait until eta:apoapsis > 60.
        wait until apoapsis > 75000.
    }
    lock throttle to 0.
    print "waiting until vertical speed < 0".
    wait until verticalSpeed < 0.
    sas off.
    kuniverse:timewarp:cancelwarp().
    toggle ag9.
    // lock steering to addons:tr:correctedvec.
    // TODO: make it so I don't go more than 45 degrees away from retrograde.
    // set steeringManager:rollpid:kp to 0.
    // set steeringManager:rollpid:ki to 0.

    lock wpvec to ship:position - wp:position.
    lock northvec to heading(0,0):vector:normalized.
    lock eastvec to heading(90,0):vector:normalized.
    lock ground_proj_vec to vDot(wpvec,northvec)*northvec + vDot(wpvec,eastvec)*eastvec.
    lock ground_vel_vec to ground_proj_vec*vDot(ship:velocity:surface,ground_proj_vec)/ground_proj_vec:sqrmagnitude.
    lock ground_dist to ground_proj_vec:mag.

    // TODO: set up PIDloop to control the pitch rate, with a high KD term
    // also, instead of trying to get over the waypoint as fast as possible,
    // instead try to get over the waypoint when our est. dist. to burn (edb) is 1000
    set max_angle_diff to 30.

    set fall_pitchkp to .001.
    set fall_pitchki to 0.
    set fall_pitchkd to 1.
    set fall_pitch_max to 30.
    set fall_pitch_min to 0.
    set fall_pitch_pid to pidLoop(fall_pitchkp, fall_pitchki, fall_pitchkd, fall_pitch_max, fall_pitch_min).
    set edb to burn_height().
    set brakes_alt to 70000.

    function fall_w_style {
        // get angle to waypoint
        local est_dist_to_airbrake to edb - brakes_alt.
        local est_time_to_airbrake to abs(est_dist_to_airbrake/verticalSpeed).
        local needed_horiz_speed to ground_dist/est_time_to_airbrake.
        local gs to ground_vel_vec:mag.
        if vdot(ground_vel_vec,ground_proj_vec) < 0 { // somehow this is flipping the calculations when it shouldn't be
            set gs to -1*gs.
        }
        // print "needed_horiz_speed:" + needed_horiz_speed.
        // print "actual relative groundspeed: " + gs.
        // print "error: " + (needed_horiz_speed - gs).
        local pitch_correct to fall_pitch_pid:update(time:seconds,needed_horiz_speed-gs).
        if abs(pitch_correct) > 15 {
            set pitch_correct to 15*pitch_correct/abs(pitch_correct).
        }
        return heading(wp:geoPosition:heading,90+pitch_correct).
    }
    lock steering to fall_w_style().
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.

    

    lock tti to -bnd:bottomaltradar/verticalSpeed.
    set edb to burn_height().
    until edb < brakes_alt {
        print "est. dist to burn: " + edb.
        print "est. time to impact: " + tti.
        print "ground_dist: " + ground_dist.
        wait 0.001.
        set edb to burn_height().
        clearscreen.
    }
    brakes on.
    until alt:radar < 5000 {
        print "est. dist to burn: " + edb.
        print "est. time to impact: " + tti.
        print "ground_dist: " + ground_dist.
        wait 0.001.
        set edb to burn_height().
        clearscreen.
    }
    until verticalSpeed < 0 and edb - .002*verticalSpeed < 0{
        print "est. dist to burn: " + edb.
        print "est. time to impact: " + tti.
        wait 0.001.
        set edb to burn_height().
        clearscreen.
    }
    set bnd to ship:bounds.
    lock steering to up.
    lock throttle to 1.
    until verticalSpeed > -1*alt:radar/50 {
        clearScreen.
        print "est. time to impact: " + tti.
        wait 0.001.
        if stage:deltav:current <= 0.0 and stage:ready and stage:number > 0 {
            stage.
        }
    }
    when stage:deltav:current <= 0.0 and stage:ready and stage:number > 0 then{
        stage.
        limit_twr().
        return true.
    }
    gear on.
    limit_twr().

    set steeringManager:rollpid:kp to 0.
    set steeringManager:rollpid:ki to 0.
    // set steeringManager:rollpid:kd to 0.

    set pitchkp to 1.
    set pitchki to 0.
    set pitchkd to 1.
    set pitchmax to 15.
    set pitchmin to -15.
    set pitchloop to pidloop(pitchkp,pitchki,pitchkd,pitchmin,pitchmax).

    set sideslipkp to 1.
    set sideslipki to 0.
    set sideslipkd to 1.
    set sideslipmin to -5.
    set sideslipmax to 5.
    set sidesliploop to pidloop(sideslipkp,sideslipki,sideslipkd,sideslipmin,sideslipmax).

    
    lock wpang to vang(up:vector, wpvec).
    // lock unitwpvec to wpvec/wpang.
    lock starboardvec to vcrs(wpvec,up:vector).
    lock unitstarboardvec to starboardvec/starboardvec:mag.
    lock sideslipvec to unitstarboardvec*vdot(unitstarboardvec,ship:velocity:surface).
    // lock forwardvec to unitwpvec*vdot(unitwpvec,ship:velocity:surface).
    set pitchsetpoint to 0.

    
    


    until not (ship:status = "flying") {

        set radaralt to max(bnd:bottomaltradar,0).

        if ground_dist > 10 or groundspeed > 1 {
            set radaralt to radaralt - 50.
        } else if radaralt < 0 {
            set radaralt to 0.
        }
        if stage:deltav:current < 300 and groundspeed < 1 {
            set radaralt to 0.
        }
        // if groundspeed > 50 {
        //     set pitch_setpoint to 0.
        // }

        lock throttle to max((-verticalSpeed-1-(radaralt/10)),.01).

        if ground_dist > 1000 {
            set pitchsetpoint to min(50,ground_dist/5).
        } else if ground_dist > 50 {
            set pitchsetpoint to ground_dist/15.
        } else if ground_dist > 10 {
            set pitchsetpoint to ground_dist/15.
        } else {
            set pitchsetpoint to 0.
        }
        if ship:deltav:current < 300 {
            set pitchsetpoint to 0.
        }
        set wpapproachspeed to groundspeed.
        if vdot(wpvec, ship:velocity:surface) > 0 {
            set wpapproachspeed to -wpapproachspeed.
        }
        set pitch to pitchloop:update(time:seconds, wpapproachspeed - pitchsetpoint).
        set pitch to 90 - pitch.
        set sideslip to sideslipvec:mag.
        if vdot(sideslipvec, unitstarboardvec) < 0 {
            set sideslip to -sideslip.
        }
        lock steering to angleAxis(sidesliploop:update(time:seconds,sideslip),wpvec)*heading(wp:geoposition:heading, pitch).
        clearScreen.
        // print "est. time to impact: " + tti.
        print "grounddist: " + ground_dist.
        print "desspeed: " + pitchsetpoint.
        print "groundspeed: " + groundspeed.
        print "pitch: " + pitch.
        // print "pitcherr: " + pitchloop:error.
        wait 0.001.
    }
    // print "landed because " + reason.
    lock throttle to 0.
    lock steering to up.
    wait 1.
    set ship:control:neutralize to true.
    set ship:control:pilotmainthrottle to 0.
    unlock all.
    brakes off.
    sas on.
    wait 1.
    sas off.
}