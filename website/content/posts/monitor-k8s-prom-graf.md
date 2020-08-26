---
title: "Add monitoring with Prometheus/Grafana in Kubernetes"
date: 2019-12-31T17:47:47Z
toc: true
categories: [kubernetes, go, analytics]
noSummary: true
---

In this post I'd like to give a short overview on the parts needed to add monitoring for a GO API with Prometheus/Grafana in Kubernetes(K8).

## Prerequisites

- K8 cluster that you can deploy to locally
- Intermediate knowledge of [K8](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/), [Docker](https://docs.docker.com/) and [GO](https://golang.org/)
- Basic knowledge of what [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) is used for


## Summary

1. Create a GO API with Prometheus `/metrics` endpoint
2. Deploy API, service, service monitor to K8
3. Deploy Prometheus to K8
4. Access Grafana dashboards


## Create a GO API with Prometheus `/metrics` endpoint

Here's a simple GO API that will have an welcome page at `/` and a metrics page at `/metrics`, which will display metrics from the API. The `/metrics` will later be used to by Prometheus Operator to scrape data about the API

```GO
package main

import (
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type prometheusHTTPMetric struct {
	Prefix                string
	ClientConnected       prometheus.Gauge
	TransactionTotal      *prometheus.CounterVec
	ResponseTimeHistogram *prometheus.HistogramVec
	Buckets               []float64
}

func initPrometheusHTTPMetric(prefix string, buckets []float64) *prometheusHTTPMetric {
	phm := prometheusHTTPMetric{
		Prefix: prefix,
		ClientConnected: promauto.NewGauge(prometheus.GaugeOpts{
			Name: prefix + "_client_connected",
			Help: "Number of active client connections",
		}),
		TransactionTotal: promauto.NewCounterVec(prometheus.CounterOpts{
			Name: prefix + "_requests_total",
			Help: "total HTTP requests processed",
		}, []string{"code", "method", "type", "action"},
		),
		ResponseTimeHistogram: promauto.NewHistogramVec(prometheus.HistogramOpts{
			Name:    prefix + "_response_time",
			Help:    "Histogram of response time for handler",
			Buckets: buckets,
		}, []string{"type", "action", "method"}),
	}

	return &phm
}

func (phm *prometheusHTTPMetric) wrapHandler(typeLabel string, actionLabel string, handlerFunc http.HandlerFunc) http.Handler {
	handle := http.HandlerFunc(handlerFunc)
	wrappedHandler := promhttp.InstrumentHandlerInFlight(phm.ClientConnected,
		promhttp.InstrumentHandlerCounter(phm.TransactionTotal.MustCurryWith(prometheus.Labels{"type": typeLabel, "action": actionLabel}),
			promhttp.InstrumentHandlerDuration(phm.ResponseTimeHistogram.MustCurryWith(prometheus.Labels{"type": typeLabel, "action": actionLabel}),
				handle),
		),
	)
	return wrappedHandler
}

func index(w http.ResponseWriter, r *http.Request) {
	_, _ = w.Write([]byte("GO API is up"))
}

func main() {
	phm := initPrometheusHTTPMetric("go_api", prometheus.LinearBuckets(0, 5, 20))

	http.Handle("/metrics", promhttp.Handler())
	http.Handle("/", phm.wrapHandler("Index", "GET", index))

	port := ":8080"
	print("API running on http://localhost" + port)

	log.Fatal(http.ListenAndServe(port, nil))
}

```


## Deploy API, service, service monitor to K8

YAML file to deploy the API, service and service monitor to K8

```YAML
apiVersion: v1
kind: Namespace
metadata:
  name: prom-go-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prom-go-api
  namespace: prom-go-api
spec:
  selector:
    matchLabels:
      app: prom-go-api
  template:
    metadata:
      labels:
        app: prom-go-api
    spec:
      containers:
        - name: prom-go-api
          image: $PROM_GO_API_IMAGE_NAME
          imagePullPolicy: Always
          resources:
            limits:
              memory: "128Mi"
              cpu: "500m"
          ports:
            - containerPort: 8080
              name: api
---
apiVersion: v1
kind: Service
metadata:
  name: prom-go-api
  namespace: prom-go-api
  labels:
    app: prom-go-api
spec:
  selector:
    app: prom-go-api
  ports:
    - port: 8080
      targetPort: api
      name: api
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prom-go-api-servicemonitor
  namespace: prom-go-api
  labels:
    app: prom-go-api
spec:
  selector:
    matchLabels:
      app: prom-go-api
  namespaceSelector:
    matchNames:
      - prom-go-api
  endpoints:
    - port: api
      path: /metrics
```

Create a local docker image of the GO API and replace IMG with the docker image name to add the above YAML to K8

```bash
# Replace ${IMG} with your local docker image name
cat ./manifests/deployment.yaml | PROM_GO_API_IMAGE_NAME=$IMG envsubst | kubectl apply -f -
kubectl apply -f ./manifests/service.yaml
```


## Deploy Prometheus to K8

Install the `prometheus-operator` helm chart

```bash
# prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false means all serviceMonitors are discovered not just 
# those deployed by the helm chart itself
helm install prom-test-api stable/prometheus-operator --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Check it's running

```bash
kubectl port-forward service/prom-azure-databricks-operator-grafana  8090:80 --namespace="default"
```

## Access Grafana dashboards

Access Grafana on `http://localhost:8090` with the credentials below

```text
Username: admin
Password: prom-operator
```

Create charts with metrics such as

```text
increase(go_api_requests_total[1m])
```
