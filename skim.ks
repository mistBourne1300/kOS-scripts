parameter dip is 250.

set o2rate to .508.
set h2rate to 1.001.

list rcs in thrusters.

function resource_starved {
    list resources in res.
    for r in res {
        if r:name = "Oxygen" {
            set o2left to r:amount.
            set o2time to o2left/o2rate.
            if o2time/60 < 20 {
                print "less than 20 minutes of oxygen left".
                lock steering to retrograde.
                lock throttle to 1.
                wait until engine_flameout().
                return true.
            }
        } else if r:name = "Hydrogen" {
            set h2left to r:amount.
            set h2time to h2left/h2rate.
            if h2time/60 < 5 {
                print "less than 5 minutes of h2 left".
                lock steering to retrograde.
                lock throttle to 1.
                wait until engine_flameout().
                return true.
            }
        }
    }
    return false.
}

function engine_flameout {
    for t in thrusters {
        if t:flameout {
            return true.
        }
    }
    return false.
}

function main {
    clearScreen.
    sas off.
    rcs on.
    set continue to true.
    if ship:periapsis > body:atm:height {
        print "periapsis not in atmosphere, burning retrograde.".
        lock steering to retrograde.
        wait until vang(ship:facing:forevector, retrograde:forevector) < 1.
        lock throttle to 0.001*(ship:periapsis - (body:atm:height - dip)).
        wait until ship:periapsis < body:atm:height.
        lock throttle to 0.
    }
    print "performing skim maneuver...".
    if ship:apoapsis > body:atm:height {
        lock steering to retrograde.
        runPath("circularization.ks","peri").
        set oldnode to nextNode.
        print "warping to node.".
        set kuniverse:timewarp:warp to 3.
        wait until kuniverse:timewarp:warp = 0 and kuniverse:timewarp:issettled.
        wait until vang(ship:facing:forevector, retrograde:forevector) < 1.
        set kuniverse:timewarp:mode to "physics".
        set kuniverse:timewarp:warp to 3.
        wait until oldnode:eta < 5.
        kuniverse:timewarp:cancelwarp().
        remove oldnode.
        lock throttle to 1.
        wait until ship:apoapsis < body:atm:height.
        lock throttle to 0.
    }
    // TODO: run this in a while loop, not with when/then.
    // that gives more flexibility for when to throttle 
    // and where to steer.
    lock steering to angleaxis(-60,ship:facing:starvector)*prograde.
    // wait until vang(ship:facing:forevector, srfprograde:forevector) < 1.
    lock needthrottle to (ship:altitude < body:atm:height - 2*dip and verticalSpeed < 0) or ship:apoapsis < body:atm:height - dip or (altitude < body:atm:height and (eta:apoapsis < 1 or (ship:orbit:period - eta:apoapsis < (1/8)*ship:orbit:period))).
    when needthrottle then {
        clearscreen.
        print "throttle: " + round(throttle,8).
        lock throttle to max(0.01*((body:atm:height - dip) - ship:periapsis), 0.01*((body:atm:height - dip) - ship:apoapsis)).
        return continue.
    }
    when not needthrottle then {
        clearscreen.
        print "throttle: inactive.".
        lock throttle to 0.
        return continue.
    }
    when terminal:input:haschar() then {
        set c to terminal:input:getchar().
        if c = "q" {
            print "program quit by user.".
            lock throttle to 0.
            set ship:control:pilotmainthrottle to 0.
            return 1/0.
        } else if c = "r" {
            print "reentry protocol engaged.".
            lock steering to srfretrograde.
            lock throttle to 1.
            wait until engine_flameout().
            lock throttle to 0.
        }
        return true.
    }
    print "when/then statements set up.".
    wait until engine_flameout() or resource_starved().
    set continue to false.
    wait 1.
    clearscreen.
    print "engine flameout. preparing for reentry.".
    lock throttle to 0.
    until stage:number = 0 {if stage:ready {stage.}}
    lock steering to srfRetrograde.
    wait until airspeed < 1500.
    sas on.
    set sasmode to "retrograde".
    set ship:control:pilotmainthrottle to 0.
    runoncepath("kerbin_descent").
}

main().