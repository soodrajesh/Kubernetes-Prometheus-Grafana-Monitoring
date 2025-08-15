#!/bin/bash

# Kubernetes Monitoring Stack Backup Script
# Author: Raj Sood
# Description: Backup Grafana dashboards and Prometheus data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=grafana" -o jsonpath="{.items[0].metadata.name}")
PROMETHEUS_POD=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=prometheus" -o jsonpath="{.items[0].metadata.name}")

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_backup_dir() {
    print_status "Creating backup directory: $BACKUP_DIR"
    mkdir -p $BACKUP_DIR
}

backup_grafana() {
    print_status "Backing up Grafana dashboards..."
    
    if [ -z "$GRAFANA_POD" ]; then
        print_error "Grafana pod not found!"
        return 1
    fi
    
    # Export dashboards
    kubectl exec -n $NAMESPACE $GRAFANA_POD -- grafana-cli admin export-dashboard > $BACKUP_DIR/grafana-dashboards.json 2>/dev/null || true
    
    # Backup Grafana database
    kubectl exec -n $NAMESPACE $GRAFANA_POD -- tar -czf /tmp/grafana-backup.tar.gz /var/lib/grafana/
    kubectl cp $NAMESPACE/$GRAFANA_POD:/tmp/grafana-backup.tar.gz $BACKUP_DIR/grafana-data.tar.gz
    
    print_success "Grafana backup completed!"
}

backup_prometheus() {
    print_status "Backing up Prometheus data..."
    
    if [ -z "$PROMETHEUS_POD" ]; then
        print_error "Prometheus pod not found!"
        return 1
    fi
    
    # Create snapshot
    kubectl exec -n $NAMESPACE $PROMETHEUS_POD -- tar -czf /tmp/prometheus-backup.tar.gz /prometheus/
    kubectl cp $NAMESPACE/$PROMETHEUS_POD:/tmp/prometheus-backup.tar.gz $BACKUP_DIR/prometheus-data.tar.gz
    
    print_success "Prometheus backup completed!"
}

backup_configurations() {
    print_status "Backing up configurations..."
    
    # Export ConfigMaps
    kubectl get configmaps -n $NAMESPACE -o yaml > $BACKUP_DIR/configmaps.yaml
    
    # Export Secrets (without sensitive data)
    kubectl get secrets -n $NAMESPACE -o yaml | sed 's/data:/data: <REDACTED>/g' > $BACKUP_DIR/secrets-structure.yaml
    
    # Export Helm values
    helm get values monitoring-stack -n $NAMESPACE > $BACKUP_DIR/helm-values.yaml
    
    print_success "Configuration backup completed!"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Monitoring Stack Backup Tool${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    create_backup_dir
    backup_grafana
    backup_prometheus
    backup_configurations
    
    echo ""
    echo -e "${GREEN}🎉 Backup completed successfully!${NC}"
    echo -e "${BLUE}Backup location: $BACKUP_DIR${NC}"
}

main
