#!/bin/bash

#  TODO: Would be nice to have a well known URI for this ala:
#          http://downloads.strongloop.com/
STRONGLOOP_CDN="http://45ec19d3127bddec1c1d-e57051fde4dbc9469167f8c2a84830dc.r36.cf1.rackcdn.com/"

#  StrongLoop Node package name.
STRONGLOOP_NODE_PACKAGE_NAME="strongloop-node"

#  Platform specific package extensions.
DEB_PACKAGE_EXTENSION="amd64.deb"
RHEL_PACKAGE_EXTENSION="el6.x86_64.rpm"

#  Vendor specific install dir.
STRONGLOOP_VENDOR_INSTALL_DIR="vendor/strongloop"


#  Defaults - change this as per the lifecycle phases this buildpack or its
#  clone goes through.
STRONGLOOP_DEFAULT_NODE_VERSION="1.2.0-1"
STRONGLOOP_DEFAULT_NODE_ENV="production"


