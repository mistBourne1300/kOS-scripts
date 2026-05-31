parameter dowarp is "y".

function main {
    if not (ship:body = body("kerbin")) {
        print "not on kerbin".
        return.
    }
    set m to body("minmus").
    set kerbin_rotation to ship:body:rotationangle.
    print "kerbin rotation: " + kerbin_rotation.
    set min_lan to body("minmus"):orbit:lan.
    print "minmus lan: " + min_lan.
    set current_long to ship:longitude.
    print "current longitude: " + current_long.
    set kerbin_period to ship:body:rotationperiod.
    print "kerbin period: " + kerbin_period.

    set ship_solar_rotation to kerbin_rotation + current_long.
    print "ship solar rotation: " + ship_solar_rotation.
    if ship_solar_rotation < 0 {
        set ship_solar_rotation to ship_solar_rotation + 360.
    }
    print "ship solar rotation: " + ship_solar_rotation.
    
    if min_lan < 180 {
        set min_ldn to min_lan + 180.
    } else {
        set min_ldn to min_lan - 180.
    }
    print "minmus ldn: " + min_ldn.

    set angle_to_lan to min_lan - ship_solar_rotation.
    set angle_to_ldn to min_ldn - ship_solar_rotation.
    print "angle_to_lan: " + angle_to_lan.
    print "angle_to_ldn: " + angle_to_ldn.

    if angle_to_lan > 0 and angle_to_ldn > 0 {
        // go to the smaller of the two
        set time_to_node to kerbin_period*min(angle_to_lan, angle_to_ldn)/360.
    } else if angle_to_lan < 0 and angle_to_ldn < 0 {
        set time_to_node to -kerbin_period*min(angle_to_lan, angle_to_ldn)/360.
    } else {
        set time_to_node to kerbin_period*max(angle_to_lan, angle_to_ldn)/360.
    }
    
    print "time_to_node: " + time_to_node.
    set time_warp_time to time_to_node -2.5*60.
    print "time_warp_time: " + time_warp_time.

    if dowarp = "y" {
        kuniverse:timewarp:warpto(time:seconds + time_warp_time).
    }
}

main().