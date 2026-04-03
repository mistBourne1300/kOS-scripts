parameter userhead is 90.
parameter useralt is 7000.
parameter userairspd is 200.
parameter uservsmax is 100.

set km to 1000.
if exists("lib/autopilot_functions.ks") {
    runOncePath("lib/autopilot_functions",userhead, useralt, userairspd, uservsmax).
} else {
    runOncePath("0:/lib/autopilot_functions",userhead, useralt, userairspd, uservsmax).
}


main().

function main {
    // this is intensive to run, so give the kos core more processing power.
    set config:ipu to 1000.
    if not check_status() {
        return.
    }
    clearscreen.
    printinfo().

    sas off.

    set starttime to time:seconds.
    until test_flameout() {
        loop_internals().
    }
    print "releasing controls.".
    set curr_throt to throttle.
    set ship:control:neutralize to true.
    set ship:control:pilotmainthrottle to curr_throt.
    sas on.
    print "performing quicksave.".
	if kuniverse:canquicksave{
		kuniverse:quicksave().
	} else {
		print "quicksaving failed.".
	}
}

function loop_internals {
    update_loops().
    if time:seconds - starttime > 1 {
        printinfo().
        set starttime to time:seconds.
    }
}