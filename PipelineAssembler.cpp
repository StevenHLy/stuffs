#include "PipelineAssembler.hpp"
#include "../feature-extraction/impl/JnrFeatureExtractor.hpp"

// Constructor implementation: simply store a reference to the provided Config.
PipelineAssembler::PipelineAssembler(const detect_core::Config& config) : config_(config)
{
    // No additional initialization required.
}

#include <algorithm>
#include <stdexcept>

std::unique_ptr<Pipeline> PipelineAssembler::assemble()
{
    createFeatureExtractors();
    // Ensure all extractor dependencies are satisfied before creating evaluators.
    validateExtractorRequirements();
    createEvaluators();

    validateEvaluatorRequirements();

    std::sort(
        evaluators_.begin(),
        evaluators_.end(),
        compareEvaluators);
    
    return std::unique_ptr<Pipeline>(
        new Pipeline(
            std::move(registry_),
            std::move(evaluators_)
        )
    );
}

bool PipelineAssembler::compareEvaluators(
    const std::unique_ptr<Evaluator>& lhs,
    const std::unique_ptr<Evaluator>& rhs)
{
    if (lhs->stage() != rhs->stage())
    {
        return lhs->stage() < rhs->stage();
    }

    return lhs->order() < rhs->order();
}

void PipelineAssembler::validateEvaluatorRequirements() const
{
    for (std::size_t i = 0; i < evaluators_.size(); ++i)
    {
        const std::vector<FeatureId> required_features = evaluators_[i]->requires();

        for (std::size_t j = 0; j < required_features.size(); ++j)
        {
            if (!registry_.hasExtractor(required_features[j]))
            {
                throw std::runtime_error("Evaluator requires feature with no extractor.");
            }
        }
    }
}

void PipelineAssembler::validateExtractorRequirements() const 
{
    std::set<FeatureId> visited;
    std::set<FeatureId> recursion_stack;

    const std::vector<FeatureId> registered_features = registry_.getRegisteredFeatures();

    for (std::size_t i = 0; i < registered_features.size(); ++i)
    {
        validateExtractorRequirement(
            registered_features[i],
            visited,
            recursion_stack
        );
    }
}

void PipelineAssembler::validateExtractorRequirement(
    FeatureId feature_id,
    std::set<FeatureId>& visited,
    std::set<FeatureId>& recursion_stack) const
{
    // Already validated
    if (visited.count(feature_id) > 0)
    {
        return;
    }

    // Cycle detected
    if (recursion_stack.count(feature_id) > 0)
    {
        throw std::runtime_error("Feature dependency cycle detected.");
    }

    recursion_stack.insert(feature_id);

    const FeatureExtractor& extractor = registry_.getExtractor(feature_id);

    const std::vector<FeatureId> dependencies = extractor.requires();

    for (std::size_t i = 0; i < dependencies.size(); ++i)
    {
        const FeatureId dependency = dependencies[i];

        if (!registry_.hasExtractor(dependency))
        {
            throw std::runtime_error("Feature dependency has no extractor.");
        }

        validateExtractorRequirement(
            dependency,
            visited,
            recursion_stack
        );
    }

    recursion_stack.erase(feature_id);

    visited.insert(feature_id);
}

void PipelineAssembler::createFeatureExtractors() 
{
    if (config_.jnrExtractorEnabled()) {
        registerExtractor(std::unique_ptr<FeatureExtractor>(new JnrFeatureExtractor()));
    }

    if (config_.snrExtractorEnabled()) {
        registerExtractor(std::unique_ptr<FeatureExtractor>(new SnrFeatureExtractor()));
    }

    if (config_.extrapolateExtractorEnabled()) {
    //    registerExtractor(std::unique_ptr<FeatureExtractor>(new ExtrapolateFeatureExtractor()));
    }
}

void PipelineAssembler::createEvaluators()
{
    if (config_.snrThresholdEvaluatorEnabled()) {
        registerEvaluator(std::unique_ptr<Evaluator>(
            new SnrThresholdEvaluator(
                config_.getSnrThreshold(),                  // min_snr
                config_.getSnrThresholdEvaluatorStage(),    // stage
                config_.getSnrThresholdEvaluatorOrder()     // order
            )));
    }

    // Add your new Evaluator here!
}

// NOTE: Prior to C++17 the order of evaluation of function arguments was unspecified.
// Even though the project sets C++17, some compilers may still evaluate the arguments
// in an order that moves the `extractor` before calling `produces()`, resulting in a
// use‑after‑move and a segfault (observed in the test). To guarantee safety we first
// capture the produced FeatureId, then move the unique_ptr into the registry.
void PipelineAssembler::registerExtractor(std::unique_ptr<FeatureExtractor> extractor)
{
    // Extract the feature identifier *before* moving the extractor.
    FeatureId feature_id = extractor->produces();
    registry_.registerExtractor(feature_id, std::move(extractor));
}

void PipelineAssembler::registerEvaluator(std::unique_ptr<Evaluator> evaluator)
{
    evaluators_.push_back(std::move(evaluator));
}
