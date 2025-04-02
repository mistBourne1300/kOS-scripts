// here's the game plan:
// first, assume the ship is within 100 m of the target
    // if not, just terminate with a message that an approach script (to be written)
    // should be used to get within 100 m
// then, get a upper limit for the size of the target ship (target:bounds:furthestcorner:mag), 
// and make sure our vessel stays outside the bounding box of the target until aligned for approach

// if the target is set as a docking port, great.
// otherwise search the target for an open docking port the same size as our ship's docking port
    // if the controlling part on our ship isn't a docking port, 
    // search our ship and the target for a docking port pair
    // that are both open to dock, and are the same size
    // this might be tricky, but shouldn't be too bad...

// now for the hard part:
    // there are two algorithms for this
        // one that always keeps my ship facing the other ship,
            // and the hard part is getting the up/down and  left/right directions to steer
        // another that starts with the docking ports aligned
            // the hard part here will be figuring out the vectors that keep the ships far enough apart, adn how to use them
// do some coordinate transformaions to figure out where to steer the ship so the docking ports align (tricky)
// get a couple PID loops set up:
    // one to steer in the up/down direction (controlls the translation speed, not the distance)
        // which means i'll have to figure out the translation speed as well
    // one for the left/right direction
    // one to make sure the ship stays outside the safe distance defined by target:bounds:furthestcorner:mag + hsip:bounds:firthestcorner:mag

// steer the ship using those PID loops until the docking port facing vectors are aligned
    // (or, rather, misaligned, as they should be 180 degrees opposite)

// once everything is aligned:
// switch the up/down and left/right PID loops to be using 
    // vertical and horizontal position instead of velocity, and keep those vertical and horizontal distances zero
// switch the fore/aft PID loop to be using the fore/aft velocity, and approach at the max safe velocity
// this should get us docked!
parameter bypass is "n".

main().

function main {
    sas off.
    rcs on.
    // check whether script can be run 
        // check for a defined target
        // and that the distance to target is < 100 m
    if hasTarget {
        if target:hassuffix("ship") {
            set target to target:ship.
        }
        if target:distance > 100 {
            print "distance to target too large.".
            return.
        }
    } else {
        print "vessel has no target.".
        return.
    }


    if bypass = "y" or bypass = "b" {
        print "WARNING!".
        print "auto-targeting bypassed.".
        print "only do this if control point.".
        print "and target are compatible.".
        print "press enter to confirm; ".
        print "anything else to quit: ".
        set c to terminal:input:getchar().
        if not c = terminal:input:return {
            sas on.
            rcs off.
            return.
        }
    } else {
        // check whether current controlling point is an open docking port
        // and current target is a compatible docking port
        // if not, search both vessels for a compatible pair of open ports
            // if this fails, abort docking procedure
        // set current control of the ship to the docking port
        // and set target as the other docking port
        if not isControlledByCompatibleDockingPorts() {
            if not setControlToCompatibleDockingPorts() {
                print "failed to auto-target a compatible docking port.".
                sas on.
                return.
            }
        }
    }
    
    print "aligning docking ports.".
    lock steering to -1*target:facing:vector.
    wait until vang(-1*target:facing:vector, ship:facing:vector) < 1.
    t_mode_converge().
    
    sas on.
    rcs off.
}

function isControlledByCompatibleDockingPorts {
    set controlPartName to ship:controlpart:name:tolower.
    if controlPartName:contains("claw") {
        return true.
    }
    if controlPartName:contains("dockingport") or controlPartName:contains("inflatableairlock"){
        // the current ship controlling part is a docking port
        if ship:controlpart:state = "Ready"{
            return false.
        }
        set targetName to target:name:tolower.
        if controlPartName = targetName {
            return true.
        } else {
            return false.
        }
    } else {
        return false.
    }
}

function setControlToCompatibleDockingPorts {
    // if the current control point is a docking port, see if we can get it to work with that one
    // the below command, I'm not sure about. I feel like it should just set the target to the target's ship
    // but code doesn't care about your feelings
    set controlPartName to ship:controlpart:name:tolower.
    if target:hassuffix("ship") {
        set target to target:ship.
    }
    set targPorts to target:dockingports.
    if controlPartName:contains("dockingport") or controlPartName:contains("inflatableairlock") {
        if not ship:controlpart:haspartner {
            for port in targPorts {
                if not port:hasPartner {
                    if port:name = controlPartName {
                        set target to port.
                        return true.
                    }
                }
            }
        }
    }
    print "current control not compatible with any port on target.".

    // so now we're here.
    // which means the current part controlling the ship has no compatible docking port on the other ship
    set shipPorts to ship:dockingports.
    for sport in shipPorts {
        if not sport:hasPartner {
            for tport in targPorts {
                if not tport:haspartner {
                    if tport:name = sport:name {
                        sport:controlfrom.
                        set target to tport.
                        return true.
                    }
                }

            }
        }
    }

    // one last check. if the ship has any claws, that can grab anything, so check that.
    set allshipparts to ship:parts.
    for part in allshipparts {
        set partname to part:name:tolower.
        if partname:contains("claw"){
            return true.
        }
    }
    return false.

}

function t_mode_converge {
    // print "ship size:".
    // print get_ship_size().
    // print "target size:".
    // print get_target_ship_size().
    set safe_dist to .5*(get_ship_size() + get_target_ship_size()).
    print "safe distance:".
    print safe_dist.

    // define useful vectors
    // p = target:position - ship:position
    // s = ship:facing:vector.
    // star = ship:facing:starvector
    // up = ship:facing:upvector
    set p to target:position - ship:controlpart:position.
    set p_prime to p - (vdot(p,ship:facing:vector)/(ship:facing:vector:mag^2))*ship:facing:vector.

    if target:hassuffix("ship") {
        set targetship to target:ship.
    } else {
        set targetship to target.
    }

    set kp to 1.
    set kd to 10.
    set ki to 0.
    set starvelLoop to pidLoop(kp,ki,kd,-.3,.3).
    set upvelLoop to pidLoop(kp,ki,kd,-.3,.3).
    set starvelLoop:setpoint to 0.
    set upvelLoop:setpoint to 0.

    set starLoop to pidLoop(kp,ki,0,-1,1).
    set uploop to pidLoop(kp,ki,0,-1,1).
    set foreloop to pidLoop(10,0,0,-1,1).
    set foreloop:setpoint to 0.
    // set foreloop:epsilon to 0.1.
    // lock starvel to hold_safe_dist_starvel().
    // lock upvel to hold_safe_dist_upvel().
    // print "getting to safe distance.".


    lock rel_star_dist to vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag).
    lock rel_up_dist to vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag).


    lock relvel to ship:velocity:orbit - targetship:velocity:orbit.
    lock rel_star_vel to vdot(ship:facing:starvector,relvel)/ship:facing:starvector:mag.
    lock rel_up_vel to vdot(ship:facing:upvector,relvel)/ship:facing:upvector:mag.

    lock fore_vel to vdot(ship:velocity:orbit - targetship:velocity:orbit,ship:facing:vector)/ship:facing:vector:mag.
    lock fore_dist to vdot(ship:facing:vector,p)/ship:facing:vector:mag.
    until p_prime:mag > safe_dist or fore_dist > 0{
        set p to target:position - ship:controlpart:position.
        set p_prime to p - (vdot(p,ship:facing:vector)/(ship:facing:vector:mag^2))*ship:facing:vector.
        set starvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:starvector)/(p_prime:mag * ship:facing:starvector:mag)) * (safe_dist + 1).
        set upvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:upvector)/(p_prime:mag * ship:facing:upvector:mag)) * (safe_dist + 1).

        
        set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
        set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

        clearscreen.
        print "getting to safe distance: " + floor(safe_dist - p_prime:mag,3).
        print "star dist: " + floor(rel_star_dist,3).
        print "des star vel: " + floor(starloop:setpoint,3).
        print "act star vel: " + floor(rel_star_vel,3).
        print " ".
        print "up dist: " + floor(rel_up_dist,3).
        print "des up vel: " + floor(uploop:setpoint,3).
        print "act up vel: " + floor(rel_up_vel,3).
        print " ".
        print "des fore vel: " + floor(foreloop:setpoint,3).
        print "fore vel: " + floor(fore_vel,3).
        
        
        

        set star_thrust to starLoop:update(time:seconds,rel_star_vel).
        set upthrust to uploop:update(time:seconds,rel_up_vel).
        set forethrust to foreloop:update(time:seconds,fore_vel).
        set ship:control:translation to v(star_thrust,upthrust,forethrust).
        // print(p_prime:mag).
        if quit() {return.}
        wait(0.01).
    }
    set foreloop:setpoint to -1.
    // until fore_vel < -1 or fore_dist > safe_dist{ // possibly not necessary with the foreloop
    //     set p to target:position - ship:controlpart:position.
    //     // update side translation
    //     set starvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:starvector)/(p_prime:mag * ship:facing:starvector:mag)) * safe_dist.
    //     set upvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:upvector)/(p_prime:mag * ship:facing:upvector:mag)) * safe_dist.

        
    //     set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
    //     set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

    //     clearscreen.
    //     print "reverse thrust: " + floor(fore_vel + 1,3).
    //     print "star dist: " + floor(rel_star_dist,3).
    //     print "des star vel: " + floor(starloop:setpoint,3).
    //     print "act star vel: " + floor(rel_star_vel,3).
    //     print " ".
    //     print "up dist: " + floor(rel_up_dist,3).
    //     print "des up vel: " + floor(uploop:setpoint,3).
    //     print "act up vel: " + floor(rel_up_vel,3).
    //     print " ".
    //     print "des fore vel: " + floor(foreloop:setpoint,3).
    //     print "fore vel: " + floor(fore_vel,3).
        
        

    //     set star_thrust to starLoop:update(time:seconds,rel_star_vel).
    //     set upthrust to uploop:update(time:seconds,rel_up_vel).
    //     set forethrust to foreloop:update(time:seconds,fore_vel).
    //     set ship:control:translation to v(star_thrust,upthrust,forethrust).
    //     if quit() {return.}
    //     wait(0.01).
    // }
    until fore_dist > safe_dist {
        set p to target:position - ship:controlpart:position.
        // update side translation
        set starvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:starvector)/(p_prime:mag * ship:facing:starvector:mag)) * safe_dist.
        set upvelLoop:setpoint to (-1*vdot(p_prime,ship:facing:upvector)/(p_prime:mag * ship:facing:upvector:mag)) * safe_dist.

        
        set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
        set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).
        
        clearscreen.
        print "coasting to adequate fore dist: " + floor(safe_dist - fore_dist,3).
        print "star dist: " + floor(rel_star_dist,3).
        print "des star vel: " + floor(starloop:setpoint,3).
        print "act star vel: " + floor(rel_star_vel,3).
        print " ".
        print "up dist: " + floor(rel_up_dist,3).
        print "des up vel: " + floor(uploop:setpoint,3).
        print "act up vel: " + floor(rel_up_vel,3).
        print " ".
        print "des fore vel: " + floor(foreloop:setpoint,3).
        print "fore vel: " + floor(fore_vel,3).
        

        set star_thrust to starLoop:update(time:seconds,rel_star_vel).
        set upthrust to uploop:update(time:seconds,rel_up_vel).
        set forethrust to foreloop:update(time:seconds,fore_vel).
        set ship:control:translation to v(star_thrust,upthrust,forethrust).
        if quit() {return.}
        wait(0.01).
    }
    set starvelLoop:setpoint to 0.
    set upvelLoop:setpoint to 0.
    set foreloop:setpoint to 0.
    // until fore_vel > 0 { // possibly not necessary with the foreloop
    //     set p to target:position - ship:controlpart:position.
    //     // update side translation
    //     set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
    //     set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

    //     clearscreen.
    //     print "cancelling fore velocity: " + floor(-fore_vel,3).
    //     print "star dist: " + floor(rel_star_dist,3).
    //     print "des star vel: " + floor(starloop:setpoint,3).
    //     print "act star vel: " + floor(rel_star_vel,3).
    //     print " ".
    //     print "up dist: " + floor(rel_up_dist,3).
    //     print "des up vel: " + floor(uploop:setpoint,3).
    //     print "act up vel: " + floor(rel_up_vel,3).
    //     print " ".
    //     print "des fore vel: " + floor(foreloop:setpoint,3).
    //     print "fore vel: " + floor(fore_vel,3).

    //     set star_thrust to starLoop:update(time:seconds,rel_star_vel).
    //     set upthrust to uploop:update(time:seconds,rel_up_vel).
    //     set forethrust to foreloop:update(time:seconds,fore_vel).
    //     set ship:control:translation to v(star_thrust,upthrust,forethrust).
    //     if quit() {return.}
    //     wait(0.01).
    // }
    
    until p_prime:mag < 1 {
        set p to target:position - ship:controlpart:position.
        set p_prime to p - (vdot(p,ship:facing:vector)/(ship:facing:vector:mag^2))*ship:facing:vector.

        set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
        set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

        clearscreen.
        print "aligning ports: " + floor(p_prime:mag - 1,3).
        print "star dist: " + floor(rel_star_dist,3).
        print "des star vel: " + floor(starloop:setpoint,3).
        print "act star vel: " + floor(rel_star_vel,3).
        print " ".
        print "up dist: " + floor(rel_up_dist,3).
        print "des up vel: " + floor(uploop:setpoint,3).
        print "act up vel: " + floor(rel_up_vel,3).
        print " ".
        print "des fore vel: " + floor(foreloop:setpoint,3).
        print "fore vel: " + floor(fore_vel,3).

        set star_thrust to starLoop:update(time:seconds,rel_star_vel).
        set upthrust to uploop:update(time:seconds,rel_up_vel).
        set forethrust to foreloop:update(time:seconds,fore_vel).
        set ship:control:translation to v(star_thrust,upthrust,forethrust).
        if quit() {return.}
        wait(0.01).
    }
    set foreloop:setpoint to 0.5.
    // until fore_vel > .5 { // possibly not necessary with the foreloop
    //     set p to target:position - ship:controlpart:position.
    //     set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
    //     set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

    //     clearscreen.
    //     print "forward thrust: " + floor(0.5 - fore_vel,3).
    //     print "star dist: " + floor(rel_star_dist,3).
    //     print "des star vel: " + floor(starloop:setpoint,3).
    //     print "act star vel: " + floor(rel_star_vel,3).
    //     print " ".
    //     print "up dist: " + floor(rel_up_dist,3).
    //     print "des up vel: " + floor(uploop:setpoint,3).
    //     print "act up vel: " + floor(rel_up_vel,3).
    //     print " ".
    //     print "des fore vel: " + floor(foreloop:setpoint,3).
    //     print "fore vel: " + floor(fore_vel,3).

    //     set star_thrust to starLoop:update(time:seconds,rel_star_vel).
    //     set upthrust to uploop:update(time:seconds,rel_up_vel).
    //     set forethrust to foreloop:update(time:seconds,fore_vel).
    //     set ship:control:translation to v(star_thrust,upthrust,forethrust).
    //     if quit() {return.}
    //     wait(0.01).
    // }
    until is_docked() {
        set p to target:position - ship:controlpart:position.
        set starLoop:setpoint to starvelLoop:update(time:seconds,-1*vdot(p,ship:facing:starvector)/(ship:facing:starvector:mag)).
        set uploop:setpoint to upvelLoop:update(time:seconds, -1*vdot(p,ship:facing:upvector)/(ship:facing:upvector:mag)).

        clearscreen.
        print "final docking: " + floor(p:mag,3).
        print "star dist: " + floor(rel_star_dist,3).
        print "des star vel: " + floor(starloop:setpoint,3).
        print "act star vel: " + floor(rel_star_vel,3).
        print " ".
        print "up dist: " + floor(rel_up_dist,3).
        print "des up vel: " + floor(uploop:setpoint,3).
        print "act up vel: " + floor(rel_up_vel,3).
        print " ".
        print "des fore vel: " + floor(foreloop:setpoint,3).
        print "fore vel: " + floor(fore_vel,3).

        set star_thrust to starLoop:update(time:seconds,rel_star_vel).
        set upthrust to uploop:update(time:seconds,rel_up_vel).
        set forethrust to foreloop:update(time:seconds,fore_vel).
        set ship:control:translation to v(star_thrust,upthrust,forethrust).
        if quit() {return.}
        wait(0.01).
    }

    set ship:control:neutralize to true.
}

function update_t_mode {
    set starloop:setpoint to 0.
}

function get_ship_size {
    return (ship:bounds:relmax - ship:bounds:relmin):mag.
}

function get_target_ship_size {
    if target:hassuffix("ship") {
        set targetship to target:ship.
    } else {
        set targetship to target.
    }
    return (targetship:bounds:relmax - targetship:bounds:relmin):mag.
}

function is_docked {
    if ship:controlpart:hassuffix("haspartner") {
        return ship:controlpart:haspartner.
    } else {
        if defined target {
            return false.
        } else {
            unlock all.
            return true.
        }
    }
}

function quit {
    if terminal:input:haschar {
        set c to terminal:input:getchar().
        if c = "q"{
            print "program quit by user".
            set ship:control:neutralize to true.
            sas on.
            return true.
        }
    }
    return false.
}