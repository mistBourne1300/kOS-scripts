// this script assumes a stable orbit has already been reached.
// it will automatically warp to the nearest apsis, then cancel the warp,
// perform any possible/necessary burns, then warp to the next apsis.
// it will continue to warp and burn until the orbit is circularized

///////////////////

// it sort of works. it will warp to next node, then do some funky stuff with the time warp. I think it's repeatedly calling the 

parameter desiredapo.
parameter desiredperi.
set apocirctol to desiredapo/80.
set pericirctol to desiredperi/80.

if desiredapo < desiredperi {
	set temp to desiredapo.
	set desiredapo to desiredperi.
	set desiredperi to temp.
	print "switched apo (" + desiredapo + ") and peri (" + desiredperi.
}

// constant sec time to node.
// circularization() will try to keep the time to the next node 
// at this value
set timetonode to 10.

// maximum allowed influence from dpitch.
set dpitchmax to 10.

main().


function main {
	until abs(desiredapo - apoapsis) < apocirctol and abs(desiredperi - periapsis) < pericirctol {
		warptonext().
		circularize().
	}
}

function warptonext {
	if eta:apoapsis < eta:periapsis {
		// warp to apoapsis
		kuniverse:timewarp:warpto(time:seconds + eta:apoapsis - 60).
		wait until kuniverse:timewarp:issettled.
		wait until kuniverse:timewarp:warp = 0.
	} else {
		// warp to periapsis
		kuniverse:timewarp:warpto(time:seconds + eta:periapsis - 60).
		wait until kuniverse:timewarp:issettled.
		wait until kuniverse:timewarp:warp = 0.
	}
}

function circularize {
	if eta:apoapsis > eta:periapsis {
		// near apoapsis, burning to affect periapsis
		if apoapsis < desiredapo {
			raiseapo().
		} else {
			lowerapo().
		}
	} else {
		// near periapsis, burning to affect apoapsis
		if periapsis < desiredperi {
			raiseperi().
		} else {
			lowerperi().
		}
	}
}

function raiseperi {
	// clearscreen.
	print "turning prograde to raise periapsis".
	set tminus to eta:apoapsis.
	lock steering to prograde.
	until abs(desiredperi - periapsis) < pericirctol or tminus > eta:periapsis {
		set tminus to eta:apoapsis.
		// throttle control based on time to apoapsis
		if tminus < timetonode {
			lock throttle to timetonode - tminus + 0.01.
		} else {
			lock throttle to 0.
		}

		// pitch control based on current apoapsis
		// it looks at the current apo, then tries to 
		set dpitch to (desiredapo - apoapsis)/apocirctol.
		if dpitch < -dpitchmax {
			set dpitch to -dpitchmax.
		} else if dpitch > dpitchmax {
			set dpitch to dpitchmax.
		}
		lock steering to prograde + r(0,dpitch,0).

	}
	lock throttle to 0.
	wait until eta:apoapsis > eta:periapsis.
}

function lowerperi { // some additional thinking required here
	// clearscreen.
	print "turning retrograde to lower periapsis".
	set tminus to eta:apoapsis.
	lock steering to retrograde.
	until abs(desiredperi - periapsis) < pericirctol or tminus > eta:periapsis {
		set tminus to eta:apoapsis.
		if tminus < timetonode {
			lock steering to retrograde.
			lock throttle to 1.
		} else {
			lock throttle to 0.
		}
	}
	lock throttle to 0.
	wait until eta:apoapsis > eta:periapsis.
}

function raiseapo {
	// clearscreen.
	print "turning prograde to raise apoapsis".
	set tminus to eta:periapsis.
	lock steering to prograde.
	until abs(desiredapo - apoapsis) < apocirctol or tminus > eta:apoapsis {
		set tminus to eta:periapsis.
		if tminus < timetonode {
			lock steering to prograde.
			lock throttle to 1.
		} else {
			lock throttle to 0.
		}
		
	}
	lock throttle to 0.
	wait until eta:periapsis > eta:apoapsis.
}

function lowerapo {
	// clearscreen.
	print "turning retrograde to lower apoapsis".
	set tminus to eta:periapsis.
	lock steering to retrograde.
	until abs(desiredapo - apoapsis) < apocirctol or tminus > eta:apoapsis{
		set tminus to eta:periapsis.
		if tminus < timetonode {
			lock throttle to timetonode - tminus + 0.01.
		} else {
			lock throttle to 0.
		}

		set dpitch to (periapsis - desiredperi)/1000.
		if dpitch < -dpitchmax {
			set dpitch to -dpitchmax.
		} else if dpitch > dpitchmax {
			set dpitch to dpitchmax.
		}

		lock steering to retrograde + r(0,dpitch,0).
		// if tminus
	}
	lock throttle to 0.
	wait until eta:periapsis > eta:apoapsis.
}