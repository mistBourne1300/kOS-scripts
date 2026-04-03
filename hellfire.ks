parameter h is "none".

main().

function main {
	lock steering to up.
	lock throttle to 1.

	if not (h = "none") {
		if h < 1000 {
			set h to h*1000.
		}
	}

	burn_like_hell().
	wait until verticalSpeed < 0.
	lock steering to heading(90, 0, 0).
	// wait until alt:radar < 1000.
}

function burn_like_hell {
	set goon to true.
	if not (h = "none") {
		print "setting up apoapsis limit for " + (h/1000) + " km".
		when apoapsis > h - 10000 then {
			lock throttle to (h-apoapsis)/10000.
			wait until verticalSpeed < 0.
			set goon to false.
			lock throttle to 0.
			set ship:control:pilotmainthrottle to 0.
			unlock throttle.
			return.
		}
	}

	// don't stop until we run out of engines (in which case we break)
	until stage:number = 0 or (not goon) {
		if stage:deltav:current <= 0 {
			wait until stage:ready.
			stage.
		}
		if vang(up:vector,ship:facing:forevector) > 10 {
			lock throttle to 0.2.
		} else {
			lock throttle to 1.
		}
		wait 0.01.
	}
	until stage:deltav:current = 0 or (not goon) {
		if vang(up:vector,ship:facing:forevector) > 10 {
			lock throttle to 0.2.
		} else {
			lock throttle to 1.
		}
		wait 0.01.
	}
}