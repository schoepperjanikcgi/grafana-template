terraform {  
    required_providers {
        coder = {
            source  = "coder/coder"    
        }
        docker = {
        source = "kreuzwerker/docker"
        }
    }
}

provider "docker" {
  # Defaulting to null if the variable is an empty string lets us have an optional variable without having to set our own default
  host = var.docker_socket != "" ? var.docker_socket : null
}

locals {
  username = data.coder_workspace_owner.me.name
}

variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI"
  type        = string
}


data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# See https://registry.coder.com/modules/coder/code-server
module "code-server" {
  count  = data.coder_workspace.me.start_count
  source = "registry.coder.com/coder/code-server/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  agent_id = coder_agent.main.id
  order    = 1
  extensions = [
    "dracula-theme.theme-dracula",
    "ms-azuretools.vscode-docker",
    "mechatroner.rainbow-csv"
  ]
  
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    #set -e
    set -ex
    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
    # Declare dependency on git-clone
    echo "Hello world from a git managed template!"

  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"

    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
    CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt"
    NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt"
  }


  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

}


resource "docker_container" "python" {
  count = data.coder_workspace.me.start_count
  name  = "foo"
  image = "codercom/ubuntu-dev-python3.7"

  entrypoint = ["sh", "-c", "sudo update-ca-certificates && ${replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}"]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
/*   host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  } */

  volumes {
    container_path = "/usr/local/share/ca-certificates/Zscaler-Root-CA.crt"
    host_path      = "/usr/local/share/ca-certificates/corporate/ZScalerRootCA.crt"
    read_only      = true
  }
  volumes {
    container_path = "/usr/local/share/ca-certificates/CGI-Web-Gateway2.crt"
    host_path      = "/usr/local/share/ca-certificates/corporate/CGIWebGateway2.crt"
    read_only      = true
  }
  volumes {
    container_path = "/usr/local/share/ca-certificates/Groupinfra-Root-CA.crt"
    host_path      = "/usr/local/share/ca-certificates/corporate/GroupinfraRootCA.crt"
    read_only      = true
  }
}  