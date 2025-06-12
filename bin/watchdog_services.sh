#!/bin/bash
# ===========================================
# Watchdog Services - Surveillance des services
# Projet ENSET - Équipe Team-B-05
# ===========================================

# Constantes
VERSION="1.0.0"
AUTEUR="Team-B-05"
DATE_CREATION="11/05/2025"

# Chemins par défaut
REPERTOIRE_COURANT=$(dirname "$(readlink -f "$0")")
REPERTOIRE_RACINE="${REPERTOIRE_COURANT}/.."
FICHIER_CONFIG="${REPERTOIRE_RACINE}/config/default.conf"

# Définition du répertoire de logs par défaut (sera éventuellement modifié par l'option -l)
REPERTOIRE_LOGS="/var/log/watchdog_services"

# Variables globales
MODE_EXECUTION="normal"  # Valeurs possibles: normal, fork, thread, subshell
SERVICES_A_SURVEILLER=()
EMAIL_ADMIN="charlyzoungrana2004@gmail.com"

# Codes d'erreur
declare -A ERROR_CODES=(
    [UNKNOWN_OPTION]=100
    [MISSING_ARG]=101 
    [PERMISSION_DENIED]=102
    [SERVICE_NOT_FOUND]=103
    [SERVICE_DOWN]=104
    [RESTART_FAILED]=105
    [CONFIG_ERROR]=106
    [LOG_ERROR]=107
    [INVALID_PATH]=108
    [INVALID_EMAIL]=109
    [INVALID_MODE]=110
)

# Fonction de gestion des erreurs
gerer_erreur() {
    local code=$1
    local message="$2"
    local solution="$3"
    
    echo "[ERREUR] Code $code: $message"
    echo "Solution: $solution"
    echo ""
    afficher_aide
    exit $code
}

# Charger la configuration
effectuer_chargement_configuration() {
    if [ -f "$FICHIER_CONFIG" ]; then
        source "$FICHIER_CONFIG"
        # Convertir la liste des services en tableau
        IFS=' ' read -r -a SERVICES_A_SURVEILLER <<< "$SERVICES"
        EMAIL_ADMIN="$ADMIN_EMAIL"
    fi
}

# Fonction pour convertir un chemin relatif en absolu
convertir_chemin_absolu() {
    local chemin="$1"
    if [[ "$chemin" != /* ]]; then
        # Si c'est un chemin relatif, on le convertit en absolu par rapport au répertoire courant
        echo "$(pwd)/$chemin"
    else
        echo "$chemin"
    fi
}

# Fonction d'aide
afficher_aide() {
    echo "Utilisation: $0 [options]"
    echo "Options:"
    echo "  -h                Affiche cette aide"
    echo "  -f               Mode fork (exécution en arrière-plan)"
    echo "  -t               Mode thread (exécution concurrente)"
    echo "  -s               Mode subshell"
    echo "  -l <répertoire>  Spécifie le répertoire des logs (chemin relatif ou absolu)"
    echo "  -r               Réinitialise la configuration (nécessite les droits root)"
    echo "  -e <email>       Adresse email pour les notifications"
    echo "  -c <fichier>     Spécifie un fichier de configuration personnalisé"
    echo "  -S <services>    Liste des services à surveiller (séparés par des virgules)"
    echo "  -v               Affiche la version"
}

# Fonction pour rediriger les sorties vers le terminal et le fichier de log
setup_logging() {
    # Si le répertoire de logs n'est pas défini, utiliser la valeur par défaut
    if [ -z "$REPERTOIRE_LOGS" ]; then
        REPERTOIRE_LOGS="/var/log/watchdog_services"
    fi
    
    # Convertir le chemin relatif en absolu si nécessaire
    REPERTOIRE_LOGS=$(convertir_chemin_absolu "$REPERTOIRE_LOGS")
    FICHIER_LOG="${REPERTOIRE_LOGS}/history.log"
    
    # Vérifier et créer le répertoire de logs avec les bonnes permissions
    if [ ! -d "$REPERTOIRE_LOGS" ]; then
        mkdir -p "$REPERTOIRE_LOGS" 2>/dev/null
        if [ $? -ne 0 ]; then
            gerer_erreur ${ERROR_CODES[LOG_ERROR]} "Impossible de créer le répertoire de logs: $REPERTOIRE_LOGS" "Vérifiez les permissions du répertoire parent ou spécifiez un autre répertoire avec l'option -l"
        fi
        chmod 755 "$REPERTOIRE_LOGS" 2>/dev/null
    fi
    
    # Vérifier les permissions d'écriture
    if [ ! -w "$REPERTOIRE_LOGS" ]; then
        gerer_erreur ${ERROR_CODES[PERMISSION_DENIED]} "Pas d'accès en écriture sur le répertoire: $REPERTOIRE_LOGS" "Assurez-vous d'avoir les permissions nécessaires sur ce répertoire ou spécifiez un autre répertoire avec l'option -l"
    fi
    
    # Créer le fichier de log s'il n'existe pas
    touch "$FICHIER_LOG" 2>/dev/null
    if [ $? -ne 0 ]; then
        gerer_erreur ${ERROR_CODES[LOG_ERROR]} "Impossible de créer/écrire dans le fichier de log: $FICHIER_LOG" "Vérifiez les permissions du répertoire ou spécifiez un autre répertoire avec l'option -l"
    fi
    chmod 644 "$FICHIER_LOG" 2>/dev/null
    
    # Rediriger stdout et stderr vers le terminal et le fichier de log
    exec > >(tee -a "$FICHIER_LOG" 2>/dev/null) 2>&1
    
    # Ajouter un séparateur de session dans le log
    echo "=== Nouvelle session démarrée le $(date '+%Y-%m-%d %H:%M:%S') ==="
}

# Fonction de journalisation
journaliser() {
    local niveau=$1
    local message=$2
    local horodatage=$(date +"%Y-%m-%d-%H-%M-%S")
    local utilisateur=$(whoami)
    
    # Formater la ligne de log selon le niveau
    local ligne_log=""
    if [ "$niveau" = "INFO" ]; then
        ligne_log="${horodatage} : ${utilisateur} : INFOS : ${message}"
    else
        ligne_log="${horodatage} : ${utilisateur} : ERROR : ${message}"
    fi
    
    # Écrire dans le fichier de log
    echo "$ligne_log"
}

# Vérifier si un service est en cours d'exécution
verifier_service() {
    local service=$1
    local status_output
    
    # Vérifier si le service existe
    if ! systemctl list-unit-files "$service.service" &>/dev/null; then
        local message="Le service $service n'existe pas sur ce système."
        journaliser "ERREUR" "$message"
        gerer_erreur ${ERROR_CODES[SERVICE_NOT_FOUND]} "$message" "Vérifiez le nom du service ou utilisez la commande 'systemctl list-units --type=service' pour voir les services disponibles"
    fi
    # Vérification existence service (modifié)
    if ! systemctl list-unit-files --full --type=service "$service.service" | grep -q "^$service.service"; then
        local message="Service $service introuvable dans la liste des services système."
        journaliser "ERREUR" "$message"
        gerer_erreur ${ERROR_CODES[SERVICE_NOT_FOUND]} "Service $service introuvable" "Vérifiez le nom exact du service dans la liste des services système"
    fi
    # Vérification état service
    status_output=$(systemctl is-active "$service" 2>&1)
    if [ "$status_output" != "active" ]; then
        local message="Service $service arrêté. Tentative de redémarrage automatique..."
        journaliser "ERREUR" "$message"
        envoyer_notification "$service" "arrêt"
        
        if ! sudo systemctl start "$service"; then
            local message="Échec du redémarrage du service $service"
            journaliser "ERREUR" "$message"
            envoyer_notification "$service" "échec_redémarrage"
            gerer_erreur ${ERROR_CODES[RESTART_FAILED]} "$message" "Vérifiez les logs système pour plus de détails sur l'échec du redémarrage"
        else
            envoyer_notification "$service" "redémarré"
        fi
    fi
    
    # Vérifier l'état final du service
    status_output=$(systemctl is-active "$service" 2>&1)
    
    if [ "$status_output" = "active" ] || [ "$status_output" = "running" ]; then
        journaliser "INFO" "Le service $service fonctionne correctement."
        return 0
    else
        local message="Le service $service est arrêté. Détails: $status_output"
        journaliser "ERREUR" "$message"
        return 1
    fi
}

# Envoyer une notification par email
envoyer_notification() {
    local service=$1
    local type_notification=${2:-"arrêt"}
    local sujet message
    
    case $type_notification in
        "arrêt")
            sujet="[Watchdog] Service $service est arrêté"
            message="Le service $service est arrêté sur $(hostname) à $(date)"
            ;;
        "redémarré")
            sujet="[Watchdog] Service $service a été redémarré"
            message="Le service $service a été redémarré avec succès sur $(hostname) à $(date)"
            ;;
        "échec_redémarrage")
            sujet="[Watchdog] Échec du redémarrage de $service"
            message="Échec de la tentative de redémarrage du service $service sur $(hostname) à $(date)"
            ;;
        *)
            sujet="[Watchdog] Notification pour le service $service"
            message="Événement inconnu pour le service $service sur $(hostname) à $(date)"
            ;;
    esac
    
    if [ -z "$EMAIL_ADMIN" ] || [ "$EMAIL_ADMIN" = "admin@example.com" ]; then
        journaliser "AVERTISSEMENT" "Email non configuré. Veuillez définir une adresse email valide dans la configuration pour recevoir les notifications."
        return 1
    fi
    
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$sujet" "$EMAIL_ADMIN"
        journaliser "INFO" "Notification envoyée à $EMAIL_ADMIN pour le service $service"
    else
        journaliser "ERREUR" "Impossible d'envoyer l'email: la commande 'mail' n'est pas disponible"
        return 1
    fi
}

# Fonction de réinitialisation du système
effectuer_reinitialisation() {
    journaliser "INFO" "Début de la réinitialisation du système de surveillance"
    
    # Vérifier les privilèges root
    if [ "$(id -u)" -ne 0 ]; then
        echo "Erreur : La réinitialisation nécessite les privilèges root." >&2
        echo "Veuillez exécuter cette commande avec sudo." >&2
        exit ${ERROR_CODES[PERMISSION_DENIED]}
    fi
    
    # Arrêter tous les processus watchdog en cours d'exécution
    echo "Arrêt des processus de surveillance en cours..."
    pkill -f "watchdog_services.sh" 2>/dev/null
    
    # Supprimer les fichiers de configuration et de logs
    echo "Nettoyage des fichiers de configuration et de logs..."
    rm -f "$FICHIER_CONFIG" 2>/dev/null
    
    if [ -d "$REPERTOIRE_LOGS" ]; then
        rm -f "${REPERTOIRE_LOGS}/"*.log 2>/dev/null
    fi
    
    echo "Réinitialisation terminée avec succès."
    journaliser "INFO" "Réinitialisation du système effectuée"
    exit 0
}

# Fonction principale de surveillance
surveiller_services() {
    # Ajouter une variable pour contrôler la surveillance continue
    if [ "${SURVEILLANCE_CONTINUE:-true}" = "false" ]; then
        # Mode test: une seule vérification
        for service in "${SERVICES_A_SURVEILLER[@]}"; do
            verifier_service "$service"
        done
        return 0
    fi
    while true; do
        for service in "${SERVICES_A_SURVEILLER[@]}"; do
            verifier_service "$service"
        done        
        sleep "${CHECK_INTERVAL:-60}"
    done
}

# Point d'entrée principal
main() {
    # Charger la configuration par défaut
    effectuer_chargement_configuration
    
    # Traiter les options de ligne de commande
    while getopts ":hftsl:re:c:S:v" option; do
        case $option in
            h) afficher_aide; exit 0 ;;
            f) MODE_EXECUTION="fork" ;;
            t) MODE_EXECUTION="thread" ;;
            s) MODE_EXECUTION="subshell" ;;
            l)
            # On ne modifie que le répertoire, le nom du fichier restera history.log
            REPERTOIRE_LOGS="$OPTARG"
            ;;
            r) effectuer_reinitialisation ;;
            e) EMAIL_ADMIN="$OPTARG" ;;
            c) FICHIER_CONFIG="$OPTARG" ;;
            S) 
                # Remplacer les virgules par des espaces pour la compatibilité
                SERVICES_A_SURVEILLER=(${OPTARG//,/ })
                # Journaliser le changement
                journaliser "INFO" "Services spécifiés en ligne de commande: ${SERVICES_A_SURVEILLER[*]}"
                ;;
            v) echo "Watchdog Services v$VERSION"; exit 0 ;; 
            #Gérer les arguments manquants
            :)
                gerer_erreur ${ERROR_CODES[MISSING_ARG]} "L'option -$OPTARG nécessite un argument" "Spécifiez l'argument requis"
                ;;
            #Gérer correctement les options invalides            
            \?) 
                gerer_erreur ${ERROR_CODES[UNKNOWN_OPTION]} "Option inconnue: -$OPTARG" "Consultez l'aide avec -h"
                ;;
            
                
        esac       
    done
    # Configurer la journalisation (après avoir traité les options de ligne de commande)
    setup_logging
    for service in "${SERVICES_A_SURVEILLER[@]}"; do
        verifier_service "$service" || {
            local exit_code=$?
            [ $exit_code -eq ${ERROR_CODES[SERVICE_NOT_FOUND]} ] && exit $exit_code
        }
    done
    # Vérifier les dépendances
    if ! command -v systemctl &> /dev/null; then
        journaliser "ERREUR" "systemctl n'est pas disponible. Ce script nécessite systemd."
        exit 1
    fi
    #Vérifier les services AVANT de démarrer la surveillance
    for service in "${SERVICES_A_SURVEILLER[@]}"; do
        verifier_service "$service" || {
            local exit_code=$?
            [ $exit_code -eq $ERREUR_SERVICE_INCONNU ] && exit $exit_code
            # Continue pour les autres erreurs (comme les services arrêtés)
        }
    done 
    # Démarrer la surveillance selon le mode sélectionné
    # À la place de la section "Démarrer la surveillance selon le mode sélectionné"

    # Vérifier si c'est un test ou surveillance continue
    if [ "${TEST_MODE:-false}" = "true" ]; then
        # Mode test: vérification unique
        journaliser "INFO" "Mode test - vérification unique"
        for service in "${SERVICES_A_SURVEILLER[@]}"; do
            verifier_service "$service" || exit $?
        done
        journaliser "INFO" "Vérification terminée avec succès"
        exit 0
    else
        # Mode surveillance continue (code existant)
        case $MODE_EXECUTION in
            "fork") surveiller_services & ;;
            "thread")
                for service in "${SERVICES_A_SURVEILLER[@]}"; do
                    verifier_service "$service" &
                done
                wait
                ;;
            "subshell") ( surveiller_services ) ;;
            *) surveiller_services ;;
        esac
    fi
}

# Démarrer le script
main "$@"
