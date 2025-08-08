# Agent Installer

## TL;DR;

```console
curl https://get.juicelabs.co | INSTALL_JUICE_TOKEN=[token] INSTALL_JUICE_POOL="[pool name]" sh -
```

This script installs the Juice Agent as a systemd or openrc service. It creates the necessary system
users and configuration file to run the Agent.

## Prerequisites

To install the Agent you will need to an access token, the installer uses this to download the necessary files and
create a service token for the Agent. You will also need to determine the pool in which the agent will operate.

If you already have an access token, you can skip on to the installation section

### Creating the authentication token
This can be done by logging into Juice on your desktop machine and then executing the following command.
```
juice m2m create --description "agent installer"
```

This command will generate a new token with the description "agent installer" and display it in the console. 
Please make sure to copy the token and store it in a secure location, as it will be required for the next steps.

### Selecting a pool
An agent can only operate within a single pool. To view the pools you have access to, run the following command on your desktop:
```
juice pool list
```

## Setup

### Download the script
```console
curl -so install.sh https://get.juicelabs.co
```

### Run the script
```console
INSTALL_JUICE_TOKEN=m2m_XXX INSTALL_JUICE_POOL=xxx sh ./install.sh 
```

If you wish to pass additional arguments to the service when it runs you can provide those as parameters to the script:
```console
INSTALL_JUICE_TOKEN=m2m_XXX INSTALL_JUICE_POOL=xxx sh ./install.sh --cache-size 128
```

### Available Install Options

| Name                    | Description       | Default Value                       |
| ----------------------- | ----------------- | ----------------------------------- |
| `INSTALL_JUICE_TOKEN`   | The token to use during installation  | None - Required |
| `INSTALL_JUICE_POOL`    | The pool to run the agent in          | None - Required |
| `INSTALL_JUICE_VERSION` | The version to install                | `latest`        |
| `INSTALL_JUICE_USER`    | The user to run the agent as          | `juice`         |
| `INSTALL_JUICE_NAME`    | The name of the systemd/openrc service| `juice`         |

## Uninstall

To remove the Juice Agent run the uninstall script

```console
/usr/local/juice/uninstall.sh
```
