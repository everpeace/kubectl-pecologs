#! /usr/bin/env bash
set -euf -o pipefail
SEP=":"
container_log(){
  if [[ $# -eq 1 ]]; then
    # spliting pod_name:container_name to (pod_name container_name)
    IFS_ORIGINAL="$IFS"
    IFS="$SEP"
    pc=($1)
    IFS="$IFS_ORIGINAL"
    local pod_name="${pc[0]}"
    local container_name="${pc[1]}"
  else
    local pod_name="$1"
    local container_name="$2"
  fi
  $KUBECTL_PLUGINS_CALLER --namespace $KUBECTL_PLUGINS_CURRENT_NAMESPACE logs "$pod_name" -c "$container_name" --since=$KUBECTL_PLUGINS_LOCAL_FLAG_SINCE | awk -v p="$pod_name" -v c="$container_name" -v sep="$SEP" '{ print "\033[4m"p sep c " \033[m|", $0; fflush() }'
}

containers_of_pod(){
  local pod_name="$1"
  $KUBECTL_PLUGINS_CALLER --namespace $KUBECTL_PLUGINS_CURRENT_NAMESPACE get po "$pod_name" -o json | jq -r '.spec.containers[].name'
}

pods(){
  $KUBECTL_PLUGINS_CALLER --namespace $KUBECTL_PLUGINS_CURRENT_NAMESPACE get po -o json | jq -r '.items[].metadata.name'
}

target_pod_and_conatiners(){
  for pod in $(pods);
  do
    for container in $(containers_of_pod "$pod");
    do
      echo "$pod$SEP$container"
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
(for t in ${targets[@]};do echo "$t";done) | env_parallel "$DRY_RUN" container_log
)

exit 0;
