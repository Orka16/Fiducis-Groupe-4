# MSPR FIDUCIS — dossier technique

Cabinet d'expertise comptable, juridique et conseil RH, 35 collaborateurs, répartis sur Bordeaux (siège), La Rochelle, Bayonne (nouvelle antenne) et du télétravail régulier. Aujourd'hui les fichiers sont sur OneDrive, le site vitrine et l'espace client chez un prestataire coûteux, il n'y a ni VPN, ni sauvegarde, ni plan de reprise, et un contrôle CNIL impose de tracer les accès aux données clients. Une coupure Internet d'une journée à La Rochelle a déjà bloqué le travail.

Objectif : relier les sites en permanence, rapatrier les fichiers et le web en interne, mettre en place une sauvegarde fiable et la traçabilité des accès.

Virtualisation : VirtualBox. Passerelles sous Ubuntu 24.04, serveurs sous Windows Server 2022.

## Besoins et solutions

| Besoin (entretiens) | Solution |
|---|---|
| Relier Bordeaux / La Rochelle / Bayonne en permanence | VPN site-à-site OpenVPN en étoile (hub = Bordeaux) |
| Télétravailleurs sans OneDrive | VPN client OpenVPN sur la passerelle de Bordeaux |
| Sortir de OneDrive et de l'hébergement web externe | Serveur de fichiers SMB interne + serveur web en DMZ |
| Aucune sauvegarde | Sauvegarde 3-2-1 avec Veeam, copie hors-site sur Azure |
| Aucun plan de reprise | PRA / PCA documentés et testés |
| Traçabilité CNIL des accès clients | Audit NTFS des accès fichiers + journaux centralisés + VPN nominatif |

## Architecture

Topologie en étoile : Bordeaux concentre les services, La Rochelle et Bayonne sont des branches reliées par des tunnels chiffrés. Ce choix permet d'ajouter un site (Bayonne) en ajoutant simplement une branche, sans retoucher les autres, et de centraliser le filtrage. Contrepartie (panne du hub) traitée par un DC secondaire à La Rochelle dans le PRA.

```mermaid
flowchart TB
    INET(("Internet simulé<br/>203.0.113.0/24"))
    subgraph BDX["Bordeaux - siège - LAN 10.10.0.0/24"]
        GW["GW-BDX<br/>OpenVPN site-à-site + nomades"]
        AD["SRV-AD - AD/DNS 10.10.0.10"]
        FILES["SRV-FILES - SMB 10.10.0.20"]
        VEEAM["SRV-VEEAM 10.10.0.30"]
        SAGE["SRV-SAGE 10.10.0.40"]
        WEB["SRV-WEB (DMZ) 172.16.10.10"]
    end
    subgraph LR["La Rochelle - 10.20.0.0/24"]
        GWL["GW-LR"]
        DC2["SRV-DC2 - DC secondaire 10.20.0.10"]
    end
    subgraph BAY["Bayonne - 10.30.0.0/24"]
        GWY["GW-BAY"]
    end
    AZ(("Azure - sauvegarde hors-site"))
    INET --- GW & GWL & GWY
    GW --- AD & FILES & VEEAM & SAGE & WEB
    GWL --- DC2
    GW <-->|tunnel site-à-site| GWL
    GW <-->|tunnel site-à-site| GWY
    NOM["Télétravailleurs (VPN)"] -.-> GW
    VEEAM -->|copie hors-site| AZ
```

### Plan d'adressage

| Rôle | Réseau | Type VirtualBox |
|---|---|---|
| Internet simulé | `203.0.113.0/24` | NAT Network `inet-sim` |
| LAN Bordeaux | `10.10.0.0/24` | Internal `lan-bdx` |
| DMZ Bordeaux | `172.16.10.0/24` | Internal `dmz-bdx` |
| LAN La Rochelle | `10.20.0.0/24` | Internal `lan-lr` |
| LAN Bayonne | `10.30.0.0/24` | Internal `lan-bay` |
| Tunnel site-à-site | `10.99.0.0/24` | OpenVPN |
| Pool télétravail | `10.8.0.0/24` | OpenVPN |

Passerelles : GW-BDX 203.0.113.11 / 10.10.0.254 (+ DMZ 172.16.10.254), GW-LR 203.0.113.12 / 10.20.0.254, GW-BAY 203.0.113.13 / 10.30.0.254. Serveurs Bordeaux : SRV-AD 10.10.0.10, SRV-FILES 10.10.0.20, SRV-VEEAM 10.10.0.30, SRV-SAGE 10.10.0.40, SRV-WEB 172.16.10.10 (DMZ). La Rochelle : SRV-DC2 10.20.0.10.

## Maquette VirtualBox

| VM | OS | RAM | Réseaux |
|---|---|---|---|
| GW-BDX | Ubuntu 24.04 | 512 Mo | WAN + LAN + DMZ |
| GW-LR / GW-BAY | Ubuntu 24.04 | 512 Mo | WAN + LAN |
| SRV-AD | Windows Server 2022 | 2 Go | LAN Bordeaux |
| SRV-FILES | Windows Server 2022 | 2 Go | LAN Bordeaux |
| SRV-VEEAM | Windows Server 2022 | 4 Go | LAN Bordeaux |
| SRV-SAGE | Windows Server 2022 | 2 Go | LAN Bordeaux |
| SRV-WEB | Ubuntu 24.04 | 512 Mo | DMZ |
| SRV-DC2 | Windows Server 2022 (Core) | 2 Go | LAN La Rochelle |

Le NAT Network `inet-sim` simule Internet : les passerelles s'y voient entre elles et atteignent le vrai Internet pour les mises à jour. Les LAN et la DMZ sont des Internal Networks. La création est scriptée (`scripts/provision-virtualbox.sh`). On démarre les VM par groupe selon la démo plutôt que toutes ensemble.

Le réseau sous Ubuntu 24.04 se configure avec Netplan. Exemple pour la passerelle de Bordeaux (`/etc/netplan/01-fiducis.yaml`, à mettre en chmod 600 puis `sudo netplan apply`) :

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:                 # WAN
      addresses: [203.0.113.11/24]
      routes: [{to: default, via: 203.0.113.1}]
    enp0s8:                 # LAN
      addresses: [10.10.0.254/24]
    enp0s9:                 # DMZ
      addresses: [172.16.10.254/24]
```

Le routage est activé sur les passerelles (`net.ipv4.ip_forward=1`).

## VPN site-à-site

Bordeaux est serveur OpenVPN, La Rochelle et Bayonne sont clients. `client-to-client` permet aux deux agences de communiquer en passant par le hub. La PKI (Easy-RSA) génère une autorité de certification et un certificat par passerelle (`scripts/init-pki.sh`). Chaque agence est déclarée dans un fichier CCD avec son IP de tunnel et la route vers son LAN.

Extrait du serveur (`configs/openvpn/server-site2site.conf`) :

```ini
topology subnet
server 10.99.0.0 255.255.255.0
client-config-dir /etc/openvpn/ccd
client-to-client
route 10.20.0.0 255.255.255.0
route 10.30.0.0 255.255.255.0
push "route 10.10.0.0 255.255.255.0"
push "route 10.20.0.0 255.255.255.0"
push "route 10.30.0.0 255.255.255.0"
```

Le fichier CCD de chaque agence (ex. `ccd/larochelle`) fixe son IP de tunnel et déclare son réseau avec `iroute`, sans quoi le serveur ne sait pas router le retour. Le pare-feu et le NAT des passerelles sont dans `configs/openvpn/nftables-gw-bdx.conf` : le trafic inter-sites n'est pas NATé (seul l'accès Internet l'est), et la DMZ ne peut pas initier de connexion vers le LAN.

## VPN télétravail

Une seconde instance OpenVPN tourne sur Bordeaux (port et sous-réseau distincts du site-à-site), avec un certificat par collaborateur, révocable individuellement — c'est aussi ce qui permet d'identifier nominativement qui se connecte. Le profil `.ovpn` est assemblé par `scripts/make-ovpn.sh`. On reste en split-tunnel : seul le trafic vers les ressources internes passe par le VPN, le reste sort directement. Une fois connecté, le télétravailleur accède au partage SMB et à Sage selon ses droits AD.

Pour révoquer un accès (départ, perte de portable) : `easyrsa revoke`, régénération de la CRL, activation de `crl-verify` dans la conf serveur.

## Internalisation des fichiers et du web

Les fichiers quittent OneDrive pour un serveur de fichiers Windows (SRV-FILES), avec des partages SMB intégrés à l'AD. Les permissions suivent des groupes AD par métier (comptables, juristes, RH, direction) en moindre privilège, et l'énumération basée sur l'accès masque ce que l'utilisateur n'a pas le droit de voir. La migration depuis OneDrive se fait par export puis copie sur les partages, avec déploiement des lecteurs réseau par GPO.

Le site vitrine, l'espace client et la prise de rendez-vous sont rapatriés sur SRV-WEB, placé en DMZ (`configs/web/fiducis-vitrine.conf` : HTTPS forcé, en-têtes de sécurité, reverse proxy pour le module de rendez-vous). La DMZ est isolée du LAN : un serveur web compromis ne peut pas atteindre les données clients. Sage reste sur son serveur dédié, désormais joignable depuis toutes les agences via le tunnel et inclus dans les sauvegardes.

## Sauvegarde 3-2-1 (Veeam, hors-site Azure)

Trois copies, deux supports différents, une hors-site :

```mermaid
flowchart LR
    PROD["1 - Production<br/>AD, fichiers, Sage"]
    LOCAL["2 - Veeam local<br/>repository Bordeaux"]
    AZ["3 - Azure Blob<br/>immuable, hors-site"]
    PROD -->|Backup Job incrémental| LOCAL
    LOCAL -->|Backup Copy Job| AZ
```

La copie hors-site est externalisée sur **Azure** : un Backup Copy Job Veeam envoie les sauvegardes vers un conteneur Azure Blob, avec immuabilité activée (protection contre la suppression et le ransomware) et chiffrement. Par rapport à une copie sur un autre site, on évite le matériel à maintenir et on bénéficie d'un stockage hors-site élastique.

| Données | Fréquence | Rétention locale | Hors-site (Azure) |
|---|---|---|---|
| Sage (compta/paie) | Quotidienne (incrémental) | 30 jours | 90 jours |
| Fichiers / pièces clients | Quotidienne (incrémental) | 30 jours | 90 jours |
| AD (system state) | Quotidienne | 15 jours | 30 jours |
| Archive mensuelle | Mensuelle (complet) | 12 mois | 12 mois |

Point important : on teste réellement les restaurations (un fichier mensuellement, une base Sage et l'AD par trimestre). Une sauvegarde non testée ne compte pas — c'était précisément le maillon manquant. Chaque test fait l'objet d'un PV daté.

## PRA / PCA

| Service | RPO | RTO |
|---|---|---|
| Sage / fichiers clients | 24 h | 4 h |
| Active Directory / DNS | réplication (~0) | < 1 h |
| Site web / espace client | 24 h | 8 h |

Continuité : le DC secondaire de La Rochelle maintient l'authentification en cas de panne du siège ; les services internalisés restent disponibles localement. Reprise : restauration depuis le repository Veeam local pour un incident isolé, ou depuis Azure en cas de sinistre Bordeaux. Les runbooks (restauration d'un fichier, sinistre du siège, ransomware) sont écrits pour pouvoir être suivis sans expertise pointue.

À noter pour la coupure Internet vécue à La Rochelle : un VPN seul ne la règle pas, puisque le tunnel a besoin du lien pour monter. La vraie continuité repose sur un lien de secours par site (4G/5G ou second FAI), conçu et documenté dans le PRA mais simulé dans la maquette faute de matériel.

## Traçabilité CNIL

La traçabilité des accès aux fichiers clients s'appuie sur l'audit d'accès aux objets NTFS du serveur de fichiers : une GPO active l'audit du système de fichiers, et des SACL sont posées sur les dossiers sensibles, ce qui journalise qui accède à quel dossier et quand (`configs/ad/audit-fichiers.gpo.md`, évènements 4663/4670 dans le journal de sécurité). Les journaux sont centralisés vers un collecteur (pour qu'un attaquant ne puisse pas effacer ses traces localement) et conservés de façon proportionnée : environ 6 mois pour les accès, 12 mois pour les évènements de sécurité.

S'ajoutent les certificats VPN nominatifs (qui s'est connecté, quand, depuis quelle IP), le chiffrement des données en transit (VPN, HTTPS) et au repos (BitLocker, sauvegardes chiffrées), et une matrice d'habilitation par groupe AD. On peut ainsi produire, pour un dossier client donné, la liste horodatée des accès que demande la CNIL.

## Tests principaux

| Test | Résultat attendu |
|---|---|
| Tunnels site-à-site | La Rochelle et Bayonne connectés au hub |
| Communication inter-agences | La Rochelle joint Bayonne via le hub |
| Accès aux ressources | Sage et partage SMB accessibles depuis une agence distante |
| VPN télétravail | Connexion, accès interne, révocation d'un certificat refusée |
| Sauvegarde / restauration | Backup Veeam, copie présente sur Azure, fichier restauré intègre |
| Cloisonnement DMZ | Depuis SRV-WEB, un accès vers le LAN échoue |
| Audit NTFS | Un accès à un dossier sensible génère un évènement horodaté |

## Contenu du dépôt

- `configs/openvpn/` : serveurs et clients (site-à-site + télétravail), CCD, pare-feu nftables
- `configs/web/` : configuration du site vitrine en DMZ
- `configs/ad/` : GPO d'audit des accès fichiers (CNIL)
- `scripts/` : provisioning VirtualBox, génération de la PKI, profils .ovpn

Les certificats et clés ne sont pas versionnés (voir `.gitignore`) ; ils se génèrent avec `scripts/init-pki.sh` et `scripts/make-ovpn.sh`.
