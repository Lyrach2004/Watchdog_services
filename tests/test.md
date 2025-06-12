# Suite de tests pour watchdog_services.sh

## Présentation
Ce document décrit les scénarios de test et les comportements attendus pour le script `watchdog_services.sh`.

## Configuration des tests

| Paramètre          | Valeur                              |
|--------------------|------------------------------------|
| Répertoire de tests| `tests/test_logs/`                 |
| Fichier de log     | `logs/history.log`                 |
| Timeout par test   | 15 secondes                       |
| Rapport de synthèse| `tests/test_logs/summary.log`     |

## Cas de test

### 1. Service inexistant
- **Commande** : `sudo watchdog_services.sh -S fake_service_123`
- **Attendu** :
  - Code de sortie : `103` (SERVICE_NOT_FOUND)
  - Message de log : "Le service fake_service_123 n'existe pas"

### 2. Permission refusée
- **Commande** : `watchdog_services.sh -r` (sans sudo)
- **Attendu** :
  - Code de sortie : `102` (PERMISSION_DENIED)
  - Message de log : "Permissions insuffisantes"

### 3. Option invalide
- **Commande** : `sudo watchdog_services.sh -z`
- **Attendu** :
  - Code de sortie : `100` (UNKNOWN_OPTION)
  - Message de log : "Option inconnue : -z"

### 4. Argument manquant
- **Commande** : `sudo watchdog_services.sh -e`
- **Attendu** :
  - Code de sortie : `101` (MISSING_ARG)
  - Message de log : "Argument manquant pour l'option -e"

### 5. Échec de redémarrage
- **Prérequis** : Nginx installé
- **Commande** : `sudo watchdog_services.sh -S nginx`
- **Préparation** :
  ```bash
  sudo systemctl stop nginx
  sudo chmod 000 /usr/sbin/nginx