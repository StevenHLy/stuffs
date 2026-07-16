namespace detect_core {

class DETECT_CORE_API Context
{
public:

    // -----------------------------
    // Simulation Object
    // -----------------------------
    struct DETECT_CORE_API SimulationObject
    {
        // Position
        double x_pos_;
        double y_pos_;
        double z_pos_;

        // Velocity
        double x_vel_;
        double y_vel_;
        double z_vel_;

        // Acceleration
        double x_accel_;
        double y_accel_;
        double z_accel_;

        // Timestamp of this object state
        double object_time_;
    };

    // -----------------------------
    // Context
    // -----------------------------
    Context();

    // Signal / Noise
    void setSignalPower(double value);
    void setNoisePower(double value);

    bool tryGetSignalPower(double& out) const;
    bool tryGetNoisePower(double& out) const;

    // Jammer
    void setJammer(bool value);
    bool hasJammer() const;

    // Current evaluation time
    void setCurrentSystemTime(double value);
    double getCurrentSystemTime() const;

    // Simulation object
    void setSimulationObject(const SimulationObject& obj);
    const SimulationObject& simulationObject() const;

private:

    double signalPower_ = 0.0;
    double noisePower_ = 0.0;

    bool jammer_ = false;

    SimulationObject sim_object_;

    double currentSystemTime_ = 0.0;

    // Future:
    // beamFrequency
    // beamWidth
    // uBeam
    // vBeam
};

} // namespace detect_core
