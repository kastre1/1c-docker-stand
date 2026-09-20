# 📘 Шпаргалка проекта: 1С + PostgreSQL в Docker

**Прогресс:** Неделя 1, Дни 1-4 ✅  
**Обновлено:** 2026-09-19  
**Автор:** kastrel@kasrtrelsrv

---

## 1. Окружение стенда

| Компонент | Значение |
|---|---|
| Хост-ОС | Windows 10/11, IP `192.168.0.129` |
| Виртуалка | Ubuntu 26.04.1 LTS (resolute), ядро 7.0.0-31 |
| Сеть ВМ | «Сетевой мост», IP `192.168.0.173` |
| CPU / RAM / Disk | 4 ядра / 7.3 ГБ / 48 ГБ |
| Docker | 29.1.3 |
| Docker Compose | v2.40.3 (плагин, не `docker-compose`) |
| Проект | `~/projects/1c-server/` |
| Зеркало реестра | `mirror.gcr.io` (в `/etc/docker/daemon.json`) |

---

## 2. Подготовка системы (до Docker)

### 2.1. Создание виртуальной машины (VirtualBox)

| Параметр | Значение |
|---|---|
| Тип ОС | Linux / Ubuntu (64-bit) |
| RAM | ≥ 6 ГБ |
| CPU | ≥ 4 ядра |
| Диск | ≥ 50 ГБ, VDI, динамический |
| Сеть | **Сетевой мост (Bridged Adapter)** |
| Видеопамять | 128 МБ |

**Почему «Сетевой мост»:** ВМ получает IP в той же подсети, что и хост → из Windows можно обращаться к `192.168.0.173` как к обычному серверу. При режиме NAT пришлось бы настраивать проброс портов.

### 2.2. Установка Ubuntu

- Скачать **Ubuntu Server 24.04 LTS** или **Desktop** с https://ubuntu.com/download
- При установке:
  - Создать пользователя (например, `kastrel`)
  - **Поставить галочку «Install OpenSSH server»** — пригодится для Ansible (Неделя 4)
- После установки:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```

### 2.3. Установка Docker Engine

**Способ 1 — из репозитория Ubuntu (простой):**
```bash
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
```

**Способ 2 — официальный репозиторий Docker:**
```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2.4. Права пользователя

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run --rm hello-world
```

### 2.5. Зеркало реестра (обязательно в РФ)

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
docker info | grep -A 2 "Registry Mirrors"
```

### 2.6. Проверка ресурсов

```bash
free -h                # ≥ 6 ГБ RAM
df -h /                # ≥ 50 ГБ свободно
nproc                  # ≥ 4 ядра
ip -4 addr show        # IP в LAN (192.168.0.x)
```

### 2.7. Полезные утилиты

```bash
sudo apt install -y nano htop tree net-tools dnsutils curl git
```

### 2.8. Firewall

```bash
sudo ufw status
# Для продакшена: sudo ufw allow 5432/tcp
# Для учебного стенда в локальной сети — можно не настраивать
```

---

## 3. Структура проекта

```
~/projects/1c-server/
├── postgres/
│   ├── Dockerfile              # образ с локалью ru_RU.UTF-8
│   ├── docker-compose.yml      # сервис pg-1c
│   └── (Volume postgres_pg_data — создаётся Docker'ом)
├── 1c-server/                  # (пусто, Неделя 1 День 7)
├── frontol/                    # (пусто, Неделя 2)
├── utm/                        # (пусто, Неделя 3)
├── ansible/                    # (пусто, Неделя 4)
├── backup/                     # (пусто)
└── scripts/                    # (пусто)
```

---

## 4. Ключевые концепции Docker

| Понятие | Аналогия | Суть |
|---|---|---|
| **Image** | ISO-диск | Неизменяемый шаблон |
| **Container** | Запущенная ВМ | Живой процесс из образа |
| **Volume** | Внешний HDD | Данные **вне** контейнера |
| **Compose** | YAML-оркестратор | Описание набора контейнеров |
| **Dockerfile** | Рецепт сборки | «Базовый образ + слой доработки» |

**Главное правило:** контейнер можно убить и пересоздать за секунду — данные в Volume останутся.

---

## 5. Итоговый `docker-compose.yml`

```yaml
services:
  postgres:
    build: .
    container_name: pg-1c
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: "Str0ngP@ss"
      POSTGRES_USER: "postgres"
      POSTGRES_DB: "postgres"
      TZ: "Europe/Moscow"
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
```

## 6. Итоговый `Dockerfile`

```dockerfile
FROM postgres:15

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends locales \
 && sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8
```

**Почему:** базовый `postgres:15` не содержит локали `ru_RU.UTF-8`. Без неё PostgreSQL падает с `initdb: error: invalid locale settings`, а 1С отказывается создавать ИБ.

---

## 7. Шпаргалка команд Docker

### Управление контейнерами
```bash
docker ps                      # запущенные
docker ps -a                   # все
docker logs <container>        # логи
docker logs -f <container>     # логи в реальном времени
docker exec -it <container> bash
docker stop <container>
docker rm <container>
docker rm -f <container>
```

### Образы
```bash
docker images
docker pull <image>
docker rmi <image>
docker image inspect <image>
```

### Обслуживание
```bash
docker system df
docker system prune -a         # ОСТОРОЖНО
```

### Compose
```bash
docker compose up -d
docker compose up -d --build
docker compose down
docker compose down -v         # ⚠️ + удалить volume
docker compose ps
docker compose logs -f <svc>
docker compose restart <svc>
docker compose build
```

---

## 8. Работа с PostgreSQL внутри контейнера

```bash
docker exec -it pg-1c psql -U postgres
docker exec -it pg-1c psql -U postgres -c "SELECT version();"
docker exec -it pg-1c psql -U postgres -c "\l"
docker exec -it pg-1c psql -U postgres -t -c "SELECT datname FROM pg_database;"
docker exec -it pg-1c psql -U postgres -c "CREATE DATABASE icheck_bd;"
docker exec -it pg-1c locale
```

---

## 9. Проверка данных на хосте

```bash
sudo ls -la /var/lib/docker/volumes/ | grep pg_data
sudo du -sh /var/lib/docker/volumes/postgres_pg_data/_data
docker volume ls
```

**Важно:** файлы PostgreSQL лежат в `/var/lib/docker/volumes/postgres_pg_data/_data/`. Правильнее делать `pg_dump`, а не копировать «руками».

---

## 10. Решённые проблемы

### ❌ `unexpected media type text/html` при `docker pull`

**Симптом:** образ скачивается, но при распаковке ошибка с `text/html`. В `docker images` размер `0B`.

**Причина:** в `/var/lib/docker` попал битый слой — вместо tar HTML-заглушка.

**Решение:**
```bash
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker
docker pull postgres:15
```

**Профилактика:** зеркало `mirror.gcr.io` (см. п. 2.5).

**Признак битого образа:** `SIZE = 0B` — красный флаг.

### ❌ `initdb: error: invalid locale settings`

**Симптом:** PostgreSQL в цикле `Restarting (1)`.

**Причина:** образ `postgres:15` не содержит локали `ru_RU.UTF-8`.

**Решение:** собрать свой образ (см. п. 6).

---

## 11. Правила безопасности (на будущее)

1. `ports: "5432:5432"` открывает БД всей локальной сети. Для прода — `127.0.0.1:5432` + WireGuard.
2. Пароль `Str0ngP@ss` — учебный. В прода: 20+ символов, хранить в `.env`, не в git.
3. `/var/lib/docker` — не трогать руками.
4. `docker system prune -a` — использовать с умом.

---

## 12. Полезные ссылки

- Docker Compose reference: https://docs.docker.com/compose/compose-file/
- Официальный образ postgres: https://hub.docker.com/_/postgres
- PostgreSQL с патчами 1С: `postgresso/postgres-pro-1c:15`
- Зеркало Google: `mirror.gcr.io`

---

## 13. Следующие шаги

- [ ] Дни 5-7. DBeaver с Windows → `192.168.0.173:5432`
- [ ] Дни 5-7. Создание БД `unf_test`
- [ ] Дни 5-7. Лицензия 1С через X11 Forwarding
- [ ] Дни 5-7. Разворачивание пустой ИБ УНФ/УТ
- [ ] Неделя 2. Linux-касса + Frontol xPOS в Docker
