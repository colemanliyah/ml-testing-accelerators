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

local common = import 'common.libsonnet';
local mixins = import 'templates/mixins.libsonnet';
local timeouts = import 'templates/timeouts.libsonnet';
local tpus = import 'templates/tpus.libsonnet';
local utils = import 'templates/utils.libsonnet';
local experimental = import '../experimental.libsonnet';

{
  local bert = common.ModelGardenTest {
    modelName: 'bert-mnli',
    command: [
      'python3',
      'official/nlp/bert/run_classifier.py',
      '--tpu=$(KUBE_GOOGLE_CLOUD_TPU_ENDPOINTS)',
      '--steps_per_loop=1000',
      '--input_meta_data_path=$(BERT_CLASSIFICATION_DIR)/mnli_meta_data',
      '--train_data_path=$(BERT_CLASSIFICATION_DIR)/mnli_train.tf_record',
      '--eval_data_path=$(BERT_CLASSIFICATION_DIR)/mnli_eval.tf_record',
      '--bert_config_file=$(KERAS_BERT_DIR)/uncased_L-24_H-1024_A-16/bert_config.json',
      '--init_checkpoint=$(KERAS_BERT_DIR)/uncased_L-24_H-1024_A-16/bert_model.ckpt',
      '--learning_rate=3e-5',
      '--distribution_strategy=tpu',
      '--model_dir=%s' % self.flags.modelDir,
    ],
    flags:: {
      modelDir: '$(MODEL_DIR)',
    },
  },
  local functional = common.Functional {
    command+: [
      '--num_train_epochs=1',
    ],
  },
  local convergence = common.Convergence {
    command+: [
      '--num_train_epochs=6',
    ],
    regressionTestConfig+: {
      metric_success_conditions+: {
        examples_per_second_average: {
          comparison: 'greater_or_equal',
          success_threshold: {
            stddevs_from_mean: 4.0,
          },
        },
      },
    },
  },
  local v2_8 = {
    accelerator: tpus.v2_8,
    command+: [
      '--train_batch_size=64',
      '--eval_batch_size=64',
    ],
  },
  local v3_8 = {
    accelerator: tpus.v3_8,
    command+: [
      '--train_batch_size=64',
      '--eval_batch_size=64',
    ],
  },
  local v2_32 = {
    accelerator: tpus.v2_32,
    command+: [
      '--train_batch_size=256',
      '--eval_batch_size=256',
    ],
  },
  local v3_32 = {
    accelerator: tpus.v3_32,
    command+: [
      '--train_batch_size=256',
      '--eval_batch_size=256',
    ],
  },
  local tpuVm = experimental.TensorFlowTpuVmMixin,
  local tpuVmProfilingCheck = experimental.TensorFlowTpuVmMixin {
    mode: 'profile',
    command: utils.scriptCommand(|||
      %s

      grep -a -c device:TPU $(LOCAL_OUTPUT_DIR)/summaries/train/plugins/profile/*/*.xplane.pb
    ||| % std.join(' ', super.command)),
    flags+:: {
      modelDir: '$(LOCAL_OUTPUT_DIR)',
    },
  },

  configs: [
    bert + v2_8 + functional,
    bert + v2_8 + functional + tpuVm,
    bert + v2_8 + functional + tpuVmProfilingCheck,
    bert + v3_8 + functional,
    bert + v3_8 + functional + tpuVm,
    bert + v2_8 + convergence + timeouts.Hours(4),
    bert + v3_8 + convergence + timeouts.Hours(3),
    bert + v2_32 + functional + tpuVm,
    bert + v3_32 + functional,
    bert + v3_32 + functional + tpuVm,
    bert + v2_32 + convergence + tpus.reserved + { schedule: '54 21 * * 1,3,5,6' },
    bert + v3_32 + convergence,
  ],
}
