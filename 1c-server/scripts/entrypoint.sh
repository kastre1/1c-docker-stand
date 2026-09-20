#!/bin/bash
set -e

V8_VERSION="8.3.26.1540"
V8_BIN="/opt/1cv8/x86_64/${V8_VERSION}"
DATA_DIR="/home/usr1cv8"

echo "[entrypoint] === Сервер 1С:Предприятие ${V8_VERSION} ==="
echo "[entrypoint] Бинарники: ${V8_BIN}"
echo "[entrypoint] Данные:    ${DATA_DIR}"

# Гарантируем корректные права на каталоги данных
chown -R usr1cv8:grp1cv8 "${DATA_DIR}" 2>/dev/null || true

# Если передан ragent — запускаем его как сервер 1С
if [ "$1" = "ragent" ]; then
    echo "[entrypoint] Запуск ragent на портах 1540/1541/1560:1591..."
    exec gosu usr1cv8:grp1cv8 "${V8_BIN}/ragent" \
        -d "${DATA_DIR}/.1cv8" \
        -port 1540 \
        -regport 1541 \
        -range 1560:1591 \
        -debug
fi

# Иначе — выполняем переданную команду (например, bash для отладки)
echo "[entrypoint] Выполняем: $*"
exec gosu usr1cv8:grp1cv8 "$@"
