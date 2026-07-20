#pragma once

#include "SimulationObject.hpp"
#include "CoordinateConversions.hpp"

namespace detector
{
namespace util
{

ENU simulationObjectToENU(
    const SimulationObject& obj);

ECEF simulationObjectToECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA);

LLA simulationObjectToLLA(
    const SimulationObject& obj,
    const LLA& referenceLLA);

ECEF simulationObjectVelocityToECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA);

ENU simulationObjectVelocityToENU(
    const SimulationObject& obj);

ECEF simulationObjectAccelerationToECEF(
    const SimulationObject& obj,
    const LLA& referenceLLA);

ENU simulationObjectAccelerationToENU(
    const SimulationObject& obj);

}
}
