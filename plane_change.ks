parameter inc.

main().

function main {
    print "getting eta to node...".
    set est_time_to_node to get_eta().
    print "eta: " + est_time_to_node.
    set normie to calc_normal(est_time_to_node).
    set retro to calc_retro(est_time_to_node).
    set mynode to node(timespan(est_time_to_node),0,normie,retro).
    add mynode.
}

function sign {
    parameter num.
    if num > 0 {
        return 1.
    } else {
        return -1.
    }
}

function get_eta {
    set currlat to ship:geoposition:lat.
    set time_till to 0.
    set predlat to body:geopositionof(positionat(ship,timestamp(time:seconds + time_till))):lat.
    until abs(predlat) < 0.01 {
        set time_till to time_till + predlat*sign(currlat).
        set predlat to body:geopositionof(positionat(ship,timestamp(time:seconds + time_till))):lat.
    }
    return time_till.
}

function calc_normal {
    parameter est_time_to_node.
    set currlat to ship:geoposition:lat.
    set currinc to ship:orbit:inclination.
    set vel to velocityAt(ship,timestamp(time:seconds + est_time_to_node)):orbit:mag.
    if inc > 0 {
        // next node is descending...
        if currinc < inc {
            // needs antinormal
            return -abs(vel*sin(abs(currinc-inc))).
        } else {
            // needs normal
            return abs(vel*sin(abs(currinc-inc))).
        }
    } else {
        // next node is ascending...
        if currinc < inc {
            // needs normal
            return abs(vel*sin(abs(currinc-inc))).
        } else {
            // needs antinormal
            return -abs(vel*sin(abs(currinc-inc))).
        }
    }
}

function calc_retro {
    parameter est_time_to_node.
    set currinc to ship:orbit:inclination.
    set vel to velocityAt(ship, timestamp(time:seconds + est_time_to_node)):orbit:mag.
    return -vel+vel*cos(abs(currinc-inc)).
}