---
title: "Databricks Operator load testing"
date: 2020-01-28T10:24:20Z
toc: true
categories: ["kubernetes, go, testing"]
noSummary: true
---

This blog will provide an high level overview of the methodology we're using when load testing, using the [Databricks Operator](https://github.com/microsoft/azure-databricks-operator) as an example.
The operator allows applications hosted in Kubernetes to launch and use Databricks data engineering and machine learning tasks through Kubernetes.

# The environment

![Simplified environment](https://dev-to-uploads.s3.amazonaws.com/i/v70vm6f13e51a8f513eh.png)

In the above simplified architecture diagram we can see:

- [Locust](https://locust.io/), the load testing framework we're using for running the test scenarios
- [Databricks Operator](https://github.com/microsoft/azure-databricks-operator), the service under test
- Databricks mock API, a mock API created to simulate the real [Databricks](https://databricks.com/) for these load tests
- [Prometheus](https://prometheus.io/), gathers metrics on the above services throughout the test
- [Grafana](https://grafana.com/), displays metrics gathered by Prometheus 

# The methodology

The steps for this load testing methodology consists of:

1. Define scenarios 
2. Run a load tests based on a scenario
3. Create a hypothesis if unhappy with the results
  1. Re-run load tests with the changes from the hypothesis
  2. Go to step 3
6. Repeat until all scenarios are covered 

# Defining scenarios

To begin the load tests, we first need to define test scenarios we wish to consider and the performance level we would like to achieve. These scenarios are the basis for the tests below.

Here are examples of test scenarios used for the operator load testing:
```
Test Scenario 1:
1. Create a Run with cluster information supplied (referred to as Runs Submit)
2. Await the Run terminating
3. Delete the Run once complete regardless of status
Notes:
- This scenario is designed to test throughput of the operator under load.
- By deleting the Run after it has complete we ensure we keep the K8s platform as clean as possible for a baseline performance.

Test Scenario 2:
1. Create a Run with cluster information supplied (referred to as Runs Submit)
2. Await the Run terminating
3. DO NOT delete the Run object
Notes
- This scenario is designed to test potential impact of the Operator if the Run objects are not cleaned up.
- The operator should still be performant, even when there are a potentially large number of objects to manage
- This test will also help us understand the acceptable stress limit of the system
```

# Running a scenario

To run a scenario, we'll start by making the load test environment as static as we can to control as many variables as possible between runs. For the operator we achieved this by using automated deployment scripts, code freezes and documenting the images used for each load test. Here's a snippet of the deployment script using specific image tags:


```bash
# The following variables control the versions of components that will be deployed
MOCK_TAG=latest-20200117.3
OPERATOR_TAG=insomnia-without-port-exhaust-20200106.2
LOCUST_TAG=latest-20200110.7
LOCUST_FILE=behaviours/scenario2_run_submit.py
```

## Baseline

We document the state of environment before load tests, as seen below. Then proceed with a baseline run, which is the first load test run in a scenario. 

```
Setup
Components
MOCK_TAG=latest-20191219.3
OPERATOR_TAG=metrics-labels or baseline-20191219.1 #See note on Run 1
LOCUST_TAG=latest-20191219.1

Locust
Users: 25
Time under load: 25mins
Spawn rate: 0.03 (1 every 30 secs)
```

After the run is done, we document what has happened, for example: the state of Grafana graphs, tests we've run if an issue was highlighted, key points discovered.

An example of the metrics:
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/84r01d0svnmaptrdsb3k.png)

![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/4ttnf2ch93g7e913n3pd.png)


From the above metrics we discovered these key points:
```
Run summary
- Run completion time increasing, which is a static value set at 6 seconds, indicating there is a issue with handling the load somewhere
- Requests to the MockAPI are decreasing and are in a spaced out pattern
```

## Hypothesis

Based on the summary we hypothesized the problem is with the operator. The MockAPI is receiving fewer requests as the load increases, meaning the operator is struggling to process the amount of requests.

This lead into an investigation into the operator, where we saw the `time.sleep` operation is in use. Based on this discovery, we created a fork of the operator and replaced the usage of `time.sleep`.

The fix for `time.sleep` can be found here: <https://github.com/microsoft/azure-databricks-operator/pull/141>

## Testing the hypothesis 

We then tested this hypothesis by running a new load test and repeating the steps above. The only difference between this load test and the baseline is the image of the operator fork.

With the fix, we can see below that the issues highlighted above have been solved, but has also revealed another issue of requests failing to be sent from the operator. 
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/30wxugujhuamv1a580ey.png)

# Repeat

To continue the cycle we'd create another hypothesis and then based on that hypothesis another load test. This would be repeated until we've reached the performance levels we've deemed acceptable when creating the scenario. 

Then reassess the scenarios and repeat this for each scenario. 

# Conclusion

Thanks to the methodology's rigorousness, it's been very easy to provide evidence for the reasons we need to make the changes and to see the progression from the baseline to the end result.