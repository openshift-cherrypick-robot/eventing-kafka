#!/usr/bin/env bash

# shellcheck disable=SC1090
source "$(dirname "$0")/../vendor/knative.dev/hack/e2e-tests.sh"
source "$(dirname "$0")/e2e-common.sh"

set -Eeuox pipefail

export TEST_IMAGE_TEMPLATE="${EVENTING_KAFKA_TEST_IMAGE_TEMPLATE}"

################################################################################
# Fallback to midstream images if Serverless Operator doesn't provide the
# required Knative versions.
# Note: This currently affects only which Knative eventing version to install.
#
# Values:
#   - True: Try to find the required knative version that matches current branch
#           on ServerlessOperator. If not found, install the matching version
#           version from midstream
#   - False: Install the Knative version provided by the ServerlessOperator
#           regardless of the version compatability.
################################################################################
fallback_to_kn_midstream=${1:-true}

env

scale_up_workers || exit 1

failed=0

(( !failed )) && install_strimzi || failed=1

(( !failed )) && install_serverless "$fallback_to_kn_midstream"|| failed=1

(( !failed )) && install_knative_kafka || failed=1

(( !failed )) && install_tracing || failed=1

(( !failed )) && run_e2e_tests || failed=1

(( failed )) && dump_cluster_state

(( failed )) && exit 1

success
