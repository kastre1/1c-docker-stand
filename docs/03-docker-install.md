# 03. Установка Docker и Docker Compose

**Навигация:** [← Предыдущий](02-vm-setup.md) | [Содержание](README.md) | [Следующий →](04-containers.md)

---

## 📌 О чём этот раздел

- Установка Docker Engine и Docker Compose в Ubuntu
- Настройка прав пользователя
- Настройка зеркала Docker Hub (важно для РФ!)
- Проверка работоспособности
- Решение проблемы с битыми образами

**Что должно получиться в конце:** работающий Docker с зеркалом, доступный без `sudo`.

---

## 🐳 Что такое Docker (короткая справка)

**Docker** — платформа для запуска приложений в **контейнерах** — изолированных окружениях, которые:
- Содержат всё нужное для работы приложения (библиотеки, зависимости)
- Изолированы друг от друга
- Легко переносятся между системами

**Ключевые сущности:**

| Термин | Аналогия | Что это |
|---|---|---|
| **Image** | ISO-диск | Неизменяемый «слепок» приложения |
| **Container** | Запущенная ВМ | Живой процесс из образа |
| **Volume** | Внешний HDD | Постоянное хранилище данных |
| **Compose** | Оркестратор | YAML-файл, описывающий набор контейнеров |

**Главное правило:** контейнер можно удалить и пересоздать за секунду — данные в Volume сохранятся.

---

## 📦 Шаг 1. Установка Docker Engine

Есть **два способа**: из репозитория Ubuntu или из официального репозитория Docker.

### Способ A. Из репозитория Ubuntu (проще)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
```

**Плюсы:** просто, быстро.
**Минусы:** версия может быть не самой свежей.

**В нашем проекте использован именно этот способ** — на Ubuntu 26.04 установлена версия `29.1.3`.

### Способ B. Из официального репозитория Docker (свежая версия)

```bash
# Удалить старые версии
sudo apt remove -y docker docker-engine docker.io containerd runc

# Установить зависимости
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Добавить GPG-ключ Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Добавить репозиторий
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Плюсы:** самая свежая версия.
**Минусы:** чуть сложнее.

### Проверка установки

```bash
docker --version
docker compose version
```

**Ожидаемо:**
```
Docker version 29.1.3, build 29.1.3-0ubuntu4.1
Docker Compose version 2.40.3+ds1-0ubuntu1
```

---

## 👤 Шаг 2. Права пользователя (без sudo)

**Проблема:** по умолчанию Docker требует `sudo` для каждой команды. Это неудобно и небезопасно.

**Решение:** добавить пользователя в группу `docker`.

```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Флаг `newgrp docker`** — обновляет группу в текущей сессии без перелогина.

**Проверка:**

```bash
groups $USER
```

**Ожидаемо:** в списке должна быть группа `docker`.

**Проверка без `sudo`:**

```bash
docker run --rm hello-world
```

**Ожидаемо:** сообщение «Hello from Docker!» без ошибок.

---

## 🌐 Шаг 3. Настройка зеркала Docker Hub

### 3.1. Зачем нужно зеркало

**Проблема в РФ:** `registry-1.docker.io` (Docker Hub) часто **отдаёт HTML-страницу-заглушку** вместо бинарных данных образа. Это выглядит как ошибка:

```
unexpected media type text/html for sha256:...
```

Docker пытается распаковать образ, но получает HTML — и падает.

**Решение:** использовать **зеркало**, которое стабильно работает в РФ. Например, `mirror.gcr.io` (от Google) или другие.

### 3.2. Настроить зеркало

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

**Содержимое:**

```json
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

**Применить:**

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**Проверить:**

```bash
docker info | grep -A 2 "Registry Mirrors"
```

**Ожидаемо:**
```
 Registry Mirrors:
  https://mirror.gcr.io/
```

### 3.3. Дополнительные зеркала (на случай сбоев)

Если `mirror.gcr.io` иногда недоступно, можно добавить **несколько зеркал** — Docker будет пробовать по очереди:

```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
```

⚠️ **Внимание:** не все зеркала стабильны. Если попадётся «битое» — оно может отдавать мусор в кэш.

---

## 🧪 Шаг 4. Проверка работоспособности

### 4.1. Простой тест

```bash
docker run --rm alpine echo "Hello from Alpine"
```

**Ожидаемо:** `Hello from Alpine`.

### 4.2. Скачать образ PostgreSQL

```bash
docker pull postgres:15
docker images | grep postgres
```

**Ожидаемо:** `postgres:15` в списке, размер **~400 МБ**.

⚠️ **Если размер `0B`** — образ битый, см. следующий раздел.

### 4.3. Запустить контейнер

```bash
docker run --rm -d --name pg-test \
  -e POSTGRES_PASSWORD=test \
  postgres:15
sleep 10
docker ps
docker exec -it pg-test psql -U postgres -c "SELECT version();"
docker stop pg-test
```

**Ожидаемо:** PostgreSQL запустился, версия 15.x, контейнер корректно остановлен.

---

## 🚨 Шаг 5. Решение проблемы с битыми образами

Если вы получили ошибку **`unexpected media type text/html`** при `docker pull` — это означает, что в локальный кэш попал **битый слой** (HTML-заглушка вместо данных образа).

**Признак:** в `docker images` размер образа — `0B`.

### Решение — полная очистка кэша

```bash
# 1. Остановить Docker
sudo systemctl stop docker

# 2. Удалить весь кэш
sudo rm -rf /var/lib/docker

# 3. Запустить Docker
sudo systemctl start docker

# 4. Повторить pull
docker pull postgres:15
docker images | grep postgres
```

**Ожидаемо:** размер образа **~400 МБ**, а не `0B`.

### Профилактика

Настройка зеркала (Шаг 3) **снижает** вероятность битых образов, но не исключает полностью.

**Правило:** если `docker images` показывает `0B` в колонке `SIZE` — образ битый, надо чистить кэш.

---

## 📁 Шаг 6. Полезные команды Docker

### Управление контейнерами

```bash
docker ps                      # запущенные
docker ps -a                   # все, включая остановленные
docker logs <container>        # логи
docker logs -f <container>     # логи в реальном времени
docker exec -it <container> bash  # зайти внутрь
docker stop <container>        # остановить
docker rm <container>          # удалить
docker rm -f <container>       # удалить принудительно
```

### Управление образами

```bash
docker images                  # список образов
docker pull <image>            # скачать
docker rmi <image>             # удалить
docker image inspect <image>   # детали
docker image prune -a          # удалить неиспользуемые
```

### Обслуживание

```bash
docker system df               # сколько места занимает
docker system df -v            # детально
docker system prune -a         # ⚠️ удалить всё неиспользуемое
docker builder prune -f        # очистить кэш сборки
```

### Docker Compose

```bash
docker compose up -d           # поднять в фоне
docker compose up -d --build   # пересобрать и поднять
docker compose down            # остановить и удалить контейнеры (volumes сохраняются)
docker compose down -v         # ⚠️ + удалить volumes (ДАННЫЕ!)
docker compose ps              # статус
docker compose logs -f <svc>   # логи сервиса
docker compose restart <svc>   # перезапуск сервиса
docker compose build           # только сборка
```

---

## 📋 Что должно быть готово

- [x] Docker Engine установлен (версия 24+)
- [x] Docker Compose установлен (версия 2+)
- [x] Пользователь в группе `docker` (без `sudo`)
- [x] Настроено зеркало `mirror.gcr.io` в `/etc/docker/daemon.json`
- [x] Проверка `docker run --rm hello-world` работает
- [x] Проверка `docker pull postgres:15` — размер ~400 МБ (не `0B`)

---

## ⚠️ Возможные проблемы

| Проблема | Решение |
|---|---|
| `permission denied` при `docker ps` | `sudo usermod -aG docker $USER && newgrp docker` |
| `Cannot connect to the Docker daemon` | `sudo systemctl start docker` |
| Образ весит `0B` | Полная очистка `/var/lib/docker` (см. Шаг 5) |
| `docker pull` медленный | Проверить зеркало в `/etc/docker/daemon.json` |
| `docker compose` не найден | Установить `docker-compose-v2` или `docker-compose-plugin` |

**Все проблемы** — в [приложении Troubleshooting](appendix/troubleshooting.md).

---

## 🗺️ Что дальше

Следующий раздел — [**04. Развёртывание контейнеров**](04-containers.md).

Там мы:
1. Соберём образ PostgreSQL 1С-сборки
2. Соберём образ сервера 1С
3. Создадим `docker-compose.yml`
4. Запустим и проверим

Это **самый большой раздел** — сердце проекта.

---

**Навигация:** [← Предыдущий](02-vm-setup.md) | [Содержание](README.md) | [Следующий →](04-containers.md)
