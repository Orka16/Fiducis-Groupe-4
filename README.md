# MSPR — Infrastructure FIDUCIS

> Cabinet d'expertise comptable, juridique et conseil RH — refonte de l'infrastructure réseau, sécurisation et internalisation des services.

Ce dépôt contient l'intégralité du dossier technique de la mise en situation : analyse du besoin, architecture cible, maquette VirtualBox reproductible, configurations, plan de sauvegarde, PRA/PCA et conformité RGPD/CNIL.

---

## Contexte en une phrase

FIDUCIS (35 collaborateurs) répartis sur **Bordeaux (siège)**, **La Rochelle**, **Bayonne (nouvelle antenne)** et du **télétravail**, dépend aujourd'hui de services externes (OneDrive, hébergement web) sans VPN, sans sauvegarde, sans plan de reprise — et fait face à un **contrôle CNIL** exigeant la traçabilité des accès aux données clients. L'objectif est de **tout rapatrier en interne**, de **relier les sites en permanence** et de **sécuriser la continuité d'activité**.

## Réponse apportée

| Besoin exprimé | Solution retenue |
|---|---|
| Relier Bordeaux / La Rochelle / Bayonne en permanence | **VPN site-à-site OpenVPN** en étoile (hub = Bordeaux) |
| Faire travailler les télétravailleurs sans OneDrive | **VPN client (road-warrior) OpenVPN** terminé sur la passerelle de Bordeaux |
| Sortir de OneDrive, espace client et site web hébergés à l'extérieur | **Internalisation** : Nextcloud (fichiers), serveur web en DMZ (vitrine + espace client + prise de RDV) |
| Aucune sauvegarde | **Sauvegarde 3-2-1 avec Veeam** (incrémental + copie hors-site) |
| Aucun plan de reprise | **PRA + PCA** documentés, avec procédures de test |
| Traçabilité CNIL des accès clients | Journalisation Nextcloud (`admin_audit`), audit des accès NTFS sur l'AD, centralisation des logs |

## Comment lire ce dépôt

Les chapitres se lisent dans l'ordre. Chaque document est autonome.

```
fiducis-mspr/
├── README.md                      ← vous êtes ici
├── docs/
│   ├── 01-contexte-besoins.md     Analyse du sujet + synthèse des 2 entretiens
│   ├── 02-architecture-cible.md   Topologie, plan d'adressage, choix techniques
│   ├── 03-maquette-virtualbox.md  VMs, réseaux VirtualBox, commandes de provisioning
│   ├── 04-vpn-site-a-site.md      PKI + OpenVPN en étoile (Bordeaux ↔ LR ↔ Bayonne)
│   ├── 05-vpn-teletravail.md      OpenVPN road-warrior pour les télétravailleurs
│   ├── 06-internalisation.md      Nextcloud, serveur web DMZ, migration OneDrive
│   ├── 07-sauvegarde-3-2-1.md     Stratégie Veeam, rétention, hors-site
│   ├── 08-pra-pca.md              Continuité et reprise, RTO/RPO, runbooks
│   ├── 09-rgpd-tracabilite.md     Conformité CNIL, journalisation, registre
│   └── 10-tests-recette.md        Plan de tests et procès-verbal de recette
├── configs/                       Fichiers de configuration réellement utilisés
│   ├── openvpn/                    Serveurs, clients, CCD, durcissement TLS
│   ├── nextcloud/                  Audit / journalisation
│   ├── web/                        Nginx vitrine + espace client
│   └── ad/                         GPO d'audit des accès fichiers
└── scripts/                       Scripts d'automatisation (PKI, provisioning VBox)
```

## Démarrage rapide

```bash
# 1. Créer les réseaux et VMs VirtualBox (voir docs/03)
./scripts/provision-virtualbox.sh

# 2. Générer la PKI OpenVPN (voir docs/04)
./scripts/init-pki.sh

# 3. Suivre les chapitres docs/04 à docs/07 pour déployer les services
```

## Pile technique

- **Virtualisation** : Oracle VirtualBox 7.x
- **Passerelles / pare-feu** : Debian 12 (Bookworm) + OpenVPN + nftables
- **Annuaire** : Windows Server 2022 (AD DS, DNS)
- **Fichiers / espace client** : Nextcloud (Debian 12)
- **Web** : Nginx (Debian 12) en DMZ
- **Sauvegarde** : Veeam Backup & Replication + Veeam Agent for Linux
- **Métier** : Sage (poste serveur dédié, inchangé fonctionnellement)

## Conventions

Les adresses « publiques » utilisent les plages de documentation `203.0.113.0/24` (RFC 5737) pour simuler Internet sans collision avec un vrai réseau. Les LAN utilisent du RFC 1918.

---

*Dossier réalisé dans le cadre d'une MSPR. Toutes les manipulations sont reproductibles sur un poste disposant de VirtualBox.*
