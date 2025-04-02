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

    print "aligning docking ports.".
    lock steering to -1*target:facing:vector.
    wait until is_docked().
    unlock all.
    sas on.
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