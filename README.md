# DetectCore

**DetectCore** is a lightweight, extensible C++ library that provides real-time modeling and simulation of radar detectability via configurable feature extraction and detection evaluation strategies.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Concepts](#key-concepts)
   * [`FeatureExtractor` & `Evaluator`](#feature-extractor--evaluator)
   * [`Model`](#model)
   * [`Config`](#config)
   * [`Pipeline`](#pipeline)
   * [`FeatureRegistry` & `FeatureState`](#feature-registry--extractors)

3. [Building & Installing](#building--installing)
4. [Usage Example](#usage-example)
5. [Extending the Library](#extending-the-library)
6. [Testing](#testing)

---

## API Workflow

The user code interacts with the DetectCore public API as follows:

1. **Configure** the `Model` by constructing it with a `Config` object instance that describes the set of enabled `FeatureExtractor` and `Evaluator` implementations.
2. **Create** the `Context`, capturing the radar simulation environment for a single object at a single point in time.
4. **Execute** the underlying `Pipeline` by passing the  `Context` instance to the `Model`: *run(const Context&)* function.



---

## Key Concepts

### `FeatureExtractor` & `Evaluator`

`FeatureExtractor` and `Evaluator` are abstract classes that encsapulate various techniques for computing radar environment features derived from `Context` and evaluating whether an object in the simulation is detectable.

`FeatureExtractor`'s `produces()` and `requires()` functions support declarative dependencies that are validated during initialization within the `PipelineAssembler`.

```cpp
class FeatureExtractor
{
public:
    virtual ~FeatureExtractor() = default;

    virtual FeatureId produces() const = 0;

    virtual std::vector<FeatureId> requires() const = 0;

    virtual FeatureValue extract(const Context& ctx,      FeatureState& state) const = 0;
};
```

Similarly, `Evaluator` contains a `requires()` function definition. 

```cpp
class Evaluator
{
public:
    virtual ~Evaluator() {}

    virtual std::vector<FeatureId> requires() const = 0;

    virtual std::unique_ptr<detect_core::Evaluation> evaluate(const detect_core::Context& ctx, FeatureState& features) const = 0;

    virtual Config::Stage stage() const = 0;

    virtual Config::Order order() const = 0;
}
```
`Evaluator` only consumes `FeatureValue`, while `FeatureExtractor` implementations may require the output from another `FeatureExtractor` (e.g., SNRFeatureExtractor uses the `FeatureValue` associated with `FeatureId::JNR`).

`Config::Stage` and `Config::Order` facilitate prioritizing the execution of certain `Evaluator` implementations. This supports the ability for the `Pipeline` to be configured to return early from a `run()` based on `Evaluation` output.

### `Model`

```cpp
class DETECT_CORE_API Model {
public:
    explicit Model(const Config& config);
    Result run(const Context& context) const;
private:
    std::unique_ptr<Pipeline> pipeline_;
};
```

The `Model` is based on a façade design pattern and abstracts real-time pipeline processing of DetectCore into a single API call.

### `Config`

The `Config` class enables or disables `FeatureExtractor` and `Evaluator` implementations.

The following built-in extractors and evaluators ship with the library:

* **JNR Feature Extractor** - a `FeatureExtractor` that provides the `FeatureValue` associated with `FeatureId::JNR` for a given `Context`.
* **SNR Feature Extractor** – a `FeatureExtractor` that provides the `FeatureValue` associated with `FeatureId::SNR` for a given `Context`.
* **SNR Threshold Evaluator** – a `DetectionEvaluator` that determines whether the `FeatureValue` associated with `FeatureId::SNR` is within the threshold specified by the `Config`.

Typical usage:

```cpp
Config cfg;
cfg.enableSnrExtractor();
cfg.enableSnrThresholdEvaluator(Stage::FIRST_STAGE, Order::FIRST_ORDER, /*snr_threshold=*/5.0);
```

### `Pipeline`

The `Pipeline` executes each `Evaluator` implementation, aggregating the returned `Evaluation` data into a cohesive `Result` to be consumed by the user.

```cpp
class Pipeline {
public:
    Pipeline(FeatureRegistry registry,
             std::vector<std::unique_ptr<Evaluator>> evaluators);
    Result run(const Context& context) const;
private:
    FeatureRegistry registry_;
    std::vector<std::unique_ptr<Evaluator>> evaluators_;
};
```

The `run` function will create a `FeatureState` instance that is passed to and shared between all `Evaluators`, facilitating cached reuse of computed `FeatureValue`'s needed to perform detection evaluation.

### `FeatureRegistry` & `FeatureState`

`FeatureRegistry` contains a map of `FeatureId` keys and `FeatureExtractor` values. 

`FeatureState` contains a map of `FeatureId` keys and `FeatureValue` values.

In the case that an `Evaluator` requests a `FeatureValue` for a non-cached `FeatureId`, `FeatureState` will use the `FeatureRegistry` to get the `FeatureExtractor` needed to compute the requested `FeatureValue`, caching it for future reuse before returning it to the `Evaluator`.

---
## Building & Installing

Detect Core is built using CMake. Because the top‑level `CMakeLists.txt` lives in
the **CommonModules** directory (not the repository root), you need to point CMake
to that directory when configuring the build.

### From the repository root (recommended)

```bash
mkdir -p build && cd build
# Tell CMake to use the CMakeLists.txt inside CommonModules
cmake ../CommonModules -DCMAKE_BUILD_TYPE=Release
make
# Optional: install to a system location
sudo make install
```

---
(default `/usr/local/include/detect-core/`).

---

## Usage Example

```cpp
#include "detect-core/Model.hpp"
#include "detect-core/Config.hpp"
#include "detect-core/Context.hpp"

int main() {
    // 1. Let's create a configuration for our model
    Config cfg;
    cfg.enableSnrExtractor();
    cfg.enableSnrThresholdEvaluator(Config::SECOND_STAGE, Config::SECOND_ORDER, 4.5);

    // 2. Create the model
    Model model(cfg);

    // 3. Create the context for the model
    Context ctx = /* fill with data */;

    // 4. Run the model
    Result result = model.run(ctx);

    // Result can be inspected or logged
    std::cout << "SNR: " << result.snr() << "\n";
    return 0;
}
```

---

## Extending the Library

To add a new feature extractor:

1. Subclass `FeatureExtractor` and implement `extract(const Context&, FeatureState&)`.
2. Register the new extractor in `FeatureRegistry` (see `FeatureRegistry.cpp`).

To add a new evaluator, subclass `Evaluator` and implement the `evaluate`
method.  Then add the evaluator to the pipeline via `Config` or a custom
pipeline builder.

---

## Testing

Unit tests are located in `CommonModules/detect-core/tests/`.  They are built
as part of the default CMake target.  Run the tests with:

```bash
ctest --output-on-failure
```

---


