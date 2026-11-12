// Given an interplanetary transfer result, find parking-orbit LAN options that
// place the ejection hyperbola in the requested inclination plane.
//
// transfer_result is the list returned by interplanetary_transfer:
// [departure UT, departure velocity, arrival velocity, total delta-v, flight time].
// Returns [LAN options, ideal ejection delta-v, hyperbolic excess velocity,
// departure UT, seconds until each launch-site alignment, alignment UTs]. An empty LAN list means no orbit with the requested
// inclination contains the ejection vector. A list containing false means the
// LAN is undefined because the orbit is equatorial or the ejection vector is
// polar.
function compute_ejection_parking_orbit {
    parameter departure_body.
    parameter transfer_result.
    parameter parking_altitude.
    parameter inclination.
    parameter launch_latitude is ship:latitude.
    parameter launch_longitude is ship:longitude.

    if not departure_body:istype("body") or not transfer_result:istype("list") {
        return false.
    }
    if transfer_result:length < 2 or parking_altitude < 0 or inclination < 0 or inclination > 180 {
        return false.
    }

    local departure_ut to transfer_result[0].
    local transfer_velocity to transfer_result[1].
    local body_velocity to velocityat(departure_body, timestamp(departure_ut)):orbit.
    local vinfinity to transfer_velocity - body_velocity.
    local vinfinity_speed to vinfinity:mag.
    local parking_radius to departure_body:radius + parking_altitude.
    local circular_speed to sqrt(departure_body:mu / parking_radius).
    local periapsis_escape_speed to sqrt(vinfinity_speed^2 + 2 * departure_body:mu / parking_radius).
    local ejection_delta_v to periapsis_escape_speed - circular_speed.

    local body_rotation_axis to departure_body:angularvel.
    if body_rotation_axis:mag < 1e-9 {
        return false.
    }
    local pole to body_rotation_axis / body_rotation_axis:mag.
    local reference_projection to solarprimevector - pole * vdot(solarprimevector, pole).
    if reference_projection:mag < 1e-9 {
        return false.
    }
    local reference_axis to reference_projection / reference_projection:mag.
    local transverse_axis to vcrs(pole, reference_axis).
    local vinfinity_x to vdot(vinfinity, reference_axis).
    local vinfinity_y to vdot(vinfinity, transverse_axis).
    local vinfinity_z to vdot(vinfinity, pole).
    local horizontal_speed to sqrt(vinfinity_x^2 + vinfinity_y^2).
    local sin_inclination to sin(inclination).
    local cos_inclination to cos(inclination).
    local lan_options to list().
    local tolerance to 1e-9.

    if horizontal_speed < tolerance {
        if abs(cos_inclination) > tolerance {
            return list(lan_options, ejection_delta_v, vinfinity, departure_ut, list(), list()).
        }
        lan_options:push(false).
        return list(lan_options, ejection_delta_v, vinfinity, departure_ut, list(false), list(false)).
    }

    if abs(sin_inclination) < tolerance {
        if abs(vinfinity_z) > tolerance {
            return list(lan_options, ejection_delta_v, vinfinity, departure_ut, list(), list()).
        }
        lan_options:push(false).
        return list(lan_options, ejection_delta_v, vinfinity, departure_ut, list(false), list(false)).
    }

    // A plane with inclination i and LAN Ω has normal
    // [sin(i)sin(Ω), -sin(i)cos(Ω), cos(i)]. The ejection vector must lie in
    // that plane, so solve dot(normal, vinfinity) = 0 for Ω.
    local sin_offset to -cos_inclination * vinfinity_z / (sin_inclination * horizontal_speed).
    if sin_offset < -1 - tolerance or sin_offset > 1 + tolerance {
        return list(lan_options, ejection_delta_v, vinfinity, departure_ut, list(), list()).
    }
    if sin_offset < -1 {
        set sin_offset to -1.
    } else if sin_offset > 1 {
        set sin_offset to 1.
    }

    local offset to arcsin(sin_offset).
    local horizontal_angle to arctan2(-vinfinity_y, vinfinity_x).
    local lan1 to mod(horizontal_angle + offset + 360, 360).
    local lan2 to mod(horizontal_angle + 180 - offset + 360, 360).
    lan_options:push(lan1).
    if abs(lan2 - lan1) > tolerance and abs(abs(lan2 - lan1) - 360) > tolerance {
        lan_options:push(lan2).
    }

    // Find the last time before departure that the launch site lies on the
    // ascending ground-track crossing for each LAN. ROTATIONANGLE is measured
    // from Solar Prime, so adding the site's longitude gives its inertial
    // longitude at the current UT.
    local node_times_to to list().
    local node_uts to list().
    local now to time:seconds.
    local rotation_period to departure_body:rotationperiod.
    local current_site_longitude to mod(departure_body:rotationangle + launch_longitude + 360, 360).
    local site_latitude_offset_sine to -tan(launch_latitude) * cos_inclination / sin_inclination.

    for lan in lan_options {
        if abs(site_latitude_offset_sine) > 1 or lan = false {
            node_times_to:push(false).
            node_uts:push(false).
        } else {
            local site_longitude_offset to arcsin(site_latitude_offset_sine).
            local target_site_longitude to mod(lan - site_longitude_offset + 360, 360).
            local phase_to_next_node to mod(target_site_longitude - current_site_longitude + 360, 360).
            local next_node_ut to now + phase_to_next_node * rotation_period / 360.
            local node_ut to next_node_ut.

            if node_ut > departure_ut {
                set node_ut to node_ut - rotation_period.
            } else {
                set node_ut to node_ut + floor((departure_ut - node_ut) / rotation_period) * rotation_period.
            }

            if node_ut < now {
                node_times_to:push(false).
                node_uts:push(false).
            } else {
                node_times_to:push(node_ut - now).
                node_uts:push(node_ut).
            }
        }
    }

    return list(lan_options, ejection_delta_v, vinfinity, departure_ut, node_times_to, node_uts).
}
