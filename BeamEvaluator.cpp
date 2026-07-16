#include "BeamEvaluator.hpp"

#include "../../include/detect-core/Context.hpp"
#include "../../include/detect-core/Evaluation.hpp"
#include "BeamResult.hpp"
#include "../../features/FeatureId.hpp"
#include "../../features/FeatureState.hpp"

using detect_core::Context;
using detect_core::Evaluation;

BeamEvaluator::BeamEvaluator(
    int stage,
    int order)
    :  stage_(stage), order_(order)
{
}

std::vector<FeatureId> BeamEvaluator::requires() const
{
    return {FeatureId::ESTIMATED_POSITION};
}

std::unique_ptr<detect_core::Evaluation> BeamEvaluator::evaluate(
    const Context& context,
    FeatureState& features) const
{
    (void)context;

    auto pos = features.get(FeatureId::ESTIMATED_POSITION).vector();

    bool insideBeam = false; 

    //----------TODO----------------------------------------
    // Beam algorithm goes here
    //--------------------------------------------------

    // Construct a polymorphic result object.
    return std::unique_ptr<detect_core::Evaluation>(
        new detect_core::BeamResult(
            insideBeam));
}

int SnrThresholdEvaluator::stage() const
{
    return stage_;
}

int SnrThresholdEvaluator::order() const
{
    return order_;
}