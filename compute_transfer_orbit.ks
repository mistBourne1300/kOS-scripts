runOncePath("0:lamberts_problem.ks").

// Search a coarse grid of Kerbol-centered transfers from Kerbin to the first
// body after Kerbol in PATH. Returns [launch UT, departure velocity,
// arrival velocity, total delta-v, flight time].
function compute_transfer_orbit {
    parameter orbital1.
    parameter orbital2.
    parameter launch_step.
    parameter flight_step.

    if orbital1:istype("body") and orbital2:istype("body") {
        return interplanetary_transfer(orbital1, orbital2, launch_step, flight_step).
    } else if orbital1:istype("vessel") and orbital2:istype("orbitable") {
        return vessel_capture(orbital1, orbital2, launch_step, flight_step).
    } else {
        return false.
    }

}

function interplanetary_transfer {
    parameter orbital1.
    parameter orbital2.
    parameter launch_step.
    parameter flight_step.

    local period1 to orbital1:orbit:period.
    local period2 to orbital2:orbit:period.
    local synodic_period to period1 * period2 / abs(period1 - period2).
    local min_flight_time to min(period1, period2).
    local max_flight_time to max(period1, period2).

    // Use 1/2 kerbin day (3 hours) for both launch-time and flight-time
    // increments. Returned velocities are Kerbol-centered Lambert endpoint
    // velocities; delta-v includes both endpoints.
    // local launch_step to 21600/2.
    // local flight_step to 21600/2.
    local now to time:seconds.
    local best_delta_v to 1e30.
    local best_launch to false.
    local best_v1 to false.
    local best_v2 to false.
    local best_flight_time to false.

    local launch_time to now.
    until launch_time > now + synodic_period {
        print "searching launch time " + timestamp(Launch_time):calendar.
        local flight_time to min_flight_time.
        until flight_time > max_flight_time {
            local departure_position to positionat(orbital1, timestamp(launch_time)).
            local arrival_time to launch_time + flight_time.
            local arrival_position to positionat(orbital2, timestamp(arrival_time)).
            local solution to lambert(departure_position, arrival_position, orbital1:body, flight_time).

            if solution {
                local v1 to solution[0].
                local v2 to solution[1].
                local orbital1_velocity to velocityat(orbital1, timestamp(launch_time)):orbit.
                local target_velocity to velocityat(orbital2, timestamp(arrival_time)):orbit.
                local total_delta_v to (v1 - orbital1_velocity):mag + (target_velocity - v2):mag.

                if total_delta_v < best_delta_v {
                    set best_delta_v to total_delta_v.
                    set best_launch to launch_time.
                    set best_v1 to v1.
                    set best_v2 to v2.
                    set best_flight_time to flight_time.
                }
            }

            set flight_time to flight_time + flight_step.
        }
        set launch_time to launch_time + launch_step.
    }

    if best_launch = false {
        print "No valid Lambert solution found in the search window.".
        return false.
    }

    return list(best_launch, best_v1, best_v2, best_delta_v, best_flight_time).
}

// Search transfers from a vessel to another orbit around the same body. For
// an escaping vessel, include the impulse needed to first enter a bound orbit.
function vessel_capture {
    parameter orbital1.
    parameter orbital2.
    parameter launch_step.
    parameter flight_step.

    local vessel_orbit to orbital1:orbit.
    if orbital2:orbit:body <> vessel_orbit:body {
        print "Vessel and target must orbit the same body.".
        return false.
    }
    if vessel_orbit:eccentricity < 1 {
        return vessel_capture_from_ellipse(orbital1, orbital2, launch_step, flight_step).
    }

    local vessel_body to vessel_orbit:body.
    local now to time:seconds.
    local capture_time to now + vessel_orbit:eta:periapsis.
    if capture_time < now {
        print "Hyperbolic periapsis has already passed; no future capture burn is available.".
        return false.
    }

    local min_periapsis to max(0, vessel_orbit:periapsis).
    local periapsis_radius to min_periapsis + vessel_body:radius.
    local max_apoapsis to vessel_body:soi - vessel_body:radius - 1.
    if max_apoapsis <= min_periapsis {
        print "No elliptic capture orbit fits inside the sphere of influence.".
        return false.
    }

    // Each candidate captures at the hyperbolic periapsis. Its ellipse shares
    // that periapsis and the hyperbolic orbit's plane, while apoapsis is varied
    // from just inside the SOI down toward periapsis.
    local samples to 12.
    local best to false.
    local best_delta_v to 1e30.
    local hyperbolic_position to vessel_orbit:position.
    local hyperbolic_velocity to vessel_orbit:velocity:orbit.
    local angular_momentum to vcrs(hyperbolic_position, hyperbolic_velocity).
    local hhat to angular_momentum / angular_momentum:mag.
    local eccentricity_vector to vcrs(hyperbolic_velocity, angular_momentum) / vessel_body:mu - hyperbolic_position / hyperbolic_position:mag.
    local periapsis_hat to eccentricity_vector / eccentricity_vector:mag.
    local tangent_hat to vcrs(hhat, periapsis_hat).
    local hyperbolic_periapsis_speed to sqrt(vessel_body:mu * (2 / periapsis_radius - 1 / vessel_orbit:semimajoraxis)).

    local apo_index to 0.
    until apo_index > samples {
        // Start with apoapsis just inside the SOI, then step inward.
        local apo_alt to max_apoapsis - (max_apoapsis - min_periapsis) * apo_index / samples.
        if apo_alt > min_periapsis {
            local apoapsis_radius to apo_alt + vessel_body:radius.
            local semimajoraxis to (periapsis_radius + apoapsis_radius) / 2.
            local capture_speed to sqrt(vessel_body:mu * (2 / periapsis_radius - 1 / semimajoraxis)).
            local periapsis_position to periapsis_hat * periapsis_radius.
            local capture_velocity to tangent_hat * capture_speed.
            local capture_orbit to createorbit(periapsis_position, capture_velocity, vessel_body, capture_time).
            local capture_delta_v to abs(hyperbolic_periapsis_speed - capture_speed).
            local result to vessel_capture_from_ellipse(orbital1, orbital2, launch_step, flight_step, capture_orbit, capture_time).
            if result {
                local total_delta_v to result[3] + capture_delta_v.
                if total_delta_v < best_delta_v {
                    set best to list(result[0], result[1], result[2], total_delta_v, result[4]).
                    set best_delta_v to total_delta_v.
                }
            }
        }
        set apo_index to apo_index + 1.
    }

    if not best {
        print "No valid Lambert solution found for an elliptic capture.".
        return false.
    }
    return best.
}

// candidate_orbit is optional and is used for hypothetical capture ellipses.
function vessel_capture_from_ellipse {
    parameter orbital1.
    parameter orbital2.
    parameter launch_step.
    parameter flight_step.
    parameter candidate_orbit is false.
    parameter search_start is false.

    local orbit1 to orbital1:orbit.
    local trajectory to orbital1.
    if candidate_orbit {
        set orbit1 to candidate_orbit.
        set trajectory to candidate_orbit.
    }
    local period1 to orbit1:period.
    local period2 to orbital2:orbit:period.
    if abs(period1 - period2) < 1e-9 {
        return false.
    }
    local synodic_period to period1 * period2 / abs(period1 - period2).
    local min_flight_time to min(period1, period2).
    local max_flight_time to max(period1, period2).
    local now to time:seconds.
    if search_start {
        set now to search_start.
    }
    local best_delta_v to 1e30.
    local best_launch to false.
    local best_v1 to false.
    local best_v2 to false.
    local best_flight_time to false.

    local launch_time to now.
    until launch_time > now + synodic_period {
        local flight_time to min_flight_time.
        until flight_time > max_flight_time {
            local departure_position to positionat(trajectory, timestamp(launch_time)).
            local arrival_time to launch_time + flight_time.
            local arrival_position to positionat(orbital2, timestamp(arrival_time)).
            local solution to lambert(departure_position, arrival_position, orbit1:body, flight_time).

            if solution {
                local v1 to solution[0].
                local v2 to solution[1].
                local orbital1_velocity to velocityat(trajectory, timestamp(launch_time)):orbit.
                local target_velocity to velocityat(orbital2, timestamp(arrival_time)):orbit.
                local total_delta_v to (v1 - orbital1_velocity):mag + (target_velocity - v2):mag.

                if total_delta_v < best_delta_v {
                    set best_delta_v to total_delta_v.
                    set best_launch to launch_time.
                    set best_v1 to v1.
                    set best_v2 to v2.
                    set best_flight_time to flight_time.
                }
            }
            set flight_time to flight_time + flight_step.
        }
        set launch_time to launch_time + launch_step.
    }

    if best_launch = false {
        return false.
    }
    return list(best_launch, best_v1, best_v2, best_delta_v, best_flight_time).
}
