parameter bodyname.
parameter orbitalt.
parameter aerobrake is false.

runOncePath("0:compute_transfer_orbit.ks").

function orbit_body_main {
    if not bodyexists(bodyname) {
        print "Unknown celestial body: " + bodyname.
        return.
    }

    local targetbody to body(bodyname).
    local bodypath to path_from_kerbin(targetbody).

    if kerbol_index(path) < 0 {
        print "within-kerbin SOI paths are not implemented yet".
        return.
    }

    local best_launch to compute_transfer_orbit(bodypath).

    local launch_time to 0.
    local v1 to V(0,0,0).
    local v2 to V(0,0,0).
    local total_dv to 0.
    local travel_time to 0.

    if best_launch {
        set launch_time to best_launch[0].
        set v1 to best_launch[1].
        set v2 to best_launch[2].
        set total_dv to best_launch[3].
        set travel_time to best_launch[4].
    } else {
        return false.
    }


}

// Return the bodies in order from Kerbin to the requested body, inclusive.
function path_from_kerbin {
    parameter targetbody.

    local path is list().
    local currentbody is targetbody.

    // Walking each body's primary eventually reaches Kerbol in the stock
    // system. Insert at the front so the returned path runs outward from
    // Kerbin toward the requested body.
    until currentbody:name = "Kerbol" {
        path:insert(0, currentbody).

        if currentbody:name = "Kerbin" {
            return path.
        }

        if not currentbody:orbit:exists {
            print "Cannot find a path from Kerbin to " + targetbody:name + ".".
            return list().
        }
        set currentbody to currentbody:orbit:body.
    }

    // The loop stops before adding the root body; include it, then prepend
    // Kerbin because Kerbin orbits Kerbol.
    path:insert(0, currentbody).
    path:insert(0, Kerbin).
    return path.
}

function kerbol_index {
    parameter path.
    local ki to -1.

    for i in range(0, path:length - 1) {
        if path[i]:name = "Kerbol" {
            set ki to i.
            break.
        }
    }

    return ki.

}
