#pragma once

#include "../Evaluator.hpp"

/**
 * @brief Evaluator that checks whether the signal‑to‑noise ratio (SNR) of the
 *        provided context meets a configured minimum threshold.
 *
 * The evaluator is part of the detection pipeline and can be ordered within a
 * specific evaluation stage. It produces an @ref Evaluation indicating
 * success or failure based on the configured `min_snr`.
 */
class BeamEvaluator : public Evaluator
{
public:
    /**
     * @brief Construct a new BeamEvaluator.
     *
     * @param stage   Evaluation stage in which this evaluator participates.
     * @param order   Ordering within the stage (lower values run earlier).
     */
    BeamEvaluator(
        int stage,
        int order);

    /** Returns the list of feature IDs required by this evaluator. */
    virtual std::vector<FeatureId> requires() const override;

    /** Performs the SNR threshold check and returns an Evaluation. */
    virtual std::unique_ptr<detect_core::Evaluation> evaluate(
        const detect_core::Context& context,
        FeatureState& features) const override;

    /** Returns the stage index for this evaluator. */
    virtual int stage() const override;

    /** Returns the order index within the stage. */
    virtual int order() const override;

private:
    int    stage_;   ///< Evaluation stage.
    int    order_;   ///< Order within the stage.
};