#!/bin/sh
set -e
if [ -z $JUICE_TOKEN ]; then
  echo "Missing JUICE_TOKEN"
  exit 1
fi

if [ -z $JUICE_POOL ]; then
  echo "Missing JUICE_POOL"
  exit 1
fi

if [ -z $JUICE_HOST_IP ]; then
  echo "Missing JUICE_HOST_IP"
  exit 1
else
  JUICE_HOST_IP=$(eval echo $JUICE_HOST_IP)
fi

if [ -n $JUICE_HOST_PORT ]; then
  JUICE_HOST_PORT=$(eval echo $JUICE_HOST_PORT)
fi

ARGS="agent --log-file stdout run $JUICE_POOL --gateway-port $JUICE_HOST_PORT --gateway-ips $JUICE_HOST_IP $JUICE_ADDITIONAL_ARGS"

echo "Logging in..."
./juice login -t $JUICE_TOKEN
echo "Starting agent: ./juice $ARGS"
exec ./juice $ARGS