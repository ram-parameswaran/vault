# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

# Code generated by pipeline generate enos-dynamic-config DO NOT EDIT.

# This file is overwritten in CI as it contains branch specific and sometimes ever-changing values.
# It's checked in here so that enos samples and scenarios can be performed, just be aware that this
# might change out from under you.

globals {
  sample_attributes = {
    aws_region              = ["us-east-1", "us-west-2"]
    distro_version_amzn     = ["2023"]
    distro_version_leap     = ["15.6"]
    distro_version_rhel     = ["8.10", "9.4"]
    distro_version_sles     = ["15.6"]
    distro_version_ubuntu   = ["20.04", "24.04"]
    upgrade_initial_version = ["1.16.1", "1.16.2", "1.16.3", "1.17.0-rc1", "1.17.0", "1.17.1", "1.17.2", "1.17.3", "1.17.4", "1.17.5", "1.17.6", "1.18.0-rc1", "1.18.0"]
  }
}
