local env = std.extVar("__ksonnet/environments");

local baseParams = std.extVar("__ksonnet/params").components["t2t-code-search-serving"];

local experiments = import "experiments.libsonnet";

local k = import "k.libsonnet";

local experimentName = baseParams.experiment;
local experimentParams= experiments[experimentName];
local params = baseParams + experimentParams + {
  name: "t2t-code-search",

  // Keep in sync with the TF version used during training.
  image: "tensorflow/serving:1.11.1",
  namespace: env.namespace,

  // The TF-Serving component uses the parameter modelBasePath
  modelBasePath: experimentParams.modelBasePath,
};


local deployment = k.apps.v1beta1.deployment;
local container = deployment.mixin.spec.template.spec.containersType;

local util = import "kubeflow/tf-serving/util.libsonnet";
local tfserving = import "kubeflow/tf-serving/tf-serving-template.libsonnet";

local base = tfserving.new(env, params);
local tfDeployment = base.tfDeployment +
                     deployment.mixin.spec.template.spec.withVolumesMixin(
                       if params.gcpCredentialSecretName != "null" then (
                         [{
                           name: "gcp-credentials",
                           secret: {
                             secretName: params.gcpCredentialSecretName,
                           },
                         }]
                       ) else [],
                     )+
                     deployment.mapContainers(
                       function(c) {
                         result::
                           c + container.withEnvMixin(
                             if params.gcpCredentialSecretName != "null" then (
                               [{
                                 name: "GOOGLE_APPLICATION_CREDENTIALS",
                                 value: "/secret/gcp-credentials/key.json",
                               }]
                             ) else [],
                           ) +
                           container.withVolumeMountsMixin(
                             if params.gcpCredentialSecretName != "null" then (
                               [{
                                 name: "gcp-credentials",
                                 mountPath: "/secret/gcp-credentials",
                               }]
                             ) else [],
                           ),
                       }.result,
                     );
util.list([
  tfDeployment,
  base.tfService,
],)
