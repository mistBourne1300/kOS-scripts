// will auto-land an aircraft at a desired location
// the location can either be passed in, or set as a waypoint
// the logic is as follows: on program start, a check is run to see if there is a valid runway set as the current waypoint.
// if no valid runway is set as the current waypoint, look to see which one is closest, and set that as the waypoint.
// a check will have to be run to "idiot proof" this, to make sure the user doesn't change the waypoint after the fact to something other than a runway 
// (a valid runway can still become the waypoint, but any non-runway waypoint will be changed back to the old (or maybe just closest???) runway waypoint)



parameter stallspeed.


set landvsmax to 50.
set waypoint_name to "".
set waypoint_alt to 0.

set landdesalt to 7000.
set landdesairspd to stallspeed*3.




set km to 1000.

set starttime to time:seconds.

set valid_runways to list("KSC", "Dessert Airfield").
runOncePath("0:/lib/autopilot_functions.ks").

function autoland_main {
    clearScreen.
    // if ship:status = "landed" or ship:status = "prelaunch" {
    //     print "ship is already landed.".
    //     brakes on.
    //     sas on.
    //     set ship:control:pilotmainthrottle to 0.
    //     set ship:control:neutralize to true.
    //     return.
    // }
    select_landing().
    sas off.
    set throtpid:setpoint to max(landdesairspd,airspeed).

    lock groundalt to altitude - alt:radar.
    set landdesalt to max(ship:altitude,groundalt + 1000).
    set vspid:setpoint to landdesalt.

    until waypoint_dist() < 100*km {
        // if test_flameout() {
        //     return.
        // }
        loop_internals().
        wait 0.001.
    }
    set landdesalt to max(7000,altitude).
    set vspid:setpoint to landdesalt.

    until waypoint_dist() < 70*km {
        loop_internals().
        wait 0.001.
    }

    set landdesairspd to stallspeed*3.
    set throtpid:setpoint to landdesairspd.

    set landdesalt to 7000.
    set vspid:setpoint to landdesalt.

    
    until waypoint_dist() < 50*km {
        if test_flameout() {
            return.
        }
        if airspeed > landdesairspd*1.3 {
            brakes on.
        }
        if airspeed < landdesairspd*1.1 {
            brakes off.
        }
        loop_internals().
        wait 0.001.
    }
    brakes off.

    set landdesairspd to stallspeed + 100.
    set throtpid:setpoint to landdesairspd.

    when altitude < 7000 then {
        set approach_time to waypoint_dist()/max(throtpid:setpoint*1.1,airspeed).

        set vspid:minoutput to -(altitude)/approach_time.
        // do some vs calculations with the landing airspeed and distance to get a better vertical speed estimate
    }

    lock landdesalt to max(waypoint_alt+300,groundalt+300).

    // until altitude - landdesalt < 1000 and pitch_for() > 0 or waypoint_dist() < 30*km{
    //     set vspid:setpoint to landdesalt.
    //     loop_internals().
    //     if test_flameout() {
    //         return.
    //     }
    //     if airspeed > landdesairspd*1.1 {
    //         brakes on.
    //     } else {
    //         brakes off.
    //     }
    //     wait 0.001.
    // }

    when (altitude - landdesalt < 1000 and pitch_for() > 0) then {

        if kuniverse:canquicksave {
            sas on.
            kuniverse:quicksave().
            sas off.
        } else {
            clearscreen.
            print "quicksaving failed.".
            print "pausing game for human decision.".
            kuniverse:pause().
        }
        brakes off.
        lights off.
        sas on.
        toggle ag3.
        wait 0.5.
        toggle ag3.
        wait 0.5.
        toggle ag3.
        sas off.
    }

    until waypoint_dist() < 20*km {
        set vspid:setpoint to landdesalt.
        loop_internals().
        if test_flameout() {
            return.
        }
        if airspeed > landdesairspd*1.3 {
            brakes on.
        }
        if airspeed < landdesairspd*1.1 {
            brakes off.
        }
        wait 0.001.
    }

    lock landdesairspd to stallspeed + (waypoint_dist() - runway_length())/200.
    lock landdesalt to max(waypoint_alt + (waypoint_dist() - runway_length())/66 + 5,groundalt+100).

    until waypoint_dist < 4.5*km {
        set throtpid:setpoint to landdesairspd.
        set vspid:setpoint to landdesalt.
        loop_internals().
        if not good_approach() {
            go_around().
        }
        if test_flameout() {
            return.
        }
        if airspeed > landdesairspd*1.3 {
            brakes on.
        }
        if airspeed < landdesairspd*1.1 {
            brakes off.
        }
        wait 0.001.
    }
    brakes off.

    gear on.
    
    // TODO: test this code that slowly lowers 
    // the landing altitude over 5 (for now) seconds.
    set loop_start_time to time:seconds.
    set loop_total_time to 5.
    set starting_desalt to landdesalt.
    set ending_desalt to waypoint_alt + stallspeed/5.
    set m to (ending_desalt-starting_desalt)/loop_total_time.
    lock landdesalt to m*(time:seconds - loop_start_time) + starting_desalt.
    
    until time:seconds - loop_start_time > loop_total_time {
        set throtpid:setpoint to landdesairspd.
        set vspid:setpoint to landdesalt.
        loop_internals().
        if not good_approach() {
            go_around().
        }
        if test_flameout() {
            go_around(0).
        }
        if airspeed > landdesairspd*1.1 {
            brakes on.
        } else {
            brakes off.
        }
        wait 0.001.
    }
    brakes off.

    lock landdesalt to ending_desalt.
    // set vspid:minoutput to -1.
    lights on.

    until waypoint_dist < runway_length() {
        set throtpid:setpoint to landdesairspd.
        loop_internals().
        if not good_approach() {
            go_around().
        }
        if test_flameout() {
            go_around(0).
        }
        if airspeed > landdesairspd*1.3 {
            brakes on.
        }
        if airspeed < landdesairspd*1.1 {
            brakes off.
        }
        wait 0.001.
    }
    brakes off.
    set throtpid:setpoint to stallspeed.
    // lock throttle to 0.
    // set vspid:setpoint to waypoint_alt.
    // set vspid:maxoutput to 0.
    // set startdecay to time:seconds.
    // set startout to vspid:maxoutput.
    // set decayexp to .9.
    until ship:status = "landed" {
        set vspid:maxoutput to verticalSpeed^2.
        loop_internals().
        if test_flameout() {
            go_around().
        }
        if airspeed > landdesairspd*1.1 and alt:radar > 5{
            brakes on.
        } else {
            brakes off.
        }
        wait 0.001.
    }
    print "touchdown.".
    lock throttle to 0.
    set wheelkp to 0.001.
    set wheelki to 0.
    set wheelkd to 0.005.
    set minwheelsteer to -1.
    set maxwheelsteer to 1.
    set wheelpid to pidLoop(wheelkp,wheelki,wheelkd,minwheelsteer,maxwheelsteer).
    set loop_start to time:seconds.
    set ad0 to abs(angleDiff(compass_for(),0)).
    set ad90 to abs(angleDiff(compass_for(),90)).
    set ad180 to abs(angleDiff(compass_for(),180)).
    set ad270 to abs(angleDiff(compass_for(),270)).
    if ad0 < ad90 and ad0 < ad180 and ad0 < ad270 {
        set wheelpid:setpoint to 0.
    } else if ad90 < ad0 and ad90 < ad180 and ad90 < ad270 {
        set wheelpid:setpoint to 90.
    } else if ad180 < ad0 and ad180 < ad90 and ad180 < ad270 {
        set wheelpid:setpoint to 180.
    } else {
        set wheelpid:setpoint to 270.
    }
    until vang(ship:facing:forevector, heading(wheelpid:setpoint,0,0):vector) < 1 {
        loop_internals().
        set ship:control:wheelsteer to -wheelpid:update(time:seconds, compass_for()).
        if test_flameout() {
            brakes on.
            return.
        }
        wait 0.001.
    }
    brakes on.
    until airspeed < 10 {
        // if time:seconds - loop_start > 1{
        //     set loop_start to time:seconds.
        //     brakes off.
        //     wait 0.1.
        //     brakes on.
        // }
        loop_internals().
        set ship:control:wheelsteer to -wheelpid:update(time:seconds, compass_for()).
        // print ship:control:wheelsteer.
        if test_flameout() {
            return.
        }
        wait 0.001.
    }
    brakes on.
    wait until airspeed < 1 or test_flameout().
    print "the captain has turned off".
    print "the fasten seatbelt sign.".
    print "you are free to".
    print "move about the cabin.".
    set ship:control:pilotmainthrottle to 0.
    set ship:control:neutralize to true.
    sas on.
}

autoland_main(). // needs to be down here so it doesn't run the main() program from the calling file

function loop_internals {
    if test_flameout() {
        set ship:control:neutralize to true.
        set ship:control:pilotmainthrottle to throt.
        sas on.
        return 1/0.
    }
    update_loops().
    if time:seconds - starttime > 1 {
        set is_valid to select_landing().
        if is_valid {
            printinfo().
            print "autoland active.".
        }
        set starttime to time:seconds.
    }
}

function waypoint_dist {
    local wp is has_waypoint().
    if wp:istype("waypoint") {
        return (wp:position -  ship:position):mag.
    }
    return 101*km.
}

function select_landing {
    local wp is has_waypoint().
    if wp:istype("waypoint") { // now check for a current waypoint and if that waypoint is valid
        if valid_runways:find(wp:name) >= 0 {
            set waypoint_name to wp:name.
            set waypoint_alt to wp:altitude.
            return true.
        } else {
            // print "waypoint is not valid: '" + wp:name + "'".
        }
    } else {
        // print "wp is not type waypoint.".
    }
    clearscreen.
    print "there is either no current waypoint".
    print "or the current waypoint is not valid.".
    print "please select a valid waypoint.".
    print "the recommended runway is:".
    set min_dist to ship:body:radius*2.
    set recommended to "".
    for name in valid_runways {
        set wp to waypoint(name).
        if (wp:position - ship:position):mag < min_dist {
            set min_dist to (wp:position - ship:position):mag.
            set recommended to name.
        }
    }
    print recommended.
    return false.
}

function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			return wp.
		}
	}
	return false.
}

function runway_length {
    if waypoint_name = "KSC" {
        return 1313.
    } else if waypoint_name = "Dessert Airfield" {
        return 1000.
    } else {
        go_around().
    }
}

function good_approach {
    // returns a boolean on whether the approach is good or not
    // true is a good approach, false is a bad one
    return true.
    
    // if altitude < waypoint_alt {
    //     return false.
    // }
    // if altitude > landdesalt + 490*waypoint_dist()/9000 + 580/9 {
    //     return false.
    // }
    // if waypoint_name = "Dessert Airfield" {
    //     // angle should be either 0 or 180
    //     if min(abs(angleDiff(compass_for(), 0)), abs(angleDiff(compass_for(),180))) > 4*(waypoint_dist()-1000)/900 + 5 {
    //         return false.
    //     }
    // } else {
    //     if min(abs(angleDiff(compass_for(),90)), abs(angleDiff(compass_for(),270))) > 4*(waypoint_dist()-1000)/900 + 5 {
    //         return false.
    //     }
    // }
    // return true.
}

function go_around {
    set landdesalt to waypoint_alt+1000.
    set landdesairspd to stallspeed+100.

    set vspid:setpoint to landdesalt.
    set throtpid:setpoint to landdesairspd.

    set rollcontrol:setpoint to 0.

    until waypoint_dist() > 20*km {
        clearscreen.
        print "go around initiated.".
        print "normal flight resuming in:".
        print round(20*km-waypoint_dist).
        set ship:control:yaw to 0.
        set ship:control:roll to rollcontrol:update(time:seconds, roll_for()).

        set throt to throtpid:update(time:seconds, airspeed).
        if abs(landdesalt-altitude) < 10 {
            set vspid:kd to 0.
        } else if abs(landdesalt - altitude) < 50 { 
            set vspid:kd to 1.
        }else {
            set vspid:kd to 2.
        }
        set vertupdate to vspid:update(time:seconds, altitude).
        set pitchang:setpoint to vertupdate.
        set angle to pitchang:update(time:seconds, verticalSpeed).
        set pitchcontrol:setpoint to angle.
        set ship:control:pitch to pitchcontrol:update(time:seconds, pitch_for()).
        if test_flameout() {
            set ship:control:neutralize to true.
            return 1/0.
        }
    }
}