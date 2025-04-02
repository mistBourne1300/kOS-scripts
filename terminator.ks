parameter vessel_to_destroy.

main().

function main {
	set term to vessel(vessel_to_destroy).
	wait until ship:unpacked.
	print "ship unpacked, launching".
	lock steering to up.
	lock throttle to 1.
	stage.
	wait 1.
	lock steering to term:positionAt(time:seconds + 0.01).
	until false {
		wait 0.001.
	}
}

function get_heading {
	return target.
}

