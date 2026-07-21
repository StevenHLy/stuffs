#pragma once

#include "../../include/detect-core/Evaluation.hpp"
#include "Export.hpp"

/**
 * @file BeamResult.hpp
 * @brief Concrete result type representing the outcome of an SNR threshold evaluator.
 */

namespace detect_core {

/**
 * @class BeamResult
 * @brief Stores whether the SNR threshold was passed and the threshold value used.
 *
 * Instances of this class are produced by @c BeamEvaluator and are stored
 * in an @c Result container. The class derives from @c Evaluation to
 * enable polymorphic handling of different result types.
 */
class DETECT_CORE_API BeamResult : public Evaluation
{
public:
    /**
     * @brief Construct a result with the given pass flag and threshold.
     * @param passed  true if the evaluated SNR meets or exceeds the threshold.
     * @param threshold The SNR threshold value used for the evaluation.
     */
    BeamResult(bool passed);

    /** @brief Query whether the threshold condition was satisfied. */
    bool passed() const;

    /** @brief Retrieve the threshold value associated with this result. */
    double threshold() const;

private:
    bool passed_;        ///< Result of the threshold comparison.
};

} // namespace detect_core