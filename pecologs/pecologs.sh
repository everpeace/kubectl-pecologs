#! /usr/bin/env bash
set -euf -o pipefail
SEP=":"

# print log of container
# arguments
#   case 1:  "namespace:pod_name:container_name" (1 string)
#   case 2:  "naemspace" "pod_name" "container_name" (3 strings)
container_log(){
  if [[ $# -eq 1 ]]; then
    IFS_ORIGINAL="$IFS"
    IFS="$SEP"
    pc=($1)
    IFS="$IFS_ORIGINAL"
    local namespace="${pc[0]}"
    local pod_name="${pc[1]}"
    local container_name="${pc[2]}"
  else
    local namespace="$1"
    local pod_name="$2"
    local container_name="$3"
  fi
  if [[ "$KUBECTL_PLUGINS_LOCAL_FLAG_ALL_NAMESPACES" = "true" ]];then
    $KUBECTL_PLUGINS_CALLER --namespace "$namespace" logs "$pod_name" -c "$container_name" --since=$KUBECTL_PLUGINS_LOCAL_FLAG_SINCE | awk -v ns="$namespace" -v p="$pod_name" -v c="$container_name" -v sep="$SEP" '{ print "\033[4m" ns sep p sep c " \033[m|", $0; fflush() }'
  else
    $KUBECTL_PLUGINS_CALLER --namespace "$namespace" logs "$pod_name" -c "$container_name" --since=$KUBECTL_PLUGINS_LOCAL_FLAG_SINCE | awk -v p="$pod_name" -v c="$container_name" -v sep="$SEP" '{ print "\033[4m" p sep c " \033[m|", $0; fflush() }'
  fi
}

# return a list of container_name of given pod
# arguments
#   case 1: "namespace:pod_name" (1 string)
#   case 2: "namespace" "pod_name" (2 strings)
containers_of_pod(){
  if [[ $# -eq 1 ]]; then
    # spliting pod_name:container_name to (pod_name container_name)
    IFS_ORIGINAL="$IFS"
    IFS="$SEP"
    pc=($1)
    IFS="$IFS_ORIGINAL"
    local namespace="${pc[0]}"
    local pod_name="${pc[1]}"
  else
    local namespace="$1"
    local pod_name="$2"
  fi
  $KUBECTL_PLUGINS_CALLER --namespace "$namespace" get po "$pod_name" -o json | jq -r '.spec.containers[].name'
}

# return a list of pod_name
# arguments:
#   "namespace" (string)
pods(){
  local namespace="$1"
  $KUBECTL_PLUGINS_CALLER --namespace "$namespace" get pod -o json | jq --arg sep "$SEP" -r '.items[].metadata.name'
}

# return a list of
#   "pod_name:container_name", when --all-namespace=false
#   "namespace:pod_name:container_name", otherwise
target_pod_and_conatiners(){
  local namespaces=$(if [[ "$KUBECTL_PLUGINS_LOCAL_FLAG_ALL_NAMESPACES" = "true" ]];then
    $KUBECTL_PLUGINS_CALLER get namespace | grep -v NAME | cut -f 1 -d' '
  else
    echo "$KUBECTL_PLUGINS_CURRENT_NAMESPACE"
  fi)

  for ns in $namespaces;
  do
    for pod in $(pods "$ns");
    do
      for container in $(containers_of_pod "$ns" "$pod");
      do
        if [[ "$KUBECTL_PLUGINS_LOCAL_FLAG_ALL_NAMESPACES" = "true" ]];then
          echo "$ns$SEP$pod$SEP$container"
        else
          echo "$pod$SEP$container"
        fi
      done;
    done;
  done;
}

QUERY="${1:-}"
INTERACTIVE="$KUBECTL_PLUGINS_LOCAL_FLAG_INTERACTIVE"
DRY_RUN=$(if [[ "$KUBECTL_PLUGINS_LOCAL_FLAG_DRY_RUN" = "true" ]]; then
  echo -n "--dry-run"
else
  echo -n ""
fi)

if [[ "$INTERACTIVE" = "true" ]]; then
  list=$(target_pod_and_conatiners)
  targets=$(echo "$list" | peco --initial-filter=Fuzzy --query "$QUERY")
else
  targets=$(target_pod_and_conatiners | grep "$QUERY")
fi

(
  . `which env_parallel.bash`
  (
  for t in ${targets[@]};do
    if [[ "$KUBECTL_PLUGINS_LOCAL_FLAG_ALL_NAMESPACES" = "true" ]];then
      echo "$t";
    else
      echo "$KUBECTL_PLUGINS_CURRENT_NAMESPACE$SEP$t";
    fi
  done
  ) | env_parallel "$DRY_RUN" container_log
)

exit 0;
