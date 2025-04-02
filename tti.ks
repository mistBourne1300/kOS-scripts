// stands for time to impact

main().

function main {
    until ship:status = "landed"{
        clearScreen.
        print "TTI: " + (alt:radar/verticalSpeed).
        wait 0.001.
    }
}