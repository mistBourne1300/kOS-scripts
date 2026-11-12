

function lambert {
    parameter pos1.
    parameter pos2.
    parameter central_body.
    parameter flight_time.
    parameter pro is True.
    parameter maxiter is 100.
    parameter tof_tol is 1e-6.
    if not pos1:istype("Vector") {
        return false.
    }
    if not pos2:istype("Vector") {
        return false.
    }
    if not central_body:istype("body") {
        return false.
    }
    if not flight_time:istype("scalar") {
        return false.
    }
    if flight_time <= 0 {
        return false.
    }


    local r1 to pos1:mag.
    local r2 to pos2:mag.

    if r1 <= 0 or r2 <= 0 {
        return false.
    }

    local delta_theta to vdot(pos1, pos2)/(r1*r2).
    if delta_theta < -1 {
        set delta_theta to -1.
    } else if delta_theta > 1 {
        set delta_theta to 1.
    }
    if abs(abs(delta_theta) - 1) < 1e-9 {
        return false.
    }
    set delta_theta to arcCos(delta_theta).
    local pos1xpos2_z to vcrs(pos1,pos2):Z.
    if pro {
        if pos1xpos2_z < 0 {
            set delta_theta to 360 - delta_theta.
        }
    } else {
        if pos1xpos2_z >= 0 {
            set delta_theta to 360 - delta_theta.
        }
    }

    local A to sin(delta_theta)*sqrt(r1*r2/(1-cos(delta_theta))).

    local z0 to 0.
    local z1 to 1.
    local iter to 0.
    local success to false.
    local fplam to 0.
    until iter > maxiter {
        set iter to iter + 1.
        set fplam to Fprime_lambert(z0, A, r1, r2).
        if abs(fplam) < 1e-9 {
            return False.
        }
        set z1 to z0 - F_lambert(z0, A, r1, r2, central_body, flight_time)/fplam.
        if abs(F_lambert(z1, A, r1, r2, central_body, flight_time)) / sqrt(central_body:mu) < tof_tol {
            set success to true.
            break.
        }
        set z0 to z1.
    }
    if not success {
        return False.
    }
    local ztrue to z1.

    local gamma to gamma_lambert(ztrue, A, r1 ,r2).
    local c to C_lambert(ztrue).
    local s to S_lambert(ztrue).
    local f to 1 - gamma/r1.
    local g to A*sqrt(gamma/central_body:mu).
    local fdot to sqrt(central_body:mu)/(r1*r2)*sqrt(gamma/c)*(ztrue*s - 1).
    local gdot to 1-gamma/r2.

    local v1 to (1/g)*(pos2 - f*pos1).
    local v2 to (gdot/g)*pos2 - pos1*(f*gdot - fdot*g)/g.
    return list(v1,v2).

}

function Fprime_lambert {
    parameter z.
    parameter A.
    parameter r1.
    parameter r2.
    if z = 0 {
        local gammalambert0 to gamma_lambert(0, A, r1, r2).
        return (sqrt(2)/40)*gammalambert0^(3/2) + (A/8)*(sqrt(gammalambert0) + A*sqrt(1/(2*gammalambert0))).
    } else {
        local g to gamma_lambert(z, A, r1, r2).
        local c to C_lambert(z).
        local s to S_lambert(z).
        return (g/c)^(3/2)*((1/(2*z))*(c - (3/2)*(s/c)) + (3/4)*((s^2)/c)) + (A/8)*(3*(s/c)*sqrt(g) + A*sqrt(c/g)).
    }
}

function F_lambert {
    parameter z.
    parameter A.
    parameter r1.
    parameter r2.
    parameter central_body.
    parameter flight_time.
    local gammalambertz to gamma_lambert(z, A, r1, r2).
    return (gammalambertz/C_lambert(z))^(3/2) * S_lambert(z) + A*sqrt(gammalambertz) - sqrt(central_body:mu)*flight_time.
}

function gamma_lambert {
    parameter z.
    parameter A.
    parameter r1.
    parameter r2.
    return r1 + r2 + A*(z*S_lambert(z) - 1)/(sqrt(C_lambert(z))).
}

function sinh {
    parameter x.
    return (constant:e^x - constant:e^(-x))/2.
}

function cosh {
    parameter x.
    return (constant:e^x + constant:e^(-x))/2.
}

function S_lambert {
    parameter z.
    if z > 0 {
        return (sqrt(z) - sin(sqrt(z)))/(z^(3/2)).
    } else if z < 0 {
        return (sinh(sqrt(-z)) - sqrt(-z))/((-z)^(3/2)).
    } else {
        return 1/6.
    }
}

function C_lambert {
    parameter z.
    if z > 0 {
        return (1- cos(sqrt(z)))/z.
    } else if z < 0 {
        return (cosh(sqrt(-z)) - 1)/(-z).
    } else {
        return 1/2.
    }
}