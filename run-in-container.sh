#!/bin/sh

# Allow overriding with a custom shell inside the container
shell="/bin/sh"
case "$1" in
	--shell) shell=$2; shift; shift;;
esac

# Copy the shell script, if any, into the container at same path
if [ -f $1 ]; then
    echo "Copying $1 to container"
	podman exec $__RUNNING_CONTAINER mkdir -p $(dirname $1)
    podman cp $1 $__RUNNING_CONTAINER:$1
fi

# Delete past temporary files for GITHUB_OUTPUT and GITHUB_ENV
OUT_FILE=/tmp/_gha_output
ENV_FILE=/tmp/_gha_env
if ! podman exec $__RUNNING_CONTAINER /bin/sh -c "rm -f $OUT_FILE $ENV_FILE && touch $OUT_FILE && touch $ENV_FILE"; then
    FAILURE=1
fi

# Run the command/script
cmd="$shell $@"
echo "Running in container $__RUNNING_CONTAINER: $cmd"
if ! podman exec -e GITHUB_OUTPUT=$OUT_FILE -e GITHUB_ENV=$ENV_FILE -w $GITHUB_WORKSPACE $__RUNNING_CONTAINER $cmd; then
    FAILURE=1
fi

# Propagate GITHUB_OUTPUT and GITHUB_ENV back out
LOCAL_OUT=$(mktemp)
LOCAL_ENV=$(mktemp)
podman cp $__RUNNING_CONTAINER:$OUT_FILE $LOCAL_OUT
podman cp $__RUNNING_CONTAINER:$ENV_FILE $LOCAL_ENV
for line in $(cat $LOCAL_OUT); do
  echo "$line" >> $GITHUB_OUTPUT
done
for line in $(cat $LOCAL_ENV); do
  echo "$line" >> $GITHUB_ENV
done

if [ -n "$variable_name" ]; then
    echo "Container command failed."
    exit 1
fi