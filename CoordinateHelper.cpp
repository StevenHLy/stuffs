/******************************************************************************
 * @file CoordinateHelper.cpp
 *
 * @brief Helper functions for adapting SimulationObject to coordinate types.
 *
 * This file does NOT implement any coordinate conversion algorithms.
 * Instead, it converts the SimulationObject representation into the
 * coordinate structures (ENU, ECEF, LLA) required by
 * CoordinateConversions.cpp.
 *
 * All mathematical coordinate transformations are delegated to the
 * existing CoordinateConversions library.
 ******************************************************************************/

#include "CoordinateHelper.hpp"
#include "CoordinateConversions.hpp"

namespace detector
{
namespace util
{

/******************************************************************************
 * @brief Convert SimulationObject position to ENU coordinates.
 *
 * Assumes SimulationObject stores position in the local ENU frame.
 *
 * @param obj Simulation object.
 * @return ENU position.
 *****************************************************************************/
ENU CoordinateHelper::toENU(
    const SimulationObject& obj)
{
    ENU enu;

    enu.east  = obj.x_pos_;
    enu.north = obj.y_pos_;
    enu.up    = obj.z_pos_;

    return enu;
}

/******************************************************************************
 * @brief Convert SimulationObject position to ECEF coordinates.
 *
 * Position is first adapted to ENU and then converted to ECEF using the
 * existing CoordinateConversions implementation.
 *
 * @param obj Simulation object.
 * @param referenceLLA Radar/reference location.
 * @return Position expressed in ECEF.
 *****************************************************************************/
ECEF CoordinateHelper::toECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA)
{
    ENU enu = toENU(obj);

    ECEF ecef;

    convertENUPosToECEFPos(
        enu,
        referenceLLA,
        ecef);

    return ecef;
}

/******************************************************************************
 * @brief Convert SimulationObject position to LLA coordinates.
 *
 * Position is converted:
 *      ENU -> ECEF -> LLA
 *
 * @param obj Simulation object.
 * @param referenceLLA Radar/reference location.
 * @return Position expressed as latitude, longitude and altitude.
 *****************************************************************************/
LLA CoordinateHelper::toLLA(
    const SimulationObject& obj,
    const LLA& referenceLLA)
{
    ECEF ecef = toECEF(
        obj,
        referenceLLA);

    LLA lla;

    convertECEFToLLA(
        ecef,
        lla);

    return lla;
}

/******************************************************************************
 * @brief Convert SimulationObject velocity to ENU.
 *
 * Assumes velocity is stored in the local ENU frame.
 *
 * @param obj Simulation object.
 * @return ENU velocity.
 *****************************************************************************/
ENU CoordinateHelper::velocityToENU(
    const SimulationObject& obj)
{
    ENU velocity;

    velocity.east  = obj.x_vel_;
    velocity.north = obj.y_vel_;
    velocity.up    = obj.z_vel_;

    return velocity;
}

/******************************************************************************
 * @brief Convert SimulationObject velocity to ECEF.
 *
 * Uses the existing CoordinateConversions implementation.
 *
 * @param obj Simulation object.
 * @param referenceLLA Radar/reference location.
 * @return Velocity expressed in ECEF.
 *****************************************************************************/
ECEF CoordinateHelper::velocityToECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA)
{
    ENU velocity = velocityToENU(obj);

    ECEF ecefVelocity;

    convertENUVelToECEFVel(
        velocity,
        referenceLLA,
        ecefVelocity);

    return ecefVelocity;
}

/******************************************************************************
 * @brief Convert SimulationObject acceleration to ENU.
 *
 * Assumes acceleration is stored in the local ENU frame.
 *
 * @param obj Simulation object.
 * @return ENU acceleration.
 *****************************************************************************/
ENU CoordinateHelper::accelerationToENU(
    const SimulationObject& obj)
{
    ENU acceleration;

    acceleration.east  = obj.x_accel_;
    acceleration.north = obj.y_accel_;
    acceleration.up    = obj.z_accel_;

    return acceleration;
}

/******************************************************************************
 * @brief Convert SimulationObject acceleration to ECEF.
 *
 * Uses the existing CoordinateConversions implementation.
 *
 * @param obj Simulation object.
 * @param referenceLLA Radar/reference location.
 * @return Acceleration expressed in ECEF.
 *****************************************************************************/
ECEF CoordinateHelper::accelerationToECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA)
{
    ENU acceleration = accelerationToENU(obj);

    ECEF ecefAcceleration;

    convertENUAccToECEFAcc(
        acceleration,
        referenceLLA,
        ecefAcceleration);

    return ecefAcceleration;
}

} // namespace util
} // namespace detector
