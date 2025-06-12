#!/bin/bash
# Teste tous les scénarios d'erreur de watchdog_services.sh

# ================= CONFIGURATION =================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$BASE_DIR/bin/watchdog_services.sh"
LOG_FILE="$BASE_DIR/logs/history.log"
TEST_LOG_DIR="$BASE_DIR/tests/test_logs"
mkdir -p "$TEST_LOG_DIR"

# Codes d'erreur (hardcodés au cas où le source échoue)
declare -A ERROR_CODES=(
    [SUCCESS]=0
    [UNKNOWN_OPTION]=100
    [MISSING_ARG]=101
    [PERMISSION_DENIED]=102 
    [SERVICE_NOT_FOUND]=103
    [SERVICE_DOWN]=104
    [RESTART_FAILED]=105
)

# ================= FONCTIONS =====================
cleanup() {
    # Rétablit l'état original après les tests
    sudo chmod 755 /usr/sbin/nginx 2>/dev/null
    sudo systemctl start nginx 2>/dev/null
}
# Vérifie que le script testé existe
verify_script() {
    if [ ! -f "$SCRIPT" ]; then
        echo -e "\033[1;31mERREUR: Script $SCRIPT introuvable\033[0m"
        exit 103
    fi
    
}

# Journalisation des résultats avec timestamp
log_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${duration}s] $test_name - $result" >> "$TEST_LOG_DIR/summary.log"
}

run_test() {
    local test_name="$1"
    local command="$2"
    local expected_code_name="$3"
    local expected_code=${ERROR_CODES[$expected_code_name]}
    local test_log="$TEST_LOG_DIR/${test_name}.log"
    local start_time=$(date +%s)

    echo -e "\n\033[1;34m=== Test: $test_name (Attendu: $expected_code_name=$expected_code) ===\033[0m"
    echo "Commande: $command"
    
    # Réinitialise les logs
    sudo truncate -s 0 "$LOG_FILE"
    
    # Exécute la commande avec timeout
    timeout 10s bash -c "$command" > "$test_log" 2>&1
    local actual_code=$?
    
    # Gestion spécifique du code 124 (timeout)
    if [ $actual_code -eq 124 ]; then
        echo -e "\033[1;33mTIMEOUT\033[0m: Le test a dépassé le temps limite"
        actual_code=124
    fi
    
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Vérification
    if [ $actual_code -eq $expected_code ]; then
        echo -e "\033[1;32mSUCCÈS\033[0m: Code retourné $actual_code (${duration}s)"
        echo "Détails du log:"
        tail -20 "$test_log"
        log_test_result "$test_name" "SUCCES" "$duration"
    else
        echo -e "\033[1;31mÉCHEC\033[0m: Code $actual_code (attendu $expected_code) (${duration}s)"
        #$********************
        echo "--- Debug Logs ---"
        cat "$test_log"
        echo "-----------------"
        #*************************
        log_test_result "$test_name" "ECHEC" "$duration"
    fi
    
    return $((actual_code == expected_code ? 0 : 1))
}

# ================= TESTS =========================
echo -e "\n\033[1;35m===== LANCEMENT DES TESTS =====\033[0m"

# 1. Service inexistant
run_test "Service inexistant" \
    "sudo $SCRIPT -S fake_service_123" \
    "SERVICE_NOT_FOUND"

# 2. Permission refusée (sans sudo)
run_test "Permission refusée" \
    "$SCRIPT -r" \
    "PERMISSION_DENIED"

# 3. Option invalide
run_test "Option invalide" \
    "sudo $SCRIPT -z" \
    "UNKNOWN_OPTION"

# 4. Argument manquant
run_test "Argument manquant" \
    "sudo $SCRIPT -e" \
    "MISSING_ARG"

# 5. Échec redémarrage (nginx)
if systemctl list-unit-files nginx.service &>/dev/null; then
    sudo systemctl stop nginx
    sudo chmod 000 /usr/sbin/nginx  # Simule l'échec
    run_test "Échec redémarrage" \
        "sudo TEST_MODE=true $SCRIPT -S nginx" \
        "RESTART_FAILED"
    cleanup
else
    echo -e "\n\033[33m[INFO] Test 'Échec redémarrage' ignoré (nginx non installé)\033[0m"
fi
# 6. Test de succès (nécessite un service connu)
if systemctl list-unit-files nginx.service &>/dev/null; then
    sudo systemctl start nginx 2>/dev/null
    test_service_success
else
    echo -e "\n\033[33m[INFO] Test 'Redémarrage réussi' ignoré (nginx non installé)\033[0m"
fi

# ================= RÉSULTATS ====================
echo -e "\n\033[1;36m===== RÉSUMÉ DES LOGS =====\033[0m"
sudo grep -E "ERREUR|Code" "$LOG_FILE" | tail -10

echo -e "\n\033[1;35mTests terminés. Consultez les logs complets:\033[0m"
echo "sudo tail -f $LOG_FILE"
# ================= STATISTIQUES ==================
echo -e "\n\033[1;35m===== STATISTIQUES =====\033[0m"
passed=$(grep -c "SUCCES" "$TEST_LOG_DIR/summary.log" 2>/dev/null || echo 0)
failed=$(grep -c "ECHEC" "$TEST_LOG_DIR/summary.log" 2>/dev/null || echo 0)
timeout=$(grep -c "TIMEOUT" "$TEST_LOG_DIR/summary.log" 2>/dev/null || echo 0)

echo "Tests réussis: $passed"
echo "Tests échoués: $failed"
[ "$timeout" -gt 0 ] && echo "Tests en timeout: $timeout"