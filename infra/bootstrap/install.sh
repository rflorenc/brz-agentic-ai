#!/bin/bash
set -o pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[38;5;214m'
readonly NC='\033[0m' # No Color
readonly RUN_DIR=$(pwd)

ENVIRONMENT=${ENVIRONMENT:-brz}
DRYRUN=${DRYRUN:-}
BASE_DOMAIN=${BASE_DOMAIN:-}
CLUSTER_NAME=${CLUSTER_NAME:-}

wait_for_openshift_api() {
    local i=0
    HOST=https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443/healthz
    until [ $(curl -k -s -o /dev/null -w %{http_code} ${HOST}) = "200" ]
    do
        echo -e "${GREEN}Waiting for 200 response from openshift api ${HOST}.${NC}"
        sleep 5
        ((i=i+1))
        if [ $i -gt 100 ]; then
            echo -e "🕱${RED}Failed - OpenShift api ${HOST} never ready?.${NC}"
            exit 1
        fi
    done
    echo "🌴 wait_for_openshift_api ran OK"
}

wait_for_project() {
    local i=0
    local project="$1"
    STATUS=$(oc get project $project -o=go-template --template='{{ .status.phase }}')
    until [ "$STATUS" == "Active" ]
    do
        echo -e "${GREEN}Waiting for project $project.${NC}"
        sleep 5
        ((i=i+1))
        if [ $i -gt 200 ]; then
            echo -e "🚨${RED}Failed waiting for project $project never Succeeded?.${NC}"
            exit 1
        fi
        STATUS=$(oc get project $project -o=go-template --template='{{ .status.phase }}')
    done
    echo "🌴 wait_for_project $project ran OK"
}

app_of_apps() {
    if [ -z "$DRYRUN" ]; then
        echo -e "${GREEN}Ignoring - app_of_apps - dry run set${NC}"
        return
    fi

    echo "🌴 Running app_of_apps..."

    oc apply -f gitops/app-of-apps/${ENVIRONMENT}-app-of-apps.yaml

    echo "🌴 app_of_apps ran OK"
}

all() {
    echo "🌴 ENVIRONMENT set to $ENVIRONMENT"
    echo "🌴 BASE_DOMAIN set to $BASE_DOMAIN"
    echo "🌴 CLUSTER_NAME set to $CLUSTER_NAME"
    echo "🌴 KUBECONFIG set to $KUBECONFIG"

    wait_for_openshift_api
    app_of_apps
    wait_for_project agent-demo
}

usage() {
  cat <<EOF 2>&1
usage: $0 [ -d ] [ -b <base_domain> ] [ -c <cluster_name> ] [ -e <environment> ] [ -k <kubeconfig> ]

Install the apps
EOF
  exit 1
}

while getopts db:c:e:k: opts; do
  case $opts in
    b)
      BASE_DOMAIN=$OPTARG
      ;;
    c)
      CLUSTER_NAME=$OPTARG
      ;;
    d)
      DRYRUN="--no-dry-run"
      ;;
    e)
      ENVIRONMENT=$OPTARG
      ;;
    k)
      KUBECONFIG=$OPTARG
      ;;
    *)
      usage
      ;;
  esac
done

shift `expr $OPTIND - 1`

# Check for EnvVars
[ -z "$BASE_DOMAIN" ] && echo "🕱 Error: must supply BASE_DOMAIN in env or cli" && exit 1
[ -z "$CLUSTER_NAME" ] && echo "🕱 Error: must supply CLUSTER_NAME in env or cli" && exit 1
[ -z "$ENVIRONMENT" ] && echo "🕱 Error: must supply ENVIRONMENT in env or cli" && exit 1
[ -z "$KUBECONFIG" ] && echo "🕱 Error: KUBECONFIG not set in env or cli" && exit 1
[ -z "$AWS_PROFILE" ] && [ -z "$AWS_ACCESS_KEY_ID" ] && echo "🕱 Error: AWS_ACCESS_KEY_ID not set in env" && exit 1
[ -z "$AWS_PROFILE" ] && [ -z "$AWS_SECRET_ACCESS_KEY" ] && echo "🕱 Error: AWS_SECRET_ACCESS_KEY not set in env" && exit 1
[ -z "$AWS_PROFILE" ] && [ -z "$AWS_DEFAULT_REGION" ] && echo "🕱 Error: AWS_DEFAULT_REGION not set in env" && exit 1

all

echo -e "\n🌻${GREEN}Apps deployed OK.${NC}🌻\n"
exit 0
