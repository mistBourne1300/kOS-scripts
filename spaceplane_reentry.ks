parameter stallspeed.

function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			return wp.
		}
	}
	return false.
}

function main {
    set km to 1000.
    if not (ship = kuniverse:activevessel) {
        print "not active vessel.".
        return.
    }

    if not addons:tr:available {
        print "trajectories not found.".
        return.
    }
    addons:tr:resetdescentprofile(45).
    set wp to has_waypoint().
    if not wp:istype("waypoint") {
        set wp to waypoint("KSC").
    }
    if wp:name = "KSC" and ship:orbit:inclination > 1 {
        runpath("plane_change.ks",0).
        runPath("reaper.ks","w").
        set n to nextNode.
        remove n.
    }
    addons:tr:settarget(wp:geoposition).
    if not addons:tr:hasimpact {
        print "adding node".
        set new_node to node(time:seconds + 600, 0, 0, 0).
        add new_node.
        until addons:tr:hasimpact {
            set new_node:prograde to new_node:prograde - .1.
        }
        
        // here we assume an equatorial orbit
        until abs(addons:tr:impactpos:lng - wp:geoposition:lng) < 10{
            set new_node:time to new_node:time + .1.
        }

        until addons:tr:impactpos:lng > wp:geoposition:lng {
            set new_node:time to new_node:time + .1.
        }
        until addons:tr:impactpos:lng < wp:geoposition:lng {
            set new_node:time to new_node:time - .01.
        }
        print addons:tr:impactpos.
        if hasNode {
            runPath("reaper.ks","w").
            sas off. 
        }
        remove new_node.
    }
    // toggle ag8.
    // wait 1.
    // toggle ag9.
    // wait 1.
    lock steering to heading(90,45).
    wait 1.
    if ship:q <= 0 {
        wait until steeringmanager:angleerror < 1 and steeringManager:rollerror < 1.
        set kuniverse:timewarp:rate to 50.
        wait until kuniverse:timewarp:issettled.
        wait until kuniverse:timewarp:rate = 1.
        wait until kuniverse:timewarp:issettled.
    }
    print "performing reentry".
    wait until airspeed < 1000.
    print "landing at KSC".
    lock steering to heading(90,0).
    wait 10.
    runoncepath("autoland",stallspeed).
}

main().