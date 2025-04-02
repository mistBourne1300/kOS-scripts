clearScreen.
for p in ship:partsdubbedpattern("chute") {
    print p:name.
    for s in p:suffixnames {
        print s.
    }
    print "/ ".
    print p:alltaggedparts.
    print "/".
    print p:getmodule("reliability"):getfield("parachute").
    // print p:getmodulebyindex(2):allfieldnames.
    break.
}
// print chutes.

// print p:getmodule("ModuleParachute"):getfield("min pressure").

// print p:getmodule("ModuleParachute"):getfield("altitude").

// moduletestsubject
// moduledragmodifier (x2)
// modulecargopart
// reliability
// kosnametag