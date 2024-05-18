#!/bin/bash

fzf_commands=("logs" "exec" "port-forward");
fzf_namespace=("Current" "Select");
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
    "Select")
        change_namespace
        ;;
    esac;
}

function set_pod {
    export pod=$(kubectl $namespace get pods | awk 'NR>1 {print $1}' | fzf --header="Select pod" $fzf_default_params)
}

function set_forward_finalizer {
    case $1 in
    "svc")
        service=$(kubectl $namespace get services | awk 'NR>1 {print $1}' | fzf --header="Select service" $fzf_default_params)
        port=$(kubectl $namespace get services $service -o custom-columns="PORT:.spec.ports[*].port" --no-headers | tr ',' '\n' | fzf --header="Select port" $fzf_default_params)
        if [ "$port" -lt 1024 ]; then
            export finalizer="$1/${service} 10${port}:${port}"
        else
            export finalizer="$1/${service} ${port}"
        fi
        ;;
    "pod")
        set_pod
        while true; do
            echo -n "[+] Container target port: "
            read -r port
            if [[ $port =~ ^[0-9]+$ ]]; then
                if [ "$port" -lt 1024 ]; then
                    export finalizer="$1/${pod} 10${port}:${port}"
                else
                    export finalizer="$1/${pod} ${port}"
                fi
                break
            fi
        done
        ;;
    esac
}

function change_namespace {
    export namespace="-n $(kubectl get namespace | awk 'NR>1 {print $1}' | fzf --header="Select namespace" $fzf_default_params)"
}

function set_logs_finalizer {
    export finalizer="-f $1"
}

function set_exec_finalizer {
    shells=("sh" "bash")
    shell=$(printf "%s\n" "${shells[@]}" | fzf --header="Select shell" $fzf_default_params)
    export finalizer="-it $1 -- $shell"
}

function set_resource {
    case $selected_command in
    "port-forward")
        export resource_kind=$(printf "%s\n" "${fzf_forward_resource[@]}" | fzf --header="Select kind" $fzf_default_params)
        set_forward_finalizer $resource_kind
        ;;
    "exec")
        set_pod
        set_exec_finalizer $pod
        ;;
    "logs")
        set_pod
        set_logs_finalizer $pod
        ;;
    esac
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo -e "\nWelcome to kubefzf!, with kubefzf you will combine the power of fzf in the kubectl command line, so you don't have to list and copy resource names before using the kubectl command, everything will be interactive and you will choose through a menu that has a filter. You need to have fzf installed in your system."
else
    start
fi

