# aws-cli-v1 — Déploiement d'un site web sur AWS (IPSSI)

Projet d'infrastructure AWS provisionnant une instance **EC2** qui héberge un
site web statique (template *Barista*) servi par **Nginx**.

Le projet illustre **trois approches complémentaires** du provisioning :

| Approche | Outil | Rôle |
|----------|-------|------|
| Impérative | **AWS CLI** + `make` | Création du réseau (NACL) et des instances EC2 via scripts Bash |
| Déclarative | **Terraform** | Provisioning complet : subnet, security group, key pair, EC2 |
| Configuration | **Ansible** | Installation de Nginx et déploiement du site sur l'instance |

Région par défaut : **`eu-west-3`** (Paris).

---

## Structure du dépôt

```
infra/
├── Makefile                 # Cibles make pour piloter l'AWS CLI (NACL + EC2)
├── cli/
│   ├── constants/vppc.sh     # Variables/constantes partagées
│   └── services/ec2.sh       # Création d'une NACL + règle d'entrée (AWS CLI)
├── terraform/
│   ├── terraform.tf          # Providers (aws, tls, local) + backend
│   ├── variables.tf          # Variables d'entrée (region, vpc_id, ami…)
│   ├── main.tf               # Subnet, SG, key pair, instance EC2
│   ├── outputs.tf            # IDs, IP publique, commande SSH
│   ├── terraform.tfvars      # Valeurs (NON versionné)
│   └── *.pem / *.tfstate     # Clé privée et state (NON versionnés)
└── ansible/
    ├── inventory.ini         # Hôtes cibles (IP publique de l'EC2)
    ├── nginx.yml             # Playbook : install Nginx + déploie le site
    └── site/                 # Template statique "Barista" (HTML/CSS/JS)
```

> ⚠️ Les fichiers sensibles (`*.pem`, `*.tfstate*`, `*.tfvars`) sont exclus du
> versionnement via `infra/terraform/.gitignore`. Ne les committez jamais.

---

## Prérequis

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configuré (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- `make` et `jq` (utilisés par les scripts Bash)
- Un compte AWS avec les droits EC2/VPC et un VPC existant

Vérifier l'accès AWS :

```bash
aws sts get-caller-identity
```

---

## 1. Approche AWS CLI (`make`)

Pilotée depuis `infra/Makefile`.

```bash
cd infra

make help            # Liste les cibles disponibles
make check           # Vérifie l'identité AWS (credentials)
make vpcs            # Liste les VPC de la région

# Provisionner réseau + instance
make up VPC_ID=vpc-xxxxxxxx

# Détruire (IDs récupérés ci-dessus)
make down INSTANCE_ID=i-xxxx NACL_ID=acl-xxxx
```

Variables surchargeables : `REGION`, `VPC_ID`, `INSTANCE_TYPE`, `AMI_ID`,
`EC2_NAME`, `NACL_NAME`.

---

## 2. Approche Terraform

```bash
cd infra/terraform

terraform init          # Télécharge les providers
terraform plan          # Prévisualise les changements
terraform apply         # Crée subnet + SG + key pair + EC2

terraform output        # IP publique, commande SSH, IDs…
terraform destroy       # Supprime toutes les ressources
```

Terraform génère la clé privée RSA (`claire-davs-key.pem`, permissions `0400`)
et expose une commande `ssh_command` prête à l'emploi dans les outputs.

Configurer les valeurs dans `terraform.tfvars` (région, `vpc_id`, `ami`,
`instance_type`, ports…) avant l'`apply`.

---

## 3. Approche Ansible (configuration du serveur)

Une fois l'instance EC2 disponible, renseignez son IP publique dans
`infra/ansible/inventory.ini`, puis :

```bash
cd infra/ansible

ansible all -m ping                 # Vérifie la connectivité SSH
ansible-playbook -i inventory.ini nginx.yml
```

Le playbook `nginx.yml` :
1. installe et active **Nginx** ;
2. déploie le contenu de `site/` dans `/var/www/html/`.

Le site est ensuite accessible sur `http://<IP_PUBLIQUE>`.

---

## Sécurité

- Les clés privées (`.pem`), le `terraform.tfstate` (contient des secrets en
  clair) et les `.tfvars` **ne sont pas versionnés** — voir `.gitignore`.
- Les security groups ouvrent par défaut les ports `22` (SSH), `80` (HTTP) et le
  port applicatif à `0.0.0.0/0` : à restreindre pour un usage réel.
- Pensez à `terraform destroy` / `make down` après usage pour éviter les coûts.

---

## Crédits

- Template web : *Barista* par [Tooplate](https://www.tooplate.com/) (usage libre).
- Projet réalisé dans le cadre de la formation **IPSSI**.
