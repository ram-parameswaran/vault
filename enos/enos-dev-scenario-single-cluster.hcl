# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

scenario "dev_single_cluster" {
  description = <<-EOF
    This scenario spins up a single Vault cluster with either an external Consul cluster or
    integrated Raft for storage. None of our test verification is included in this scenario in order
    to improve end-to-end speed. If you wish to perform such verification you'll need to use a
    non-dev scenario instead.

    The scenario supports finding and installing any released 'linux/amd64' or 'linux/arm64' Vault
    artifact as long as its version is >= 1.8. You can also use the 'artifact:local' variant to
    build and deploy the current branch!

    You can use the following command to get a textual outline of the entire
    scenario:

      $ enos scenario outline dev_single_cluster

    You can also create an HTML version that is suitable for viewing in web browsers:

      $ enos scenario outline dev_single_cluster --format html > index.html
      $ open index.html

    # How to run this scenario

    1. Install Enos (more info: https://eng-handbook.hashicorp.services/internal-tools/enos/getting-started/)
    
      $ brew tap hashicorp/tap && brew update && brew install hashicorp/tap/enos

    2. Authenticate to AWS with Doormat (more info: https://eng-handbook.hashicorp.services/internal-tools/enos/getting-started/#authenticate-to-aws-with-doormat)
    
      $ doormat login && eval $(doormat aws -a <your_aws_account_name> export)

    3. Set the following variables either as environment variables (`export ENOS_VAR_var_name=value`)
    or by creating a 'enos-local.vars' file and setting it there (see enos.vars.hcl for examples):

    Required variables
      - aws_ssh_private_key_path (more info about AWS SSH keypairs: https://eng-handbook.hashicorp.services/internal-tools/enos/getting-started/#set-your-aws-key-pair-name-and-private-key)
      - aws_ssh_keypair_name

    Optional variables
      - aws_region (set if different from the default value in enos-variables.hcl)
      - dev_build_local_ui (set if different from the default value in enos-dev-variables.hcl)
      - dev_consul_version (set if different from the default value in enos-dev-variables.hcl)
      - distro_version_<distro> (set if different from the default version for your target
        distro in enos-globals.hcl)
      - vault_license_path (set if using an ENT edition of Vault)
      - consul_license_path (set if using an ENT edition of Consul, according to var.backend_edition)
    
    4. Choose what type of Vault artifact you want to use, and set the appropriate variables.

      a. 'artifact:local'
      This will build a Vault .zip bundle from your local branch. Set the following variable:

      vault_artifact_path = path/to/where/vault-should-be-built.zip

      b. 'artifact:deb' or 'artifact:rpm'
      This will download a Vault .deb or .rpm package from Artifactory with the version and
      edition you specify. To do this, you will need to set your Artifactory credentials:

      artifactory_username = your-user
      artifactory_token = your-token

      c. 'artifact:zip'
      This will download a Vault .zip bundle from releases.hashicorp.com with the version and
      edition you specify.
    
    5. If you don't know yet what combination of matrix variants you want to use for your scenario, you 
    can view all the possible combinations through the `list` command. You can also reduce the list by
    adding one or more filter items, e.g. 'arch:amd64' to get just the scenario combinations that use amd64.

      $ enos scenario list dev_single_cluster
    
    Once you know what filter you want to use to obtain your desired combination of matrix variants,
    use the `launch` command with that filter to launch your scenario, e.g.:

      $ enos scenario launch dev_single_cluster arch:amd64 artifact:zip backend:consul distro:ubuntu edition:ent seal:awskms

    Notes:
    - To learn more about any Enos command, use the `--help` flag, e.g.:

        $ enos scenario launch --help

    - Enos will run all matrix variant combinations that match your filter. If you specify one
      variant for each matrix item, only one combination of variants will match the filter, and
      therefore Enos will run only one scenario.

    - If you want to use the 'distro:leap' variant you must first accept SUSE's terms for the AWS
      account. To verify that your account has agreed, sign-in to your AWS through Doormat,
      and visit the following links to verify your subscription or subscribe:
        - arm64 AMI: https://aws.amazon.com/marketplace/server/procurement?productId=a516e959-df54-4035-bb1a-63599b7a6df9
        - amd64 AMI: https://aws.amazon.com/marketplace/server/procurement?productId=5535c495-72d4-4355-b169-54ffa874f849

    6. When the scenario is finished launching, refer to the scenario outputs to see information
    related to your cluster, including public IPs. You can use this information to SSH into nodes
    and/or to interact with Vault. If using Ubuntu, your SSH user will be `ubuntu`; if using any
    of the other supported distros, it will be `ec2-user`.

      $ enos scenario output dev_single_cluster <filter>
      $ ssh -i /path/to/your/ssh-private-key.pem <ssh-user>@<public-ip>
      $ vault status

    For Enos troubleshooting tips, see https://eng-handbook.hashicorp.services/internal-tools/enos/troubleshooting/.

    7. When you're done, destroy the scenario and associated infrastructure:

      $ enos scenario destroy dev_single_cluster <filter>
  EOF

  // The matrix is where we define all the baseline combinations that enos can utilize to customize
  // your scenario. By default enos attempts to perform your command on the entire product of these
  // possible comginations! Most of the time you'll want to reduce that by passing in a filter.
  // Run 'enos scenario list --help' to see more about how filtering scenarios works in enos.
  matrix {
    arch     = ["amd64", "arm64"]
    artifact = ["local", "deb", "rpm", "zip"]
    backend  = ["consul", "raft"]
    distro   = ["amzn2", "leap", "rhel", "sles", "ubuntu"]
    edition  = ["ce", "ent", "ent.fips1402", "ent.hsm", "ent.hsm.fips1402"]
    seal     = ["awskms", "pkcs11", "shamir"]

    exclude {
      edition = ["ent.hsm", "ent.fips1402", "ent.hsm.fips1402"]
      arch    = ["arm64"]
    }

    exclude {
      artifact = ["rpm"]
      distro   = ["ubuntu"]
    }

    exclude {
      artifact = ["deb"]
      distro   = ["rhel"]
    }

    exclude {
      seal    = ["pkcs11"]
      edition = ["ce", "ent", "ent.fips1402"]
    }
  }

  // Specify which Terraform configs and providers to use in this scenario. Most of the time you'll
  // never need to change this! If you wanted to test with different terraform or terraform CLI
  // settings you can define them and assign them here.
  terraform_cli = terraform_cli.default
  terraform     = terraform.default

  // Here we declare all of the providers that we might need for our scenario.
  // There are two different configurations for the Enos provider, each specifying
  // SSH transport configs for different Linux distros.
  providers = [
    provider.aws.default,
    provider.enos.ec2_user,
    provider.enos.ubuntu
  ]

  // These are variable values that are local to our scenario. They are evaluated after external
  // variables and scenario matrices but before any of our steps.
  locals {
    // The enos provider uses different ssh transport configs for different distros (as
    // specified in enos-providers.hcl), and we need to be able to access both of those here.
    enos_provider = {
      amzn2  = provider.enos.ec2_user
      leap   = provider.enos.ec2_user
      rhel   = provider.enos.ec2_user
      sles   = provider.enos.ec2_user
      ubuntu = provider.enos.ubuntu
    }
    // We install vault packages from artifactory. If you wish to use one of these variants you'll
    // need to configure your artifactory credentials.
    use_artifactory = matrix.artifact == "deb" || matrix.artifact == "rpm"
    // Zip bundles and local builds don't come with systemd units or any associated configuration.
    // When this is true we'll let enos handle this for us.
    manage_service = matrix.artifact == "zip" || matrix.artifact == "local"
    // If you are using an ent edition, you will need a Vault license. Common convention
    // is to store it at ./support/vault.hclic, but you may change this path according
    // to your own preference.
    vault_install_dir = matrix.artifact == "zip" || matrix.artifact == "local" ? global.vault_install_dir["bundle"] : global.vault_install_dir["package"]
  }

  // Begin scenario steps. These are the steps we'll perform to get your cluster up and running.
  step "build_or_find_vault_artifact" {
    description = <<-EOF
      Depending on how we intend to get our Vault artifact, this step either builds vault from our
      current branch or finds debian or redhat packages in Artifactory. If we're using a zip bundle
      we'll get it from releases.hashicorp.com and skip this step entirely. Please note that if you
      wish to use a deb or rpm artifact you'll have to configure your artifactory credentials!

      Variables that are used in this step:

        artifactory_host:
          The artifactory host to search. It's very unlikely that you'll want to change this. The
          default value is the HashiCorp Artifactory instance.
        artifactory_repo
          The artifactory host to search. It's very unlikely that you'll want to change this. The
          default value is where CRT will publish packages.
        artifactory_username
          The artifactory username associated with your token. You'll need this if you wish to use
          deb or rpm artifacts! You can request access via Okta.
        artifactory_token
          The artifactory token associated with your username. You'll need this if you wish to use
          deb or rpm artifacts! You can create a token by logging into Artifactory via Okta.
        vault_product_version:
          When using the artifact:rpm or artifact:deb variants we'll use this variable to determine
          which version of the Vault pacakge we should fetch from Artifactory.
        vault_artifact_path:
          When using the artifact:local variant we'll utilize this variable to determine where
          to create the vault.zip archive from the local branch. Default: to /tmp/vault.zip.
        vault_local_build_tags:
          When using the artifact:local variant we'll use this variable to inject custom build
          tags. If left unset we'll automatically use the build tags that correspond to the edition
          variant.
    EOF
    module      = matrix.artifact == "local" ? "build_local" : local.use_artifactory ? "build_artifactory_package" : "build_crt"

    variables {
      // Used for all modules
      arch            = matrix.arch
      edition         = matrix.edition
      product_version = var.vault_product_version
      // Required for the local build which will always result in using a local zip bundle
      artifact_path = matrix.artifact == "local" ? abspath(var.vault_artifact_path) : null
      build_tags    = var.vault_local_build_tags != null ? var.vault_local_build_tags : global.build_tags[matrix.edition]
      build_ui      = var.dev_build_local_ui
      goarch        = matrix.arch
      goos          = "linux"
      // Required when using a RPM or Deb package
      // Some of these variables don't have default values so we'll only set them if they are
      // required.
      artifactory_host     = local.use_artifactory ? var.artifactory_host : null
      artifactory_repo     = local.use_artifactory ? var.artifactory_repo : null
      artifactory_username = local.use_artifactory ? var.artifactory_username : null
      artifactory_token    = local.use_artifactory ? var.artifactory_token : null
      distro               = matrix.distro
    }
  }

  step "ec2_info" {
    description = "This discovers usefull metadata in Ec2 like AWS AMI ID's that we use in later modules."
    module      = module.ec2_info
  }

  step "create_vpc" {
    description = <<-EOF
      Create the VPC resources required for our scenario.

        Variables that are used in this step:
          tags:
            If you wish to add custom tags to taggable resources in AWS you can set the 'tags' variable
            and they'll be added to resources when possible.
    EOF
    module      = module.create_vpc
    depends_on  = [step.ec2_info]

    variables {
      common_tags = global.tags
    }
  }

  step "read_backend_license" {
    description = <<-EOF
      Read the contents of the backend license if we're using a Consul backend and the edition is "ent".

      Variables that are used in this step:
        backend_edition:
          The edition of Consul to use. If left unset it will default to CE.
         backend_license_path:
          If this variable is set we'll use it to determine the local path on disk that contains a
          Consul Enterprise license. If it is not set we'll attempt to load it from
          ./support/consul.hclic.
    EOF
    skip_step   = matrix.backend == "raft" || var.backend_edition == "oss" || var.backend_edition == "ce"
    module      = module.read_license

    variables {
      file_name = global.backend_license_path
    }
  }

  step "read_vault_license" {
    description = <<-EOF
      Validates and reads into memory the contents of a local Vault Enterprise license if we're
      using an Enterprise edition. This step does not run when using a community edition of Vault.

      Variables that are used in this step:
        vault_license_path:
          If this variable is set we'll use it to determine the local path on disk that contains a
          Vault Enterprise license. If it is not set we'll attempt to load it from
          ./support/vault.hclic.
    EOF
    skip_step   = matrix.edition == "ce"
    module      = module.read_license

    variables {
      file_name = global.vault_license_path
    }
  }

  step "create_seal_key" {
    description = <<-EOF
      Create the necessary seal keys depending on our configured seal.

      Variables that are used in this step:
        tags:
          If you wish to add custom tags to taggable resources in AWS you can set the 'tags' variable
          and they'll be added to resources when possible.
    EOF
    module      = "seal_${matrix.seal}"
    depends_on  = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_id  = step.create_vpc.id
      common_tags = global.tags
    }
  }

  step "create_vault_cluster_targets" {
    description = <<-EOF
      Creates the necessary machine infrastructure targets for the Vault cluster. We also ensure
      that the firewall is configured to allow the necessary Vault and Consul traffic and SSH
      from the machine executing the Enos scenario.

      Variables that are used in this step:
        aws_ssh_keypair_name:
          The AWS SSH Keypair name to use for target machines.
        project_name:
          The project name is used for additional tag metadata on resources.
        tags:
          If you wish to add custom tags to taggable resources in AWS you can set the 'tags' variable
          and they'll be added to resources when possible.
        vault_instance_count:
          How many instances to provision for the Vault cluster. If left unset it will use a default
          of three.
    EOF
    module      = module.target_ec2_instances
    depends_on  = [step.create_vpc]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      ami_id          = step.ec2_info.ami_ids[matrix.arch][matrix.distro][global.distro_version[matrix.distro]]
      instance_count  = try(var.vault_instance_count, 3)
      cluster_tag_key = global.vault_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_vault_cluster_backend_targets" {
    description = <<-EOF
      Creates the necessary machine infrastructure targets for the backend Consul storage cluster.
      We also ensure that the firewall is configured to allow the necessary Consul traffic and SSH
      from the machine executing the Enos scenario. When using integrated storage this step is a
      no-op that does nothing.

      Variables that are used in this step:
        tags:
          If you wish to add custom tags to taggable resources in AWS you can set the 'tags' variable
          and they'll be added to resources when possible.
        project_name:
          The project name is used for additional tag metadata on resources.
        aws_ssh_keypair_name:
          The AWS SSH Keypair name to use for target machines.
    EOF

    module     = matrix.backend == "consul" ? module.target_ec2_instances : module.target_ec2_shim
    depends_on = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id          = step.ec2_info.ami_ids["arm64"]["ubuntu"]["22.04"]
      cluster_tag_key = global.backend_tag_key
      common_tags     = global.tags
      seal_key_names  = step.create_seal_key.resource_names
      vpc_id          = step.create_vpc.id
    }
  }

  step "create_backend_cluster" {
    description = <<-EOF
      Install, configure, and start the backend Consul storage cluster. When we are using the raft
      storage variant this step is a no-op.

      Variables that are used in this step:
        backend_edition:
          When configured with the backend:consul variant we'll utilize this variable to determine
          the edition of Consul to use for the cluster. Note that if you set it to 'ent' you will
          also need a valid license configured for the read_backend_license step. Default: ce.
        dev_consul_version:
          When configured with the backend:consul variant we'll utilize this variable to determine
          the version of Consul to use for the cluster.
    EOF
    module      = "backend_${matrix.backend}"
    depends_on = [
      step.create_vault_cluster_backend_targets
    ]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      cluster_name    = step.create_vault_cluster_backend_targets.cluster_name
      cluster_tag_key = global.backend_tag_key
      license         = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      release = {
        edition = var.backend_edition
        version = var.dev_consul_version
      }
      target_hosts = step.create_vault_cluster_backend_targets.hosts
    }
  }

  step "create_vault_cluster" {
    description = <<-EOF
      Install, configure, start, initialize and unseal the Vault cluster on the specified target
      instances.

      Variables that are used in this step:
      backend_edition:
        When configured with the backend:consul variant we'll utilize this variable to determine
        which version of the consul client to install on each node for Consul storage. Note that
        if you set it to 'ent' you will also need a valid license configured for the
        read_backend_license step. If left unset we'll use an unlicensed CE version.
      dev_config_mode:
        You can set this variable to instruct enos on how to primarily configure Vault when starting
        the service. Options are 'file' and 'env' for configuration file or environment variables.
        If left unset we'll use the default value.
      dev_consul_version:
        When configured with the backend:consul variant we'll utilize this variable to determine
        which version of Consul to install. If left unset we'll utilize the default value.
      vault_artifact_path:
        When using the artifact:local variant this variable is utilized to specify where on
        the local disk the vault.zip file we've built is located. It can be left unset to use
        the default value.
      vault_enable_audit_devices:
        Whether or not to enable various audit devices after unsealing the Vault cluster. By default
        we'll configure syslog, socket, and file auditing.
      vault_product_version:
        When using the artifact:zip variant this variable is utilized to specify the version of
        Vault to download from releases.hashicorp.com.
    EOF
    module      = module.vault_cluster
    depends_on = [
      step.create_backend_cluster,
      step.create_vault_cluster_targets,
      step.build_or_find_vault_artifact,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      // We set vault_artifactory_release when we want to get a .deb or .rpm package from Artifactory.
      // We set vault_release when we want to get a .zip bundle from releases.hashicorp.com
      // We only set one or the other, never both.
      artifactory_release     = local.use_artifactory ? step.build_or_find_vault_artifact.release : null
      backend_cluster_name    = step.create_vault_cluster_backend_targets.cluster_name
      backend_cluster_tag_key = global.backend_tag_key
      cluster_name            = step.create_vault_cluster_targets.cluster_name
      config_mode             = var.dev_config_mode
      consul_license          = (matrix.backend == "consul" && var.backend_edition == "ent") ? step.read_backend_license.license : null
      consul_release = matrix.backend == "consul" ? {
        edition = var.backend_edition
        version = var.dev_consul_version
      } : null
      enable_audit_devices = var.vault_enable_audit_devices
      install_dir          = local.vault_install_dir
      license              = matrix.edition != "ce" ? step.read_vault_license.license : null
      local_artifact_path  = matrix.artifact == "local" ? abspath(var.vault_artifact_path) : null
      manage_service       = local.manage_service
      packages             = concat(global.packages, global.distro_packages[matrix.distro])
      release              = matrix.artifact == "zip" ? { version = var.vault_product_version, edition = matrix.edition } : null
      seal_attributes      = step.create_seal_key.attributes
      seal_type            = matrix.seal
      storage_backend      = matrix.backend
      target_hosts         = step.create_vault_cluster_targets.hosts
    }
  }

  // When using a Consul backend, these output values will be for the Consul backend.
  // When using a Raft backend, these output values will be null.
  output "audit_device_file_path" {
    description = "The file path for the file audit device, if enabled"
    value       = step.create_vault_cluster.audit_device_file_path
  }

  output "cluster_name" {
    description = "The Vault cluster name"
    value       = step.create_vault_cluster.cluster_name
  }

  output "hosts" {
    description = "The Vault cluster target hosts"
    value       = step.create_vault_cluster.target_hosts
  }

  output "private_ips" {
    description = "The Vault cluster private IPs"
    value       = step.create_vault_cluster.private_ips
  }

  output "public_ips" {
    description = "The Vault cluster public IPs"
    value       = step.create_vault_cluster.public_ips
  }

  output "root_token" {
    description = "The Vault cluster root token"
    value       = step.create_vault_cluster.root_token
  }

  output "recovery_key_shares" {
    description = "The Vault cluster recovery key shares"
    value       = step.create_vault_cluster.recovery_key_shares
  }

  output "recovery_keys_b64" {
    description = "The Vault cluster recovery keys b64"
    value       = step.create_vault_cluster.recovery_keys_b64
  }

  output "recovery_keys_hex" {
    description = "The Vault cluster recovery keys hex"
    value       = step.create_vault_cluster.recovery_keys_hex
  }

  output "seal_key_attributes" {
    description = "The Vault cluster seal attributes"
    value       = step.create_seal_key.attributes
  }

  output "unseal_keys_b64" {
    description = "The Vault cluster unseal keys"
    value       = step.create_vault_cluster.unseal_keys_b64
  }

  output "unseal_keys_hex" {
    description = "The Vault cluster unseal keys hex"
    value       = step.create_vault_cluster.unseal_keys_hex
  }
}
