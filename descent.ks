// Created by Chase Ford on Jan 15, 2023
// no parameters, will simply blindly descend to the surface of a non-atmospheric body.
// it will keep the surface speed around 10% of the surface altitude, until landed.

// function decend_throttle {
// 	set desspeed to alt:radar/10.
// 	lock throttle to (surfaceSpeed-desspeed) + 0.01.
// }

set bnds to ship:bounds.

function initial_descent {
	if altitude/10 > airspeed {
		return 0.01.
	}
	return airspeed-(altitude/10).
}

function final_descent {
	if alt:radar/5 > airspeed {
		return 0.01.
	}
	return (airspeed-(alt:radar/5)).
}

function touchdown {
	if bnds:bottomaltradar/10 > -1*verticalSpeed {
		return 0.01.
	}
	return (-1*verticalSpeed-1-(bnds:bottomaltradar/10)).
}


function main {
	clearscreen.
	print "descent script active".
	wait until airspeed > altitude/10 or alt:radar < 5000.
	sas off.
	print "throttle set to 1/10th altitude".
	lock steering to srfRetrograde.
	lock throttle to initial_descent().
	wait until alt:radar < 1000.
	print "radar altitude 1000m".
	lock throttle to final_descent().
	wait until alt:radar < 50.
	// lock steering to up.
	set gear to true.
	lock throttle to touchdown().
	wait until ship:status="LANDED".
	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	lock steering to up.
	wait 5.
	unlock steering.
	sas on.
}

main().