parameter h is "none".
copypath("0:suicide","suicide").
list.
rcs on.
runpath("0:hellfire",h).
print "hellfire finished".
until stage:deltav:current > 0 or stage:number=0{
    wait until stage:ready.
    stage.
}
wait until altitude > 70000.

lock steering to heading(180,0).
wait 5.
lock throttle to 1.
wait until stage:deltav:current = 0.
until stage:number = 0 {
    wait until stage:deltav:current = 0.
    wait until stage:ready.
    stage.
}
lock throttle to 0.
lock steering to srfRetrograde.

print "waiting until atmosphere".
wait until altitude < 70000.
print "waiting until alt < 15000".
wait until altitude < 15000.
print "running suicide".
run suicide.