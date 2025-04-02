parameter desiredperi.

main().

function main {
	deorbit().
	wait until altitude < 65000.
	stageall().
}

function deorbit {
	print "turning retrograde.".
	lock steering to retrograde.
	wait 13.
	print "beginning deorbit.".
	lock throttle to 1.
	wait until periapsis < (desiredperi+1).
	lock throttle to 0.
	clearscreen.
	print "craft is now suborbital.".
	wait 2.5.
	print "please return seatback and tray tables".
	print "to their locked and upright position.".
	wait 5.
	print "and stow all carryon items.".
	wait 2.5.
	print "notice the seatbelt sign is on".
	print "we ask that you remain seated for the remainder of the flight.".
	wait 5.
	print "we have enjoyed having you on kerbal science spacelines.".
}

function stageall {
	until stage:number = 0 { if stage:ready{stage.} wait 1.}
}