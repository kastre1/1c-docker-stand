# Приложение B. Шпаргалка команд

**Навигация:** [← Troubleshooting](troubleshooting.md) | [Содержание](../README.md)

---

## 📌 О чём этот документ

**Все команды**, которые могут пригодиться при работе со стендом.

Разбито по категориям:
- Docker
- PostgreSQL
- Сервер 1С
- X11
- Диагностика

---

## 🐳 Docker

### Управление контейнерами

```bash
docker ps                          # запущенные
docker ps -a                       # все, включая остановленные
docker ps --filter "name=1c-server"  # по имени
docker logs <container>            # логи
docker logs -f <container>         # логи в реальном времени
docker logs --tail=50 <container>  # последние 50 строк
docker exec -it <container> bash   # зайти внутрь
docker exec -it -u root <container> bash  # зайти от root
docker stop <container>            # остановить
docker start <container>           # запустить
docker restart <container>         # перезапустить
docker rm <container>              # удалить
docker rm -f <container>           # удалить принудительно
```

### Управление образами

```bash
docker images                      # список образов
docker images | grep 1c-server     # фильтр по имени
docker pull <image>                # скачать
docker rmi <image>                 # удалить
docker image inspect <image>       # детали
docker image prune -a              # удалить неиспользуемые
```

### Копирование файлов

```bash
docker cp <container>:/path/to/file /host/path/     # из контейнера на хост
docker cp /host/path/file <container>:/container/path/  # с хоста в контейнер
```

### Обслуживание

```bash
docker system df                   # сколько места занимает
docker system df -v                # детально
docker system prune -a             # ⚠️ удалить всё неиспользуемое
docker builder prune -f            # очистить кэш сборки
docker volume ls                   # список volumes
docker volume inspect <volume>     # детали volume
docker volume rm <volume>          # ⚠️ удалить volume
```

### Docker Compose

```bash
docker compose up -d               # поднять в фоне
docker compose up -d --build       # пересобрать и поднять
docker compose down                # остановить и удалить контейнеры (volumes сохраняются)
docker compose down -v             # ⚠️ + удалить volumes (ДАННЫЕ!)
docker compose stop                # остановить (не удалять)
docker compose start               # запустить
docker compose restart <svc>       # перезапуск сервиса
docker compose ps                  # статус
docker compose ps -a               # все, включая остановленные
docker compose logs -f <svc>       # логи сервиса
docker compose build               # только сборка
docker compose build --no-cache    # пересборка без кэша
docker compose config              # валидация конфига
```

---

## 🐘 PostgreSQL

### Подключение

```bash
docker exec -it pg-1c psql -U postgres                  # интерактивно
docker exec -it pg-1c psql -U postgres -c "\l"          # список БД
docker exec -it pg-1c psql -U postgres -d <db> -c "\dt" # таблицы БД
```

### Проверки

```bash
# Версия
docker exec -it pg-1c psql -U postgres -c "SELECT version();"

# Расширения
docker exec -it pg-1c psql -U postgres -c "SELECT name FROM pg_available_extensions WHERE name IN ('mchar', 'fasttrun');"

# Установленные расширения в БД
docker exec -it pg-1c psql -U postgres -d <db> -c "SELECT extname FROM pg_extension;"

# Локаль
docker exec -it pg-1c psql -U postgres -c "\l"
```

### Создание/удаление

```bash
# Создать БД
docker exec -it pg-1c psql -U postgres -c "CREATE DATABASE <name> WITH ENCODING='UTF8' LC_COLLATE='ru_RU.UTF-8' LC_CTYPE='ru_RU.UTF-8' TEMPLATE=template0;"

# Удалить БД
docker exec -it pg-1c psql -U postgres -c "DROP DATABASE <name>;"
```

### Логи

```bash
docker compose logs postgres --tail=50
docker compose logs postgres -f
docker compose logs postgres | grep -E "listening|ready"
```

---

## 🏢 Сервер 1С

### Процессы

```bash
# Все процессы 1С
docker exec -it 1c-server ps aux | grep -E "ragent|rmngr|rphost" | grep -v grep

# Только ragent
docker exec -it 1c-server ps aux | grep ragent | grep -v grep
```

### Порты

```bash
# Проверка порта изнутри
docker exec -it 1c-server bash -c 'IP=$(hostname -i); (echo > /dev/tcp/$IP/1540) 2>/dev/null && echo "1540 OPEN" || echo "CLOSED"'
docker exec -it 1c-server bash -c 'IP=$(hostname -i); (echo > /dev/tcp/$IP/1541) 2>/dev/null && echo "1541 OPEN" || echo "CLOSED"'
```

### Утилиты `rac` / `ras`

```bash
# Список кластеров
docker exec -it 1c-server /opt/1cv8/x86_64/8.3.26.1540/rac cluster list

# Список ИБ в кластере
docker exec -it 1c-server /opt/1cv8/x86_64/8.3.26.1540/rac infobase list \
  --cluster=localhost:1540 \
  --infobase-user=admin \
  --infobase-pwd=""
```

⚠️ **Синтаксис отличается:**
- `rac cluster list` — `--admin-user`, `--admin-password`
- `rac infobase list` — `--infobase-user`, `--infobase-pwd`

### Логи

```bash
docker compose logs 1c-server --tail=50
docker compose logs 1c-server -f
docker compose logs 1c-server | grep -i "license\|error"
```

### Данные 1С

```bash
# Структура каталога данных
docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/

# Список лицензий
docker exec -it 1c-server ls -la /opt/1cv8/conf/
docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/conf/

# Поиск всех .lic
docker exec -it -u root 1c-server find / -name "*.lic" 2>/dev/null
```

### Управление кластером

```bash
# Удалить повреждённый реестр кластера
docker exec -it 1c-server bash
rm -rf /home/usr1cv8/.1cv8/1C/1cv8/reg_1541
exit
docker compose restart 1c-server
```

---

## 🎨 X11

### Запуск GUI-контейнера

```bash
# На хосте
xhost +192.168.0.173

# Запуск
cd ~/projects/1c-server
docker compose run --rm \
  -e DISPLAY=192.168.0.129:0.0 \
  -v 1c-server_1c_data:/home/usr1cv8 \
  1c-server bash
```

### Внутри GUI-контейнера

```bash
# Переменные
export GDK_BACKEND=x11
export LIBGL_ALWAYS_INDIRECT=1

# Запуск 1С
/opt/1cv8/x86_64/8.3.26.1540/1cv8s -DisableHWA
```

### Проверка X11

```bash
echo $DISPLAY                # 192.168.0.129:0.0
xeyes                        # тестовое окно
xclock                       # часы
xwininfo -root -tree | grep -i 1c  # список окон
```

### VcXsrv (Windows)

```powershell
netstat -an | findstr ":6000"  # проверка, что VcXsrv слушает
```

---

## 🔍 Диагностика

### Сеть

```bash
# IP-адрес VM
ip -4 addr show | grep inet

# Проверка доступности с Windows
# PowerShell:
Test-NetConnection -ComputerName 192.168.0.173 -Port 5432
Test-NetConnection -ComputerName 192.168.0.173 -Port 1540
Test-NetConnection -ComputerName 192.168.0.173 -Port 1541

# Изнутри контейнера
docker exec -it 1c-server getent hosts pg-1c
docker exec -it 1c-server getent hosts 1c-server
```

### Ресурсы

```bash
# RAM/CPU
free -h
htop

# Диск
df -h /
df -h /var/lib/docker

# Использование Docker
docker system df -v
```

### Логи

```bash
# Все контейнеры
docker compose logs > /tmp/all-logs.txt

# Postgres
docker compose logs postgres > /tmp/pg-logs.txt

# 1С-сервер
docker compose logs 1c-server > /tmp/1c-logs.txt

# Логи 1С внутри контейнера
docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/logs/
```

---

## 🔧 Полезные однострочники

### Перезапустить всё

```bash
cd ~/projects/1c-server && docker compose restart
```

### Полная остановка

```bash
cd ~/projects/1c-server && docker compose stop
```

### Поднять всё

```bash
cd ~/projects/1c-server && docker compose up -d && sleep 15 && docker compose ps
```

### Проверить всё разом

```bash
cd ~/projects/1c-server && \
docker compose ps && \
echo "--- PostgreSQL ---" && \
docker exec -it pg-1c psql -U postgres -c "SELECT version();" && \
echo "--- 1C Processes ---" && \
docker exec -it 1c-server ps aux | grep -E "ragent|rmngr|rphost" | grep -v grep && \
echo "--- Ports ---" && \
docker exec -it 1c-server bash -c 'IP=$(hostname -i); (echo > /dev/tcp/$IP/1541) 2>/dev/null && echo "1541 OPEN" || echo "CLOSED"'
```

### Найти `.lic` везде

```bash
docker exec -it -u root 1c-server find / -name "*.lic" 2>/dev/null
```

### Скопировать `.lic` в оба каталога

```bash
docker exec -it -u root 1c-server bash -c "
  cp /path/to/*.lic /opt/1cv8/conf/ && \
  cp /path/to/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/ && \
  chown usr1cv8:grp1cv8 /opt/1cv8/conf/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/*.lic && \
  chmod 666 /opt/1cv8/conf/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/*.lic
"
```

### Бэкап проекта

```bash
cd ~/projects/1c-server && tar -czf ~/backup-1c-$(date +%Y%m%d).tar.gz .
```

### Бэкап БД PostgreSQL

```bash
docker exec pg-1c pg_dumpall -U postgres > ~/backups/all_pg_$(date +%Y%m%d).sql
```

---

## ⚠️ Команды «Осторожно»

Эти команды могут **привести к потере данных**. Используйте только когда уверены:

```bash
docker compose down -v          # ❌ УДАЛЯЕТ ВСЕ VOLUMES (данные!)
docker volume rm <volume>       # ❌ УДАЛЯЕТ VOLUME
docker system prune -a          # ❌ УДАЛЯЕТ неиспользуемые образы
docker rm -f 1c-server          # ❌ МЕНЯЕТ MAC, ломает лицензию!
docker compose up --force-recreate 1c-server  # ❌ Тоже MAC
```

**Правило:** перед `down -v` или `volume rm` — **сделайте бэкап**.

---

**Навигация:** [← Troubleshooting](troubleshooting.md) | [Содержание](../README.md)
