#pragma once

#include <set>
#include <memory>
#include <vector>

#include "Config.hpp"
#include "../features/FeatureRegistry.hpp"
#include "../detection-evaluation/impl/SnrThresholdEvaluator.hpp"
#include "../feature-extraction/impl/SnrFeatureExtractor.hpp"
#include "Pipeline.hpp"

/**
 * @brief Assembles a @ref Pipeline based on a @ref Config.
 *
 * This class is responsible for:
 *   - Validating that all feature extractor and evaluator dependencies are met.
 *   - Instantiating the required extractors and evaluators.
 *   - Sorting evaluators according to their stage and order.
 *   - Registering extractors in a @ref FeatureRegistry.
 *   - Returning a fully‑configured @c std::unique_ptr&lt;Pipeline&gt; ready for use.
 */
class PipelineAssembler
{
public:
    /** Construct the assembler with the provided configuration. */
    PipelineAssembler(const detect_core::Config& config);

    /** Build and return the assembled pipeline. */
    std::unique_ptr<Pipeline> assemble();

private:
    /** Comparator for ordering evaluators by stage then order. */
    static bool compareEvaluators(const std::unique_ptr<Evaluator>& lhs,
        const std::unique_ptr<Evaluator>& rhs);

    /** Ensure all evaluator requirements are satisfied. */
    void validateEvaluatorRequirements() const;

    /** Ensure all feature extractor requirements are satisfied. */
    void validateExtractorRequirements() const;

    /** Recursive helper to detect circular extractor dependencies. */
    void validateExtractorRequirement(
        FeatureId feature_id,
        std::set<FeatureId>& visited,
        std::set<FeatureId>& recursion_stack
    ) const;

    /** Create feature extractor instances based on the config. */
    void createFeatureExtractors();

    /** Create evaluator instances based on the config. */
    void createEvaluators();

    /** Register a feature extractor with the internal registry. */
    void registerExtractor(std::unique_ptr<FeatureExtractor> extractor);

    /** Register an evaluator for later pipeline assembly. */
    void registerEvaluator(std::unique_ptr<Evaluator> extractor);

    const detect_core::Config& config_;   ///< Reference to the configuration.
    FeatureRegistry           registry_; ///< Registry of created extractors.
    std::vector<std::unique_ptr<Evaluator>> evaluators_; ///< List of evaluators.
};