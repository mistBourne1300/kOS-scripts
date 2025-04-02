function get_stage_ISP {
	list engines in engs.
	local numer is 0.
	local denom is 0.
	for eng in engs {
		if eng:ignition {
			set numer to numer + eng:availablethrust.
			set denom to denom + eng:availablethrust/eng:isp.
		}
	}
	return numer/denom.
}

set isp to get_stage_ISP().

set g0 to constant():g0.
set m0 to ship:mass.
set m1 to ship:drymass.

print "total ship dv (based on isp of current stage): " + (isp*g0*ln(m0/m1)).