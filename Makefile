# Sur Windows, make lance ses recettes dans cmd.exe (qui n'a pas grep/awk).
# On lui dit d'utiliser Git Bash. Chemin court 8.3 pour eviter l'espace de "Program Files".
ifeq ($(OS),Windows_NT)
SHELL := C:/PROGRA~1/Git/bin/bash.exe
.SHELLFLAGS := -c
endif

ANSIBLE_DIR := infra/ansible
TERRAFORM_DIR := infra/terraform

.DEFAULT_GOAL := help
.PHONY: help tr_l tr_p tr_a tr_o

help: ## Show help message
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

tr_l: ## Format and validate Terraform config
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive
	@cd $(TERRAFORM_DIR) && terraform validate

tr_p: tr_l ## Generate and show an execution plan
	@cd $(TERRAFORM_DIR) && terraform plan

tr_a: tr_p ## Apply Terraform changes
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve

tr_d: ## Destroy Terraform-managed infrastructure
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

tr_o: ## Generate Ansible inventory from Terraform outputs
	@echo "[web_servers]" > $(ANSIBLE_DIR)/inventory.ini
	@echo "$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip) ansible_user=ubuntu ansible_ssh_private_key_file=$$(cd $(TERRAFORM_DIR) && realpath $$(terraform output -raw private_key_path))" >> $(ANSIBLE_DIR)/inventory.ini
	@echo "" >> $(ANSIBLE_DIR)/inventory.ini
	@echo "[web_servers:vars]" >> $(ANSIBLE_DIR)/inventory.ini
	@echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> $(ANSIBLE_DIR)/inventory.ini