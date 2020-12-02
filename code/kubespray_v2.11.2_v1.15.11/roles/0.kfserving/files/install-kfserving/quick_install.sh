set -e 

export ISTIO_VERSION=1.6.2
export KNATIVE_VERSION=0.15.0
export KFSERVING_VERSION=0.4.0

echo "STEP1. Install istio"
istio-${ISTIO_VERSION}/bin/istioctl manifest apply -f istio-${ISTIO_VERSION}/istio-max-operator.yaml

sleep 1

# Install Knative
echo "STEP2. Install Knative"
kubectl apply --filename knative-${KNATIVE_VERSION}/serving-crds.yaml
kubectl apply --filename knative-${KNATIVE_VERSION}/serving-core.yaml
kubectl apply --filename knative-${KNATIVE_VERSION}/release.yaml
kubectl apply --filename knative-${KNATIVE_VERSION}/monitoring-core.yaml
kubectl apply --filename knative-${KNATIVE_VERSION}/monitoring-metrics-prometheus.yaml

sleep 10

echo "STEP2. Patch knative monitoring resources (grafana, prometheus)"
kubectl -n knative-monitoring patch deployment grafana --patch "$(cat knative-${KNATIVE_VERSION}/patch-scaleup-grafana-resources.yaml)"
kubectl -n knative-monitoring rollout restart deployment grafana

sleep 5

kubectl -n knative-monitoring patch statefulset prometheus-system --type=merge --patch "$(cat knative-${KNATIVE_VERSION}/patch-scaleup-prometheus-resources.yaml)"
kubectl -n knative-monitoring rollout restart statefulset prometheus-system

sleep 5

# Install Cert Manager
echo "STEP3. Install CertManager"
kubectl apply --validate=false -f certmanager-0.15.1/cert-manager.yaml
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager-webhook -n cert-manager

sleep 15s

# Install KFServing
echo "STEP4. Install KFServing"
kubectl apply -f kfserving-${KFSERVING_VERSION}/kfserving.yaml --validate=false