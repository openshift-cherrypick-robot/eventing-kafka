#!/usr/bin/env bash

# shellcheck disable=SC1090
source "$(dirname "$0")/../vendor/knative.dev/hack/e2e-tests.sh"
source "$(dirname "$0")/e2e-common.sh"

set -Eeuox pipefail

export TEST_IMAGE_TEMPLATE="${EVENTING_KAFKA_TEST_IMAGE_TEMPLATE}"

# Check if the same version of eventing is available via the serverless operator
so_branch="$(find_matching_so_release_branch)"
if [[ "$so_branch" == "0" ]]; then
  # Only run e2e tests in case the serverless operator doesn't have a matching
  # eventing version.
  # This assumes that the version provided by SO is an older eventing version,
  # thus a forward compatibility test is needed.

  # Don't fall back to midstream knative and use serverless operator knative
  sh "$(dirname "$0")/e2e-tests.sh" false
fi

exit 0
