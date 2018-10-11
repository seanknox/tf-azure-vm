# tf-azure-vm

Quickly spin up a (semi-)hardened Linux VM with [Docker CE][dockerce], [azure-cli][azurecli], and other tools preinstalled using [Terraform][terraform] on your laptop.

## What you get
- Single Standard_B2ms Linux VM running Ubuntu 18.04 Bionic
- VM reachable at public IP/FQDN based on your Azure alias
- Installed packages: Docker CE, azure-cli, fail2ban, automake, git, vim, tmux, and a handful of other tools.
- Network Security Group configured to allow only SSH incoming (protected by [fail2ban][fail2ban])

[dockerce]: https://docs.docker.com/install/linux/docker-ce/ubuntu/
[azurecli]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest
[terraform]: http://terraform.io
[fail2ban]: https://www.fail2ban.org/wiki/index.php/Main_Page

## Running
1. Install Terraform: https://www.terraform.io/downloads.html
1. Clone the repo to your machine and `cd tf-azure-vm`
1. Run:
```
make build
```

## Want to tear everything down?
`make destroy` will remove all infrastructure created.
