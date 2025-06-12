# Watchdog Services

Un script de surveillance et de maintenance automatique des services système, développé par l'équipe Team-B-05 pour le projet SE à l'ENSET.

## Description

Watchdog Services est un outil de surveillance robuste qui permet de :
- Surveiller l'état des services système en temps réel
- Redémarrer automatiquement les services défaillants
- Envoyer des notifications par email en cas de problème
- Journaliser toutes les actions et événements
- S'exécuter dans différents modes (normal, fork, thread, subshell)

## Fonctionnalités

- 🔍 Surveillance continue des services
- 🔄 Redémarrage automatique des services défaillants
- 📧 Notifications par email
- 📝 Journalisation détaillée
- ⚙️ Configuration flexible
- 🔒 Gestion des erreurs robuste

## Prérequis

- Système d'exploitation Linux
- Bash shell
- Accès root ou sudo pour la gestion des services
- Services système à surveiller (SSH, MySQL, Nginx, etc.)

## Installation

1. Clonez le dépôt :
```bash
git clone https://github.com/votre-username/watchdog_services.git
```

2. Rendez le script exécutable :
```bash
chmod +x bin/watchdog_services.sh
```

3. Configurez les services à surveiller dans `config/default.conf`

## Utilisation

### Options disponibles

```bash
./bin/watchdog_services.sh [options]

Options:
  -h                Affiche l'aide
  -f               Mode fork (exécution en arrière-plan)
  -t               Mode thread (exécution concurrente)
  -s               Mode subshell
  -l <répertoire>  Spécifie le répertoire des logs
  -r               Réinitialise la configuration
  -e <email>       Adresse email pour les notifications
  -c <fichier>     Fichier de configuration personnalisé
  -S <services>    Liste des services à surveiller
  -v               Affiche la version
```

### Exemple d'utilisation

```bash
# Surveillance basique
./bin/watchdog_services.sh

# Surveillance avec configuration personnalisée
./bin/watchdog_services.sh -c /chemin/vers/config.conf

# Surveillance en mode fork avec répertoire de logs personnalisé
./bin/watchdog_services.sh -f -l /var/log/mes_logs
```

## Structure du projet

```
watchdog_services/
├── bin/
│   └── watchdog_services.sh
├── config/
│   └── default.conf
├── logs/
├── tests/
└── doc/
```

## Configuration

Le fichier de configuration par défaut (`config/default.conf`) permet de définir :
- L'adresse email de l'administrateur
- Les services à surveiller
- L'intervalle de vérification
- Le niveau de détail des logs
- Le répertoire des logs

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
1. Fork le projet
2. Créer une branche pour votre fonctionnalité
3. Commiter vos changements
4. Pousser vers la branche
5. Ouvrir une Pull Request

## Licence

Ce projet est sous licence MIT.

## Auteurs

- Team-B-05
- Contact : charlyzoungrana2004@gmail.com

## Version

Version actuelle : 1.0.0 
