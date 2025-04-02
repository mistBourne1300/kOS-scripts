set KM to 1000.
set PROJECTION_TIME to 5.

main().

function get_time_to_alt {
    parameter desalt.
    if desalt > altitude {
        print "already below " + desalt.
        return time:seconds.
    }
    set pred_alt to 0.
    set pred_time to time:seconds + eta:periapsis.
    print "getting time to " + desalt + " m altitude...".
    until pred_alt > desalt {
        set pred_time to pred_time - 1.
        set ship_pred_pos to positionAt(ship,pred_time).
        // for some reason, the shi:body:positon below 
        // does not need to be predicted into the future, and I have no idea why
        // read this github thread to see: 
        //  https://github.com/KSP-KOS/KOS/issues/1304
        set pred_alt to (ship_pred_pos - ship:body:position):mag - ship:body:radius.
        // clearScreen.

        // print "eta: " + (pred_time - time:seconds) + " (" + pred_alt + ")".
        // wait 0.001.
    }
    print "eta: " + (pred_time - time:seconds) + " (" + pred_alt + ")".

    return pred_time.
}

function all_parachutes_fully_deployed {
    // TODO: check whether all parachutes are fully deployed.
    return get_next_parachute_full_deploy_altitude() = 0 and get_next_parachute_half_deploy_pressure() = ship:body:atm:sealevelpressure.
}

function get_next_parachute_half_deploy_pressure {
    // TODO: actually make this check the deployment pressure
    // returs sea level pressure if all parachutes are half deployed
    local minpressure is ship:body:atm:sealevelpressure.
    local currpressure is ship:body:atm:altitudepressure(altitude).
    for p in ship:parts {
        if p:hasmodule("realchutefar") {
            local far to p:getmodule("realchutefar").
            if far:hasfield("min pressure") {
                local mp to far:getfield("min pressure").
                if mp > currpressure and mp < minpressure {
                    set minpressure to mp. 
                }
            }
        }
    }
    // for p in ship:partsdubbedpattern("chute") {
    //     // if the deployment pressure is greater than the current pressure
    //     // and it is less than the minimum deploy pressure so far
    //     if p:getmodule("realchutefar"):getfield("min pressure") > currpressure and p:getmodule("realchutefar"):getfield("min pressure") < minpressure {
    //         set minpressure to p:getmodule("realchutefar"):getfield("min pressure").
    //     }
    // }
    // for p in ship:partsdubbedpattern("drogue") {
    //     // if the deployment pressure is greater than the current pressure
    //     // and it is less than the minimum deploy pressure so far
    //     if p:getmodule("realchutefar"):getfield("min pressure") > currpressure and p:getmodule("realchutefar"):getfield("min pressure") < minpressure {
    //         set minpressure to p:getmodule("realchutefar"):getfield("min pressure").
    //     }
    // }
    // print "next pressure deploy: " + minpressure.
    return minpressure.
}

function get_next_parachute_full_deploy_altitude {
    // TODO: actually check the next full deployment altitude
    // returns 0 if all parachutes are fully deployed.
    local deploy_alt is 0.
    local curralt is alt:radar.
    // for p in ship:parts {
    //     if p:hasmodule("realchutefar"){
    //         local far to p:getmodule("realchutefar").
    //         if far:hasfield("altitude"){
    //             local a to far:getfield("altitude").
    //             if a < curralt and a > deployalt {
    //                 set deploy_alt to a.
    //             }
    //         }
    //     }
    // }
    for p in ship:partsdubbedpattern("chute") {
        // if deployment altitude is less then the current altitude, 
        // and if it is greater than the maximum deploy altitude so far...
        // if p:getmodule("realchutefar"):getfield("altitude") < curralt and p:getmodule("realchutefar"):getfield("altitude") > deploy_alt {
        //     set deploy_alt to p:getmodule("realchutefar"):getfield("altitude").
        // }
        if curralt > 1000 {
            set deploy_alt to 1000.
            break.
        }
    }
    for p in ship:partsdubbedpattern("drogue") {
        // if deployment altitude is less then the current altitude, 
        // and if it is greater than the maximum deploy altitude so far...
        // if p:getmodule("realchutefar"):getfield("altitude") < curralt and p:getmodule("realchutefar"):getfield("altitude") > deploy_alt {
        //     set deploy_alt to p:getmodule("realchutefar"):getfield("altitude").
        // }
        if curralt > 2500 {
            set deploy_alt to 2500.
            break.
        }
    }
    // print "next altitude deployment: " + deploy_alt.
    return deploy_alt.
}

function wait_until_pressure_deployment {
    local parameter pressure.
    print "waiting for half parachute deployment.".
    wait until ship:body:atm:altitudepressure(altitude) > pressure.
    wait 8.
    print "parachutes deployed. warping".
}

function wait_until_full_parachute_deployment {
    local parameter deploy_alt.
    print "waiting for full parachute deployment at " + deploy_alt.
    wait until alt:radar < deploy_alt.
    wait 8. // wait 5 seconds after parachute deployment to actually return to warp.
    print "parachutes deployed. warping".
}

function main {
    clearScreen.

    if not ship:body:atm:exists {
        print "cannot rely on parachutes for non-atmospheric bodies".
        return.
    }

    if periapsis > ship:body:atm:height {
        print "periapsis not in atmosphere, quitting program".
        return.
    }
    sas off.

    
    

    set warp_alt_list to list(ship:body:atm:height + 100*KM, ship:body:atm:height + 30*KM).
    set pred_time to time:seconds.
    for walt in warp_alt_list {
        if altitude > walt {
            if stage:number > 0 {
                print "locking to normal vector".
                lock steering to vcrs(prograde:vector,up:vector).
                wait until vang(ship:facing:vector,vcrs(prograde:vector,up:vector)) < 1.
            }

            set pred_time to get_time_to_alt(walt).
            kuniverse:timewarp:warpto(pred_time).
            wait until kuniverse:timewarp:rate = 1.
            wait until kuniverse:timewarp:issettled.
            wait 1.
        }
    }
    

    

    
    // return.

    wait until kuniverse:timewarp:rate = 1.
    wait until kuniverse:timewarp:issettled.
    if pred_time - time:seconds > 120 {
        print "something stopped the warp early".
        print "you should go deal with that.".
        return.
    }


    wait 1.
    print "staging".
    until stage:number = 0 {if stage:ready{stage.} wait 1.}
    print "locking to retrograde".

    lock steering to srfretrograde.
    wait until vang(ship:facing:vector, srfRetrograde:vector) < 1.
    print "warping to atmosphere".
    kuniverse:timewarp:warpto(get_time_to_alt(ship:body:atm:height + 1*KM)).
	
	wait until altitude < ship:body:atm:height.
	print "entered atmosphere. prepare for physics warp.".
    wait until vang(ship:facing:vector, srfretrograde:vector)<5.
	set kuniverse:timewarp:mode to "physics".
    set kuniverse:timewarp:rate to 4.


    set next_parachute_half_deploy_pressure to get_next_parachute_half_deploy_pressure().
    set next_parachute_full_deploy_altitude to get_next_parachute_full_deploy_altitude().

    set old_pressure to ship:body:atm:altitudepressure(altitude).
    set old_time to time:seconds.
    wait 0.001.

    until all_parachutes_fully_deployed() {
        set curr_pressure to ship:body:atm:altitudepressure(altitude).
        set curr_altitude to alt:radar.
        set curr_time to time:seconds.

        set pressure_delta_per_sec to (old_pressure - curr_pressure)/(old_time - curr_time).
        
        // calculate expected pressure 10 seconds in the future
        set projected_pressure to curr_pressure + PROJECTION_TIME*pressure_delta_per_sec.
        set projected_altitude to curr_altitude + PROJECTION_TIME*verticalSpeed.

        set old_pressure to curr_pressure.
        set old_time to curr_time.

        clearScreen.

        print "pressure delta: " + pressure_delta_per_sec.
        print "projected pressure: " + projected_pressure.
        print "deploy pressure: " + next_parachute_half_deploy_pressure.
        print " ".
        print "altitude delta: " + verticalSpeed.
        print "projected altitude: " + projected_altitude.
        print "deploy altitude: " + next_parachute_full_deploy_altitude.

        if projected_pressure > next_parachute_half_deploy_pressure{
            kuniverse:timewarp:cancelwarp().
            wait_until_pressure_deployment(next_parachute_half_deploy_pressure).
            set next_parachute_half_deploy_pressure to get_next_parachute_half_deploy_pressure().
            set kuniverse:timewarp:rate to 4.
        }

        if projected_altitude < next_parachute_full_deploy_altitude {
            unlock all.
            kuniverse:timewarp:cancelwarp().
            wait_until_full_parachute_deployment(next_parachute_full_deploy_altitude).
            set next_parachute_full_deploy_altitude to get_next_parachute_full_deploy_altitude().
            if all_parachutes_fully_deployed() {
                break.
            }
            set kuniverse:timewarp:rate to 4.
        }
        wait 0.001.
    }

    print "parachutes fully deployed.".

    kuniverse:timewarp:cancelwarp().
	wait until kuniverse:timewarp:issettled.
    wait until abs(verticalSpeed) < 10.
	print "warping to splashdown.".
    set kuniverse:timewarp:rate to 4.
    wait until alt:radar < 100.
	print "splashdown imminent.".
    set kuniverse:timewarp:rate to 3.
    wait until alt:radar < 75.
    set kuniverse:timewarp:rate to 2.
    wait until alt:radar < 50.
    unlock steering.
    sas on.
	print "brace for impact.".
    kuniverse:timewarp:cancelwarp().
}

// TODO: samrt stopping of physics warp in atmosphere.
// look at each parachute and see what pressure it is meant to deploy at
// find the altitude that gives that pressure, 
// and stop warp before that pressure. 

// also check what altitude all parachutes fully deploy at
// and stop warp for those as well