parameter srb.

main().

function main {
	if srb{
		stage.
	}
	lock throttle to 1.
	burn_like_hell().
}

function burn_like_hell {
	set done to false.
	// don't stop until we run out of engines (in which case we break)
	until done=true {
		print("recalculating lit engines").
		set recalculate to false.
		list engines in engs.
		set candles to list().
		for eng in engs {
			if eng:ignition {candles:add(eng).}
		}
		if candles:empty {break.}
		until recalculate {
			for eng in candles {
				if eng:flameout {
					stage.
					set recalculate to True.
					break.
				}
			}
			wait .001.
		}
		
	}
}