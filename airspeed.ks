parameter desairspd.

main().

function main {
	print "program active.".
	wait until alt:radar > 10.
    set throtkp to 0.1.
	set throtki to 0.01.
	set throtkd to 0.1.
	set minthrot to 0.0.
	set maxthrot to 1.0.
	set throtpid to pidloop(throtkp, throtki, throtkd, minthrot, maxthrot).
	set throtpid:setpoint to desairspd.
	set throt to 1.0.
	lock throttle to throt.

	

    until alt:radar < 10 {
        set throt to throtpid:update(time:seconds, airspeed).
        wait 0.001.
    }
    set ship:control:pilotmainthrottle to 0.
}