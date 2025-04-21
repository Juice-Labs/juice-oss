# Juice Agent Helm Chart

A [Juice Agent](https://juicelabs.co/) chart for Kubernetes. 
# TL;DR;

```console
helm repo add juicelabs https://juice-labs.github.io/juice
helm upgrade --install juice juicelabs/agent --set credentials.secretName=<kubernetes secret>
```


## Introduction

This chart deploys [Juice Agents](https://juicelabs.co/) on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.


## Installing the Chart

Before install the chart, an authentication token must be created for the agents. Additionally, you will need to determine the pool in which the agents will operate.

### Creating the authentication token
This can be done by logging into Juice on your desktop machine and then executing the following command.
```
juice m2m create --description kubernetes
```

This command will generate a new token with the description "kubernetes" and display it in the console. Please make sure to copy the token and store it in a secure location, as it will be required for the next steps.

### Selecting a pool
An agent can only operate within a single pool. To view the pools you have access to, run the following command on your desktop:
```
juice pool list
```

Choose a pool and make a note of the pool ID, as it will be required when configuring the agent.

### Creating the credentials secret
This chart requires a the authentication token and pool id to be stored in a kubernetes secret. To create the secret run the following command using the values you obtained in the previous steps:

```console
kubectl create secret generic juice --from-literal=JUICE_TOKEN=<token> --from-liternal=JUICE_POOL=<pool-id>
```

Once the secret is created, the chart can be installed as follows:

```console
helm repo add juicelabs https://juice-labs.github.io/juice
```

```console
helm upgrade --install juice juicelabs/agent --set credentials.secretName=juice
```
Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm upgrade --install juice juicelabs/agent -f values.yaml
```


## Uninstalling the Chart

To uninstall/delete the `juice` deployment:

```console
$ helm uninstall juice
```

The command removes all the Kubernetes components associated with the chart and deletes the release.


## Configuration

## Parameters

### Credentials

| Name                     | Description                                            | Value         |
| ------------------------ | ------------------------------------------------------ | ------------- |
| `credentials.secretName` | Name of the kubernetes secret to read credentials from | `""`          |
| `credentials.poolKey`    | The key in the secret to read the pool from            | `JUICE_POOL`  |
| `credentials.tokenKey`   | The key in the secret to read the token from           | `JUICE_TOKEN` |

### Agent Settings

| Name         | Description                  | Value  |
| ------------ | ---------------------------- | ------ |
| `agent.port` | The port to run the agent on | `7865` |

### Image

| Name               | Description       | Value                        |
| ------------------ | ----------------- | ---------------------------- |
| `image.repository` | Image Repository  | `docker.io/juicelabs/server` |
| `image.pullPolicy` | Image Pull policy | `IfNotPresent`               |
| `image.tag`        | Image Tag         | `latest`                     |

### Deployment

| Name                 | Description                                                        | Value                    |
| -------------------- | ------------------------------------------------------------------ | ------------------------ |
| `daemonSet`          | Run as a DaemonSet rather than a Deployment                        | `false`                  |
| `replicaCount`       | Replicas to deploy when running as a Deployment                    | `1`                      |
| `nameOverride`       | Partially override release name                                    | `""`                     |
| `fullnameOverride`   | Fully override name                                                | `""`                     |
| `podAnnotations`     | Annotations to add to pods                                         | `{}`                     |
| `podLabels`          | Labels to add to pods                                              | `{}`                     |
| `env`                | Additional environment variables to add                            | `{}`                     |
| `envFrom`            | Additional environment variables to add from configmaps or secrets | `{}`                     |
| `nodeSelector`       | Node labels for pod assignment                                     | `{}`                     |
| `tolerations`        | Tolerations for pod assignment                                     | `[]`                     |
| `nodeSelectorPreset` | If no nodeSelector is specified, fallback to looking for GPU nodes | `nvidia.com/gpu.present` |

### Resources

| Name                        | Description     | Value   |
| --------------------------- | --------------- | ------- |
| `resources.requests.cpu`    | CPU Requests    | `500m`  |
| `resources.requests.memory` | Memory Requests | `128Mi` |
