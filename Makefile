TERRAFORM_BIN ?= /usr/local/bin/terraform
SSH_KEY := $(HOME)/.ssh/id_rsa.pub
FQDN := $(shell terraform output fqdn)
ifneq (,$(wildcard $(SSH_KEY)))
	export TF_VAR_admin_username := $(USER)
	export TF_VAR_ssh_key := $(shell cat $(SSH_KEY))
endif

export TF_VAR_standard_vm_size := "Standard_B2ms"

ssh:
	ssh $(USER)@$(FQDN)

build: .terraform/terraform.tfstate terraform.tfvars
	./scripts/helpers/ensure_user_auth
	terraform apply

destroy: .terraform/terraform.tfstate terraform.tfvars
	./scripts/helpers/ensure_user_auth
	terraform destroy

terraform.tfvars:
	./scripts/make-dev-tfvars $@

backend-config.tfvars: terraform.tfvars
	./scripts/backend-config-from-tfvars $^ $@

.terraform/terraform.tfstate: backend-config.tfvars
	./scripts/install-terraform $(shell dirname $(TERRAFORM_BIN))
	./scripts/helpers/ensure_user_auth
	terraform init -backend-config backend-config.tfvars

.PHONY: plan apply destroy validate
