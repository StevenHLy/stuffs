#pragma once

// Export macro for public API symbols
#include "Export.hpp"

/**
 * @file Context.hpp
 * @brief Header defining the @c detect_core::Context class.
 */
/**
 * @class detect_core::Context
 * @brief Encapsulates the input data required for feature extraction and detection evaluation.
 *
 * The @c detect_core::Context should be extended to describe the state of a single object in the
 * simulation as well as attributes of radar propagation.
 * Additional fields are not yet part of the implementation but are documented
 * here to guide future extensions.
 */
namespace detect_core {

class DETECT_CORE_API Context
{
public:
    Context();

    /** Set the measured signal power (dB). */
    void setSignalPower(double value);
    /** Set the measured noise power (dB). */
    void setNoisePower(double value);

    /**
     * @brief Retrieve the signal power if available.
     * @param[out] out Destination for the signal power value.
     * @return true always in this simplified implementation.
     */
    bool tryGetSignalPower(double& out) const;
    /**
     * @brief Retrieve the noise power if available.
     * @param[out] out Destination for the noise power value.
     * @return true always in this simplified implementation.
     */
    bool tryGetNoisePower(double& out) const;

    /** Enable or disable the presence of a jammer. */
    void setJammer(bool v);
    /** Query whether a jammer is present. */
    bool hasJammer() const;

    /** Set current system time. */
    void setCurrentSystemTime(double value);

    /** get current system time. */

    double getCurrentSystemTime() const;

    const SimulationObject& sim_obj() const;


    /**
     * @brief Describes the object in the simulation that we are considering for detectability.
     * 
     */
    struct DETECT_CORE_API SimulationObject
    {
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) x-axis position of the object
        double x_pos_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) y-axis position of the object
        double y_pos_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) z-axis position of the object
        double z_pos_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) x-axis velocity of the object
        double x_vel_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) y-axis velocity of the object
        double y_vel_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) z-axis velocity of the object
        double z_vel_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) x-axis acceleration of the object
        double x_accel_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) y-axis acceleration of the object
        double y_accel_;
        /// @brief  Earth-Centered-Earth-Fixed (ECEF) z-axis acceleration of the object
        double z_accel_;

        /// @brief  current timestamp of the object
        double object_time_;

    };

private:
    /// @brief The power of the radiating signal (in dB)
    double signalPower_ = 0.0;
    /// @brief The power of the noise (in dB) affecting the radiating signal
    double noisePower_ = 0.0;

    /// @brief Whether there is a jammer in the simulation
    bool jammer_ = false;

    /// @brief The object in the simulation that we will assess for detectability
    SimulationObject sim_object_;

    // @todo capture beam attributes. Center beam frequency, beamwidth, beam u & v, etc.

    /// @brief current system time
    double currentSystemTime_;


};

} // namespace detect_core
