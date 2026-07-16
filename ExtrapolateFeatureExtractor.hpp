#pragma once

/**
 * @file JnrFeatureExtractor.hpp
 * @brief Header for the JNR (Jam-to-Noise Ratio) feature extractor.
 */

#include "../FeatureExtractor.hpp"

/**
 * @class JnrFeatureExtractor
 * @brief Extracts the JNR feature from a @c Context.
 *
 * The extractor declares no prerequisite features and produces the
 * @c FeatureId::JNR value. Implementation details are in the corresponding .cpp
 * file.
 */
class JnrFeatureExtractor : public FeatureExtractor
{
public:
    /** Default constructor. */
    JnrFeatureExtractor();

    /** @brief Returns the FeatureId produced by this extractor. */
    virtual FeatureId produces() const override;

    /** @brief No required features for JNR extraction. */
    virtual std::vector<FeatureId> requires() const override;

    /**
     * @brief Perform the JNR extraction.
     * @param context The detection context containing signal information.
     * @param state   Mutable feature state (unused for JNR).
     * @return The computed JNR @c FeatureValue.
     */
    virtual FeatureValue extract(const Context& context, FeatureState& state) const override;
};