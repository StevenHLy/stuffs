#pragma once

/**
 * @file FeatureId.hpp
 * @brief Definition of the @c FeatureId enumeration used to uniquely identify
 *        features within the Detect Core library.
 */

#include <cstdint>
#include <functional>

/**
 * @enum FeatureId
 * @brief Enumerates the supported feature types.
 *
 * Each value corresponds to a specific feature that can be extracted by a
 * @c FeatureExtractor and subsequently used by evaluators.
 */
enum class FeatureId : std::uint32_t
{
    /** Jam‑to‑Noise Ratio */
    JNR = 1,
    /** Signal‑to‑Noise Ratio */
    SNR = 2,
    /** Estimated position of the target object */
    ESTIMATED_POSITION = 3
};

/**
 * @brief Specialisation of @c std::hash for @c FeatureId to enable use as keys in
 *        unordered containers.
 */
namespace std
{
    template<>
    struct hash<FeatureId>
    {
        std::size_t operator()(FeatureId id) const noexcept
        {
            return static_cast<std::size_t>(id);
        }
    };
}