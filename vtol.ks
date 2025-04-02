list engines in engs.
main().

function main {
    // create PID loops
    set twrpid to pidLoop(1,0.001,1,-1,1). // takes in vertical speed, spits out a twr to be at
    lock thrust to summed_thrust_vector().
    lock upthrustmag to ((thrust*(up:forevector))*up:forevector):mag. // component of thrust directly upwards
    // until false {
    //     print thrust:mag.
    //     print vang(up:forevector,thrust).
    //     print upthrustmag.
    //     clearscreen.
    // }
    clearScreen.
    print "desired vertical speed: " + twrpid:setpoint.

    set twrpid:setpoint to 0.
    on ag9 { // ag2 says go up faster
        set twrpid:setpoint to twrpid:setpoint + 0.5.
        clearScreen.
        print "desired vertical speed: " + twrpid:setpoint.
        return true.
    }

    on ag8 {
        set twrpid:setpoint to twrpid:setpoint - 0.5.
        clearScreen.
        print "desired vertical speed: " + twrpid:setpoint.
        return true.
    }

    on ag10 {
        set twrpid:setpoint to 0.
        clearScreen.
        print "desired vertical speed: " + twrpid:setpoint.
        return true.
    }

    on abort {
        sas off.
        lock steering to srfRetrograde.
        until verticalSpeed > -10 and alt:radar < 1000 and airspeed < 10 {
            set twrpid:setpoint to -(alt:radar/10 + 0.75).
        }
        lock steering to up.
        print "quitting program".
        until not ship:status = "flying"{
            set twrpid:setpoint to -(alt:radar/10 + 0.75).
        }
        return 1/0.
    }

    lock weight to ship:mass*ship:body:mu/((ship:body:radius + ship:altitude)^2).
    lock destwr to twrpid:update(time:seconds,verticalSpeed) + 1.
    lock throt to destwr*weight/(upthrustmag+0.00001) + 0.01.
    lock throttle to throt.
    wait until alt:radar > 10 and ship:status = "flying".
    set start to time:seconds.
    until not ship:status = "flying" {
        if time:seconds - start > 1{
            set start to time:seconds.
            clearScreen.
            print "press 8 to decrease vs".
            print "press 9 to increase vs".
            print "press 10 to zero vs".
            print "press backspace to abort".
            print "desired vertical speed: " + twrpid:setpoint.
            // print "twr: " + (thrust/weight).
            print "upwards twr: " + (upthrustmag/weight).
        }
    }
    set ship:control:pilotmainthrottle to 0.
}

function summed_thrust_vector {
    set summed_thrust to v(0,0,0).
    for e in engs {
        set summed_thrust to summed_thrust - e:availablethrust*facing:forevector.
    }
    return summed_thrust.
}

