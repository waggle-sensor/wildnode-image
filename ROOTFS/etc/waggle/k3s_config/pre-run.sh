#!/bin/bash -e

# Script to be run before every execution of the K3s server

CONFIG_DEST=/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
CONFIG_SRC=/etc/waggle/k3s_config/config.toml.tmpl

# ensure the destination path exists
mkdir -p $(dirname $CONFIG_DEST)

cp $CONFIG_SRC $CONFIG_DEST
