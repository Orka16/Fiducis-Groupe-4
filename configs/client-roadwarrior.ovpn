# Configurations OpenVPN

Les **certificats et clés ne sont pas versionnés** (cf. `.gitignore`). Ils se génèrent
avec `scripts/init-pki.sh` (PKI site-à-site) et `scripts/make-ovpn.sh` (profils nomades).

## Fichiers de ce dossier
| Fichier | Rôle | Déployé sur |
|---|---|---|
| `server-site2site.conf` | Serveur VPN inter-sites (étoile) | GW-BDX (hub) |
| `ccd/larochelle`, `ccd/bayonne` | IP de tunnel + iroute par spoke | GW-BDX |
| `client-larochelle.conf` | Client site-à-site | GW-LR |
| `client-bayonne.conf` | Client site-à-site | GW-BAY |
| `server-roadwarrior.conf` | Serveur VPN télétravail | GW-BDX (hub) |
| `client-roadwarrior.ovpn` | Modèle de profil nomade | postes télétravail |
| `nftables-gw-bdx.conf` | Pare-feu/NAT du hub | GW-BDX |

## Fichiers à distribuer (générés, non versionnés)
- `ca.crt`, `ta.key` → toutes les passerelles
- `bordeaux.crt` / `bordeaux.key` → hub uniquement
- `larochelle.crt` / `larochelle.key` → GW-LR
- `bayonne.crt` / `bayonne.key` → GW-BAY
- `dh.pem` → hub
