#!/usr/bin/env bash

branch=${1-'knative-v0.19.1'}
openshift=${2-'4.6'}
promotion_disabled=${3-false}
generate_continuous=${4-false}

if [[ "$branch" == "knative-next" ]]; then
  promotion_name="knative-nightly"
  generate_continuous=false
else
  promotion_name="$branch.0"
fi

core_images=$(find ./openshift/ci-operator/knative-images -mindepth 1 -maxdepth 1 -type d | LC_COLLATE=posix sort)
test_images=$(find ./openshift/ci-operator/knative-test-images -mindepth 1 -maxdepth 1 -type d | LC_COLLATE=posix sort)
function print_image_dependencies {
  for img in $core_images; do
    image_base=knative-eventing-kafka-$(basename $img)
    to_image=$(echo ${image_base//[_.]/-})
    to_image=$(echo ${to_image//v0/upgrade-v0})
    to_image=$(echo ${to_image//migrate/storage-version-migration})
    to_image=$(echo ${to_image//kafka-kafka-/kafka-})
    image_env=$(echo ${to_image//-/_})
    image_env=$(echo ${image_env^^})
    cat <<EOF
      - env: $image_env
        name: $to_image
EOF
  done

  for img in $test_images; do
    image_base=knative-eventing-kafka-test-$(basename $img)
    to_image=$(echo ${image_base//_/-})
    image_env=$(echo ${to_image//-/_})
    image_env=$(echo ${image_env^^})
    cat <<EOF
      - env: $image_env
        name: $to_image
EOF
  done
}

function print_promotion {
  cat <<EOF
promotion:
  additional_images:
    knative-eventing-kafka-src: src
  disabled: $promotion_disabled
  cluster: https://api.ci.openshift.org
  namespace: openshift
  name: $promotion_name
EOF
}

function print_releases {
  cat <<EOF
releases:
  initial:
    integration:
      name: "$openshift"
      namespace: ocp
  latest:
    integration:
      include_built_images: true
      name: "$openshift"
      namespace: ocp
EOF
}

function print_base_images {
  cat <<EOF
base_images:
  base:
    name: "$openshift"
    namespace: ocp
    tag: base
EOF
}

function print_build_root {
  cat <<EOF
build_root:
  project_image:
    dockerfile_path: openshift/ci-operator/build-image/Dockerfile
canonical_go_repository: knative.dev/eventing-kafka
binary_build_commands: make install
test_binary_build_commands: make test-install
EOF
}

function print_not_openshift_47 {
  cat <<EOF
- as: e2e-aws-ocp-${openshift//./}
  cluster_claim:
    architecture: amd64
    cloud: aws
    owner: openshift-ci
    product: ocp
    timeout: 1h0m0s
    version: "$openshift"
  steps:
    test:
    - as: test
      cli: latest
      commands: make test-e2e
      dependencies:
$image_deps
      from: src
      resources:
        requests:
          cpu: 100m
      timeout: 4h0m0s
    workflow: generic-claim
EOF
  if [[ "$openshift" == "4.9" ]]; then
    cat <<EOF
- as: so-forward-compatibility-ocp-${openshift//./}
  optional: true
  cluster_claim:
    architecture: amd64
    cloud: aws
    owner: openshift-ci
    product: ocp
    timeout: 1h0m0s
    version: "$openshift"
  steps:
    test:
    - as: test
      cli: latest
      commands: make test-so-forward-compat
      dependencies:
$image_deps
      from: src
      resources:
        requests:
          cpu: 100m
      timeout: 4h0m0s
    workflow: generic-claim
EOF
  fi
  if [[ "$generate_continuous" == true ]]; then
    cat <<EOF
- as: e2e-aws-ocp-${openshift//./}-continuous
  cluster_claim:
    architecture: amd64
    cloud: aws
    owner: openshift-ci
    product: ocp
    timeout: 1h0m0s
    version: "$openshift"
  cron: 0 */12 * * 1-5
  steps:
    test:
    - as: test
      cli: latest
      commands: make test-e2e
      dependencies:
$image_deps
      from: src
      resources:
        requests:
          cpu: 100m
      timeout: 4h0m0s
    workflow: generic-claim
EOF
  fi
}

function print_openshift_47 {
  cat <<EOF
- as: e2e-aws-ocp-${openshift//./}
  steps:
    cluster_profile: aws
    test:
    - as: test
      cli: latest
      commands: make test-e2e
      dependencies:
$image_deps
      from: src
      resources:
        requests:
          cpu: 100m
    workflow: ipi-aws
EOF
  if [[ "$generate_continuous" == true ]]; then
    cat <<EOF
- as: e2e-aws-ocp-${openshift//./}-continuous
  cron: 0 */12 * * 1-5
  steps:
    cluster_profile: aws
    test:
    - as: test
      cli: latest
      commands: make test-e2e
      dependencies:
$image_deps
      from: src
      resources:
        requests:
          cpu: 100m
    workflow: ipi-aws
EOF
  fi
}

function print_resources {
  cat <<EOF
resources:
  '*':
    limits:
      memory: 6Gi
    requests:
      cpu: 4
      memory: 6Gi
  'bin':
    limits:
      memory: 6Gi
    requests:
      cpu: 4
      memory: 6Gi
EOF
}

function print_images {
  cat <<EOF
images:
EOF

for img in $core_images; do
  image_base=$(basename $img)
  to_image=$(echo ${image_base//[_.]/-})
  to_image=$(echo ${to_image//v0/upgrade-v0})
  to_image=$(echo ${to_image//migrate/storage-version-migration})
  to_image=$(echo ${to_image//kafka-kafka-/kafka-})
  cat <<EOF
- dockerfile_path: openshift/ci-operator/knative-images/$image_base/Dockerfile
  from: base
  inputs:
    bin:
      paths:
      - destination_dir: .
        source_path: /go/bin/$image_base
  to: knative-eventing-kafka-$to_image
EOF
done

for img in $test_images; do
  image_base=$(basename $img)
  to_image=$(echo ${image_base//_/-})
  cat <<EOF
- dockerfile_path: openshift/ci-operator/knative-test-images/$image_base/Dockerfile
  from: base
  inputs:
    test-bin:
      paths:
      - destination_dir: .
        source_path: /go/bin/$image_base
  to: knative-eventing-kafka-test-$to_image
EOF
done
}

image_deps=$(print_image_dependencies)

print_base_images
print_build_root

cat <<EOF
tests:
EOF

if [[ "$openshift" != "4.7" ]]; then
  print_not_openshift_47
else
  print_openshift_47
fi

print_releases
print_promotion
print_resources
print_images
