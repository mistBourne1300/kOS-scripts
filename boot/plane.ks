if kuniverse:activevessel = ship {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
}
function main {
    

    copypath("0:ap.ks","ap.ks").
    if not exists("ap.ks") {
        print("copying ap failed").
        return.
    } else {
        print("ap file saved.").
    }
    if not exists("lib") {
        createDir("lib").
    }
    copypath("0:lib/autopilot_functions.ks","lib/autopilot_functions.ks").
    if not exists("lib/autopilot_functions.ks") {
        print("copying autopilot functions failed.").
    } else {
        print "autopilot functions saved.".
    }

    copypath("0:autoland.ks","autoland.ks").
    if not exists("autoland.ks") {
        print("copying autoland failed.").
    } else {
        print "autoland saved.".
    }
    

}
brakes on.
main().