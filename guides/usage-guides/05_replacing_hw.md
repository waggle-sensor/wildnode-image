# Replacing Hardware (i.e. RPi or NX Agent)

**Table of Contents**
- [Replacing Hardware (i.e. RPi or NX Agent)](#replacing-hardware-ie-rpi-or-nx-agent)
- [Replacing a RPi](#replacing-a-rpi)
- [Replacing a NX Agent](#replacing-a-nx-agent)
- [Replacing a NX Core](#replacing-a-nx-core)

If a compute unit (i.e. RPi, NX Agent) needs to be replaced this guide outlines the steps that need to be taken.

# Replacing a RPi

If a RPi is replaced follow these steps:

- Remove the old RPi entry (by MAC address) from the `/var/lib/misc/dnsmasq.leases` file on the NX core and then reboot the node.
- Delete the old RPi `kubectl node`
  - reference: https://stackoverflow.com/questions/35757620/how-to-gracefully-remove-a-node-from-kubernetes )
- Update the cloud manifest with the new RPI mac address

> Remember that the WSN was designed form the beginning to only have 1 “shield” (or primary) RPi, so only 1 RPi will have a permanent lease to 10.31.81.4.

# Replacing a NX Agent

If a NX Agent is replaced follow these steps:

You will need to delete the `kubectl node` (see: https://stackoverflow.com/questions/35757620/how-to-gracefully-remove-a-node-from-kubernetes )
- Update the cloud manifest with the new NX Agent mac address


# Replacing a NX Core

If the NX Core is replaced (i.e. a new NX Core mac address is associated with a VSN), there isn’t much to transition over.  It is basically like starting from scratch.

If the NX Core is replaced follow these steps:
- Update the cloud manifest with the new NX Core mac address
