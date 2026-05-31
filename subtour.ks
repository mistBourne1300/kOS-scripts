function has_clamps {
	list parts in partlist.
	for p in partlist {
		if p:name = "launchClamp1"{
			return true.
		}
	}
	return false.
}

function subtour_main {
    sas off.
    lock steering to up.
    lock throttle to 1.
    list engines in engs.
    set n to engs:length.
    until not has_clamps() {
		for eng in engs {
			if eng:flameout {
				print "engine failure. aborting.".
                lock throttle to 0.
                set ship:control:pilotmainthrottle to 0.
				return false.
			}
		}
		wait until stage:ready.
		stage.
		list engines in engs.
		if not engs:length = n {
            lock throttle to 0.
            set ship:control:pilotmainthrottle to 0. 
            return false.
        }
		print "stage activated".
		wait 0.75.
	}
    until apoapsis > 80000 {
        // print(ship:body:atm:altitudepressure(altitude)).
        if stage:deltav:current <= 0.0 and stage:ready and ship:body:atm:altitudepressure(altitude) < .5 {
            stage.
        }
    }
    lock throttle to 0.
    set kuniverse:timewarp:rate to 4.
    set wp to waypoint("KSC").
    if addons:tr:available {
        addons:tr:settarget(wp:geoposition).
        wait until altitude > 60000.
        kuniverse:timewarp:cancelwarp.
        wait until kuniverse:timewarp:issettled.
        lock wp_vec to wp:position.
        lock impact_vec to addons:tr:impactpos:position.
        lock delta_vector to wp_vec - impact_vec.
        // vecDraw(V(0,0,0),{return delta_vector.},RGB(1,0,0),"delta_vector",1.0,True, 0.2,True, True).

        lock steering_vec to vxcl(up:vector,delta_vector).
        lock steering to steering_vec.
        // vecDraw(V(0,0,0),{return steering_vec.},RGB(1,0,0),"steering_vector",1.0,True, 0.2,True, True).
        wait until vang(steering_vec, ship:facing:forevector) < 1.
        wait 5.
        list engines in engs.
        for eng in engs {
            if eng:title:contains("swivel") {
                set eng:thrustlimit to 0.
                eng:shutdown.
                break.
            }
        }
        lock throttle to 0.05.
        until steering_vec:mag < 100  or vang(steering_vec, ship:facing:forevector) > 10 {
            clearScreen.
            print steering_vec:mag.
        }
        lock throttle to 0.
        for eng in engs {
            if eng:title:contains("swivel") {
                set eng:thrustlimit to 0.
                eng:activate.
                lock throttle to 0.
                set eng:thrustlimit to 100.
            }
        }
    }
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    lock steering to heading(90,0,90).
    wait 5.
    stage.
    when ship:deltavasl < 300 then {
        until stage:number = 0 {
            wait until stage:ready.
            stage.
        }
    }
    runpath("0:precise_suicide").
}

subtour_main().