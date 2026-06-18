# aws-cli-v2 — Déploiement d'un site web sur AWS (IPSSI)

Provisioning d'une instance **EC2 (Ubuntu)** qui héberge un site web statique
(template *Barista* de Tooplate) servi par **Nginx**.

Le déploiement est piloté de bout en bout par un **`Makefile`** (à la racine) qui
orchestre **Terraform** (infrastructure) puis **Ansible** (configuration du
serveur). Un script **AWS CLI** complémentaire illustre l'approche impérative.

Région par défaut : **`eu-west-3`** (Paris).

---

## Architecture provisionnée

Terraform crée, dans un VPC existant :

- un **subnet** dédié (CIDR configurable) ;
- un **security group** ouvrant `22` (SSH), `80` (HTTP) et un port applicatif
  configurable, sortie ouverte ;
- une **key pair** : clé RSA 4096 générée localement (`tls_private_key`),
  enregistrée en `.pem` (permissions `0400`) et poussée sur AWS ;
- une **instance EC2** (`t2.micro` par défaut) avec IP publique, rattachée au
  subnet et au security group.

Ansible installe ensuite Nginx et déploie le site sur cette instance.

---

## Structure du dépôt

```
.
├── Makefile                      # ★ Pilote du déploiement (Terraform + inventaire Ansible)
├── README.md
└── infra/
    ├── terraform/
    │   ├── terraform.tf          # Providers (aws ~>5, tls ~>4, local ~>2)
    │   ├── variables.tf          # Entrées : project_name, region, vpc_id, ami, port…
    │   ├── locals.tf             # Noms dérivés ("<project>-subnet", "-sg", "-key", "-instance")
    │   ├── main.tf               # Subnet, SG, key pair, clé .pem, instance EC2
    │   ├── outputs.tf            # IDs, IP publique, chemin de la clé, commande SSH
    │   ├── terraform.tfvars      # Valeurs locales (NON versionné)
    │   └── *.pem / *.tfstate*    # Clé privée et state (NON versionnés)
    ├── ansible/
    │   ├── inventory.ini         # Généré par `make tr_o` (IP + chemin de la clé)
    │   ├── nginx.yml             # Playbook : installe Nginx + déploie site/
    │   └── site/                 # Template statique "Barista" (HTML/CSS/JS)
    └── cli/
        ├── constants/vppc.sh     # Constantes partagées
        └── services/ec2.sh       # Script AWS CLI autonome : crée une NACL + règle d'entrée
```

>  Fichiers sensibles (`*.pem`, `*.tfstate*`, `*.tfvars`) exclus du
> versionnement via `infra/terraform/.gitignore`. Ne les committez jamais.

---

## Prérequis

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configuré (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- `make` et `jq`
- Un compte AWS avec droits EC2/VPC et un **VPC existant**
- **Windows** : le `Makefile` exécute ses recettes via **Git Bash** (il utilise
  `grep`, `awk`, `realpath`…). Lancez `make` depuis un terminal Git Bash.

Vérifier l'accès AWS :

```bash
aws sts get-caller-identity
```

---

## Configuration

Avant tout déploiement, renseigner `infra/terraform/terraform.tfvars`. La
variable **`ami` est obligatoire** (aucun défaut) et doit pointer vers une **AMI
Ubuntu** (le playbook utilise `apt`, et l'inventaire se connecte en `ubuntu`).

```hcl
# infra/terraform/terraform.tfvars
ami    = "ami-xxxxxxxxxxxxxxxxx"   # AMI Ubuntu dans eu-west-3
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
# project_name, region, subnet_cidr, port, instance_type ont des défauts (voir variables.tf)
```

---

## Déploiement (via le `Makefile`)

`make` seul (ou `make help`) liste les cibles disponibles :

| Cible | Action |
|-------|--------|
| `make help` | Affiche l'aide (cibles documentées) |
| `make tr_l` | **Lint** : `terraform fmt -check -recursive` + `terraform validate` |
| `make tr_p` | **Plan** : prévisualise les changements (dépend de `tr_l`) |
| `make tr_a` | **Apply** : crée l'infra (`-auto-approve`, dépend de `tr_p`) |
| `make tr_o` | Génère `infra/ansible/inventory.ini` depuis les outputs Terraform |
| `make tr_d` | **Destroy** : supprime toute l'infra (`-auto-approve`) |

Les cibles s'enchaînent par dépendances : `tr_a` → `tr_p` → `tr_l`. Lancer
`make tr_a` exécute donc lint → plan → apply dans l'ordre.

### Workflow complet

```bash
# 0. Initialisation Terraform (une seule fois — pas de cible make pour ça)
cd infra/terraform && terraform init && cd ../..

# 1. Provisionner l'infrastructure (lint → plan → apply)
make tr_a

# 2. Générer l'inventaire Ansible à partir des outputs (IP + clé .pem)
make tr_o

# 3. Configurer le serveur : installer Nginx + déployer le site
cd infra/ansible
ansible all -m ping -i inventory.ini          # vérifie la connectivité SSH
ansible-playbook -i inventory.ini nginx.yml

# 4. Le site est accessible sur http://<IP_PUBLIQUE>

# 5. Tout détruire après usage
make tr_d
```

> `make tr_o` n'affiche rien dans le terminal : c'est normal, il écrit
> directement dans `infra/ansible/inventory.ini`. Vérifiez avec
> `cat infra/ansible/inventory.ini`.

---

## Le playbook Ansible

`nginx.yml` cible le groupe `web_servers` (en `become`) et :

1. installe **Nginx** (`apt`) ;
2. démarre et active le service ;
3. copie `site/` vers `/var/www/html/`.

L'inventaire (`inventory.ini`) est généré automatiquement par `make tr_o` à
partir de `terraform output` : IP publique de l'instance et chemin absolu de la
clé privée.

---

## Approche AWS CLI (impérative, optionnelle)

`infra/cli/services/ec2.sh` est un script Bash **autonome** (non piloté par le
Makefile) qui illustre la création manuelle d'une **Network ACL** et d'une règle
d'entrée via l'AWS CLI. Exécution directe :

```bash
bash infra/cli/services/ec2.sh <nom-de-la-nacl>
```

Il stocke la réponse dans `nacl.json` et en extrait le `NetworkAclId` avec `jq`.

---

## Sécurité

- Clés privées (`.pem`), `terraform.tfstate` (secrets en clair) et `.tfvars`
  **ne sont pas versionnés** — voir `.gitignore`.
- Le security group ouvre `22`, `80` et le port applicatif à `0.0.0.0/0` :
  à restreindre pour un usage réel.
- Pensez à `make tr_d` après usage pour éviter les coûts AWS.

---

## Crédits

- Template web : *Barista* par [Tooplate](https://www.tooplate.com/) (usage libre).
- Projet réalisé dans le cadre de la formation **IPSSI**.
