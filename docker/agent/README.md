# Juice Agent

This image enables you to run your Juice Agent inside Docker on your Linux server.

## Prerequisites
 * NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

## Setup

Before launching the agent container, an authentication token must be created for the agent to use for authentication. Additionally, you will need to determine the pool in which the agent will operate.

### Creating the authentication token
This can be done by logging into Juice on your desktop machine and then executing the following command.
```
juice m2m create --description docker
```

This command will generate a new token with the description "docker" and display it in the console. Please make sure to copy the token and store it in a secure location, as it will be required for the next steps.

### Selecting a pool
An agent can only operate within a single pool. To view the pools you have access to, run the following command on your desktop:
```
juice pool list
```

Choose a pool and make a note of the pool ID, as it will be required when configuring the agent.

## Usage

### docker-compose (recommended)

Create the following two files and update the .env file with the values you obtained in the Setup section.

docker-compose.yaml
```yaml
---
services:
  juice-agent:
    image: juicelabs/agent:${VERSION}
    container_name: juice-agent
    environment:
      - JUICE_TOKEN=${JUICE_TOKEN}
      - JUICE_POOL=${JUICE_POOL}
      - JUICE_HOST_IP=${JUICE_HOST_IP}
    ports:
      - 7865:7865/udp
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

.env
```
VERSION=latest
JUICE_TOKEN=your_token
JUICE_POOL=your_pool_id
JUICE_HOST_IP=your_host_ip
```

To start you agent run:
`docker compose up -d`

You can then view the logs with:
`docker compose logs -f juice-agent`

### docker-cli

Run the following command to start the container
```bash
docker run \
   --name juice-agent \
   --gpus all \
   -p 7865:7865/udp \
   -e JUICE_TOKEN=<YOUR_TOKEN> \
   -e JUICE_POOL=<YOUR_POOL_ID> \
   -e JUICE_HOST_IP=<YOUR_HOST_IP> \
   -v ./logs:/home/juice/agent/log \
   --restart unless-stopped \
   juicelabs/agent:latest
```

## Parameters

The container is configured using environment variables passed at runtime (such as those above). 

| Parameter | Default Value | Descripton |
| --- | --- | --- |
| `JUICE_TOKEN` | none (required) |The m2m token for this agent |
| `JUICE_POOL` | none (required) | The pool to connect this agent to |
| `JUICE_HOST_IP` | none (required) | A CSV of network addresses that clients should use when connecting to the agent. This is usually your machine LAN IP and Internet IP if clients will be connecting over the Internet |
| `JUICE_HOST_PORT` | 7865 | The network port to use |
| `JUICE_ADDITIONAL_ARGS` | none | Additional arguments to pass to the agent |


## Updating

The example configuration above uses the `latest` tag. If you prefer to lock your agent to a specific version you can set the `VERSION` parameter in the `.env` file. Available versions can be found on [Docker Hub](https://hub.docker.com/r/juicelabs/agent/tags).

If you choose to continue using the latest tag, you will need to force Docker to pull the latest version. You can do this by running the following command:

`docker pull juicelabs/agent:latest`

and then restarting your container with compose:

`docker compose up -d`
