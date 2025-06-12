# Watchdog Services

## Description

Outil de surveillance de services système pour Linux permettant de surveiller l'état des services critiques et d'alerter l'administrateur en cas de problème.

## Fonctionnalités

* Surveillance des services système
* Notifications par email
* Plusieurs modes d'exécution (normal, fork, thread, subshell)
* Journalisation des événements
* Configuration personnalisable

## Prérequis

* Système d'exploitation Linux avec systemd
* Bash 4.0 ou supérieur
* Outils système systemctl
* Droits root pour certaines fonctionnalités

## Installation

## Configuration des notifications email

### 1. Installation des dépendances requises

Pour Ubuntu/Debian, installez les paquets nécessaires :

```bash
sudo apt-get update
sudo apt-get install -y mailutils ssmtp
```

### 2. Configuration de SSMTP pour Gmail

1. Éditez le fichier de configuration SSMTP :

   ```bash
   sudo nano /etc/ssmtp/ssmtp.conf
   ```

2. Remplacez tout le contenu par cette configuration (remplissez avec vos informations) :

   ```ini
   # Adresse email qui envoie les notifications
   root=votre_email@gmail.com
   
   # Configuration du serveur SMTP de Gmail
   mailhub=smtp.gmail.com:587
   
   # Nom d'hôte de votre serveur (utilisez la commande 'hostname' pour le connaître)
   hostname=$(hostname)
   
   # Paramètres de sécurité
   UseSTARTTLS=YES
   UseTLS=YES
   
   # Authentification
   AuthUser=votre_email@gmail.com
   
   # Mot de passe d'application (pas votre mot de passe Gmail !)
   # Voir la section suivante pour générer ce mot de passe
   AuthPass=votre_mot_de_passe_application
   
   # Permet de personnaliser l'expéditeur
   FromLineOverride=YES
   
   # Délai d'attente augmenté pour éviter les erreurs
   Timeout=60
   
   # Active la journalisation détaillée (utile pour le débogage)
   Debug=YES
   ```

### 3. Configuration des permissions

Assurez-vous que le fichier de configuration a les bonnes permissions :

```bash
sudo chmod 600 /etc/ssmtp/ssmtp.conf
sudo chown root:mail /etc/ssmtp/ssmtp.conf
```

### 4. Création d'un mot de passe d'application (Gmail)

1. Allez sur [votre compte Google](https://myaccount.google.com/)
2. Activez la validation en 2 étapes si ce n'est pas déjà fait
3. Allez dans "Sécurité" > "Connexion à Google"
4. Sélectionnez "Mots de passe d'application"
5. Créez un nouveau mot de passe pour l'application "Autre (Nom personnalisé)"
6. Utilisez ce mot de passe comme `AuthPass` dans la configuration SSMTP

### 5. Configuration du fichier revaliases (optionnel mais recommandé)

```bash
sudo nano /etc/ssmtp/revaliases
```

Ajoutez cette ligne (remplacez `utilisateur` par votre nom d'utilisateur Linux) :

```ini
utilisateur:votre_email@gmail.com:smtp.gmail.com:587
```

### 6. Test de l'envoi d'email

Pour vérifier que tout fonctionne :

```bash
echo "Ceci est un test d'envoi depuis Watchdog Services" | mail -s "Test de configuration" votre@email.com
```

### 7. Vérification des logs

Si l'email n'arrive pas, consultez les logs :

```bash
sudo tail -f /var/log/mail.log
```

### 8. Dépannage courant

* **Erreur d'authentification** : Vérifiez que vous utilisez bien un mot de passe d'application et non votre mot de passe Gmail
* **Connexion refusée** : Vérifiez que votre pare-feu autorise les connexions sortantes sur le port 587
* **Délai dépassé** : Vérifiez votre connexion Internet ou augmentez la valeur de `Timeout` dans la configuration

## Utilisation

### Options de ligne de commande

```text
-h      Affiche ce message d'aide
-f      Exécution en arrière-plan (fork)
-t      Mode thread (exécution concurrente)
-s      Mode subshell
-l DIR  Spécifie le répertoire des logs
-r      Réinitialise la configuration (root requis)
-e EMAIL Adresse email pour les notifications
-c FILE Fichier de configuration personnalisé
-S SRV  Liste des services à surveiller (séparés par des virgules)
-v      Affiche la version
```

### Exemples

```bash
# Afficher l'aide
./watchdog_services.sh -h

# Mode normal
./watchdog_services.sh

# Mode arrière-plan avec notification email
./watchdog_services.sh -f -e admin@example.com

# Surveiller des services spécifiques
./watchdog_services.sh -S "sshd,nginx,mysql"

# Spécifier un répertoire de logs personnalisé
./watchdog_services.sh -l /var/log/watchdog
```

## Configuration

Le fichier de configuration par défaut se trouve dans `config/default.conf`

```ini
# Adresse email de l'administrateur
ADMIN_EMAIL="admin@example.com"

# Services à surveiller
SERVICES="sshd mysql nginx"

# Intervalle de vérification (secondes)
CHECK_INTERVAL=60

# Niveau de détail des logs
LOG_LEVEL="INFO"
```

## Fichiers de logs

Les journaux sont enregistrés dans `/var/log/watchdog_services/history.log` avec le format suivant :

```log
YYYY-MM-DD-HH-MM-SS : username : NIVEAU : message
```

## Codes de sortie

* 0 - Succès
* 100 - Option inconnue
* 101 - Argument manquant
* 102 - Droits insuffisants
