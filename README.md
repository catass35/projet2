# projet2

https://dev.betterdoc.org/infrastructure/2020/02/04/setting-up-a-nat-gateway-on-aws-using-terraform.html

![terraform_swam_schema](https://github.com/user-attachments/assets/af33a7c3-1f97-475b-adbc-26facbd522df)

```[tasklist]
### My tasks
- [ ] Ajouter user_data a jumphost pour éditer le header ssh
- [ ] Séparer master 1 et master 2
- [ ] Ajouter user_data a master 1 pour (copier la clé privée), installer docker et initialiser le cluster swarm
- [ ] Ajouter user_data a master 2 pour (copier la clé privée), installer docker et join le cluster comme manager (depends_on)
- [ ] Ajouter user_data aux worker pour (copier la clé privée), installer docker et join le cluster (depends_on)
- [ ] Ajouter user_data a ansible pour copier la clé privée, installer ansible, initialiser l'inventaire et copier les playbooks
- [ ] 
- [ ] 
- [ ]
- [ ] 
- [ ] 
```
