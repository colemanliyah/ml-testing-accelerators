// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

local base = import 'templates/base.libsonnet';
local metrics = import 'templates/metrics.libsonnet';

{
  CloudAcceleratorTest:: base.BaseTest {
    local config = self,

    publisherImage: 'gcr.io/xl-ml-test/publisher:stable',

    tpuSettings+: {
      requireTpuAvailableLabel: true,
    },

    metricConfig:
      metrics.CompatMetrics(config.metricCollectionConfig, config.regressionTestConfig),

    // Add experimental TPU health monitor to Job.
    podTemplate+:: {
      spec+: {
        containerMap+: if config.accelerator.type == 'tpu' then
          {
            monitor: {
              name: 'monitor',
              image: 'gcr.io/xl-ml-test/health-monitor:stable',
              imagePullPolicy: 'Always',
              env: [
                {
                  name: 'POD_NAME',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.name',
                    },
                  },
                },
                {
                  name: 'POD_NAMESPACE',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.namespace',
                    },
                  },
                },
              ],
            },
          }
        else {},
      } + if config.accelerator.type == 'gpu' then {
        priorityClassName: 'gpu-%(version)s' % config.accelerator,
      } else if config.accelerator.type == 'tpu' then {
        priorityClassName: if config.accelerator.replicas == 1 then
          'tpu-device' else 'tpu-pod',
        containerMap+: {
          train+: {
            resources+: {
              limits+: {
                ['tpu.googleapis.com/v%s' % config.accelerator.version]: config.accelerator.size,
              },
            },
          },
        },
      } else {},
    },

    cronJob+:: {
      metadata+: {
        namespace: 'automated',
      },
    },
  },
}
