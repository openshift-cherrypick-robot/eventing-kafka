#!/usr/bin/env bash

source $(dirname $0)/resolve.sh

release=$1

source_output_file="openshift/release/knative-eventing-kafka-source-ci.yaml"
source_postinstall_output_file="openshift/release/knative-eventing-kafka-source-postinstall-ci.yaml"
channel_output_file="openshift/release/knative-eventing-kafka-channel-ci.yaml"
channel_postinstall_file="openshift/release/knative-eventing-kafka-channel-postinstall-ci.yaml"

if [ "$release" == "ci" ]; then
    image_prefix="registry.ci.openshift.org/openshift/knative-nightly:knative-eventing-kafka-"
    tag=""
else
    image_prefix="registry.ci.openshift.org/openshift/${release}:knative-eventing-kafka-"
    tag=""
fi

# the source parts
resolve_resources config/source/single $source_output_file $image_prefix $tag
resolve_resources config/source/post-install $source_postinstall_output_file $image_prefix $tag

# the channel parts
resolve_resources config/channel/consolidated $channel_output_file $image_prefix $tag
resolve_resources config/channel/post-install $channel_postinstall_file $image_prefix $tag
