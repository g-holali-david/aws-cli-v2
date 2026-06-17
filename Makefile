# Sur Windows, make lance ses recettes dans cmd.exe (qui n'a pas grep/awk).
# On lui dit d'utiliser Git Bash. Chemin court 8.3 pour eviter l'espace de "Program Files".
ifeq ($(OS),Windows_NT)
SHELL := C:/PROGRA~1/Git/bin/bash.exe
.SHELLFLAGS := -c
endif

-include .env      # charger .env (le "-" = ignore si absent)
export             # exporter toutes les variables make vers les sous-process

ANSIBLE_DIR := infra/ansible
TERRAFORM_DIR := infra/terraform

.DEFAULT_GOAL := help
.PHONY: help build clean tr_l tr_p tr_a tr_d tr_o ans_l ans_p test

help: ## Show help message
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

## Terraform commands
tr_l: ## Format and validate Terraform config
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive
	@cd $(TERRAFORM_DIR) && terraform validate

tr_p: tr_l ## Generate and show an execution plan
	@cd $(TERRAFORM_DIR) && terraform plan

tr_a: tr_p ## Apply Terraform changes
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve

tr_d: ## Destroy Terraform-managed infrastructure
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

tr_o: ## Generate Ansible inventory + copy SSH key into WSL
	@ip=$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip); \
	keypath=$$(cd $(TERRAFORM_DIR) && realpath $$(terraform output -raw private_key_path)); \
	keyname=$$(basename "$$keypath"); \
	keypath_wsl=$$(echo "$$keypath" | sed 's|^/\([a-zA-Z]\)/|/mnt/\1/|'); \
	MSYS_NO_PATHCONV=1 wsl bash -c "mkdir -p ~/.ssh && cp $$keypath_wsl ~/.ssh/$$keyname && chmod 400 ~/.ssh/$$keyname"; \
	{ \
		echo "[web_servers]"; \
		echo "$$ip ansible_user=$(TF_VAR_ssh_user) ansible_ssh_private_key_file=~/.ssh/$$keyname"; \
		echo ""; \
		echo "[web_servers:vars]"; \
		echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"; \
	} > $(ANSIBLE_DIR)/inventory.ini
	@echo "-> inventory.ini genere + cle copiee dans WSL ~/.ssh/"


## Ansible commands
ans_l: ## Lint Ansible playbooks
	@cd $(ANSIBLE_DIR) && wsl ansible-lint

ans_p: tr_o ans_l ## Run Ansible playbooks
	@cd $(ANSIBLE_DIR) && wsl ansible-playbook -i inventory.ini nginx.yml


build: tr_a ans_p ## Build infrastructure and deploy application

clean: tr_d ## Destroy infrastructure and clean up


test: ## Smoke test : verifie que le site repond (HTTP 200)
	@ip=$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip); \
	echo "-> Test de http://$$ip"; \
	code=$$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$$ip"); \
	if [ "$$code" = "200" ]; then \
		echo "OK - le site repond (HTTP $$code)"; \
	else \
		echo "ECHEC - HTTP $$code"; exit 1; \
	fi
