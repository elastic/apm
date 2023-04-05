# OpenTelemetry Metrics API Support

Agents SHOULD support collecting custom metrics via the OpenTelemetry Metrics API.
This SHOULD be done by supplying an OpenTelemetry Metrics SDK compatible [MetricExporter](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#metricexporter). If a pull based approach is preferred, a [MetricReader](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#metricreader) can be used instead. This `MetricExporter/MetricReader` SHOULD transform the received metrics data to IntakeV2 metricsets and send them via the existing reporting mechanism.

## Metric naming

Agents MUST NOT alter/sanitize OpenTelemetry metric names. For example, agents MUST NOT de-dot metric names.
Unfortunately, this can lead to mapping problems in elasticsearch (state: January 2023) if for example metrics with the names `foo.bar` and `foo` are both ingested.
Due to the nested object representation within metricsets, `foo` would need to be mapped as both an object and a number at the same time, which is not possible.

We plan on solving these conflicts on the APM-server side instead by adjusting the mapping of metricsets (Again, state of January 2023).

Agents MUST respect the `disable_metrics` configuration for OpenTelemetry metrics.

## Aggregation Temporality

In OpenTelemetry the [AggregationTemporality](https://opentelemetry.io/docs/reference/specification/metrics/data-model/#temporality) defines whether metrics report the total, cumulative observed values or the delta since the last export.
The temporality is fully controlled by exporters / MetricReaders, therefore we can decide which temporality to use.

For now, Agents MUST use the delta-preferred temporality:

| **Instrument Type**         | **Temporality**            |
|-----------------------------|----------------------------|
|  Counter                    | Delta                      |
|  Asynchronous Counter       | Delta                      |
|  UpDownCounter              | Cumulative                 |
|  Asynchronous UpDownCounter | Cumulative                 |
|  Histogram                  | Delta                      |

The reason is that monotonic counter metrics are currently more difficult to handle and visualize in kibana and elasticsearch.
As soon as the support gets better, we will revisit this spec and allow users to switch between cumulative and delta temporality via configuration.

For all instrument types with delta temporality, agents MUST filter out zero values before exporting.
E.g. if a counter does not change since the last export, it must not be exported.

## Aggregation

The OpenTelemetry SDK [Aggregations](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#aggregation) define how the observations made on a given Instrument are aggregated into a single value for export. For example, counters are aggregated by summing all values, whereas for gauges the last value is used.

Aggregations are configurable in OpenTelemetry. Currently, this mainly makes sense for Histogram-Instruments. A histogram instrument is usually used when the distribution of the observed values is of interest, e.g. for latency. At the moment the SDK offers [two options](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#histogram-aggregations) for histogram aggregations:
 * A bucket based histogram with explicitly provided bucket boundaries
 * An exponential histogram with predefined, exponentially increasing bucket boundaries

In the SDK, the default aggregation to use for each instrument type (counter, gauge, histogram, etc) is defined by the Exporter / MetricsReader. However, users can explicitly override the aggregation per metric by using [Views](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#view). Note that views are an SDK concept and are not part of the OpenTelemetry API.

Agents MUST use the OpenTelemetry SDK [default aggregations per instrument type](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#default-aggregation) as default aggregations for their exporter:

| **Instrument Type**         | **Aggregation**            |
|-----------------------------|----------------------------|
|  Counter                    | Sum                        |
|  Asynchronous Counter       | Sum                        |
|  UpDownCounter              | Sum                        |
|  Asynchronous UpDownCounter | Sum                        |
|  Asynchronous Gauge         | Last Value                 |
|  Histogram                  | Explicit Bucket Histogram  |

### Histogram Aggregation

The OpenTelemetry SDK uses the following prometheus-inspired bucket boundaries for histograms by default:
```
[0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000]
```

Because IntakeV2 histogram serialization skips empty buckets, we are free to use histogram boundaries which are more accurate and cover a greater range. Therefore, agents SHOULD use the following histogram boundaries by default instead:

```
[0.00390625, 0.00552427, 0.0078125, 0.0110485, 0.015625, 0.0220971, 0.03125, 0.0441942, 0.0625, 0.0883883, 0.125, 0.176777, 0.25, 0.353553, 0.5, 0.707107, 1, 1.41421, 2, 2.82843, 4, 5.65685, 8, 11.3137, 16, 22.6274, 32, 45.2548, 64, 90.5097, 128, 181.019, 256, 362.039, 512, 724.077, 1024, 1448.15, 2048, 2896.31, 4096, 5792.62, 8192, 11585.2, 16384, 23170.5, 32768, 46341.0, 65536, 92681.9, 131072]
```

These boundaries are an exponential scale base `sqrt(2)` rounded to six significant figures.

Agents MUST allow users to configure the default histogram boundaries via the `custom_metrics_histogram_boundaries` configuration option (described in the section below).

In the future, we might replace the default aggregation with one better suited for elasticsearch, e.g. HDRHistogram or T-Digest.

Because users would need to take extra steps to prevent our exporter from using the preferred explicit bucket aggregation (by configuring SDK views), agents are not required to support any other histogram aggregation types. In other words, agents MAY ignore [ExponentialHistograms](https://opentelemetry.io/docs/reference/specification/metrics/data-model/#exponentialhistogram) and [Summaries](https://opentelemetry.io/docs/reference/specification/metrics/data-model/#summary-legacy). If a metric is ignored due to its aggregation, agents SHOULD emit a warning with a message including the metric name.

However, agents MUST support explicit bucket histogram aggregations with custom boundaries provided by users via views.

Before export, the OpenTelemetry histogram bucket data needs to be converted to IntakeV2 histogram data. Because the OpenTelemetry specification allows negative values in histograms, the data needs to be converted to T-Digests: For T-Digests, the IntakeV2 metricset `samples.values` properties holds the **midpoints** of the histogram buckets instead of the upper/lower bounds.

Therefore, the following algorithm needs to be used to convert [OpenTelemetry explicit bucket histogram data](https://opentelemetry.io/docs/reference/specification/metrics/data-model/#histogram) to IntakeV2 histograms:

```
IntakeV2Histo convertBucketBoundaries(OtelHisto input) {
    List<Double> intakeCounts = new ArrayList<>();
    List<Double> intakeValues = new ArrayList<>();

    List<Double> otelCounts = input.getCounts();
    List<Double> otelBoundaries = input.getBoundaries();
    
    int bucketCount = otelCounts.size();
    // otelBoundaries has a size of bucketCount-1
    // the first bucket has the boundaries ( -inf, otelBoundaries[0] ]
    // the second bucket has the boundaries ( otelBoundaries[0], otelBoundaries[1] ]
    // ..
    // the last bucket has the boundaries (otelBoundaries[bucketCount-2], inf)
    
    for (int i = 0; i < bucketCount; i++) {
        if (otelCounts.get(i) != 0) { //ignore empty buckets
            intakeCounts.add(otelCounts.get(i));
            if (i == 0) { //first bucket
                double bounds = otelBoundaries.get(0);
                if(bounds > 0) {
                    bounds /= 2;
                }
                intakeValues.add(bounds);
            } else if (i == bucketCount - 1) { //last bucket
                intakeValues.add(otelBoundaries.get(bucketCount - 2));
            } else { //in between
                double lower = otelBoundaries.get(i - 1);
                double upper = otelBoundaries.get(i);
                intakeValues.add(lower + (upper - lower) / 2);
            }
        }
    }
    
    return new IntakeV2Histo(intakeCounts, intakeValues);
}
```

The same algorithm is used by the APM server to convert OTLP histograms.
The `sum`, `count`, `min` and `max` within the OpenTelemetry histogram data are discarded for now until we support them in IntakeV2 histograms.

#### custom_metrics_histogram_boundaries configuration

Defines the default bucket boundaries to use for OpenTelemetry histograms.

|                |                                          |
|----------------|------------------------------------------|
| Type           | `double list`                            |
| Default        | <see base `sqrt(2)` boundaries above>    |
| Dynamic        | `false`                                  |
| Central config | `false`                                  |

## Labels

Conceptually, elastic metric labels keys correspond to [OpenTelemetry Attributes](https://opentelemetry.io/docs/reference/specification/common/#attribute).
When exporting, the agents MUST convert the attributes to labels as described in this section and MUST group metrics with the same attributes and OpenTelemetry instrumentation scope together into a single metricset.

Attribute keys MUST NOT be modified. Potential sanitization will happen within the APM server, if any.
APM servers pre version 7.11 will drop metricsets if the label keys contain any of the characters `.`, `*` or `"`, which are however allowed characters in OpenTelemetry.
Therefore, agents SHOULD document that OpenTelemetry metrics might be dropped when using an APM Server pre version 7.11.

The attribute values MUST NOT be modified and their type MUST be preserved. E.g. `strings` must remain `string`-labels, `booleans` must remain `boolean`-labels.
Metricsets currently do not support array-valued labels, whereas OpenTelemetry attribute values can be arrays. For this reason, array-valued attributes MUST be ignored. Agents SHOULD emit a warning with a message containing the metric name when attributes are dropped because they are array-valued.

To summarize and to give an example, given the following set of attributes

| **Attribute Key** | **Attribute Value** | **Type**       |
|-------------------|---------------------|----------------|
|  `foo.bar`        | `baz`               | `string`       |
|  `my_array`       | `[first, second]`   | `string array` |
|  `testnum*`       | `42.42`             | `number`       |

the following labels must be used for the resulting metricset:

| **Label Key** | **Label Value** | **Type**       |
|---------------|-----------------|----------------|
|  `foo_bar`    | `baz`           | `string`       |
|  `testnum_`   | `42.42`         | `number`       |

The OpenTelemetry specification allows the definition of metrics with the same name as long as they reside within a different instrumentation scope ([spec link](https://opentelemetry.io/docs/reference/specification/metrics/api/#get-a-meter)). Agents MUST report metrics from different instrumentation scopes in separate metricsets to avoid naming conflicts at collection time. This separation MUST be done based on the instrumentation scope name and version. In the future, we might add dedicated intake fields to metricsets for differentiation them based on the instrumentation scope identifiers.

## Exporter Installation

The onboarding should be as easy as possible for users. Ideally, the users should be able to browse their OpenTelemetry metrics by just following the standard agent installation process without requiring additional configuration or code changes.

We focus on two ways of how OpenTelemetry may be used by users:

1. The user application has a OpenTelemetry Metrics SDK Instance setup and configured. E.g. the user already has a prometheus exporter running and did some customizations on their metrics via [Views](https://opentelemetry.io/docs/reference/specification/metrics/sdk/#view).
2. The user application does not setup a OpenTelemetry Metrics SDK Instance, but uses the OpenTelemetry Metrics API to define metrics. This is usually the case when the user application does not care / know about OpenTelemetry metrics, but a library used by the application implemented observability via OpenTelemetry.

For **1.** we want to make sure that the existing user configuration is respected by our apm agents. Ideally, agents SHOULD just register an additional exporter to the existing OpenTelemetry Metrics SDK instance(s). If the agent and language capabilities allow it, the exporter registration SHOULD be done automatically without requiring code changes by the user. 

For **2.** agents MAY automatically register an agent-provided SDK instance to bind the user provided OpenTelemetry API to, if this is possible in their language and does not cause too much overhead of any kind (e.g. implementation or agent package size).
Agents MUST NOT override a user-provided global OpenTelemetry metrics SDK with their own SDK or prevent the user from providing his own SDK instance in any means.
For example the Java agent MUST NOT install an OpenTelemetry Metrics SDK instance in the [GlobalOpenTelemetry](https://www.javadoc.io/static/io.opentelemetry/opentelemetry-api/1.20.0/io/opentelemetry/api/GlobalOpenTelemetry.html) if it detects that another Metrics SDK has already been registered there.

Agents SHOULD ensure that remaining metric data is properly flushed when the user application shuts down. for **1.**, the user is responsible for shutting down the SDK instance before their application terminates. This shutdown initiates a metrics flush, therefore no special actions needs to be taken by agents in this case. For **2.**, agents SHOULD initiate a proper shutdown of the agent provided SDK instance when the user application terminates, which automatically causes a flush.