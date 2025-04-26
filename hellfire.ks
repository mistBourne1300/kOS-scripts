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
}

function burn_like_hell {
	set goon to true.
	if not (h = "none") {
		print "setting up apoapsis limit.".
		when apoapsis > h then {
			lock throttle to (h-apoapsis)/10000.
			wait until altitude > 70000.
			set goon to false.
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