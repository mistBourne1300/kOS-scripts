
function has_waypoint {
	for wp in allwaypoints() {
		if wp:isselected() {
			return wp.
		}
	}
	return false.
}

function latlngdist {
    parameter geopos1.
    parameter geopos2.
    set lat1 to geopos1:lat.
    set lng1 to geopos1:lng.
    set lat2 to geopos2:lat.
    set lng2 to geopos2:lng.

    return arcCos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(lng2-lng1))*ship:body:radius.
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
    toggle ag9. // activate pitch, yaw, and roll control for airbrakes
    addons:tr:resetdescentprofile(180).
    set wp to has_waypoint().
    if not wp:istype("waypoint") {
        set wp to waypoint("KSC").
    }
    if wp:name = "KSC" and ship:orbit:inclination > 1 {
        runpath("plane_change.ks",0).
    }
    addons:tr:settarget(wp:geoposition).
    until not hasnode {
        set mynode to nextNode.
        remove mynode.
        wait 0.5.
    }
    if not addons:tr:hasimpact {
        print "adding node".
        set new_node to node(time:seconds + 600, 0, 0, 0).
        add new_node.
        until addons:tr:hasimpact {
            set new_node:prograde to new_node:prograde - .1.
        }
        
        // here we assume an equatorial orbit
        until addons:tr:impactpos:lng < wp:geoposition:lng {
            set new_node:time to new_node:time + .1.
        }
        until addons:tr:impactpos:lng > wp:geoposition:lng {
            set new_node:time to new_node:time + .01.
        }
        print addons:tr:impactpos.
        if hasNode {
            runPath("reaper.ks","w").
        }
        sas off.
        remove new_node.
    }
    print "locking to retrograde.".
    lock steering to srfretrograde.
    if ship:q <=0 {
        wait until vang(srfretrograde:vector, ship:facing:vector) < 5.
        print "warping to atmosphere".
        set kuniverse:timewarp:warp to 3.
        wait until kuniverse:timewarp:issettled().
        wait until kuniverse:timewarp:rate = 1.
        wait until kuniverse:timewarp:issettled().
    }
    print "beginning reentry.".

    // until alt:radar < 5*km {
    //     set corrected_proj to (vdot(addons:tr:correctedvec,ship:facing:forevector)*ship:facing:forevector).
    //     set ortho_corrected to addons:tr:correctedvec - corrected_proj.
    //     lock steering to corrected_proj - ortho_corrected.
    // }
    wait until alt:radar < 5*km.
    runpath("precise_suicide.ks").
}

main().