# OpenFlight Hub Configuration

## Image

The OpenFlight hub is available as an image. Creating an instance of this image will provide a fully working hub with the tools, local tool mirror repo and prompt. 

Image available at:
- AWS: openflight-hub-20190523152135

## Build Process

The base machine creation is outside the scope of this doc/repo. A base CentOS image that matches the requirements in the Specification section will need to be created.

To configure the base appliance, run the setup script:

```
curl https://raw.githubusercontent.com/openflighthpc/openflight-hub/master/hub-setup.sh |/bin/bash
```

On next login as the CentOS user, the system will prompt for instance-specific configuration.

## Specification

### Base Machine

The base CentOS machine consists of:

* A standard CentOS installation (@core and @base packages)
* 1 network interface 

This machine could be physical, virtual or cloud as long as it complies with the above bullet points.

### Base Appliance

The base appliance script does the following:

* Disables SElinux
* Clones the OpenFlight yum repository (and configures HTTP for serving packages)
* Installs Flight Architect
* Installs Flight Cloud
* Installs Flight Inventory
* Setup prompt

### Tool Versions

Alces Appliance 1.0 uses the following tool versions:
- Overware 1.2
- Flight Architect 1.0
- Flight Cloud 1.1
- Flight Inventory 1.2

