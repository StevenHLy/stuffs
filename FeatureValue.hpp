/**
 * @file FeatureValue.hpp
 * @brief Declaration of the @c FeatureValue class which represents a feature value
 *        that can be either a scalar or a vector of scalars.
 *
 * The Detect‑Core library stores extracted feature data using this lightweight
 * container. It abstracts the underlying storage so that callers can treat a
 * value uniformly regardless of whether it is a single double or a sequence of
 * doubles.
 */

#pragma once

#include <vector>
#include <cassert>

/**
 * @class FeatureValue
 * @brief Holds a feature value that may be either a scalar or a vector.
 *
 * The class tracks the current @c Type and provides type‑specific accessors.
 * It is deliberately simple – no heap allocation is performed for scalar
 * values, while vector values are stored directly in a @c std::vector<double>.
 */
class FeatureValue 
{
public:
    /**
     * @brief Enumerates the possible storage kinds for a feature value.
     */
    enum class Type
    {
        /** A single double value */
        Scalar,
        /** A vector of double values */
        Vector
    };

    /**
     * @brief Default‑constructs an empty scalar value (0.0).
     */
    FeatureValue();

    /**
     * @brief Constructs a scalar feature value.
     * @param v The scalar value to store.
     */
    explicit FeatureValue(double v);

    /**
     * @brief Constructs a vector feature value.
     * @param v The vector of values to store.
     */
    explicit FeatureValue(std::vector<double> v);

    /**
     * @brief Returns the current storage type.
     */
    Type getType() const;

    /**
     * @brief Provides mutable access to the scalar value.
     * @pre The stored type must be @c Type::Scalar.
     */
    double& scalar();

    /**
     * @brief Provides read‑only access to the scalar value.
     * @pre The stored type must be @c Type::Scalar.
     */
    const double& scalar() const;

    /**
     * @brief Provides mutable access to the underlying vector.
     * @pre The stored type must be @c Type::Vector.
     */
    std::vector<double>& vector();

    /**
     * @brief Provides read‑only access to the underlying vector.
     * @pre The stored type must be @c Type::Vector.
     */
    const std::vector<double>& vector() const;

private:
    /** The current type of the stored value */
    Type type_;

    /** Scalar storage – valid when @c type_ == Type::Scalar */
    double scalar_;
    /** Vector storage – valid when @c type_ == Type::Vector */
    std::vector<double> vector_;
};