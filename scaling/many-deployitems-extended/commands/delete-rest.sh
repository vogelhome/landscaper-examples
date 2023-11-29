#!/bin/bash
#
# Copyright (c) 2022 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

COMPONENT_DIR="$(dirname $0)/.."
cd "${COMPONENT_DIR}"
COMPONENT_DIR="$(pwd)"
echo compdir ${COMPONENT_DIR}

source ${COMPONENT_DIR}/commands/settings

TMP_DIR=`mktemp -d`
echo tempdir ${TMP_DIR}

mako-render "${COMPONENT_DIR}/installation/context.yaml.tlp" \
  --var namespace="${NAMESPACE}" \
  --output-file="${TMP_DIR}/context.yaml"

mako-render "${COMPONENT_DIR}/installation/dataobject-values.yaml.tlp" \
  --var namespace="${NAMESPACE}" \
  --var sleep="${SLEEP}" \
  --var helm="${HELM}" \
  --var helmDeployment="${HELM_DEPLOYMENT}" \
  --var text="${TEXT}" \
  --var numOfCm="${NUM_OF_CM}" \
  --output-file="${TMP_DIR}/dataobject-values.yaml"

# Counter
externalLoop=1
# Iterate over all files in the directory
for TARGET_CLUSTER_KUBECONFIG_PATH in "$TARGET_CLUSTER_KUBECONFIG_FOLDER"/*
do
  # Check if it is a file (not a directory)
  if [ -f "$TARGET_CLUSTER_KUBECONFIG_PATH" ]; then
    echo "External loop: $externalLoop"
    echo "Reading file $TARGET_CLUSTER_KUBECONFIG_PATH"

    mako-render "${COMPONENT_DIR}/installation/target.yaml.tlp" \
      --var namespace="${NAMESPACE}" \
      --var externalLoop="${externalLoop}" \
      --var kubeconfig_path="${TARGET_CLUSTER_KUBECONFIG_PATH}" \
      --output-file="${TMP_DIR}/target-${externalLoop}.yaml"

    for (( internalLoop=1; internalLoop<=${NUM_TOP_LEVEL_INSTS}; internalLoop++ ))
    do
       echo "Internal loop $internalLoop"

       echo "render releases"

       mako-render "${COMPONENT_DIR}/installation/dataobject-releases.yaml.tlp" \
         --var namespace="${NAMESPACE}" \
         --var externalLoop="${externalLoop}" \
         --var internalLoop="${internalLoop}" \
         --var numsubinsts="${NUM_SUB_INSTS}" \
         --output-file="${TMP_DIR}/dataobject-releases-${externalLoop}-${internalLoop}.yaml"

       echo "delete namespace"
       for (( j=0; j<${NUM_SUB_INSTS}; j++ ))
       do
         kubectl delete ns item-${externalLoop}-${internalLoop}-${j} --kubeconfig "${TARGET_CLUSTER_KUBECONFIG_PATH}" --wait=false
       done
    done

    externalLoop=$((externalLoop+1))
  fi
done

echo "delete k8s resources"
kubectl delete -f "${TMP_DIR}"

