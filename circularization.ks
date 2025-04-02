parameter circ is "apo".

circ_main().

function circ_main {
    if circ = "apo" {
        circ_apo().
    } else {
        circ_peri().
    }
}

function circ_apo {
    local apo_time is eta:apoapsis.
    set circnode to node(timespan(apo_time), 0 ,0, 0).
	set r1 to periapsis + body:radius.
	set r2 to apoapsis + body:radius.
	set circnode:prograde to sqrt(body:mu/r2)*(1-sqrt(2*r1/(r1+r2))).
    add circnode.
}

function circ_peri {
    local peri_time is eta:periapsis.
    set circnode to node(timespan(peri_time), 0 ,0, 0).
	set r1 to periapsis + body:radius.
	set r2 to apoapsis + body:radius.
	set circnode:prograde to -sqrt(body:mu/r1)*(sqrt(2*r2/(r1+r2))-1).
    add circnode.
}