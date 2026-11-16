#!/usr/bin/env bash
# ============================================================
# CEICONTROL - ROTINAS DE BACKUP (Requisito 16)
#
# Uso:
#   ./backup_ceicontrol.sh full                  # 1. backup completo (estrutura + dados + rotinas)
#   ./backup_ceicontrol.sh estrutura             # 2. somente DDL, views, procedures, functions, triggers
#   ./backup_ceicontrol.sh dados                 # 3. somente dados (INSERTs)
#   ./backup_ceicontrol.sh criticas              # 4. só as tabelas com dados das crianças (parcial)
#   ./backup_ceicontrol.sh diferencial           # 5. registros lançados desde o último FULL (lógico)
#   ./backup_ceicontrol.sh incremental           # 6. binary logs desde o último backup (físico)
#   ./backup_ceicontrol.sh restaurar ARQ [BANCO] # 7. restaura um .sql.gz
#   ./backup_ceicontrol.sh verificar             # 8. restaura o último FULL num banco de teste e compara
#
# Conexão: usa as mesmas variáveis do config/database.php (Railway).
#   MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD, MYSQLDATABASE
# Agendamento sugerido (crontab -e):
#   0 23 * * 0     /caminho/backup_ceicontrol.sh full          # domingo 23h
#   0 23 * * 1-6   /caminho/backup_ceicontrol.sh diferencial   # seg-sáb 23h
#   0 * * * *      /caminho/backup_ceicontrol.sh incremental   # de hora em hora
# ============================================================
set -euo pipefail

DB_HOST="${MYSQLHOST:-localhost}"
DB_PORT="${MYSQLPORT:-3306}"
DB_USER="${MYSQLUSER:-root}"
DB_NAME="${MYSQLDATABASE:-ceicontrol}"
# a senha vai por variável de ambiente para não aparecer no "ps"
if [[ -n "${MYSQLPASSWORD:-}" ]]; then export MYSQL_PWD="$MYSQLPASSWORD"; fi

BACKUP_DIR="${BACKUP_DIR:-$(dirname "$0")/arquivos}"
RETENCAO_DIAS="${RETENCAO_DIAS:-30}"
DATA="$(date +%Y%m%d_%H%M%S)"
CONN=(--host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER")

# Opções comuns: snapshot consistente (InnoDB) sem travar as tabelas
DUMP_OPTS=(--single-transaction --quick --hex-blob --default-character-set=utf8mb4)

mkdir -p "$BACKUP_DIR"

# Se qualquer etapa falhar, apaga o arquivo incompleto (backup corrompido
# é pior que backup nenhum, pois dá falsa sensação de segurança)
ARQ=""; DEST=""
trap 'rc=$?; if [[ $rc -ne 0 ]]; then [[ -n "$ARQ" ]] && rm -f "$ARQ"; [[ -n "$DEST" ]] && rm -rf "$DEST"; echo "FALHA no backup (código $rc)" >&2; fi' EXIT

log() { echo "[$(date '+%F %T')] $*"; }

# Remove DEFINER=`usuario`@`host` para o dump restaurar em outro servidor/usuário
sem_definer() { sed -E 's/DEFINER=`[^`]+`@`[^`]+`//g'; }

finaliza() {
    local arq="$1"
    sha256sum "$arq" > "$arq.sha256"
    log "Gerado: $arq ($(du -h "$arq" | cut -f1))"
}

limpa_antigos() {
    find "$BACKUP_DIR" -name 'ceicontrol_*' -type f -mtime +"$RETENCAO_DIAS" -delete
}

case "${1:-}" in

  # 1. FULL - estrutura + dados + procedures/functions + triggers + events
  full)
    ARQ="$BACKUP_DIR/ceicontrol_full_$DATA.sql.gz"
    mysqldump "${CONN[@]}" "${DUMP_OPTS[@]}" --routines --triggers --events \
              "$DB_NAME" | sem_definer | gzip -9 > "$ARQ"
    date '+%F %T' > "$BACKUP_DIR/.ultimo_full"
    date '+%F %T' > "$BACKUP_DIR/.ultimo_backup"
    finaliza "$ARQ"
    limpa_antigos
    ;;

  # 2. ESTRUTURA - só o esquema (útil para versionar o modelo físico)
  estrutura)
    ARQ="$BACKUP_DIR/ceicontrol_estrutura_$DATA.sql.gz"
    mysqldump "${CONN[@]}" --no-data --routines --triggers --events \
              "$DB_NAME" | sem_definer | gzip -9 > "$ARQ"
    finaliza "$ARQ"
    ;;

  # 3. DADOS - só INSERTs, sem CREATE TABLE e sem triggers
  dados)
    ARQ="$BACKUP_DIR/ceicontrol_dados_$DATA.sql.gz"
    mysqldump "${CONN[@]}" "${DUMP_OPTS[@]}" --no-create-info --skip-triggers \
              --complete-insert "$DB_NAME" | gzip -9 > "$ARQ"
    finaliza "$ARQ"
    ;;

  # 4. PARCIAL - tabelas críticas com dados sensíveis das crianças (LGPD)
  criticas)
    ARQ="$BACKUP_DIR/ceicontrol_criticas_$DATA.sql.gz"
    mysqldump "${CONN[@]}" "${DUMP_OPTS[@]}" --skip-triggers "$DB_NAME" \
              criancas responsaveis crianca_responsavel matriculas \
              frequencias medicamentos_dispensas | gzip -9 > "$ARQ"
    finaliza "$ARQ"
    ;;

  # 5. DIFERENCIAL (lógico) - tudo que foi lançado desde o último FULL.
  #    Usa REPLACE para poder ser aplicado por cima do FULL sem duplicar.
  diferencial)
    [[ -f "$BACKUP_DIR/.ultimo_full" ]] || { echo "Execute um backup full primeiro." >&2; exit 1; }
    DESDE="$(cat "$BACKUP_DIR/.ultimo_full")"
    ARQ="$BACKUP_DIR/ceicontrol_diferencial_$DATA.sql.gz"
    {
      echo "-- Diferencial desde $DESDE"
      for T in "frequencias:data_aula" "movimentacoes_estoque:data_movimentacao" \
               "medicamentos_dispensas:data_hora" "mensagens:data_envio" \
               "matriculas:data_matricula" "auditoria:data_hora"; do
        TAB="${T%%:*}"; COL="${T##*:}"
        mysqldump "${CONN[@]}" "${DUMP_OPTS[@]}" --no-create-info --skip-triggers \
                  --replace --where="$COL >= '$DESDE'" "$DB_NAME" "$TAB"
      done
    } | gzip -9 > "$ARQ"
    date '+%F %T' > "$BACKUP_DIR/.ultimo_backup"
    finaliza "$ARQ"
    ;;

  # 6. INCREMENTAL (binary log) - fecha o binlog atual e copia os anteriores.
  #    Requer log_bin ativo e privilégios RELOAD + REPLICATION CLIENT/SLAVE.
  incremental)
    DEST="$BACKUP_DIR/binlog_$DATA"
    mkdir -p "$DEST"
    mysql "${CONN[@]}" -e "FLUSH BINARY LOGS"
    mapfile -t LOGS < <(mysql "${CONN[@]}" -N -e "SHOW BINARY LOGS" | awk '{print $1}' | head -n -1)
    [[ ${#LOGS[@]} -gt 0 ]] || { log "Nenhum binlog fechado para copiar."; rm -rf "$DEST"; DEST=""; exit 0; }
    mysqlbinlog "${CONN[@]}" --read-from-remote-server --raw \
                --result-file="$DEST/" "${LOGS[@]}"
    ARQ="$BACKUP_DIR/ceicontrol_incremental_$DATA.tar.gz"
    tar -czf "$ARQ" -C "$BACKUP_DIR" "binlog_$DATA"
    rm -rf "$DEST"; DEST=""
    date '+%F %T' > "$BACKUP_DIR/.ultimo_backup"
    finaliza "$ARQ"
    # Restauração: tar -xzf ARQ && mysqlbinlog binlog_*/* | mysql -u root -p
    ;;

  # 7. RESTAURAR um arquivo .sql.gz (opcionalmente em outro banco)
  restaurar)
    ORIGEM="${2:?Informe o arquivo .sql.gz}"
    DESTINO="${3:-$DB_NAME}"
    sha256sum -c "$ORIGEM.sha256" >/dev/null 2>&1 || log "Aviso: checksum não conferido."
    mysql "${CONN[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DESTINO\` CHARACTER SET utf8mb4"
    gunzip -c "$ORIGEM" | mysql "${CONN[@]}" "$DESTINO"
    log "Restaurado $ORIGEM em $DESTINO"
    ;;

  # 8. VERIFICAR - teste de restauração do último FULL (backup não testado não é backup)
  verificar)
    ULTIMO="$(ls -1t "$BACKUP_DIR"/ceicontrol_full_*.sql.gz | head -1)"
    TESTE="${DB_NAME}_verificacao"
    mysql "${CONN[@]}" -e "DROP DATABASE IF EXISTS \`$TESTE\`"
    "$0" restaurar "$ULTIMO" "$TESTE"
    CONSULTA="SELECT table_name FROM information_schema.tables
              WHERE table_schema = '%s' AND table_type = 'BASE TABLE' ORDER BY table_name"
    if diff <(mysql "${CONN[@]}" -N -e "$(printf "$CONSULTA" "$DB_NAME")") \
            <(mysql "${CONN[@]}" -N -e "$(printf "$CONSULTA" "$TESTE")") >/dev/null; then
        for T in usuarios criancas matriculas frequencias produtos; do
            A=$(mysql "${CONN[@]}" -N -e "SELECT COUNT(*) FROM \`$DB_NAME\`.$T")
            B=$(mysql "${CONN[@]}" -N -e "SELECT COUNT(*) FROM \`$TESTE\`.$T")
            log "$T: produção=$A backup=$B $([[ $A == "$B" ]] && echo OK || echo DIVERGENTE)"
        done
    else
        log "ERRO: as tabelas do backup não conferem com a produção."; exit 1
    fi
    mysql "${CONN[@]}" -e "DROP DATABASE \`$TESTE\`"
    ;;

  *)
    sed -n '4,13p' "$0"; exit 1 ;;
esac
