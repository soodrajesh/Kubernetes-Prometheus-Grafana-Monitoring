#!/bin/bash

# Kubernetes Monitoring Stack Deployment Script
# Author: Raj Sood
# Description: Automated deployment script for Prometheus, Grafana, and AlertManager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="monitoring-stack"
CHART_PATH="./helm/monitoring-stack"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm 3.x first."
        exit 1
    fi
    
    # Check if we can connect to Kubernetes cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

create_namespace() {
    print_status "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists."
    else
        kubectl create namespace $NAMESPACE
        print_success "Namespace $NAMESPACE created successfully!"
    fi
}

add_helm_repos() {
    print_status "Adding Helm repositories..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    print_success "Helm repositories added and updated!"
}

deploy_monitoring_stack() {
    print_status "Deploying monitoring stack..."
    
    # Check if release already exists
    if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        print_warning "Release $RELEASE_NAME already exists. Upgrading..."
        helm upgrade $RELEASE_NAME $CHART_PATH -n $NAMESPACE
    else
        helm install $RELEASE_NAME $CHART_PATH -n $NAMESPACE
    fi
    
    print_success "Monitoring stack deployed successfully!"
}

wait_for_pods() {
    print_status "Waiting for pods to be ready..."
    
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE --timeout=300s
    
    print_success "All pods are ready!"
}

show_access_info() {
    print_status "Deployment completed! Access information:"
    echo ""
    echo -e "${GREEN}Grafana Dashboard:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:80"
    echo "  Access at: http://localhost:3000"
    echo "  Default credentials: admin/admin123 (change immediately!)"
    echo ""
    echo -e "${GREEN}Prometheus UI:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-server 9090:80"
    echo "  Access at: http://localhost:9090"
    echo ""
    echo -e "${GREEN}AlertManager:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE svc/alertmanager 9093:80"
    echo "  Access at: http://localhost:9093"
    echo ""
    echo -e "${YELLOW}Security Note:${NC} Please change default passwords and configure proper authentication!"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Kubernetes Monitoring Stack Deployer${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    check_prerequisites
    create_namespace
    add_helm_repos
    deploy_monitoring_stack
    wait_for_pods
    show_access_info
    
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "uninstall")
        print_status "Uninstalling monitoring stack..."
        helm uninstall $RELEASE_NAME -n $NAMESPACE
        kubectl delete namespace $NAMESPACE
        print_success "Monitoring stack uninstalled successfully!"
        ;;
    "status")
        print_status "Checking deployment status..."
        kubectl get pods -n $NAMESPACE
        helm status $RELEASE_NAME -n $NAMESPACE
        ;;
    *)
        echo "Usage: $0 [deploy|uninstall|status]"
        echo "  deploy    - Deploy the monitoring stack (default)"
        echo "  uninstall - Remove the monitoring stack"
        echo "  status    - Check deployment status"
        exit 1
        ;;
esac
