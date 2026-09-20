# 04. Развёртывание контейнеров

**Навигация:** [← Предыдущий](03-docker-install.md) | [Содержание](README.md) | [Следующий →](05-x11-forwarding.md)

---

## 📌 О чём этот раздел

**Самый большой раздел документации.** Здесь описано:
- Устройство PostgreSQL 1С-сборки и её `Dockerfile` (построчно)
- Устройство сервера 1С и его `Dockerfile` (построчно)
- Разбор `entrypoint.sh`
- Разбор главного `docker-compose.yml`
- Запуск и проверка всей системы

**Что должно получиться:** работающие контейнеры `pg-1c` и `1c-server`, готовые к созданию ИБ.

---

## 🏗️ Общая картина

Мы собираем **два кастомных образа**:

1. **`1c-server-postgres`** — PostgreSQL 15.17-1.1C на базе `ubuntu:24.04`
2. **`1c-server-1c-server`** — Сервер 1С 8.3.26.1540 на базе `ubuntu:24.04`

**Почему кастомные, а не готовые из Docker Hub:**
- **PostgreSQL** — нужны **расширения 1С** (`mchar`, `fasttrun`), которых нет в ванильном образе
- **1С-сервер** — нужен **официальный дистрибутив** с `releases.1c.ru`, а также **сертификаты Минцифры** для лицензирования

Оба образа собираются **из официальных дистрибутивов** — не community-поделок.

---

## 🐘 Часть 1. PostgreSQL 15.17-1.1C

### 1.1. Зачем нужна 1С-сборка

Ванильный `postgres:15` из Docker Hub **НЕ содержит** расширений, которые требует 1С:

| Расширение | Зачем нужно |
|---|---|
| **`mchar`** | Хранение строк переменной длины в формате 1С |
| **`fasttrun`** | Быстрый TRUNCATE больших таблиц |

Без них 1С **отказывается создавать ИБ** с ошибкой:
```
0A000: расширение "mchar" отсутствует
```

Поэтому мы берём **официальную сборку** с `releases.1c.ru`.

### 1.2. Структура папки `postgres/`

```
postgres/
├── Dockerfile              # ← разберём ниже
├── .dockerignore           # Что не копировать в образ
├── distr/                  # Исходные архивы + все .deb
│   ├── *.tar.bz2
│   └── *.deb
└── distr-min/              # Только 5 нужных .deb
    ├── postgresql-15_15.17-1.1C_amd64.deb
    ├── postgresql-client-15_15.17-1.1C_amd64.deb
    ├── libpq5_15.17-1.1C_amd64.deb
    ├── postgresql-common_290.pgdg24.04+1_all.deb
    └── postgresql-client-common_290.pgdg24.04+1_all.deb
```

### 1.3. `Dockerfile` — построчный разбор

```dockerfile
# ============================================================
# PostgreSQL 15.17-1.1C (сборка 1С) на базе Ubuntu 24.04
# ============================================================
FROM postgres:15 AS official

FROM ubuntu:24.04

USER root
```

**Что здесь:**
- **Multi-stage build:** первая строка `FROM postgres:15 AS official` — это **промежуточный этап**, из которого мы возьмём `docker-entrypoint.sh`. Второй `FROM ubuntu:24.04` — **основной образ**.
- **Почему не оставляем `postgres:15` основным:** он на базе Debian, а `.deb`-пакеты 1С собраны под **Ubuntu 24.04** (разные версии `libicu`, `libssl`). Смешивать нельзя.
- **`USER root`:** нужен, чтобы ставить `.deb`-пакеты.

```dockerfile
# Зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales libicu74 libssl3 libxml2 libreadline8 \
    libzstd1 liblz4-1 zlib1g tzdata ca-certificates gnupg gosu \
 && rm -rf /var/lib/apt/lists/*
```

**Что здесь:**
- **`libicu74`** — ICU-библиотека, нужна 1С-сборке PostgreSQL
- **`gosu`** — утилита для запуска процессов от имени других пользователей (нужна будет в 1С-сервере)
- **`ca-certificates`** — системное хранилище сертификатов
- **`rm -rf /var/lib/apt/lists/*`** — чистка apt-кэша, уменьшает размер образа

```dockerfile
# .deb 1С
COPY distr-min/*.deb /tmp/debs/
RUN dpkg -i --force-overwrite /tmp/debs/*.deb || true \
 && apt-get update \
 && apt-get install -f -y --no-install-recommends \
 && rm -rf /tmp/debs /var/lib/apt/lists/*
```

**Что здесь:**
- **`COPY distr-min/*.deb`** — копируем только **5 нужных** `.deb` (не все 23)
- **`dpkg -i --force-overwrite`** — устанавливаем `.deb`. Флаг `--force-overwrite` нужен, потому что `.deb` 1С ставят **те же файлы**, что уже есть в образе — иначе dpkg ругнётся
- **`|| true`** — игнорируем возможные ошибки зависимостей (мы их доустановим)
- **`apt-get install -f -y`** — «доставить» недостающие зависимости
- **`rm -rf /tmp/debs`** — удаляем `.deb` из образа (не нужны после установки)

```dockerfile
# Удаляем кластер, созданный .deb-пакетом — entrypoint создаст свой
RUN rm -rf /var/lib/postgresql/15
```

**Что здесь — и это ключевой момент:**
- **`.deb`-пакет 1С при установке запускает `initdb`** и создаёт кластер в `/var/lib/postgresql/15/main` (Debian-style)
- **`docker-entrypoint.sh`** ожидает кластер в `$PGDATA` = `/var/lib/postgresql/data` (Docker-style)
- **Конфликт:** если оставить оба, `entrypoint` не поймёт, что делать
- **Решение:** удаляем кластер от `.deb`, оставляем только тот, что создаст `entrypoint`

```dockerfile
# Локаль
RUN sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8
```

**Что здесь:**
- **Раскомментируем** нужные локали в `/etc/locale.gen`
- **`locale-gen`** — генерирует локали
- **`ENV`** — задаёт локаль на уровне образа, чтобы `postgres` стартовал с правильными настройками

**Почему это важно:** без `ru_RU.UTF-8` PostgreSQL создаст кластер с `C.UTF-8`, и 1С откажется с ним работать.

```dockerfile
# entrypoint из официального postgres:15
COPY --from=official /usr/local/bin/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
```

**Что здесь:**
- **`COPY --from=official`** — берём `docker-entrypoint.sh` из **первой стадии** (`postgres:15`)
- Это **готовый** скрипт, который:
  - Проверяет `$PGDATA`
  - Запускает `initdb`, если кластера нет
  - Обрабатывает `/docker-entrypoint-initdb.d/*.sql`
  - Запускает `postgres` от имени `postgres`

**Почему не написали свой:** этот скрипт **надёжный**, проверен миллионами пользователей Docker. Писать свой — изобретать велосипед.

```dockerfile
# Каталог для init-скриптов
RUN mkdir -p /docker-entrypoint-initdb.d
```

**Что здесь:**
- **`docker-entrypoint.sh` ожидает** этот каталог
- Если его нет — скрипт падает с `ls: cannot access '/docker-entrypoint-initdb.d/'`
- Создаём пустым (пока туда ничего не кладём)

```dockerfile
# Каталоги PostgreSQL
RUN mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/postgresql/data \
 && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d \
 && chmod 2775 /var/run/postgresql
```

**Что здесь:**
- Создаём каталоги для данных и сокета
- **`chown postgres:postgres`** — пользователь `postgres` создан `.deb`-пакетом, даём ему права
- **`chmod 2775`** — стандартные права для `/var/run/postgresql`

```dockerfile
# ⚠️ ГЛАВНОЕ: бинарники 1С в PATH
ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"

ENV PGDATA=/var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

EXPOSE 5432
ENTRYPOINT ["docker-entrypoint.sh"]
STOPSIGNAL SIGINT
CMD ["postgres"]
```

**Что здесь — ещё один критичный момент:**
- **`PATH`:** `.deb` 1С ставит бинарники в `/usr/lib/postgresql/15/bin/`, а не в `/usr/local/bin/`. Без добавления в `PATH` `docker-entrypoint.sh` не найдёт `initdb` и упадёт с `command not found`
- **`PGDATA`:** путь к каталогу данных — `/var/lib/postgresql/data`. Именно сюда монтируется volume `pg_data`
- **`VOLUME`:** объявляем точку монтирования
- **`EXPOSE 5432`:** документируем порт
- **`STOPSIGNAL SIGINT`:** сигнал для корректного завершения

### 1.4. `command` в `docker-compose.yml`

В основном `docker-compose.yml` для сервиса `postgres` есть **важная строка**:

```yaml
command: ["postgres", "-c", "listen_addresses=*"]
```

**Что это делает:** заставляет PostgreSQL слушать **все интерфейсы** (`0.0.0.0`), а не только `localhost`.

**Почему это критично:**
- По умолчанию `.deb`-пакет 1С создаёт конфиг с `listen_addresses='localhost'`
- Тогда PostgreSQL **не виден снаружи контейнера**
- Ошибка при попытке подключиться из 1С: `Connection refused`
- **Решение:** переопределить через `-c listen_addresses=*`

**Проверка в логах:**

```bash
docker compose logs postgres | grep listening
```

**Ожидаемо:**
```
listening on IPv4 address "0.0.0.0", port 5432
listening on IPv6 address "::", port 5432
```

⚠️ Если увидите `listening on IPv4 address "127.0.0.1"` — `command` не применился, PostgreSQL слушает только localhost.

### 1.5. Проверка PostgreSQL после запуска

```bash
# Версия — должна быть 15.17-1.1C (1С-сборка!)
docker exec -it pg-1c psql -U postgres -c "SELECT version();"

# Расширения 1С
docker exec -it pg-1c psql -U postgres -c "SELECT name FROM pg_available_extensions WHERE name IN ('mchar', 'fasttrun');"

# Локаль
docker exec -it pg-1c psql -U postgres -c "\l"
```

**Ожидаемо:**

| Что проверяем | Результат |
|---|---|
| Версия | `PostgreSQL 15.17 (Ubuntu 15.17-1.1C) ...` |
| Расширения | `mchar`, `fasttrun` |
| Локали БД | `ru_RU.UTF-8` |

---

## 🏢 Часть 2. Сервер 1С 8.3.26.1540

### 2.1. Компоненты 1С

Сервер 1С — это **кластер**, состоящий из нескольких процессов:

| Компонент | Порт | Что делает |
|---|---|---|
| **`ragent`** | 1540 | Центральный агент, принимает подключения |
| **`rmngr`** | 1541 | Менеджер кластера, управляет ИБ и сеансами |
| **`rphost`** | 1560-1591 | Рабочие процессы, выполняют код 1С |
| **Search server** | — | Сервер поиска (новый в 8.3.26) |

**Ключевое:** сервер работает **headless** — без графики. Для GUI (активация лицензии, создание ИБ) подключаем X11 отдельно.

### 2.2. Структура папки `1c-server/`

```
1c-server/
├── Dockerfile              # ← разберём ниже
├── .dockerignore
├── scripts/
│   └── entrypoint.sh       # Точка входа контейнера
├── conf/                   # Монтируется в /opt/1cv8/conf
│   └── *.lic               # Сюда попадёт лицензия
└── distr/
    └── setup-full-8.3.26.1540-x86_64.run
```

### 2.3. `Dockerfile` — построчный разбор

```dockerfile
FROM ubuntu:24.04

LABEL maintainer="kastrel" \
      description="1C:Enterprise Server 8.3.26.1540 on Ubuntu 24.04" \
      version="1.0"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8 \
    TZ=Europe/Moscow
```

**Что здесь:**
- Базовый образ — `ubuntu:24.04` (LTS, стабильная)
- **`DEBIAN_FRONTEND=noninteractive`** — чтобы `apt` не задавал вопросы при установке
- Локаль `ru_RU.UTF-8` — критично для 1С
- `TZ=Europe/Moscow` — часовой пояс

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    fontconfig \
    libfreetype6 \
    libgsf-1-114 \
    libglib2.0-0 \
    libodbc2 \
    libkrb5-3 \
    libgssapi-krb5-2 \
    libenchant-2-2 \
    liblcms2-2 \
    libwebkit2gtk-4.1-0 \
    libgtk-3-0 \
    gosu \
    curl \
    wget \
    iproute2 \
    unixodbc \
    ghostscript \
    imagemagick \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*
```

**Что здесь — самое важное про зависимости:**

| Пакет | Зачем |
|---|---|
| `locales`, `fontconfig` | Локали, шрифты |
| `libfreetype6` | Работа со шрифтами (для отчётов) |
| `libgsf-1-114` | Чтение ODF-документов |
| `libglib2.0-0` | Базовая библиотека GLib |
| `libodbc2` | ODBC (внешние источники данных) |
| `libkrb5-3`, `libgssapi-krb5-2` | Kerberos-аутентификация |
| `libenchant-2-2` | Проверка орфографии |
| `liblcms2-2` | Управление цветом (для PDF) |
| `libwebkit2gtk-4.1-0` | **Критично:** движок WebKit для встроенного браузера 1С |
| `libgtk-3-0` | GUI-библиотека (нужна для `1cv8s`) |
| `gosu` | Запуск процессов от `usr1cv8` |
| `curl`, `wget` | Скачивание сертификатов |
| **`iproute2`** | **Критично:** даёт `/sbin/ip`, без которого 1С падает при старте |
| `unixodbc` | Драйверы ODBC |
| `ghostscript`, `imagemagick` | PDF/диаграммы |

**Особый акцент: `iproute2`.** Без него платформа 1С при запуске `1cv8s` падает с `/bin/sh: /sbin/ip: not found`. Это неочевидная зависимость, но она критична.

```dockerfile
RUN sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
```

Генерация локалей — стандартный шаг.

```dockerfile
# --- Установка сертификатов Минцифры для Центра Лицензирования ---
RUN curl -o /usr/local/share/ca-certificates/russian_trusted_root_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_root_ca_pem.crt \
 && curl -o /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_sub_ca_pem.crt \
 && update-ca-certificates
```

**Что здесь — критичный для лицензирования шаг:**
- Центр Лицензирования 1С (`users.v8.1c.ru`) работает по HTTPS с **сертификатами Минцифры**
- Без них 1С не может проверить подлинность сервера → ошибка **«Хранилище сертификатов Linux не обнаружено»**
- Скачиваем **два сертификата** (корневой и промежуточный)
- **`update-ca-certificates`** добавляет их в **системное хранилище** `/etc/ssl/certs/ca-certificates.crt`

**Важно:** этот шаг идёт **после** установки `ca-certificates` — иначе `update-ca-certificates` не найдёт хранилище.

```dockerfile
# --- Копирование и установка сервера 1С ---
COPY distr/setup-full-8.3.26.1540-x86_64.run /tmp/1c-installer.run

RUN chmod +x /tmp/1c-installer.run \
 && /tmp/1c-installer.run \
      --mode unattended \
      --unattendedmodeui none \
      --enable-components server,server_admin,ws,client_full,liberica_jre,ru \
 && rm -f /tmp/1c-installer.run
```

**Что здесь — установка 1С в headless-режиме:**

| Параметр | Что делает |
|---|---|
| `--mode unattended` | Без GUI |
| `--unattendedmodeui none` | Никаких диалогов вообще |
| `--enable-components` | Список компонентов |

**Разбор компонентов:**

| Компонент | Что ставит |
|---|---|
| `server` | Сам сервер (`ragent`, `rmngr`, `rphost`) |
| `server_admin` | Утилиты администрирования (`ras`, `rac`) |
| `ws` | Модули расширения веб-сервера |
| **`client_full`** | **Толстый клиент + Конфигуратор** — нужен для GUI-операций |
| `liberica_jre` | Java (для лицензирования) |
| `ru` | Русский язык интерфейса |

**Что НЕ ставим** (важно понимать):
- `v8_install_deps` — установка зависимостей от 1С (мы их сами ставим через `apt`, контролируем)
- `client_thin` — тонкий клиент (нам не нужен в контейнере)
- `client_thin_fib` — файловый вариант тонкого клиента
- `desktop_icons` — ярлыки рабочего стола (нет GUI)
- `config_storage_server` — хранилище конфигураций (не для стенда)
- `integrity_monitoring` — мониторинг целостности
- `libenchant` и прочее

```dockerfile
# --- Создание пользователя и группы для сервера 1С ---
RUN usermod -d /home/usr1cv8 -m -s /bin/bash usr1cv8 || true
```

**Что здесь:**
- Установщик 1С **сам создаёт** пользователя `usr1cv8` и группу `grp1cv8`
- Эта команда — **на всякий случай**: если пользователь уже есть, `|| true` не даст упасть сборке
- `-d /home/usr1cv8 -m` — домашний каталог
- `-s /bin/bash` — шелл

```dockerfile
# --- Каталоги для данных и конфигурации ---
RUN mkdir -p /home/usr1cv8/.1cv8/1C/1cv8/conf \
             /home/usr1cv8/.1cv8/1C/1cv8/logs \
             /home/usr1cv8/.1cv8/1C/1cv8/tmp \
             /opt/1cv8/conf \
 && chown -R usr1cv8:grp1cv8 /home/usr1cv8 /opt/1cv8/conf
```

**Что здесь:**
- Создаём каталоги для конфигурации, логов, временных файлов
- **`/opt/1cv8/conf`** — глобальный каталог лицензий (сюда будем класть `.lic`)
- **`chown usr1cv8:grp1cv8`** — владелец — серверный пользователь

```dockerfile
# --- Точка входа ---
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1540 1541 1560-1591

WORKDIR /home/usr1cv8
ENTRYPOINT ["/entrypoint.sh"]
CMD ["ragent"]
```

**Что здесь:**
- Копируем `entrypoint.sh`
- Объявляем порты: `1540` (`ragent`), `1541` (`rmngr`), диапазон `1560-1591` (`rphost`)
- **`ENTRYPOINT`** — запускается всегда
- **`CMD ["ragent"]`** — аргумент по умолчанию, можно переопределить (`docker compose run ... bash`)

### 2.4. `entrypoint.sh` — разбор

```bash
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
```

**Что здесь:**
- **`set -e`** — выход при первой ошибке
- **Переменные** — пути к бинарникам и данным
- **`chown`** — при старте контейнера том `1c_data` монтируется **от root**, и надо вернуть права `usr1cv8`
- **`2>/dev/null || true`** — если `chown` не удался (например, нет прав), не падаем

```bash
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
```

**Что здесь — ключевая логика:**

| Параметр `ragent` | Что делает |
|---|---|
| `-d /home/usr1cv8/.1cv8` | Каталог данных сервера |
| `-port 1540` | Порт агента |
| `-regport 1541` | Порт менеджера кластера |
| `-range 1560:1591` | Диапазон портов рабочих процессов |
| `-debug` | Отладочный вывод (для стенда удобно) |

**Логика:**
- **Если передан `ragent`** — запускаем сервер (по умолчанию из `CMD`)
- **Иначе** — выполняем команду (например, `docker compose run ... bash` для отладки)

**`exec gosu usr1cv8:grp1cv8`** — критично:
- Контейнер запускается от `root`
- `ragent` **не должен** работать от root
- `gosu` переключает пользователя и запускает процесс
- **`exec`** — заменяет процесс bash на `ragent`, чтобы сигналы (`SIGTERM`) доходили напрямую

---

## 🐳 Часть 3. `docker-compose.yml` — разбор

### 3.1. Полный файл

```yaml
services:
  postgres:
    build:
      context: ./postgres
      dockerfile: Dockerfile
    container_name: pg-1c
    restart: unless-stopped
    command: ["postgres", "-c", "listen_addresses=*"]
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
    networks:
      - 1c-net

  1c-server:
    build:
      context: ./1c-server
      dockerfile: Dockerfile
    container_name: 1c-server
    restart: unless-stopped
    environment:
      TZ: "Europe/Moscow"
    ports:
      - "1540:1540"
      - "1541:1541"
      - "1560-1591:1560-1591"
    volumes:
      - 1c_data:/home/usr1cv8
      - 1c_logs:/home/usr1cv8/.1cv8/1C/1cv8/logs
      - ./1c-server/conf:/opt/1cv8/conf
    networks:
      - 1c-net
    depends_on:
      postgres:
        condition: service_healthy

networks:
  1c-net:
    driver: bridge

volumes:
  pg_data:
  1c_data:
  1c_logs:
```

### 3.2. Разбор ключевых параметров

**`restart: unless-stopped`** — контейнер автоматически поднимается после перезагрузки хоста, **кроме** случая, когда его остановили вручную (`docker compose stop`).

**`command`** (только для postgres) — переопределяет `CMD` из `Dockerfile`. Заставляет PostgreSQL слушать все интерфейсы.

**`environment`** — переменные окружения. Для postgres — стандартные `POSTGRES_*`.

**`ports: "ХОСТ:КОНТЕЙНЕР"`** — проброс портов:
- `"5432:5432"` — PostgreSQL доступен на хосте по порту 5432
- `"1540:1540"` — `ragent`
- `"1560-1591:1560-1591"` — диапазон для `rphost`

**`volumes`** — постоянные хранилища:

| Volume | Монтируется в | Что хранит |
|---|---|---|
| `pg_data` | `/var/lib/postgresql/data` | Все БД PostgreSQL |
| `1c_data` | `/home/usr1cv8` | Данные сервера 1С (кластер, snccntx) |
| `1c_logs` | `/home/usr1cv8/.1cv8/1C/1cv8/logs` | Технологические логи |
| `./1c-server/conf` | `/opt/1cv8/conf` | Лицензии (bind-mount) |

**Bind-mount `./1c-server/conf:/opt/1cv8/conf`** — каталог хоста монтируется в контейнер. Это нужно, чтобы лицензия **сохранялась** между пересозданиями контейнера и была доступна из хостовой системы.

**`healthcheck`** — Docker сам проверяет, что PostgreSQL готов принимать подключения. Полезно, потому что `1c-server` запускается **только после** `healthy`.

**`depends_on: condition: service_healthy`** — гарантирует порядок запуска.

**`networks: 1c-net`** — оба контейнера в одной **bridge-сети**. Это значит:
- Контейнеры **видят друг друга по именам** (`pg-1c`, `1c-server`)
- 1С-сервер может подключаться к PostgreSQL по имени `pg-1c:5432`

---

## 🚀 Часть 4. Сборка и запуск

### 4.1. Сборка образов

```bash
cd ~/projects/1c-server
docker compose build
```

**Ожидаемое время:**
- `postgres`: 3-5 минут
- `1c-server`: 5-10 минут (установка 1С большая)

**При проблемах — сборка с нуля:**

```bash
docker compose build --no-cache
```

### 4.2. Запуск

```bash
docker compose up -d
sleep 20
docker compose ps
```

**Ожидаемо:**

```
NAME        STATUS
pg-1c       Up (healthy)
1c-server   Up
```

### 4.3. Проверка логов

```bash
docker compose logs postgres --tail=20
docker compose logs 1c-server --tail=20
```

**Ожидаемо (postgres):**
```
database system is ready to accept connections
listening on IPv4 address "0.0.0.0", port 5432
```

**Ожидаемо (1c-server):**
```
[entrypoint] === Сервер 1С:Предприятие 8.3.26.1540 ===
[entrypoint] Запуск ragent на портах 1540/1541/1560:1591...
1C:Enterprise 8.3 (x86-64) (8.3.26.1540) Server Agent (debug) started.
1C:Enterprise 8.3 (x86-64) (8.3.26.1540) Search server (debug) started.
```

### 4.4. Проверка процессов 1С

```bash
docker exec -it 1c-server ps aux | grep -E "ragent|rmngr|rphost" | grep -v grep
```

**Ожидаемо:** три процесса.

```bash
docker exec -it 1c-server bash -c 'IP=$(hostname -i); (echo > /dev/tcp/$IP/1540) 2>/dev/null && echo "1540 OPEN" || echo "1540 CLOSED"; (echo > /dev/tcp/$IP/1541) 2>/dev/null && echo "1541 OPEN" || echo "1541 CLOSED"'
```

**Ожидаемо:** оба порта `OPEN`.

### 4.5. Проверка PostgreSQL

```bash
docker exec -it pg-1c psql -U postgres -c "SELECT version();"
docker exec -it pg-1c psql -U postgres -c "\l"
```

**Ожидаемо:**
- Версия `15.17-1.1C`
- Список БД: `postgres`, `template0`, `template1`

### 4.6. Проверка с Windows

```powershell
Test-NetConnection -ComputerName 192.168.0.173 -Port 5432
Test-NetConnection -ComputerName 192.168.0.173 -Port 1540
Test-NetConnection -ComputerName 192.168.0.173 -Port 1541
```

**Ожидаемо:** все три `TcpTestSucceeded : True`.

---

## 📋 Что должно быть готово

- [x] Образ `1c-server-postgres` собран
- [x] Образ `1c-server-1c-server` собран
- [x] Контейнеры `pg-1c` и `1c-server` запущены
- [x] PostgreSQL 15.17-1.1C с `mchar` и `fasttrun`
- [x] Локаль БД `ru_RU.UTF-8`
- [x] `ragent`, `rmngr`, `rphost` работают
- [x] Порты 5432, 1540, 1541 открыты с Windows
- [x] Volumes созданы и смонтированы

---

## ⚠️ Возможные проблемы

### PostgreSQL не стартует

- **`initdb: error: invalid locale settings`** → проверьте, что в `Dockerfile` есть `locale-gen` **до** установки 1С
- **`groupadd: group 'postgres' already exists`** → уберите ручное создание пользователя из `Dockerfile`
- **`ls: cannot access '/docker-entrypoint-initdb.d/'`** → добавьте `RUN mkdir -p /docker-entrypoint-initdb.d`
- **`initdb: command not found`** → добавьте `ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"`

### PostgreSQL работает, но порт закрыт

- **`listen_addresses` = `localhost`** → добавьте в `docker-compose.yml`: `command: ["postgres", "-c", "listen_addresses=*"]`

### 1С-сервер в цикле `Restarting`

- Проверьте `docker compose logs 1c-server`
- Если `reg_1541` повреждён — удалите его (см. [Troubleshooting](appendix/troubleshooting.md))

### Порт 1541 закрыт

- Кластер не инициализирован → удалите volume `1c_data` и запустите заново
- ⚠️ **Внимание:** это удалит реестр кластера, но **не** БД PostgreSQL

**Все проблемы** — в [приложении Troubleshooting](appendix/troubleshooting.md).

---

## 🗺️ Что дальше

Следующий раздел — [**05. Проброс графики в контейнер**](05-x11-forwarding.md).

Сейчас у нас есть работающие контейнеры, но **без графики**. Для **активации лицензии** и **создания ИБ** нужно **пробросить X11**.

---

**Навигация:** [← Предыдущий](03-docker-install.md) | [Содержание](README.md) | [Следующий →](05-x11-forwarding.md)
