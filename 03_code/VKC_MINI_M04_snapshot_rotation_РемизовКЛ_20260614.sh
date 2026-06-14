#!/usr/bin/env bash

set -euo pipefail

BACKUP_PREFIX="backup-"
RETENTION_DAYS=7
LOG_FILE="./vm_backup.log"


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_openstack() {
    if ! command -v openstack &> /dev/null; then
        log "ОШИБКА: OpenStack CLI не найден. Установите python-openstackclient."
        exit 1
    fi
    if ! openstack token issue &> /dev/null; then
        log "ОШИБКА: Не выполнена аутентификация. Загрузите RC-файл (source ...-openrc.sh)."
        exit 1
    fi
}

get_root_volume_id() {
    local server_id="$1"
    local image_field
    image_field=$(openstack server show "$server_id" -f value -c image 2>/dev/null || echo "")
    if [[ "$image_field" != "N/A (booted from volume)" ]]; then
        echo ""
        return
    fi
    local volumes_json
    volumes_json=$(openstack server show "$server_id" -f json | jq -r '.volumes_attached // []')
    local volume_id
    volume_id=$(echo "$volumes_json" | jq -r '.[] | select(.["boot_index"]==0) | .id' | head -1)
    if [[ -z "$volume_id" ]]; then
        volume_id=$(echo "$volumes_json" | jq -r '.[0].id // empty')
    fi
    echo "$volume_id"
}

backup_server() {
    local server_id="$1"
    local server_name="$2"
    local backup_name="${BACKUP_PREFIX}${server_name}-$(date +%Y%m%d-%H%M%S)"

    local root_vol_id
    root_vol_id=$(get_root_volume_id "$server_id")

    if [[ -n "$root_vol_id" ]]; then
        log "✔ Сервер '$server_name' загружен с тома $root_vol_id. Создаём снапшот тома."
        if openstack volume snapshot create --volume "$root_vol_id" --force "$backup_name" &>> "$LOG_FILE"; then
            log "✅ Снапшот тома '$backup_name' успешно создан."
        else
            log "❌ ОШИБКА: Не удалось создать снапшот тома для '$server_name'."
        fi
    else
        log "⚠ Сервер '$server_name' использует эфемерный диск. Пробуем создать образ (snapshot)."
        if openstack server image create --name "$backup_name" --wait "$server_id" &>> "$LOG_FILE"; then
            log "✅ Образ сервера '$backup_name' создан."
        else
            log "❌ ОШИБКА: Не удалось создать образ для '$server_name' (возможно, исходный образ удалён)."
        fi
    fi
}

create_snapshots() {
    log "▶ Начало создания бэкапов для всех серверов..."
    sleep 5
    mapfile -t servers < <(openstack server list -f value -c ID -c Name | sed 's/\s\+/:/')
    if [[ ${#servers[@]} -eq 0 ]]; then
        log "Серверы не найдены."
        return
    fi

    for entry in "${servers[@]}"; do
        IFS=':' read -r server_id server_name <<< "$entry"
        [[ -z "$server_name" ]] && continue
        backup_server "$server_id" "$server_name"
    done
    log "▶ Создание бэкапов завершено."
}

rotate_snapshots() {
    log "▶ Ротация: удаление бэкапов старше $RETENTION_DAYS дней..."
    local cutoff_date
    cutoff_date=$(date -d "-$RETENTION_DAYS days" +%Y-%m-%dT%H:%M:%S)

    local images_json
    images_json=$(openstack image list --long -f json 2>/dev/null || echo "[]")
    if [[ -n "$images_json" ]]; then
        echo "$images_json" | jq -r --arg PREFIX "$BACKUP_PREFIX" \
            '.[] | select(.Name | startswith($PREFIX)) | "\(.ID):\(.Name):\(.CreatedAt)"' 2>/dev/null | while IFS=: read -r img_id img_name img_created; do
            if [[ "$img_created" < "$cutoff_date" ]]; then
                log "🗑 Удаление образа: $img_name (создан $img_created)"
                openstack image delete "$img_id" &>> "$LOG_FILE" && log "   Удалён" || log "   Ошибка удаления"
            fi
        done
    fi

    # 2. Снапшоты томов (volume snapshots)
    local snapshots_json
    snapshots_json=$(openstack volume snapshot list -f json 2>/dev/null || echo "[]")
    if [[ -n "$snapshots_json" ]]; then
        echo "$snapshots_json" | jq -r --arg PREFIX "$BACKUP_PREFIX" \
            '.[] | select(.Name | startswith($PREFIX)) | "\(.ID):\(.Name):\(.CreatedAt)"' 2>/dev/null | while IFS=: read -r snap_id snap_name snap_created; do
            if [[ "$snap_created" < "$cutoff_date" ]]; then
                log "🗑 Удаление снапшота тома: $snap_name (создан $snap_created)"
                openstack volume snapshot delete "$snap_id" &>> "$LOG_FILE" && log "   Удалён" || log "   Ошибка удаления"
            fi
        done
    fi

    log "▶ Ротация завершена."
}

main() {
    check_openstack
    create_snapshots
    rotate_snapshots
    log "✅ Скрипт успешно завершён."
}

main "$@"
