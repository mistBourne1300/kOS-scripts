// set terminal:width to 50.
// set terminal:height to 16.
if kuniverse:activevessel = ship {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
}

set p to "archive:/boot/alt_pitches.json".
copypath("0:reaper.ks","reaper").

if exists(p) {
    print "path found.".wait .1.
    set l to readJson(p).
    if l:haskey(ship:name) {
        print " " + ship:name + " found.".wait .1.
        print l[ship:name].
    } else {
        print " " + ship:name + " not found in lexicon.".wait .1.
    }
} else {
    print "path not found.".wait .1.
}
print "boot program complete.".