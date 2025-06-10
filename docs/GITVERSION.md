# GitVersion Integration Guide

The project uses [GitVersion](https://gitversion.net/) to generate semantic version numbers based on Git history. These versions are applied to container images and artifacts automatically.

## Usage

1. Ensure `GitVersion` is installed on your build machine.
2. Run `gitversion` or use the provided Makefile targets which call GitVersion internally.
3. The calculated version is exported as `GIT_VERSION` and consumed by build scripts and GitHub Actions.

See `VERSION_MANAGEMENT.md` for more details on centralized version handling.
