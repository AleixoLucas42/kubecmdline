#!/bin/bash

fzf_commands=("exec" "log" "port-forward");
fzf_namespace=("Current" "All");
fzf_forward_resource=("svc" "pod");
fzf_default_params="--reverse"

function start {
    selected_command=$(printf "%s\n" "${fzf_commands[@]}" | fzf --header="Select command" $fzf_default_params)
    set_namespace
    set_resource
    echo "[+] Executing: kubectl $namespace $selected_command $finalizer"
    eval "kubectl $namespace $selected_command $finalizer"
    exit 0
}

function set_namespace {
    selected_namespace=$(printf "%s\n" "${fzf_namespace[@]}" | fzf --header="Select namespace" $fzf_default_params)
    case $selected_namespace in
    "Current")
        export namespace="-n $(kubectl config view --minify --output 'jsonpath={..namespace}')"
        ;;
    "All")
        export namespace="--all-namespaces"
        ;;
    esac;
}

function set_forward_finalizer {
    case $1 in
    "svc")
        service=$(kubectl $namespace get services | awk 'NR>1 {print $1}' | fzf --header="Select service" $fzf_default_params)
        port=$(kubectl $namespace get services $service -o custom-columns="PORT:.spec.ports[*].port" --no-headers | tr ',' '\n' | fzf --header="Select port" $fzf_default_params)
        if [ "$port" -lt 1024 ]; then
            export finalizer="svc/${service} 10${port}:${port}"
        else
            export finalizer="svc/${service} ${port}"
        fi
        
        ;;
    "exec" | "log")
        export namespace="--all-namespaces"
        ;;
    esac
}

function set_resource {
    case $selected_command in
    "port-forward")
        export resource_kind=$(printf "%s\n" "${fzf_forward_resource[@]}" | fzf --header="Select kind" $fzf_default_params)
        set_forward_finalizer $resource_kind
        ;;
    "exec" | "log")
        export namespace="--all-namespaces"
        ;;
    esac
}

start
