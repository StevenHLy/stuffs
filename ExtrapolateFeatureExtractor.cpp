#include "JnrFeatureExtractor.hpp"

#include <cmath>

// Default constructor – currently does no special initialization.
JnrFeatureExtractor::JnrFeatureExtractor()
{
    // No-op: the extractor relies solely on the provided Context.
}

FeatureId JnrFeatureExtractor::produces() const 
{
    return FeatureId::JNR;
}

std::vector<FeatureId> JnrFeatureExtractor::requires() const
{
    return {};
}

FeatureValue JnrFeatureExtractor::extract(const Context& context, FeatureState& state) const
{
    if (!context.hasJammer())
    {
        return FeatureValue(0.0);
    }

    // TODO: Make this a non-bogus operation for JNR. Just using this basic calculation to showcase framework.
    return FeatureValue(0.5);
}