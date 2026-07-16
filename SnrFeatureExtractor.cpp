#include "SnrFeatureExtractor.hpp"

#include <cmath>

// Default constructor – currently does no special initialization.
SnrFeatureExtractor::SnrFeatureExtractor()
{
    // No-op: all necessary setup is performed by the base class.
}

FeatureId SnrFeatureExtractor::produces() const 
{
    return FeatureId::SNR;
}

std::vector<FeatureId> SnrFeatureExtractor::requires() const
{
    return {FeatureId::JNR};
}

FeatureValue SnrFeatureExtractor::extract(const Context& context, FeatureState& state) const
{
    double signal_power = 0.0;
    double noise_power = 0.0;

    if (!context.tryGetSignalPower(signal_power) ||
        !context.tryGetNoisePower(noise_power))
    {
        return FeatureValue(0.0);
    }

    if (noise_power <= 0.0)
    {
        return FeatureValue(0.0);
    }

    double jnr = state.get(FeatureId::JNR).scalar();

    // TODO: Make this a non-bogus operation for SNR. Just using this basic calculation to showcase framework.
    double snr = (signal_power / noise_power) * jnr;

    return FeatureValue(snr);
}