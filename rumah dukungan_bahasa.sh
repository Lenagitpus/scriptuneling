#!/bin/bash
# Multi-Language Support for VPS Manager
# Version: HAPPY NEW YEAR 2025

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONFIG_DIR="/etc/vps_manager"
LANG_DIR="$CONFIG_DIR/languages"
DEFAULT_LANG="en"
CURRENT_LANG=$(cat "$CONFIG_DIR/language" 2>/dev/null || echo "$DEFAULT_LANG")

# Ensure directories exist
mkdir -p $CONFIG_DIR
mkdir -p $LANG_DIR

# Function to log messages
log_message() {
    echo -e "$1"
}

# Function to create language files
create_language_files() {
    log_message "${YELLOW}Creating language files...${NC}"
    
    # English (Default)
    cat > "$LANG_DIR/en.lang" << 'EOF'
# English language file for VPS Manager
LANG_NAME="English"
LANG_CODE="en"
LANG_AUTHOR="VPS Manager Team"

# Main Menu
MENU_TITLE="VPS MANAGER MENU"
MENU_SSH="SSH Account Management"
MENU_VMESS="VMESS Account Management"
MENU_VLESS="VLESS Account Management"
MENU_TROJAN="TROJAN Account Management"
MENU_NOOBZVPN="NOOBZVPN Account Management"
MENU_SS="Shadowsocks Account Management"
MENU_UDP="Install UDP Custom"
MENU_BACKUP="Backup & Restore"
MENU_MONITOR="System Monitor"
MENU_RESTART="Restart All Services"
MENU_TELEGRAM="Telegram Bot Settings"
MENU_UPDATE="Update Menu"
MENU_SERVICES="Show Running Services"
MENU_PORTS="Show Port Information"
MENU_BOT="Bot Menu"
MENU_DOMAIN="Change Domain"
MENU_CERT="Fix Certificate"
MENU_BANNER="Change Banner"
MENU_RESTART_BANNER="Restart Banner"
MENU_SPEEDTEST="Speed Test"
MENU_EXTRACT="Extract Configs"
MENU_BANDWIDTH="Bandwidth Management"
MENU_DASHBOARD="Web Dashboard"
MENU_SECURITY="Security Settings"
MENU_LANGUAGE="Language Settings"
MENU_EXIT="Exit"

# Common
BTN_BACK="Back"
BTN_EXIT="Exit"
BTN_CONTINUE="Continue"
BTN_CANCEL="Cancel"
BTN_YES="Yes"
BTN_NO="No"
BTN_OK="OK"
BTN_SAVE="Save"
BTN_DELETE="Delete"
BTN_CREATE="Create"
BTN_EDIT="Edit"
BTN_REFRESH="Refresh"
MSG_INVALID_OPTION="Invalid option!"
MSG_PRESS_ENTER="Press Enter to continue..."

# SSH Menu
SSH_MENU_TITLE="SSH ACCOUNT MANAGEMENT"
SSH_CREATE="Create SSH Account"
SSH_TRIAL="Create Trial Account"
SSH_RENEW="Renew Account"
SSH_DELETE="Delete Account"
SSH_CHECK="Check Login"
SSH_LIST="Member List"
SSH_DELETE_EXP="Delete Expired Accounts"
SSH_AUTOKILL="Auto Kill Multi Login"
SSH_BACK="Back to Main Menu"

# Account Creation
ACCOUNT_USERNAME="Username"
ACCOUNT_PASSWORD="Password"
ACCOUNT_DAYS="Active Days"
ACCOUNT_LIMIT="Connection Limit"
ACCOUNT_CREATED="Account created successfully"
ACCOUNT_RENEWED="Account renewed successfully"
ACCOUNT_DELETED="Account deleted successfully"
ACCOUNT_EXISTS="Account already exists"
ACCOUNT_NOT_FOUND="Account not found"
ACCOUNT_EXPIRED="Account has expired"

# System
SYS_CPU="CPU Usage"
SYS_MEMORY="Memory Usage"
SYS_DISK="Disk Usage"
SYS_UPTIME="Uptime"
SYS_OS="Operating System"
SYS_KERNEL="Kernel Version"
SYS_HOSTNAME="Hostname"
SYS_IP="IP Address"
SYS_DATE="Date & Time"

# Bandwidth
BW_TITLE="BANDWIDTH MANAGEMENT"
BW_USAGE="Bandwidth Usage"
BW_LIMIT="Set Bandwidth Limit"
BW_RESET="Reset Bandwidth Usage"
BW_RESET_ALL="Reset All Bandwidth Usage"
BW_UNLOCK="Unlock User Account"
BW_INTERVAL="Change Monitoring Interval"
BW_COLLECT="Collect Bandwidth Data Now"
BW_LOGS="View Bandwidth Logs"
BW_USERNAME="Username"
BW_USAGE_GB="Usage (GB)"
BW_LIMIT_GB="Limit (GB)"
BW_STATUS="Status"
BW_UNLIMITED="Unlimited"
BW_EXCEEDED="EXCEEDED"
BW_WARNING="WARNING"
BW_OK="OK"
BW_RESET_CONFIRM="Are you sure you want to reset bandwidth usage for all users?"
BW_RESET_SUCCESS="Bandwidth usage reset successfully"
BW_LIMIT_SET="Bandwidth limit set successfully"
BW_UNLOCK_SUCCESS="Account unlocked successfully"
BW_INTERVAL_SET="Monitoring interval set to"
BW_MINUTES="minutes"
BW_DATA_COLLECTED="Bandwidth data collected"

# Dashboard
DASH_TITLE="WEB DASHBOARD MANAGEMENT"
DASH_INSTALL="Install Dashboard"
DASH_START="Start Dashboard"
DASH_STOP="Stop Dashboard"
DASH_RESTART="Restart Dashboard"
DASH_STATUS="Check Dashboard Status"
DASH_CREDS="Change Dashboard Credentials"
DASH_PORT="Change Dashboard Port"
DASH_INSTALLED="Dashboard installed successfully"
DASH_STARTED="Dashboard service started successfully"
DASH_STOPPED="Dashboard service stopped"
DASH_RESTARTED="Dashboard service restarted successfully"
DASH_CREDS_UPDATED="Dashboard credentials updated"
DASH_PORT_UPDATED="Dashboard port updated to"
DASH_ACCESS="Dashboard is accessible at"

# Security
SEC_TITLE="SECURITY ENHANCEMENT MENU"
SEC_PACKAGES="Install Security Packages"
SEC_FAIL2BAN="Configure Fail2ban"
SEC_UFW="Configure UFW Firewall"
SEC_SSH="Harden SSH Configuration"
SEC_UPDATES="Configure Automatic Security Updates"
SEC_AUDIT="Run Security Audit"
SEC_MEMORY="Secure Shared Memory"
SEC_SYSCTL="Secure Sysctl Settings"
SEC_ACCOUNTS="Secure User Accounts"
SEC_AUDITD="Configure Audit System"
SEC_ROOTKIT="Configure Rootkit Detection"
SEC_INTRUSION="Configure Intrusion Detection"
SEC_ALL="Apply All Security Enhancements"
SEC_INSTALLED="Security packages installed successfully"
SEC_FAIL2BAN_CONF="Fail2ban configured successfully"
SEC_UFW_CONF="UFW firewall configured successfully"
SEC_SSH_HARDENED="SSH configuration hardened"
SEC_UPDATES_CONF="Automatic security updates configured successfully"
SEC_AUDIT_COMPLETE="Security audit completed. Reports saved to"
SEC_MEMORY_SECURED="Shared memory secured successfully"
SEC_SYSCTL_SECURED="Sysctl settings secured successfully"
SEC_ACCOUNTS_SECURED="User account security configured successfully"
SEC_AUDITD_CONF="Audit system configured successfully"
SEC_ROOTKIT_CONF="Rootkit detection configured successfully"
SEC_INTRUSION_CONF="Intrusion detection configured successfully"

# Language Settings
LANG_TITLE="LANGUAGE SETTINGS"
LANG_SELECT="Select Language"
LANG_CURRENT="Current Language"
LANG_CHANGED="Language changed to"
LANG_AVAILABLE="Available Languages"
LANG_ADD="Add New Language"
LANG_EDIT="Edit Language File"
LANG_DELETE="Delete Language"
LANG_CONFIRM_DELETE="Are you sure you want to delete this language?"
LANG_DEFAULT="Set as Default"
LANG_DEFAULT_SET="Default language set to"
LANG_FILE_CREATED="Language file created successfully"
LANG_FILE_UPDATED="Language file updated successfully"
LANG_FILE_DELETED="Language file deleted successfully"
EOF
    
    # Spanish
    cat > "$LANG_DIR/es.lang" << 'EOF'
# Archivo de idioma español para VPS Manager
LANG_NAME="Español"
LANG_CODE="es"
LANG_AUTHOR="VPS Manager Team"

# Menú Principal
MENU_TITLE="MENÚ DE VPS MANAGER"
MENU_SSH="Gestión de Cuentas SSH"
MENU_VMESS="Gestión de Cuentas VMESS"
MENU_VLESS="Gestión de Cuentas VLESS"
MENU_TROJAN="Gestión de Cuentas TROJAN"
MENU_NOOBZVPN="Gestión de Cuentas NOOBZVPN"
MENU_SS="Gestión de Cuentas Shadowsocks"
MENU_UDP="Instalar UDP Custom"
MENU_BACKUP="Copia de Seguridad y Restauración"
MENU_MONITOR="Monitor del Sistema"
MENU_RESTART="Reiniciar Todos los Servicios"
MENU_TELEGRAM="Configuración de Bot de Telegram"
MENU_UPDATE="Menú de Actualización"
MENU_SERVICES="Mostrar Servicios en Ejecución"
MENU_PORTS="Mostrar Información de Puertos"
MENU_BOT="Menú de Bot"
MENU_DOMAIN="Cambiar Dominio"
MENU_CERT="Arreglar Certificado"
MENU_BANNER="Cambiar Banner"
MENU_RESTART_BANNER="Reiniciar Banner"
MENU_SPEEDTEST="Prueba de Velocidad"
MENU_EXTRACT="Extraer Configuraciones"
MENU_BANDWIDTH="Gestión de Ancho de Banda"
MENU_DASHBOARD="Panel Web"
MENU_SECURITY="Configuración de Seguridad"
MENU_LANGUAGE="Configuración de Idioma"
MENU_EXIT="Salir"

# Común
BTN_BACK="Volver"
BTN_EXIT="Salir"
BTN_CONTINUE="Continuar"
BTN_CANCEL="Cancelar"
BTN_YES="Sí"
BTN_NO="No"
BTN_OK="Aceptar"
BTN_SAVE="Guardar"
BTN_DELETE="Eliminar"
BTN_CREATE="Crear"
BTN_EDIT="Editar"
BTN_REFRESH="Actualizar"
MSG_INVALID_OPTION="¡Opción inválida!"
MSG_PRESS_ENTER="Presione Enter para continuar..."

# Menú SSH
SSH_MENU_TITLE="GESTIÓN DE CUENTAS SSH"
SSH_CREATE="Crear Cuenta SSH"
SSH_TRIAL="Crear Cuenta de Prueba"
SSH_RENEW="Renovar Cuenta"
SSH_DELETE="Eliminar Cuenta"
SSH_CHECK="Verificar Inicio de Sesión"
SSH_LIST="Lista de Miembros"
SSH_DELETE_EXP="Eliminar Cuentas Expiradas"
SSH_AUTOKILL="Auto Matar Multi Inicio de Sesión"
SSH_BACK="Volver al Menú Principal"

# Creación de Cuenta
ACCOUNT_USERNAME="Nombre de Usuario"
ACCOUNT_PASSWORD="Contraseña"
ACCOUNT_DAYS="Días Activos"
ACCOUNT_LIMIT="Límite de Conexión"
ACCOUNT_CREATED="Cuenta creada exitosamente"
ACCOUNT_RENEWED="Cuenta renovada exitosamente"
ACCOUNT_DELETED="Cuenta eliminada exitosamente"
ACCOUNT_EXISTS="La cuenta ya existe"
ACCOUNT_NOT_FOUND="Cuenta no encontrada"
ACCOUNT_EXPIRED="La cuenta ha expirado"

# Sistema
SYS_CPU="Uso de CPU"
SYS_MEMORY="Uso de Memoria"
SYS_DISK="Uso de Disco"
SYS_UPTIME="Tiempo de Actividad"
SYS_OS="Sistema Operativo"
SYS_KERNEL="Versión del Kernel"
SYS_HOSTNAME="Nombre de Host"
SYS_IP="Dirección IP"
SYS_DATE="Fecha y Hora"

# Ancho de Banda
BW_TITLE="GESTIÓN DE ANCHO DE BANDA"
BW_USAGE="Uso de Ancho de Banda"
BW_LIMIT="Establecer Límite de Ancho de Banda"
BW_RESET="Restablecer Uso de Ancho de Banda"
BW_RESET_ALL="Restablecer Todo el Uso de Ancho de Banda"
BW_UNLOCK="Desbloquear Cuenta de Usuario"
BW_INTERVAL="Cambiar Intervalo de Monitoreo"
BW_COLLECT="Recopilar Datos de Ancho de Banda Ahora"
BW_LOGS="Ver Registros de Ancho de Banda"
BW_USERNAME="Nombre de Usuario"
BW_USAGE_GB="Uso (GB)"
BW_LIMIT_GB="Límite (GB)"
BW_STATUS="Estado"
BW_UNLIMITED="Ilimitado"
BW_EXCEEDED="EXCEDIDO"
BW_WARNING="ADVERTENCIA"
BW_OK="OK"
BW_RESET_CONFIRM="¿Está seguro de que desea restablecer el uso de ancho de banda para todos los usuarios?"
BW_RESET_SUCCESS="Uso de ancho de banda restablecido exitosamente"
BW_LIMIT_SET="Límite de ancho de banda establecido exitosamente"
BW_UNLOCK_SUCCESS="Cuenta desbloqueada exitosamente"
BW_INTERVAL_SET="Intervalo de monitoreo establecido en"
BW_MINUTES="minutos"
BW_DATA_COLLECTED="Datos de ancho de banda recopilados"

# Panel
DASH_TITLE="GESTIÓN DEL PANEL WEB"
DASH_INSTALL="Instalar Panel"
DASH_START="Iniciar Panel"
DASH_STOP="Detener Panel"
DASH_RESTART="Reiniciar Panel"
DASH_STATUS="Verificar Estado del Panel"
DASH_CREDS="Cambiar Credenciales del Panel"
DASH_PORT="Cambiar Puerto del Panel"
DASH_INSTALLED="Panel instalado exitosamente"
DASH_STARTED="Servicio del panel iniciado exitosamente"
DASH_STOPPED="Servicio del panel detenido"
DASH_RESTARTED="Servicio del panel reiniciado exitosamente"
DASH_CREDS_UPDATED="Credenciales del panel actualizadas"
DASH_PORT_UPDATED="Puerto del panel actualizado a"
DASH_ACCESS="El panel es accesible en"

# Seguridad
SEC_TITLE="MENÚ DE MEJORA DE SEGURIDAD"
SEC_PACKAGES="Instalar Paquetes de Seguridad"
SEC_FAIL2BAN="Configurar Fail2ban"
SEC_UFW="Configurar Firewall UFW"
SEC_SSH="Endurecer Configuración SSH"
SEC_UPDATES="Configurar Actualizaciones Automáticas de Seguridad"
SEC_AUDIT="Ejecutar Auditoría de Seguridad"
SEC_MEMORY="Asegurar Memoria Compartida"
SEC_SYSCTL="Asegurar Configuración Sysctl"
SEC_ACCOUNTS="Asegurar Cuentas de Usuario"
SEC_AUDITD="Configurar Sistema de Auditoría"
SEC_ROOTKIT="Configurar Detección de Rootkit"
SEC_INTRUSION="Configurar Detección de Intrusiones"
SEC_ALL="Aplicar Todas las Mejoras de Seguridad"
SEC_INSTALLED="Paquetes de seguridad instalados exitosamente"
SEC_FAIL2BAN_CONF="Fail2ban configurado exitosamente"
SEC_UFW_CONF="Firewall UFW configurado exitosamente"
SEC_SSH_HARDENED="Configuración SSH endurecida"
SEC_UPDATES_CONF="Actualizaciones automáticas de seguridad configuradas exitosamente"
SEC_AUDIT_COMPLETE="Auditoría de seguridad completada. Informes guardados en"
SEC_MEMORY_SECURED="Memoria compartida asegurada exitosamente"
SEC_SYSCTL_SECURED="Configuración Sysctl asegurada exitosamente"
SEC_ACCOUNTS_SECURED="Seguridad de cuentas de usuario configurada exitosamente"
SEC_AUDITD_CONF="Sistema de auditoría configurado exitosamente"
SEC_ROOTKIT_CONF="Detección de rootkit configurada exitosamente"
SEC_INTRUSION_CONF="Detección de intrusiones configurada exitosamente"

# Configuración de Idioma
LANG_TITLE="CONFIGURACIÓN DE IDIOMA"
LANG_SELECT="Seleccionar Idioma"
LANG_CURRENT="Idioma Actual"
LANG_CHANGED="Idioma cambiado a"
LANG_AVAILABLE="Idiomas Disponibles"
LANG_ADD="Agregar Nuevo Idioma"
LANG_EDIT="Editar Archivo de Idioma"
LANG_DELETE="Eliminar Idioma"
LANG_CONFIRM_DELETE="¿Está seguro de que desea eliminar este idioma?"
LANG_DEFAULT="Establecer como Predeterminado"
LANG_DEFAULT_SET="Idioma predeterminado establecido en"
LANG_FILE_CREATED="Archivo de idioma creado exitosamente"
LANG_FILE_UPDATED="Archivo de idioma actualizado exitosamente"
LANG_FILE_DELETED="Archivo de idioma eliminado exitosamente"
EOF
    
    # Portuguese
    cat > "$LANG_DIR/pt.lang" << 'EOF'
# Arquivo de idioma português para VPS Manager
LANG_NAME="Português"
LANG_CODE="pt"
LANG_AUTHOR="VPS Manager Team"

# Menu Principal
MENU_TITLE="MENU DO VPS MANAGER"
MENU_SSH="Gerenciamento de Contas SSH"
MENU_VMESS="Gerenciamento de Contas VMESS"
MENU_VLESS="Gerenciamento de Contas VLESS"
MENU_TROJAN="Gerenciamento de Contas TROJAN"
MENU_NOOBZVPN="Gerenciamento de Contas NOOBZVPN"
MENU_SS="Gerenciamento de Contas Shadowsocks"
MENU_UDP="Instalar UDP Custom"
MENU_BACKUP="Backup e Restauração"
MENU_MONITOR="Monitor do Sistema"
MENU_RESTART="Reiniciar Todos os Serviços"
MENU_TELEGRAM="Configurações do Bot do Telegram"
MENU_UPDATE="Menu de Atualização"
MENU_SERVICES="Mostrar Serviços em Execução"
MENU_PORTS="Mostrar Informações de Portas"
MENU_BOT="Menu de Bot"
MENU_DOMAIN="Alterar Domínio"
MENU_CERT="Corrigir Certificado"
MENU_BANNER="Alterar Banner"
MENU_RESTART_BANNER="Reiniciar Banner"
MENU_SPEEDTEST="Teste de Velocidade"
MENU_EXTRACT="Extrair Configurações"
MENU_BANDWIDTH="Gerenciamento de Largura de Banda"
MENU_DASHBOARD="Painel Web"
MENU_SECURITY="Configurações de Segurança"
MENU_LANGUAGE="Configurações de Idioma"
MENU_EXIT="Sair"

# Comum
BTN_BACK="Voltar"
BTN_EXIT="Sair"
BTN_CONTINUE="Continuar"
BTN_CANCEL="Cancelar"
BTN_YES="Sim"
BTN_NO="Não"
BTN_OK="OK"
BTN_SAVE="Salvar"
BTN_DELETE="Excluir"
BTN_CREATE="Criar"
BTN_EDIT="Editar"
BTN_REFRESH="Atualizar"
MSG_INVALID_OPTION="Opção inválida!"
MSG_PRESS_ENTER="Pressione Enter para continuar..."

# Menu SSH
SSH_MENU_TITLE="GERENCIAMENTO DE CONTAS SSH"
SSH_CREATE="Criar Conta SSH"
SSH_TRIAL="Criar Conta de Teste"
SSH_RENEW="Renovar Conta"
SSH_DELETE="Excluir Conta"
SSH_CHECK="Verificar Login"
SSH_LIST="Lista de Membros"
SSH_DELETE_EXP="Excluir Contas Expiradas"
SSH_AUTOKILL="Auto Matar Multi Login"
SSH_BACK="Voltar ao Menu Principal"

# Criação de Conta
ACCOUNT_USERNAME="Nome de Usuário"
ACCOUNT_PASSWORD="Senha"
ACCOUNT_DAYS="Dias Ativos"
ACCOUNT_LIMIT="Limite de Conexão"
ACCOUNT_CREATED="Conta criada com sucesso"
ACCOUNT_RENEWED="Conta renovada com sucesso"
ACCOUNT_DELETED="Conta excluída com sucesso"
ACCOUNT_EXISTS="A conta já existe"
ACCOUNT_NOT_FOUND="Conta não encontrada"
ACCOUNT_EXPIRED="A conta expirou"

# Sistema
SYS_CPU="Uso da CPU"
SYS_MEMORY="Uso de Memória"
SYS_DISK="Uso de Disco"
SYS_UPTIME="Tempo de Atividade"
SYS_OS="Sistema Operacional"
SYS_KERNEL="Versão do Kernel"
SYS_HOSTNAME="Nome do Host"
SYS_IP="Endereço IP"
SYS_DATE="Data e Hora"

# Largura de Banda
BW_TITLE="GERENCIAMENTO DE LARGURA DE BANDA"
BW_USAGE="Uso de Largura de Banda"
BW_LIMIT="Definir Limite de Largura de Banda"
BW_RESET="Redefinir Uso de Largura de Banda"
BW_RESET_ALL="Redefinir Todo o Uso de Largura de Banda"
BW_UNLOCK="Desbloquear Conta de Usuário"
BW_INTERVAL="Alterar Intervalo de Monitoramento"
BW_COLLECT="Coletar Dados de Largura de Banda Agora"
BW_LOGS="Ver Registros de Largura de Banda"
BW_USERNAME="Nome de Usuário"
BW_USAGE_GB="Uso (GB)"
BW_LIMIT_GB="Limite (GB)"
BW_STATUS="Status"
BW_UNLIMITED="Ilimitado"
BW_EXCEEDED="EXCEDIDO"
BW_WARNING="AVISO"
BW_OK="OK"
BW_RESET_CONFIRM="Tem certeza de que deseja redefinir o uso de largura de banda para todos os usuários?"
BW_RESET_SUCCESS="Uso de largura de banda redefinido com sucesso"
BW_LIMIT_SET="Limite de largura de banda definido com sucesso"
BW_UNLOCK_SUCCESS="Conta desbloqueada com sucesso"
BW_INTERVAL_SET="Intervalo de monitoramento definido para"
BW_MINUTES="minutos"
BW_DATA_COLLECTED="Dados de largura de banda coletados"

# Painel
DASH_TITLE="GERENCIAMENTO DO PAINEL WEB"
DASH_INSTALL="Instalar Painel"
DASH_START="Iniciar Painel"
DASH_STOP="Parar Painel"
DASH_RESTART="Reiniciar Painel"
DASH_STATUS="Verificar Status do Painel"
DASH_CREDS="Alterar Credenciais do Painel"
DASH_PORT="Alterar Porta do Painel"
DASH_INSTALLED="Painel instalado com sucesso"
DASH_STARTED="Serviço do painel iniciado com sucesso"
DASH_STOPPED="Serviço do painel parado"
DASH_RESTARTED="Serviço do painel reiniciado com sucesso"
DASH_CREDS_UPDATED="Credenciais do painel atualizadas"
DASH_PORT_UPDATED="Porta do painel atualizada para"
DASH_ACCESS="O painel está acessível em"

# Segurança
SEC_TITLE="MENU DE APRIMORAMENTO DE SEGURANÇA"
SEC_PACKAGES="Instalar Pacotes de Segurança"
SEC_FAIL2BAN="Configurar Fail2ban"
SEC_UFW="Configurar Firewall UFW"
SEC_SSH="Fortalecer Configuração SSH"
SEC_UPDATES="Configurar Atualizações Automáticas de Segurança"
SEC_AUDIT="Executar Auditoria de Segurança"
SEC_MEMORY="Proteger Memória Compartilhada"
SEC_SYSCTL="Proteger Configurações Sysctl"
SEC_ACCOUNTS="Proteger Contas de Usuário"
SEC_AUDITD="Configurar Sistema de Auditoria"
SEC_ROOTKIT="Configurar Detecção de Rootkit"
SEC_INTRUSION="Configurar Detecção de Intrusão"
SEC_ALL="Aplicar Todos os Aprimoramentos de Segurança"
SEC_INSTALLED="Pacotes de segurança instalados com sucesso"
SEC_FAIL2BAN_CONF="Fail2ban configurado com sucesso"
SEC_UFW_CONF="Firewall UFW configurado com sucesso"
SEC_SSH_HARDENED="Configuração SSH fortalecida"
SEC_UPDATES_CONF="Atualizações automáticas de segurança configuradas com sucesso"
SEC_AUDIT_COMPLETE="Auditoria de segurança concluída. Relatórios salvos em"
SEC_MEMORY_SECURED="Memória compartilhada protegida com sucesso"
SEC_SYSCTL_SECURED="Configurações Sysctl protegidas com sucesso"
SEC_ACCOUNTS_SECURED="Segurança de contas de usuário configurada com sucesso"
SEC_AUDITD_CONF="Sistema de auditoria configurado com sucesso"
SEC_ROOTKIT_CONF="Detecção de rootkit configurada com sucesso"
SEC_INTRUSION_CONF="Detecção de intrusão configurada com sucesso"

# Configurações de Idioma
LANG_TITLE="CONFIGURAÇÕES DE IDIOMA"
LANG_SELECT="Selecionar Idioma"
LANG_CURRENT="Idioma Atual"
LANG_CHANGED="Idioma alterado para"
LANG_AVAILABLE="Idiomas Disponíveis"
LANG_ADD="Adicionar Novo Idioma"
LANG_EDIT="Editar Arquivo de Idioma"
LANG_DELETE="Excluir Idioma"
LANG_CONFIRM_DELETE="Tem certeza de que deseja excluir este idioma?"
LANG_DEFAULT="Definir como Padrão"
LANG_DEFAULT_SET="Idioma padrão definido como"
LANG_FILE_CREATED="Arquivo de idioma criado com sucesso"
LANG_FILE_UPDATED="Arquivo de idioma atualizado com sucesso"
LANG_FILE_DELETED="Arquivo de idioma excluído com sucesso"
EOF
    
    # French
    cat > "$LANG_DIR/fr.lang" << 'EOF'
# Fichier de langue française pour VPS Manager
LANG_NAME="Français"
LANG_CODE="fr"
LANG_AUTHOR="VPS Manager Team"

# Menu Principal
MENU_TITLE="MENU VPS MANAGER"
MENU_SSH="Gestion des Comptes SSH"
MENU_VMESS="Gestion des Comptes VMESS"
MENU_VLESS="Gestion des Comptes VLESS"
MENU_TROJAN="Gestion des Comptes TROJAN"
MENU_NOOBZVPN="Gestion des Comptes NOOBZVPN"
MENU_SS="Gestion des Comptes Shadowsocks"
MENU_UDP="Installer UDP Custom"
MENU_BACKUP="Sauvegarde et Restauration"
MENU_MONITOR="Moniteur Système"
MENU_RESTART="Redémarrer Tous les Services"
MENU_TELEGRAM="Paramètres du Bot Telegram"
MENU_UPDATE="Menu de Mise à Jour"
MENU_SERVICES="Afficher les Services en Cours"
MENU_PORTS="Afficher les Informations de Port"
MENU_BOT="Menu Bot"
MENU_DOMAIN="Changer de Domaine"
MENU_CERT="Réparer le Certificat"
MENU_BANNER="Changer la Bannière"
MENU_RESTART_BANNER="Redémarrer la Bannière"
MENU_SPEEDTEST="Test de Vitesse"
MENU_EXTRACT="Extraire les Configurations"
MENU_BANDWIDTH="Gestion de la Bande Passante"
MENU_DASHBOARD="Tableau de Bord Web"
MENU_SECURITY="Paramètres de Sécurité"
MENU_LANGUAGE="Paramètres de Langue"
MENU_EXIT="Quitter"

# Commun
BTN_BACK="Retour"
BTN_EXIT="Quitter"
BTN_CONTINUE="Continuer"
BTN_CANCEL="Annuler"
BTN_YES="Oui"
BTN_NO="Non"
BTN_OK="OK"
BTN_SAVE="Enregistrer"
BTN_DELETE="Supprimer"
BTN_CREATE="Créer"
BTN_EDIT="Modifier"
BTN_REFRESH="Actualiser"
MSG_INVALID_OPTION="Option invalide !"
MSG_PRESS_ENTER="Appuyez sur Entrée pour continuer..."

# Menu SSH
SSH_MENU_TITLE="GESTION DES COMPTES SSH"
SSH_CREATE="Créer un Compte SSH"
SSH_TRIAL="Créer un Compte d'Essai"
SSH_RENEW="Renouveler un Compte"
SSH_DELETE="Supprimer un Compte"
SSH_CHECK="Vérifier la Connexion"
SSH_LIST="Liste des Membres"
SSH_DELETE_EXP="Supprimer les Comptes Expirés"
SSH_AUTOKILL="Auto-Kill Multi Connexion"
SSH_BACK="Retour au Menu Principal"

# Création de Compte
ACCOUNT_USERNAME="Nom d'Utilisateur"
ACCOUNT_PASSWORD="Mot de Passe"
ACCOUNT_DAYS="Jours Actifs"
ACCOUNT_LIMIT="Limite de Connexion"
ACCOUNT_CREATED="Compte créé avec succès"
ACCOUNT_RENEWED="Compte renouvelé avec succès"
ACCOUNT_DELETED="Compte supprimé avec succès"
ACCOUNT_EXISTS="Le compte existe déjà"
ACCOUNT_NOT_FOUND="Compte non trouvé"
ACCOUNT_EXPIRED="Le compte a expiré"

# Système
SYS_CPU="Utilisation CPU"
SYS_MEMORY="Utilisation Mémoire"
SYS_DISK="Utilisation Disque"
SYS_UPTIME="Temps de Fonctionnement"
SYS_OS="Système d'Exploitation"
SYS_KERNEL="Version du Noyau"
SYS_HOSTNAME="Nom d'Hôte"
SYS_IP="Adresse IP"
SYS_DATE="Date et Heure"

# Bande Passante
BW_TITLE="GESTION DE LA BANDE PASSANTE"
BW_USAGE="Utilisation de la Bande Passante"
BW_LIMIT="Définir la Limite de Bande Passante"
BW_RESET="Réinitialiser l'Utilisation de la Bande Passante"
BW_RESET_ALL="Réinitialiser Toute l'Utilisation de la Bande Passante"
BW_UNLOCK="Débloquer le Compte Utilisateur"
BW_INTERVAL="Changer l'Intervalle de Surveillance"
BW_COLLECT="Collecter les Données de Bande Passante Maintenant"
BW_LOGS="Voir les Journaux de Bande Passante"
BW_USERNAME="Nom d'Utilisateur"
BW_USAGE_GB="Utilisation (GB)"
BW_LIMIT_GB="Limite (GB)"
BW_STATUS="Statut"
BW_UNLIMITED="Illimité"
BW_EXCEEDED="DÉPASSÉ"
BW_WARNING="AVERTISSEMENT"
BW_OK="OK"
BW_RESET_CONFIRM="Êtes-vous sûr de vouloir réinitialiser l'utilisation de la bande passante pour tous les utilisateurs ?"
BW_RESET_SUCCESS="Utilisation de la bande passante réinitialisée avec succès"
BW_LIMIT_SET="Limite de bande passante définie avec succès"
BW_UNLOCK_SUCCESS="Compte débloqué avec succès"
BW_INTERVAL_SET="Intervalle de surveillance défini à"
BW_MINUTES="minutes"
BW_DATA_COLLECTED="Données de bande passante collectées"

# Tableau de Bord
DASH_TITLE="GESTION DU TABLEAU DE BORD WEB"
DASH_INSTALL="Installer le Tableau de Bord"
DASH_START="Démarrer le Tableau de Bord"
DASH_STOP="Arrêter le Tableau de Bord"
DASH_RESTART="Redémarrer le Tableau de Bord"
DASH_STATUS="Vérifier l'État du Tableau de Bord"
DASH_CREDS="Changer les Identifiants du Tableau de Bord"
DASH_PORT="Changer le Port du Tableau de Bord"
DASH_INSTALLED="Tableau de bord installé avec succès"
DASH_STARTED="Service du tableau de bord démarré avec succès"
DASH_STOPPED="Service du tableau de bord arrêté"
DASH_RESTARTED="Service du tableau de bord redémarré avec succès"
DASH_CREDS_UPDATED="Identifiants du tableau de bord mis à jour"
DASH_PORT_UPDATED="Port du tableau de bord mis à jour à"
DASH_ACCESS="Le tableau de bord est accessible à"

# Sécurité
SEC_TITLE="MENU D'AMÉLIORATION DE LA SÉCURITÉ"
SEC_PACKAGES="Installer les Paquets de Sécurité"
SEC_FAIL2BAN="Configurer Fail2ban"
SEC_UFW="Configurer le Pare-feu UFW"
SEC_SSH="Renforcer la Configuration SSH"
SEC_UPDATES="Configurer les Mises à Jour Automatiques de Sécurité"
SEC_AUDIT="Exécuter l'Audit de Sécurité"
SEC_MEMORY="Sécuriser la Mémoire Partagée"
SEC_SYSCTL="Sécuriser les Paramètres Sysctl"
SEC_ACCOUNTS="Sécuriser les Comptes Utilisateurs"
SEC_AUDITD="Configurer le Système d'Audit"
SEC_ROOTKIT="Configurer la Détection de Rootkit"
SEC_INTRUSION="Configurer la Détection d'Intrusion"
SEC_ALL="Appliquer Toutes les Améliorations de Sécurité"
SEC_INSTALLED="Paquets de sécurité installés avec succès"
SEC_FAIL2BAN_CONF="Fail2ban configuré avec succès"
SEC_UFW_CONF="Pare-feu UFW configuré avec succès"
SEC_SSH_HARDENED="Configuration SSH renforcée"
SEC_UPDATES_CONF="Mises à jour automatiques de sécurité configurées avec succès"
SEC_AUDIT_COMPLETE="Audit de sécurité terminé. Rapports enregistrés dans"
SEC_MEMORY_SECURED="Mémoire partagée sécurisée avec succès"
SEC_SYSCTL_SECURED="Paramètres Sysctl sécurisés avec succès"
SEC_ACCOUNTS_SECURED="Sécurité des comptes utilisateurs configurée avec succès"
SEC_AUDITD_CONF="Système d'audit configuré avec succès"
SEC_ROOTKIT_CONF="Détection de rootkit configurée avec succès"
SEC_INTRUSION_CONF="Détection d'intrusion configurée avec succès"

# Paramètres de Langue
LANG_TITLE="PARAMÈTRES DE LANGUE"
LANG_SELECT="Sélectionner la Langue"
LANG_CURRENT="Langue Actuelle"
LANG_CHANGED="Langue changée en"
LANG_AVAILABLE="Langues Disponibles"
LANG_ADD="Ajouter une Nouvelle Langue"
LANG_EDIT="Modifier le Fichier de Langue"
LANG_DELETE="Supprimer la Langue"
LANG_CONFIRM_DELETE="Êtes-vous sûr de vouloir supprimer cette langue ?"
LANG_DEFAULT="Définir par Défaut"
LANG_DEFAULT_SET="Langue par défaut définie à"
LANG_FILE_CREATED="Fichier de langue créé avec succès"
LANG_FILE_UPDATED="Fichier de langue mis à jour avec succès"
LANG_FILE_DELETED="Fichier de langue supprimé avec succès"
EOF
    
    # German
    cat > "$LANG_DIR/de.lang" << 'EOF'
# Deutsche Sprachdatei für VPS Manager
LANG_NAME="Deutsch"
LANG_CODE="de"
LANG_AUTHOR="VPS Manager Team"

# Hauptmenü
MENU_TITLE="VPS MANAGER MENÜ"
MENU_SSH="SSH-Kontoverwaltung"
MENU_VMESS="VMESS-Kontoverwaltung"
MENU_VLESS="VLESS-Kontoverwaltung"
MENU_TROJAN="TROJAN-Kontoverwaltung"
MENU_NOOBZVPN="NOOBZVPN-Kontoverwaltung"
MENU_SS="Shadowsocks-Kontoverwaltung"
MENU_UDP="UDP Custom installieren"
MENU_BACKUP="Sicherung & Wiederherstellung"
MENU_MONITOR="Systemüberwachung"
MENU_RESTART="Alle Dienste neustarten"
MENU_TELEGRAM="Telegram-Bot-Einstellungen"
MENU_UPDATE="Aktualisierungsmenü"
MENU_SERVICES="Laufende Dienste anzeigen"
MENU_PORTS="Port-Informationen anzeigen"
MENU_BOT="Bot-Menü"
MENU_DOMAIN="Domain ändern"
MENU_CERT="Zertifikat reparieren"
MENU_BANNER="Banner ändern"
MENU_RESTART_BANNER="Banner neustarten"
MENU_SPEEDTEST="Geschwindigkeitstest"
MENU_EXTRACT="Konfigurationen extrahieren"
MENU_BANDWIDTH="Bandbreitenverwaltung"
MENU_DASHBOARD="Web-Dashboard"
MENU_SECURITY="Sicherheitseinstellungen"
MENU_LANGUAGE="Spracheinstellungen"
MENU_EXIT="Beenden"

# Allgemein
BTN_BACK="Zurück"
BTN_EXIT="Beenden"
BTN_CONTINUE="Fortfahren"
BTN_CANCEL="Abbrechen"
BTN_YES="Ja"
BTN_NO="Nein"
BTN_OK="OK"
BTN_SAVE="Speichern"
BTN_DELETE="Löschen"
BTN_CREATE="Erstellen"
BTN_EDIT="Bearbeiten"
BTN_REFRESH="Aktualisieren"
MSG_INVALID_OPTION="Ungültige Option!"
MSG_PRESS_ENTER="Drücken Sie Enter, um fortzufahren..."

# SSH-Menü
SSH_MENU_TITLE="SSH-KONTOVERWALTUNG"
SSH_CREATE="SSH-Konto erstellen"
SSH_TRIAL="Testkonto erstellen"
SSH_RENEW="Konto verlängern"
SSH_DELETE="Konto löschen"
SSH_CHECK="Login überprüfen"
SSH_LIST="Mitgliederliste"
SSH_DELETE_EXP="Abgelaufene Konten löschen"
SSH_AUTOKILL="Auto-Kill bei mehrfacher Anmeldung"
SSH_BACK="Zurück zum Hauptmenü"

# Kontoerstellung
ACCOUNT_USERNAME="Benutzername"
ACCOUNT_PASSWORD="Passwort"
ACCOUNT_DAYS="Aktive Tage"
ACCOUNT_LIMIT="Verbindungslimit"
ACCOUNT_CREATED="Konto erfolgreich erstellt"
ACCOUNT_RENEWED="Konto erfolgreich verlängert"
ACCOUNT_DELETED="Konto erfolgreich gelöscht"
ACCOUNT_EXISTS="Konto existiert bereits"
ACCOUNT_NOT_FOUND="Konto nicht gefunden"
ACCOUNT_EXPIRED="Konto ist abgelaufen"

# System
SYS_CPU="CPU-Auslastung"
SYS_MEMORY="Speicherauslastung"
SYS_DISK="Festplattennutzung"
SYS_UPTIME="Betriebszeit"
SYS_OS="Betriebssystem"
SYS_KERNEL="Kernel-Version"
SYS_HOSTNAME="Hostname"
SYS_IP="IP-Adresse"
SYS_DATE="Datum & Uhrzeit"

# Bandbreite
BW_TITLE="BANDBREITENVERWALTUNG"
BW_USAGE="Bandbreitennutzung"
BW_LIMIT="Bandbreitenlimit festlegen"
BW_RESET="Bandbreitennutzung zurücksetzen"
BW_RESET_ALL="Alle Bandbreitennutzung zurücksetzen"
BW_UNLOCK="Benutzerkonto entsperren"
BW_INTERVAL="Überwachungsintervall ändern"
BW_COLLECT="Bandbreitendaten jetzt sammeln"
BW_LOGS="Bandbreitenprotokolle anzeigen"
BW_USERNAME="Benutzername"
BW_USAGE_GB="Nutzung (GB)"
BW_LIMIT_GB="Limit (GB)"
BW_STATUS="Status"
BW_UNLIMITED="Unbegrenzt"
BW_EXCEEDED="ÜBERSCHRITTEN"
BW_WARNING="WARNUNG"
BW_OK="OK"
BW_RESET_CONFIRM="Sind Sie sicher, dass Sie die Bandbreitennutzung für alle Benutzer zurücksetzen möchten?"
BW_RESET_SUCCESS="Bandbreitennutzung erfolgreich zurückgesetzt"
BW_LIMIT_SET="Bandbreitenlimit erfolgreich festgelegt"
BW_UNLOCK_SUCCESS="Konto erfolgreich entsperrt"
BW_INTERVAL_SET="Überwachungsintervall eingestellt auf"
BW_MINUTES="Minuten"
BW_DATA_COLLECTED="Bandbreitendaten gesammelt"

# Dashboard
DASH_TITLE="WEB-DASHBOARD-VERWALTUNG"
DASH_INSTALL="Dashboard installieren"
DASH_START="Dashboard starten"
DASH_STOP="Dashboard stoppen"
DASH_RESTART="Dashboard neustarten"
DASH_STATUS="Dashboard-Status prüfen"
DASH_CREDS="Dashboard-Anmeldedaten ändern"
DASH_PORT="Dashboard-Port ändern"
DASH_INSTALLED="Dashboard erfolgreich installiert"
DASH_STARTED="Dashboard-Dienst erfolgreich gestartet"
DASH_STOPPED="Dashboard-Dienst gestoppt"
DASH_RESTARTED="Dashboard-Dienst erfolgreich neugestartet"
DASH_CREDS_UPDATED="Dashboard-Anmeldedaten aktualisiert"
DASH_PORT_UPDATED="Dashboard-Port aktualisiert auf"
DASH_ACCESS="Dashboard ist erreichbar unter"

# Sicherheit
SEC_TITLE="SICHERHEITSVERBESSERUNGSMENÜ"
SEC_PACKAGES="Sicherheitspakete installieren"
SEC_FAIL2BAN="Fail2ban konfigurieren"
SEC_UFW="UFW-Firewall konfigurieren"
SEC_SSH="SSH-Konfiguration härten"
SEC_UPDATES="Automatische Sicherheitsupdates konfigurieren"
SEC_AUDIT="Sicherheitsaudit durchführen"
SEC_MEMORY="Gemeinsamen Speicher sichern"
SEC_SYSCTL="Sysctl-Einstellungen sichern"
SEC_ACCOUNTS="Benutzerkonten sichern"
SEC_AUDITD="Audit-System konfigurieren"
SEC_ROOTKIT="Rootkit-Erkennung konfigurieren"
SEC_INTRUSION="Einbruchserkennung konfigurieren"
SEC_ALL="Alle Sicherheitsverbesserungen anwenden"
SEC_INSTALLED="Sicherheitspakete erfolgreich installiert"
SEC_FAIL2BAN_CONF="Fail2ban erfolgreich konfiguriert"
SEC_UFW_CONF="UFW-Firewall erfolgreich konfiguriert"
SEC_SSH_HARDENED="SSH-Konfiguration gehärtet"
SEC_UPDATES_CONF="Automatische Sicherheitsupdates erfolgreich konfiguriert"
SEC_AUDIT_COMPLETE="Sicherheitsaudit abgeschlossen. Berichte gespeichert in"
SEC_MEMORY_SECURED="Gemeinsamer Speicher erfolgreich gesichert"
SEC_SYSCTL_SECURED="Sysctl-Einstellungen erfolgreich gesichert"
SEC_ACCOUNTS_SECURED="Benutzerkontensicherheit erfolgreich konfiguriert"
SEC_AUDITD_CONF="Audit-System erfolgreich konfiguriert"
SEC_ROOTKIT_CONF="Rootkit-Erkennung erfolgreich konfiguriert"
SEC_INTRUSION_CONF="Einbruchserkennung erfolgreich konfiguriert"

# Spracheinstellungen
LANG_TITLE="SPRACHEINSTELLUNGEN"
LANG_SELECT="Sprache auswählen"
LANG_CURRENT="Aktuelle Sprache"
LANG_CHANGED="Sprache geändert zu"
LANG_AVAILABLE="Verfügbare Sprachen"
LANG_ADD="Neue Sprache hinzufügen"
LANG_EDIT="Sprachdatei bearbeiten"
LANG_DELETE="Sprache löschen"
LANG_CONFIRM_DELETE="Sind Sie sicher, dass Sie diese Sprache löschen möchten?"
LANG_DEFAULT="Als Standard festlegen"
LANG_DEFAULT_SET="Standardsprache festgelegt auf"
LANG_FILE_CREATED="Sprachdatei erfolgreich erstellt"
LANG_FILE_UPDATED="Sprachdatei erfolgreich aktualisiert"
LANG_FILE_DELETED="Sprachdatei erfolgreich gelöscht"
EOF
    
    # Chinese (Simplified)
    cat > "$LANG_DIR/zh.lang" << 'EOF'
# VPS Manager 简体中文语言文件
LANG_NAME="简体中文"
LANG_CODE="zh"
LANG_AUTHOR="VPS Manager Team"

# 主菜单
MENU_TITLE="VPS 管理器菜单"
MENU_SSH="SSH 账户管理"
MENU_VMESS="VMESS 账户管理"
MENU_VLESS="VLESS 账户管理"
MENU_TROJAN="TROJAN 账户管理"
MENU_NOOBZVPN="NOOBZVPN 账户管理"
MENU_SS="Shadowsocks 账户管理"
MENU_UDP="安装 UDP Custom"
MENU_BACKUP="备份与恢复"
MENU_MONITOR="系统监控"
MENU_RESTART="重启所有服务"
MENU_TELEGRAM="Telegram 机器人设置"
MENU_UPDATE="更新菜单"
MENU_SERVICES="显示运行中的服务"
MENU_PORTS="显示端口信息"
MENU_BOT="机器人菜单"
MENU_DOMAIN="更改域名"
MENU_CERT="修复证书"
MENU_BANNER="更改横幅"
MENU_RESTART_BANNER="重启横幅"
MENU_SPEEDTEST="速度测试"
MENU_EXTRACT="提取配置"
MENU_BANDWIDTH="带宽管理"
MENU_DASHBOARD="网页仪表板"
MENU_SECURITY="安全设置"
MENU_LANGUAGE="语言设置"
MENU_EXIT="退出"

# 通用
BTN_BACK="返回"
BTN_EXIT="退出"
BTN_CONTINUE="继续"
BTN_CANCEL="取消"
BTN_YES="是"
BTN_NO="否"
BTN_OK="确定"
BTN_SAVE="保存"
BTN_DELETE="删除"
BTN_CREATE="创建"
BTN_EDIT="编辑"
BTN_REFRESH="刷新"
MSG_INVALID_OPTION="无效选项！"
MSG_PRESS_ENTER="按 Enter 键继续..."

# SSH 菜单
SSH_MENU_TITLE="SSH 账户管理"
SSH_CREATE="创建 SSH 账户"
SSH_TRIAL="创建试用账户"
SSH_RENEW="续期账户"
SSH_DELETE="删除账户"
SSH_CHECK="检查登录"
SSH_LIST="成员列表"
SSH_DELETE_EXP="删除过期账户"
SSH_AUTOKILL="自动终止多重登录"
SSH_BACK="返回主菜单"

# 账户创建
ACCOUNT_USERNAME="用户名"
ACCOUNT_PASSWORD="密码"
ACCOUNT_DAYS="有效天数"
ACCOUNT_LIMIT="连接限制"
ACCOUNT_CREATED="账户创建成功"
ACCOUNT_RENEWED="账户续期成功"
ACCOUNT_DELETED="账户删除成功"
ACCOUNT_EXISTS="账户已存在"
ACCOUNT_NOT_FOUND="未找到账户"
ACCOUNT_EXPIRED="账户已过期"

# 系统
SYS_CPU="CPU 使用率"
SYS_MEMORY="内存使用率"
SYS_DISK="磁盘使用率"
SYS_UPTIME="运行时间"
SYS_OS="操作系统"
SYS_KERNEL="内核版本"
SYS_HOSTNAME="主机名"
SYS_IP="IP 地址"
SYS_DATE="日期和时间"

# 带宽
BW_TITLE="带宽管理"
BW_USAGE="带宽使用情况"
BW_LIMIT="设置带宽限制"
BW_RESET="重置带宽使用情况"
BW_RESET_ALL="重置所有带宽使用情况"
BW_UNLOCK="解锁用户账户"
BW_INTERVAL="更改监控间隔"
BW_COLLECT="立即收集带宽数据"
BW_LOGS="查看带宽日志"
BW_USERNAME="用户名"
BW_USAGE_GB="使用量 (GB)"
BW_LIMIT_GB="限制 (GB)"
BW_STATUS="状态"
BW_UNLIMITED="无限制"
BW_EXCEEDED="已超出"
BW_WARNING="警告"
BW_OK="正常"
BW_RESET_CONFIRM="您确定要重置所有用户的带宽使用情况吗？"
BW_RESET_SUCCESS="带宽使用情况重置成功"
BW_LIMIT_SET="带宽限制设置成功"
BW_UNLOCK_SUCCESS="账户解锁成功"
BW_INTERVAL_SET="监控间隔设置为"
BW_MINUTES="分钟"
BW_DATA_COLLECTED="带宽数据已收集"

# 仪表板
DASH_TITLE="网页仪表板管理"
DASH_INSTALL="安装仪表板"
DASH_START="启动仪表板"
DASH_STOP="停止仪表板"
DASH_RESTART="重启仪表板"
DASH_STATUS="检查仪表板状态"
DASH_CREDS="更改仪表板凭据"
DASH_PORT="更改仪表板端口"
DASH_INSTALLED="仪表板安装成功"
DASH_STARTED="仪表板服务启动成功"
DASH_STOPPED="仪表板服务已停止"
DASH_RESTARTED="仪表板服务重启成功"
DASH_CREDS_UPDATED="仪表板凭据已更新"
DASH_PORT_UPDATED="仪表板端口已更新为"
DASH_ACCESS="仪表板可通过以下地址访问"

# 安全
SEC_TITLE="安全增强菜单"
SEC_PACKAGES="安装安全软件包"
SEC_FAIL2BAN="配置 Fail2ban"
SEC_UFW="配置 UFW 防火墙"
SEC_SSH="加固 SSH 配置"
SEC_UPDATES="配置自动安全更新"
SEC_AUDIT="运行安全审计"
SEC_MEMORY="保护共享内存"
SEC_SYSCTL="保护 Sysctl 设置"
SEC_ACCOUNTS="保护用户账户"
SEC_AUDITD="配置审计系统"
SEC_ROOTKIT="配置 Rootkit 检测"
SEC_INTRUSION="配置入侵检测"
SEC_ALL="应用所有安全增强"
SEC_INSTALLED="安全软件包安装成功"
SEC_FAIL2BAN_CONF="Fail2ban 配置成功"
SEC_UFW_CONF="UFW 防火墙配置成功"
SEC_SSH_HARDENED="SSH 配置已加固"
SEC_UPDATES_CONF="自动安全更新配置成功"
SEC_AUDIT_COMPLETE="安全审计完成。报告已保存至"
SEC_MEMORY_SECURED="共享内存保护成功"
SEC_SYSCTL_SECURED="Sysctl 设置保护成功"
SEC_ACCOUNTS_SECURED="用户账户安全配置成功"
SEC_AUDITD_CONF="审计系统配置成功"
SEC_ROOTKIT_CONF="Rootkit 检测配置成功"
SEC_INTRUSION_CONF="入侵检测配置成功"

# 语言设置
LANG_TITLE="语言设置"
LANG_SELECT="选择语言"
LANG_CURRENT="当前语言"
LANG_CHANGED="语言已更改为"
LANG_AVAILABLE="可用语言"
LANG_ADD="添加新语言"
LANG_EDIT="编辑语言文件"
LANG_DELETE="删除语言"
LANG_CONFIRM_DELETE="您确定要删除此语言吗？"
LANG_DEFAULT="设为默认"
LANG_DEFAULT_SET="默认语言设置为"
LANG_FILE_CREATED="语言文件创建成功"
LANG_FILE_UPDATED="语言文件更新成功"
LANG_FILE_DELETED="语言文件删除成功"
EOF
    
    log_message "${GREEN}Language files created successfully.${NC}"
}

# Function to get a string from the current language file
get_string() {
    local key=$1
    local lang_file="$LANG_DIR/$CURRENT_LANG.lang"
    
    # Check if language file exists
    if [ ! -f "$lang_file" ]; then
        lang_file="$LANG_DIR/$DEFAULT_LANG.lang"
    fi
    
    # Get string from language file
    local value=$(grep "^$key=" "$lang_file" | cut -d '"' -f 2)
    
    # If string not found, try default language
    if [ -z "$value" ] && [ "$CURRENT_LANG" != "$DEFAULT_LANG" ]; then
        value=$(grep "^$key=" "$LANG_DIR/$DEFAULT_LANG.lang" | cut -d '"' -f 2)
    fi
    
    # If still not found, return the key
    if [ -z "$value" ]; then
        echo "$key"
    else
        echo "$value"
    fi
}

# Function to list available languages
list_languages() {
    log_message "${YELLOW}$(get_string "LANG_AVAILABLE"):${NC}"
    
    echo -e "${CYAN}Code\tName${NC}"
    echo -e "${CYAN}----\t----${NC}"
    
    for lang_file in "$LANG_DIR"/*.lang; do
        if [ -f "$lang_file" ]; then
            local lang_code=$(basename "$lang_file" .lang)
            local lang_name=$(grep "^LANG_NAME=" "$lang_file" | cut -d '"' -f 2)
            
            if [ "$lang_code" == "$CURRENT_LANG" ]; then
                echo -e "${GREEN}$lang_code\t$lang_name ${YELLOW}($(get_string "LANG_CURRENT"))${NC}"
            else
                echo -e "$lang_code\t$lang_name"
            fi
        fi
    done
}

# Function to change language
change_language() {
    log_message "${YELLOW}$(get_string "LANG_SELECT"):${NC}"
    
    list_languages
    
    echo ""
    read -p "$(get_string "LANG_SELECT") ($(get_string "LANG_CODE")): " lang_code
    
    if [ -f "$LANG_DIR/$lang_code.lang" ]; then
        CURRENT_LANG="$lang_code"
        echo "$CURRENT_LANG" > "$CONFIG_DIR/language"
        log_message "${GREEN}$(get_string "LANG_CHANGED") $CURRENT_LANG ($(grep "^LANG_NAME=" "$LANG_DIR/$CURRENT_LANG.lang" | cut -d '"' -f 2))${NC}"
    else
        log_message "${RED}$(get_string "LANG_CODE") '$lang_code' $(get_string "ACCOUNT_NOT_FOUND")${NC}"
    fi
}

# Function to set default language
set_default_language() {
    log_message "${YELLOW}$(get_string "LANG_DEFAULT"):${NC}"
    
    list_languages
    
    echo ""
    read -p "$(get_string "LANG_SELECT") ($(get_string "LANG_CODE")): " lang_code
    
    if [ -f "$LANG_DIR/$lang_code.lang" ]; then
        DEFAULT_LANG="$lang_code"
        echo "$DEFAULT_LANG" > "$CONFIG_DIR/default_language"
        log_message "${GREEN}$(get_string "LANG_DEFAULT_SET") $DEFAULT_LANG ($(grep "^LANG_NAME=" "$LANG_DIR/$DEFAULT_LANG.lang" | cut -d '"' -f 2))${NC}"
    else
        log_message "${RED}$(get_string "LANG_CODE") '$lang_code' $(get_string "ACCOUNT_NOT_FOUND")${NC}"
    fi
}

# Function to add a new language
add_language() {
    log_message "${YELLOW}$(get_string "LANG_ADD"):${NC}"
    
    read -p "$(get_string "LANG_CODE"): " lang_code
    read -p "$(get_string "LANG_NAME"): " lang_name
    read -p "$(get_string "LANG_AUTHOR"): " lang_author
    
    if [ -f "$LANG_DIR/$lang_code.lang" ]; then
        log_message "${RED}$(get_string "LANG_CODE") '$lang_code' $(get_string "ACCOUNT_EXISTS")${NC}"
        return
    fi
    
    # Create new language file by copying English
    cp "$LANG_DIR/en.lang" "$LANG_DIR/$lang_code.lang"
    
    # Update language metadata
    sed -i "s/^LANG_NAME=.*/LANG_NAME=&quot;$lang_name&quot;/" "$LANG_DIR/$lang_code.lang"
    sed -i "s/^LANG_CODE=.*/LANG_CODE=&quot;$lang_code&quot;/" "$LANG_DIR/$lang_code.lang"
    sed -i "s/^LANG_AUTHOR=.*/LANG_AUTHOR=&quot;$lang_author&quot;/" "$LANG_DIR/$lang_code.lang"
    
    log_message "${GREEN}$(get_string "LANG_FILE_CREATED") ($lang_code)${NC}"
    log_message "${YELLOW}$(get_string "MSG_PRESS_ENTER") $(get_string "LANG_EDIT") $(get_string "LANG_FILE")${NC}"
}

# Function to edit a language file
edit_language() {
    log_message "${YELLOW}$(get_string "LANG_EDIT"):${NC}"
    
    list_languages
    
    echo ""
    read -p "$(get_string "LANG_SELECT") ($(get_string "LANG_CODE")): " lang_code
    
    if [ -f "$LANG_DIR/$lang_code.lang" ]; then
        # Check if nano is installed
        if ! command -v nano &> /dev/null; then
            apt-get update
            apt-get install -y nano
        fi
        
        nano "$LANG_DIR/$lang_code.lang"
        log_message "${GREEN}$(get_string "LANG_FILE_UPDATED") ($lang_code)${NC}"
    else
        log_message "${RED}$(get_string "LANG_CODE") '$lang_code' $(get_string "ACCOUNT_NOT_FOUND")${NC}"
    fi
}

# Function to delete a language
delete_language() {
    log_message "${YELLOW}$(get_string "LANG_DELETE"):${NC}"
    
    list_languages
    
    echo ""
    read -p "$(get_string "LANG_SELECT") ($(get_string "LANG_CODE")): " lang_code
    
    if [ -f "$LANG_DIR/$lang_code.lang" ]; then
        # Check if it's the current or default language
        if [ "$lang_code" == "$CURRENT_LANG" ] || [ "$lang_code" == "$DEFAULT_LANG" ]; then
            log_message "${RED}$(get_string "LANG_CANNOT_DELETE_CURRENT")${NC}"
            return
        fi
        
        read -p "$(get_string "LANG_CONFIRM_DELETE") (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            rm -f "$LANG_DIR/$lang_code.lang"
            log_message "${GREEN}$(get_string "LANG_FILE_DELETED") ($lang_code)${NC}"
        fi
    else
        log_message "${RED}$(get_string "LANG_CODE") '$lang_code' $(get_string "ACCOUNT_NOT_FOUND")${NC}"
    fi
}

# Function to display language menu
language_menu() {
    clear
    echo -e "${BLUE}${BOLD}=== $(get_string "LANG_TITLE") ===${NC}"
    echo -e "${CYAN}1.${NC} $(get_string "LANG_SELECT")"
    echo -e "${CYAN}2.${NC} $(get_string "LANG_DEFAULT")"
    echo -e "${CYAN}3.${NC} $(get_string "LANG_ADD")"
    echo -e "${CYAN}4.${NC} $(get_string "LANG_EDIT")"
    echo -e "${CYAN}5.${NC} $(get_string "LANG_DELETE")"
    echo -e "${CYAN}6.${NC} $(get_string "BTN_BACK")"
    echo -e "${CYAN}0.${NC} $(get_string "BTN_EXIT")"
    echo ""
    read -p "$(get_string "LANG_SELECT"): " option
    
    case $option in
        1)
            change_language
            echo ""
            read -p "$(get_string "MSG_PRESS_ENTER")"
            language_menu
            ;;
        2)
            set_default_language
            echo ""
            read -p "$(get_string "MSG_PRESS_ENTER")"
            language_menu
            ;;
        3)
            add_language
            echo ""
            read -p "$(get_string "MSG_PRESS_ENTER")"
            language_menu
            ;;
        4)
            edit_language
            echo ""
            read -p "$(get_string "MSG_PRESS_ENTER")"
            language_menu
            ;;
        5)
            delete_language
            echo ""
            read -p "$(get_string "MSG_PRESS_ENTER")"
            language_menu
            ;;
        6)
            # Return to main menu (handled by calling script)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}$(get_string "MSG_INVALID_OPTION")${NC}"
            sleep 2
            language_menu
            ;;
    esac
}

# Function to install language support
install_language_support() {
    # Create language directories
    mkdir -p $LANG_DIR
    
    # Create language files
    create_language_files
    
    # Set default language
    if [ ! -f "$CONFIG_DIR/default_language" ]; then
        echo "$DEFAULT_LANG" > "$CONFIG_DIR/default_language"
    else
        DEFAULT_LANG=$(cat "$CONFIG_DIR/default_language")
    fi
    
    # Set current language
    if [ ! -f "$CONFIG_DIR/language" ]; then
        echo "$DEFAULT_LANG" > "$CONFIG_DIR/language"
    else
        CURRENT_LANG=$(cat "$CONFIG_DIR/language")
    fi
    
    log_message "${GREEN}Language support installed successfully.${NC}"
    log_message "${GREEN}Current language: $CURRENT_LANG ($(grep "^LANG_NAME=" "$LANG_DIR/$CURRENT_LANG.lang" | cut -d '"' -f 2))${NC}"
}

# Main execution
case "$1" in
    install)
        install_language_support
        ;;
    list)
        list_languages
        ;;
    change)
        if [ -n "$2" ] && [ -f "$LANG_DIR/$2.lang" ]; then
            CURRENT_LANG="$2"
            echo "$CURRENT_LANG" > "$CONFIG_DIR/language"
            log_message "${GREEN}$(get_string "LANG_CHANGED") $CURRENT_LANG ($(grep "^LANG_NAME=" "$LANG_DIR/$CURRENT_LANG.lang" | cut -d '"' -f 2))${NC}"
        else
            change_language
        fi
        ;;
    default)
        if [ -n "$2" ] && [ -f "$LANG_DIR/$2.lang" ]; then
            DEFAULT_LANG="$2"
            echo "$DEFAULT_LANG" > "$CONFIG_DIR/default_language"
            log_message "${GREEN}$(get_string "LANG_DEFAULT_SET") $DEFAULT_LANG ($(grep "^LANG_NAME=" "$LANG_DIR/$DEFAULT_LANG.lang" | cut -d '"' -f 2))${NC}"
        else
            set_default_language
        fi
        ;;
    add)
        add_language
        ;;
    edit)
        if [ -n "$2" ] && [ -f "$LANG_DIR/$2.lang" ]; then
            nano "$LANG_DIR/$2.lang"
            log_message "${GREEN}$(get_string "LANG_FILE_UPDATED") ($2)${NC}"
        else
            edit_language
        fi
        ;;
    delete)
        if [ -n "$2" ] && [ -f "$LANG_DIR/$2.lang" ]; then
            if [ "$2" == "$CURRENT_LANG" ] || [ "$2" == "$DEFAULT_LANG" ]; then
                log_message "${RED}$(get_string "LANG_CANNOT_DELETE_CURRENT")${NC}"
            else
                rm -f "$LANG_DIR/$2.lang"
                log_message "${GREEN}$(get_string "LANG_FILE_DELETED") ($2)${NC}"
            fi
        else
            delete_language
        fi
        ;;
    get)
        if [ -n "$2" ]; then
            get_string "$2"
        else
            echo "Usage: $0 get <string_key>"
        fi
        ;;
    menu)
        language_menu
        ;;
    *)
        echo -e "${BLUE}${BOLD}Multi-Language Support for VPS Manager${NC}"
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0 install              - Install language support"
        echo -e "  $0 list                 - List available languages"
        echo -e "  $0 change [lang_code]   - Change current language"
        echo -e "  $0 default [lang_code]  - Set default language"
        echo -e "  $0 add                  - Add new language"
        echo -e "  $0 edit [lang_code]     - Edit language file"
        echo -e "  $0 delete [lang_code]   - Delete language"
        echo -e "  $0 get <string_key>     - Get string from current language"
        echo -e "  $0 menu                 - Show language menu"
        ;;
esac

exit 0
