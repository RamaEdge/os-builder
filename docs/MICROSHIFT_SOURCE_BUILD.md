# MicroShift Source Build Guide

This document describes how to build MicroShift from source when creating the OS image.

1. Clone the MicroShift repository:
   ```bash
   git clone https://github.com/openshift/microshift.git
   ```
2. Build the binaries using the provided scripts inside `os/`:
   ```bash
   cd os
   make microshift
   ```
3. The resulting binaries are copied into the container during the image build.

Use the `MICROSHIFT_VERSION` variable to check out a specific branch or tag when running `make build`.
