# Terraform AWS Swarm Cluster Setup

Ce dépôt contient une configuration Terraform pour configurer un cluster Docker Swarm sur AWS.

## Prérequis

- Terraform v0.12+
- AWS CLI configuré avec les droits d'accès appropriés

## Résumé

La configuration Terraform dans `main.tf` effectue les opérations suivantes :

1. **Provider AWS** : Spécifie l'utilisation de AWS comme fournisseur de cloud avec la région définie sur `eu-central-1`.

2. **VPC** : Crée un VPC avec un bloc CIDR de `10.0.0.0/16`.

3. **Sous-réseaux** :
   - Crée un sous-réseau pour les instances avec un bloc CIDR de `10.0.1.0/24`.
   - Crée un sous-réseau pour le NAT Gateway avec un bloc CIDR de `10.0.2.0/24`.

4. **Groupe de Sécurité** : Définit un groupe de sécurité pour permettre le trafic SSH, Docker Swarm et le trafic de sortie.

5. **Paire de Clés SSH** : Génère une clé privée TLS et une paire de clés AWS pour l'accès SSH.

6. **Instances EC2** :
   - **Cluster Master** : Déploie une instance EC2 pour le maître du cluster Docker Swarm et initialise le cluster Swarm.
   - **Managers** : Déploie des instances EC2 supplémentaires pour les gestionnaires du cluster et les joint au cluster Swarm en tant que managers.
   - **Workers** : Déploie des instances EC2 supplémentaires pour les travailleurs du cluster et les joint au cluster Swarm en tant que workers.
   - **Ansible** : Déploie une instance EC2 avec Ansible installé pour la gestion du cluster.
   - **Jump Host** : Déploie une instance EC2 pour accéder au cluster à travers un NAT Gateway.

7. **NAT Gateway** :
   - Crée une passerelle Internet et un NAT Gateway pour permettre aux instances privées d'accéder à Internet.
   - Associe des tables de routage pour diriger le trafic Internet via le NAT Gateway.

## Outputs

Le fichier `main.tf` génère également plusieurs outputs :

- **ssh_private_key_pem** : La clé privée SSH pour accéder aux instances.
- **ssh_public_key_pem** : La clé publique SSH.
- **Cluster_master_ips** : Les adresses IP privées des maîtres du cluster.
- **master_ips** : Les adresses IP privées des gestionnaires du cluster.
- **worker_ips** : Les adresses IP privées des travailleurs du cluster.
- **ansible_ips** : Les adresses IP privées des instances Ansible.
- **nat_gateway_ip** : L'adresse IP publique du NAT Gateway.
- **jumphost_ip** : L'adresse IP publique du jump host.

## Documentation de référence

https://dev.betterdoc.org/infrastructure/2020/02/04/setting-up-a-nat-gateway-on-aws-using-terraform.html

![terraform_swam_schema](https://github.com/user-attachments/assets/af33a7c3-1f97-475b-adbc-26facbd522df)

## Todo list

```[tasklist]
### My tasks
- [ ] Ajouter user_data a jumphost pour éditer le header ssh
- [&#9745] Séparer master 1 et master 2
- [x] Ajouter user_data a master 1 pour (copier la clé privée), installer docker et initialiser le cluster swarm
- [x] Ajouter user_data a master 2 pour (copier la clé privée), installer docker et join le cluster comme manager (depends_on)
- [x] Ajouter user_data aux worker pour (copier la clé privée), installer docker et join le cluster (depends_on)
- [ ] Ajouter user_data a ansible pour copier la clé privée,installer ansible, initialiser l'inventaire, copier les playbooks et les executer
- [x] Playbook pour éditer le fichier /ect/hosts avec les alias des instances de l'infrastructure et leurs ips
- [x] Playbook pour éditer le fichier le header ssh avec les alias des instances de l'infrastructure et leurs ips
```
