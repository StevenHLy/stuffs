#include "CoordinateConversions/include/CoordinateConversions.hpp"

namespace common_modules::coordinate_conversions {

/* --------------------------------------------------------------------------------------------------------------------------- */
/* ---------------------------------------------------- LLA <-> ECEF --------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */

/** \brief Convert geodetic coordinates (LLA) to ECEF.
 *  Takes a LLA struct and fills an ECEF struct.
 */
void convertLLAToECEF(const LLA& lla, ECEF& ecef) noexcept {
    double sin_lat = std::sin(lla.latitude);
    double cos_lat = std::cos(lla.latitude);
    double sin_lon = std::sin(lla.longitude);
    double cos_lon = std::cos(lla.longitude);

    double prime_vertical_radius_of_curvature =
        wgs84_semi_major_axis / std::sqrt(1.0 - wgs84_first_eccentricity_squared * sin_lat * sin_lat);

    ecef.x = (prime_vertical_radius_of_curvature + lla.altitude) *
             cos_lat * cos_lon;

    ecef.y = (prime_vertical_radius_of_curvature + lla.altitude) *
             cos_lat * sin_lon;

    ecef.z = (prime_vertical_radius_of_curvature *
             (1 - wgs84_first_eccentricity_squared) + lla.altitude) *
             sin_lat;
}

/** \brief Convert ECEF coordinates to geodetic (LLA).
 *  Takes an ECEF struct and fills a LLA struct.
 */
void convertECEFToLLA(const ECEF& ecef, LLA& lla) noexcept {
    lla.longitude = std::atan2(ecef.y, ecef.x);

    double p = std::sqrt(ecef.x * ecef.x + ecef.y * ecef.y);

    double theta = std::atan2(ecef.z * wgs84_semi_major_axis, p * wgs84_semi_minor_axis);
    double sin_theta = std::sin(theta);
    double cos_theta = std::cos(theta);

    lla.latitude = std::atan2(ecef.z + (wgs84_first_eccentricity_squared * wgs84_semi_minor_axis) *
                             sin_theta * sin_theta * sin_theta,
                             p - wgs84_first_eccentricity_squared * wgs84_semi_major_axis * cos_theta * cos_theta * cos_theta);

    double sin_lat = std::sin(lla.latitude);
    double prime_vertical_radius_of_curvature =
        wgs84_semi_major_axis / std::sqrt(1.0 - wgs84_first_eccentricity_squared * sin_lat * sin_lat);

    lla.altitude = p / std::cos(lla.latitude) - prime_vertical_radius_of_curvature;
}

/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */



/* --------------------------------------------------------------------------------------------------------------------------- */
/* ----------------------------------------------------- ENU -> ECEF --------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */

/* This function rotates the East-North-Up (ENU) vecotrs to align to the Earth-Centered, Earth-Fixed (ECEF) axes
   at the provided reference latitude and longitude. The resulting x, y, and z are not relative to the center of Earth,
   but the reference object originally considered for ENU. I.e., for positional calculations, we now have the distance
   along ECEF axes, but not yet relative to the center of Earth. We will need to add the ECEF positional vector for our
   original ENU reference object to our delta vector calculated here. Think of the "delta" vector as an intermediate
   vector when converting from ENU to ECEF -- correct axes, incorrect reference point.                                         */

void rotateENUVectorToECEFAxes(double east,
    double north,
    double up,
    double reference_latitude_in_radians,
    double reference_longitude_in_radians,
    double& delta_x,
    double& delta_y,
    double& delta_z)
{
    double sin_lat = std::sin(reference_latitude_in_radians);
    double cos_lat = std::cos(reference_latitude_in_radians);
    double sin_lon = std::sin(reference_longitude_in_radians);
    double cos_lon = std::cos(reference_longitude_in_radians);

    delta_x = -sin_lon * east - sin_lat * cos_lon *
              north + cos_lat * cos_lon * up;

    delta_y = cos_lon * east - sin_lat * sin_lon *
              north + cos_lat * sin_lon * up;

    delta_z = cos_lat * north + sin_lat * up;
}

/** \brief Convert ENU position to ECEF position.
 *  Takes an ENU struct, a reference LLA (including altitude), and fills an ECEF struct.
 */
void convertENUPosToECEFPos(const ENU& enu,
    const LLA& reference,
    ECEF& ecef) noexcept {
    // Reference point in ECEF
    ECEF reference_ecef;
    convertLLAToECEF(reference, reference_ecef);

    // Rotate ENU vector
    double delta_x, delta_y, delta_z;
    rotateENUVectorToECEFAxes(enu.east, enu.north, enu.up,
        reference.latitude, reference.longitude,
        delta_x, delta_y, delta_z);

    // Add reference ECEF coordinates
    ecef.x = reference_ecef.x + delta_x;
    ecef.y = reference_ecef.y + delta_y;
    ecef.z = reference_ecef.z + delta_z;
}

/** \brief Convert ENU velocity to ECEF velocity.
 *  Takes an ENU velocity vector and a reference LLA (latitude/longitude) and fills an ECEF velocity vector.
 */
void convertENUVelToECEFVel(const ENU& velocity,
    const LLA& reference,
    ECEF& ecef_velocity) noexcept {
    rotateENUVectorToECEFAxes(velocity.east, velocity.north, velocity.up,
        reference.latitude, reference.longitude,
        ecef_velocity.x, ecef_velocity.y, ecef_velocity.z);
}

/** \brief Convert ENU acceleration to ECEF acceleration.
 *  Takes an ENU acceleration vector and a reference LLA (latitude/longitude) and fills an ECEF acceleration vector.
 */
void convertENUAccToECEFAcc(const ENU& acceleration,
    const LLA& reference,
    ECEF& ecef_acceleration) noexcept {
    rotateENUVectorToECEFAxes(acceleration.east, acceleration.north, acceleration.up,
        reference.latitude, reference.longitude,
        ecef_acceleration.x, ecef_acceleration.y, ecef_acceleration.z);
}

/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */



/* --------------------------------------------------------------------------------------------------------------------------- */
/* ----------------------------------------------------- ECEF -> ENU --------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */

/* This function rotates the Earth-Centered, Earth-Fixed (ECEF) vectors to align to the East-North-Up (ENU) axes
   at the provided reference latitude and longitude. Note, the ECEF "delta" vector is relative to the reference object,
   along the ECEF axes, but not from the center of Earth. Think of the "delta" vector as an intermediate vector when
   converting from ECEF to ENU -- correct axes, incorrect reference point.                                                     */
void rotateECEFVectorToENUAxes(double delta_x,
    double delta_y,
    double delta_z,
    double reference_latitude_in_radians,
    double reference_longitude_in_radians,
    double& east,
    double& north,
    double& up)
{
    double sin_lat = std::sin(reference_latitude_in_radians);
    double cos_lat = std::cos(reference_latitude_in_radians);
    double sin_lon = std::sin(reference_longitude_in_radians);
    double cos_lon = std::cos(reference_longitude_in_radians);

    east  = -sin_lon * delta_x + cos_lon * delta_y;
    north = -sin_lat * cos_lon * delta_x - sin_lat * sin_lon * delta_y + cos_lat * delta_z;
    up    = cos_lat * cos_lon * delta_x + cos_lat * sin_lon * delta_y + sin_lat * delta_z;
}

/** \brief Convert ECEF position to ENU position.
 *  Takes an ECEF struct, a reference LLA (including altitude), and fills an ENU struct.
 */
void convertECEFPosToENUPos(const ECEF& ecef,
    const LLA& reference,
    ENU& enu) noexcept {
    // Reference point in ECEF
    ECEF reference_ecef;
    convertLLAToECEF(reference, reference_ecef);

    // Compute deltas
    double delta_x = ecef.x - reference_ecef.x;
    double delta_y = ecef.y - reference_ecef.y;
    double delta_z = ecef.z - reference_ecef.z;

    // Rotate to ENU
    rotateECEFVectorToENUAxes(delta_x, delta_y, delta_z,
        reference.latitude, reference.longitude,
        enu.east, enu.north, enu.up);
}

void convertECEFVelToENUVel(const ECEF& ecef_velocity,
    const LLA& reference,
    ENU& enu_velocity) noexcept {
    rotateECEFVectorToENUAxes(ecef_velocity.x, ecef_velocity.y, ecef_velocity.z,
        reference.latitude, reference.longitude,
        enu_velocity.east, enu_velocity.north, enu_velocity.up);
}

void convertECEFAccToENUAcc(const ECEF& ecef_acceleration,
    const LLA& reference,
    ENU& enu_acceleration) noexcept {
    rotateECEFVectorToENUAxes(ecef_acceleration.x, ecef_acceleration.y, ecef_acceleration.z,
        reference.latitude, reference.longitude,
        enu_acceleration.east, enu_acceleration.north, enu_acceleration.up);
}

/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------------------------- */

} // namespace common_modules::coordinate_conversions
