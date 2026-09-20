# Приложение A. Решение проблем (Troubleshooting)

**Навигация:** [← Содержание](../README.md) | [Cheat Sheet →](cheat-sheet.md)

---

## 📌 О чём этот документ

**Сборник всех проблем**, с которыми мы столкнулись при развёртывании стенда, и их решения.

**Как пользоваться:**
- Ищите по **симптому** (сообщению об ошибке)
- Каждая проблема — с **причиной** и **решением**
- В конце каждого раздела — **проверка**, что проблема решена

---

## 🔴 Проблемы с Docker

### P1. `unexpected media type text/html` при `docker pull`

**Симптом:**

```bash
docker pull postgres:15
# ...
failed to unpack image on snapshotter overlayfs: unexpected media type text/html
for sha256:xxx: not found
```

**Также:** в `docker images` размер образа `0B`.

**Причина:** в локальный кэш Docker попал **битый слой** — вместо tar-архива пришёл HTML (подмена на стороне сети/провайдера).

**Решение:**

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

**Профилактика:** настроить зеркало `mirror.gcr.io` в `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

Затем:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**Признак битого образа:** `SIZE = 0B` в `docker images` — красный флаг.

---

### P2. `permission denied` при работе с Docker

**Симптом:**

```bash
docker ps
# permission denied while trying to connect to the Docker daemon socket
```

**Причина:** пользователь **не в группе** `docker`.

**Решение:**

```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Проверка:**

```bash
groups $USER
# Ожидаемо: в списке есть docker

docker ps
# Должно работать без sudo
```

---

## 🔴 Проблемы с PostgreSQL

### P3. `initdb: error: invalid locale settings`

**Симптом:** контейнер `pg-1c` в цикле `Restarting`.

В логах:

```
initdb: error: invalid locale settings; check LANG and LC_* environment variables
```

**Причина:** базовый образ `postgres:15` **не содержит** локали `ru_RU.UTF-8`. А мы её задали через `environment`.

**Решение:** собрать **свой образ** с `locale-gen` в `Dockerfile`:

```dockerfile
RUN sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8
```

См. [раздел 04](../04-containers.md).

---

### P4. `groupadd: group 'postgres' already exists`

**Симптом:** при сборке образа:

```
groupadd: group 'postgres' already exists
ERROR: process ... did not complete successfully: exit code: 9
```

**Причина:** `.deb`-пакет `postgresql-15` **сам создаёт** пользователя и группу `postgres`. Мы пытались создать их **второй раз**.

**Решение:** **убрать** из `Dockerfile` вручную создание пользователя. Оставить только:

```dockerfile
RUN mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/postgresql/data \
 && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql \
 && chmod 2775 /var/run/postgresql
```

---

### P5. `ls: cannot access '/docker-entrypoint-initdb.d/'`

**Симптом:** при запуске контейнера в цикле:

```
ls: cannot access '/docker-entrypoint-initdb.d/': No such file or directory
```

**Причина:** `docker-entrypoint.sh` из `postgres:15` **ожидает** этот каталог. Мы скопировали **только скрипт**, а каталог — нет.

**Решение:** добавить в `Dockerfile`:

```dockerfile
RUN mkdir -p /docker-entrypoint-initdb.d
```

---

### P6. `initdb: command not found`

**Симптом:**

```
/usr/local/bin/docker-entrypoint.sh: line 92: initdb: command not found
```

**Причина:** `.deb`-пакет 1С ставит бинарники в `/usr/lib/postgresql/15/bin/`, а `docker-entrypoint.sh` ожидает их в `$PATH`.

**Решение:** добавить в `Dockerfile`:

```dockerfile
ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"
```

**Проверка:**

```bash
docker exec -it pg-1c which initdb
# Ожидаемо: /usr/lib/postgresql/15/bin/initdb
```

---

### P7. PostgreSQL слушает только `localhost`

**Симптом:** порт 5432 **закрыт** снаружи, хотя контейнер `healthy`.

С Windows:

```powershell
Test-NetConnection -ComputerName 192.168.0.173 -Port 5432
# TcpTestSucceeded : False
```

В логах:

```
listening on IPv4 address "127.0.0.1", port 5432
```

**Причина:** `.deb`-пакет 1С создаёт конфиг с `listen_addresses='localhost'`.

**Решение:** добавить в `docker-compose.yml`:

```yaml
services:
  postgres:
    command: ["postgres", "-c", "listen_addresses=*"]
```

**Проверка в логах:**

```bash
docker compose logs postgres | grep listening
# Ожидаемо: "0.0.0.0" и "::"
```

---

### P8. `DATABASE не пригоден для использования`

**Симптом:** при создании ИБ в 1С:

```
0A000: ОШИБКА: расширение "mchar" отсутствует
DETAIL: Не удалось открыть управляющий файл расширения
        "/usr/share/postgresql/15/extension/mchar.control"
```

**Причина:** ванильный PostgreSQL **не содержит** расширений 1С.

**Решение:** использовать **1С-сборку** PostgreSQL (см. [раздел 04](../04-containers.md)).

**Проверка:**

```bash
docker exec -it pg-1c psql -U postgres -c "SELECT name FROM pg_available_extensions WHERE name IN ('mchar', 'fasttrun');"
# Ожидаемо: mchar, fasttrun
```

---

## 🔴 Проблемы с сервером 1С

### P9. Контейнер 1С в цикле `Restarting`

**Симптом:** `docker compose ps` показывает `Restarting (N)`.

**Причина:** обычно — повреждённый **реестр кластера** (`reg_1541`), особенно после пересборки образа.

**Решение:**

```bash
docker exec -it 1c-server bash
rm -rf /home/usr1cv8/.1cv8/1C/1cv8/reg_1541
exit
docker compose restart 1c-server
sleep 15
docker compose ps
docker exec -it 1c-server ps aux | grep -E "ragent|rmngr|rphost" | grep -v grep
```

**Радикальное решение:** удалить volume `1c_data` (⚠️ потеря реестра кластера, но **не** БД PostgreSQL):

```bash
docker compose stop 1c-server
docker compose rm -f 1c-server
docker volume rm 1c-server_1c_data
docker compose up -d 1c-server
sleep 20
```

---

### P10. Порт 1541 закрыт, `rmngr` не запускается

**Симптом:**

```bash
Test-NetConnection -Port 1541
# TcpTestSucceeded : False
```

В процессах — только `ragent`, но нет `rmngr` и `rphost`.

**Причина:** кластер 1С не инициализирован. Обычно — повреждённый `reg_1541`.

**Решение:** см. P9.

---

### P11. `/sbin/ip: not found` при запуске `1cv8s`

**Симптом:** при запуске 1С:

```
/bin/sh: 1: /sbin/ip: not found
```

**Причина:** в образе `1c-server` нет пакета `iproute2`.

**Решение:** добавить в `Dockerfile`:

```dockerfile
RUN apt-get install -y iproute2
```

**Проверка:**

```bash
docker exec -it 1c-server ls -la /sbin/ip
# Ожидаемо: файл существует
```

---

### P12. `Хранилище сертификатов Linux не обнаружено`

**Симптом:** при активации лицензии:

```
Ошибка обращения к Центру Лицензирования
Хранилище сертификатов Linux не обнаружено
```

**Причина:** нет **сертификатов Минцифры** для проверки HTTPS-соединения с `users.v8.1c.ru`.

**Решение:** добавить в `Dockerfile` (см. [раздел 04](../04-containers.md)):

```dockerfile
RUN curl -o /usr/local/share/ca-certificates/russian_trusted_root_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_root_ca_pem.crt \
 && curl -o /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_sub_ca_pem.crt \
 && update-ca-certificates
```

**Проверка:**

```bash
docker exec -it 1c-server bash -c "grep -c 'BEGIN CERTIFICATE' /etc/ssl/certs/ca-certificates.crt"
# Ожидаемо: 120+
```

---

### P13. Лицензия активирована, но 1С её не видит

**Симптом:** на портале `developer.1c.ru` лицензия есть, но 1С при запуске **требует лицензию**.

**Причина:** файл `.lic` находится **не в том каталоге**, или у него **неверные права**.

**Решение:**

```bash
# 1. Найти .lic
docker exec -it -u root 1c-server find / -name "*.lic" 2>/dev/null

# 2. Скопировать в два каталога
docker exec -it -u root 1c-server bash
cp /path/to/*.lic /opt/1cv8/conf/
cp /path/to/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/
chown usr1cv8:grp1cv8 /opt/1cv8/conf/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/*.lic
chmod 666 /opt/1cv8/conf/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/*.lic
exit

# 3. Перезапустить
docker compose restart 1c-server
```

**Проверка:**

```bash
docker exec -it 1c-server ls -la /opt/1cv8/conf/
docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/conf/
# Ожидаемо: файлы .lic с правами usr1cv8:grp1cv8
```

---

### P14. `.lic` пропала после `exit` из GUI-контейнера

**Симптом:** активировали лицензию в `docker compose run --rm`, но в основном контейнере файла нет.

**Причина:** `--rm` контейнер удаляется после `exit`. Файл был в его **временной** файловой системе, а не в volume.

**Решение (пока контейнер жив):**

```bash
# 1. Найти ID живого контейнера
docker ps | grep 1c-server

# 2. Вытащить .lic
docker cp <CONTAINER_ID>:/var/1C/licenses/XXXXX.lic ~/projects/1c-server/1c-server/conf/

# 3. Скопировать в основной контейнер
docker cp ~/projects/1c-server/1c-server/conf/XXXXX.lic 1c-server:/opt/1cv8/conf/
docker cp ~/projects/1c-server/1c-server/conf/XXXXX.lic 1c-server:/home/usr1cv8/.1cv8/1C/1cv8/conf/

# 4. Права
docker exec -it -u root 1c-server chown usr1cv8:grp1cv8 /opt/1cv8/conf/*.lic /home/usr1cv8/.1cv8/1C/1cv8/conf/*.lic
```

**Профилактика:** **всегда** монтировать volume при `docker compose run` для GUI:

```bash
docker compose run --rm \
  -e DISPLAY=192.168.0.129:0.0 \
  -v 1c-server_1c_data:/home/usr1cv8 \
  1c-server bash
```

---

## 🔴 Проблемы с X11

### P15. `Unable to initialize GTK+ or connect to the windowing system`

**Симптом:** при запуске 1С в GUI-контейнере:

```
*** Unable to initialize GTK+ or connect to the windowing system.
Is DISPLAY set properly?
```

**Причина:** `DISPLAY` установлен неправильно, или X-сервер не принимает TCP.

**Решение:**

1. Проверить `DISPLAY` внутри контейнера:
   ```bash
   echo $DISPLAY
   # Ожидаемо: 192.168.0.129:0.0
   ```
2. Проверить на Windows:
   ```powershell
   netstat -an | findstr ":6000"
   # Ожидаемо: LISTENING
   ```
3. Проверить в XLaunch: галочка **«Disable access control»** стоит
4. На Ubuntu: `xhost +192.168.0.173`

---

### P16. Окно 1С открывается, но пустое

**Симптом:** запустили `1cv8s`, окно вроде есть, но **пустое**, без элементов.

**Причина:** 1С пытается использовать GPU, который X11 через TCP не поддерживает.

**Решение:** запустить с флагом **`-DisableHWA`**:

```bash
/opt/1cv8/x86_64/8.3.26.1540/1cv8s -DisableHWA
```

Также установить:

```bash
export GDK_BACKEND=x11
export LIBGL_ALWAYS_INDIRECT=1
```

---

### P17. Окно 1С вообще не появляется

**Симптом:** команда `1cv8s` запускается, но окно не появляется, ошибок тоже нет.

**Причина:** возможно, окно **уходит за пределы экрана**.

**Решение:** проверить координаты окна:

```bash
xwininfo -root -tree | grep -i 1c
```

Если координаты с минусом — окно «уехало».

**Альтернатива:** запустить с логированием:

```bash
/opt/1cv8/x86_64/8.3.26.1540/1cv8s -DisableHWA -log /tmp/1c.log
cat /tmp/1c.log
```

---

### P18. MobaXterm не пробрасывает X11 в Docker

**Симптом:** `xeyes` на хосте работает, но `1cv8s` в Docker — нет.

**Причина:** MobaXterm создаёт X11-туннель **внутри SSH-сессии**. Docker-контейнер не имеет доступа к этому туннелю.

**Решение:** использовать **VcXsrv напрямую с TCP** (см. [раздел 05](../05-x11-forwarding.md)).

**Проверка:** с хоста должно работать:

```bash
export DISPLAY=192.168.0.129:0.0
xhost +192.168.0.173
xeyes
```

Если `xeyes` открывается — VcXsrv работает, и Docker тоже сможет.

---

## 🔴 Проблемы с тонким клиентом

### P19. `Не найден сервер 1С:Предприятия: 13b42dfae82e`

**Симптом:** при подключении тонкого клиента с Windows:

```
Не найден сервер 1С:Предприятия: 13b42dfae82e
```

**Причина:** сервер 1С регистрирует ИБ с **внутренним именем контейнера** (`13b42dfae82e`), которое **не резолвится** на Windows.

**Решение:** добавить в `C:\Windows\System32\drivers\etc\hosts`:

```
192.168.0.173 13b42dfae82e
```

⚠️ **ID контейнера индивидуален.** Узнать:

```bash
docker ps --filter "name=1c-server" --format "{{.ID}}"
```

См. [раздел 08](../08-thin-client.md).

---

### P20. `База не найдена`

**Симптом:** тонкий клиент не находит ИБ в кластере.

**Причина:** неверное **имя ИБ в кластере** (не путать с именем в PostgreSQL).

**Решение:** проверить точное имя:

```bash
docker exec -it 1c-server /opt/1cv8/x86_64/8.3.26.1540/rac infobase list \
  --cluster=localhost:1540 \
  --infobase-user=admin \
  --infobase-pwd=""
```

Или посмотреть в GUI-мастере 1С.

---

### P21. `Несовместимая версия клиента`

**Симптом:** тонкий клиент отказывается подключаться.

**Причина:** версия клиента **не совпадает** с сервером.

**Решение:** установить клиент **той же версии** (8.3.26.1540).

---

## 📋 Чек-лист диагностики

Если что-то не работает — пройдитесь по списку:

### 1. Docker

```bash
docker --version              # 20+
docker compose version        # 2+
docker ps                     # контейнеры Up
```

### 2. PostgreSQL

```bash
docker exec -it pg-1c psql -U postgres -c "SELECT version();"
# 15.17-1.1C
docker exec -it pg-1c psql -U postgres -c "SELECT name FROM pg_available_extensions WHERE name IN ('mchar', 'fasttrun');"
# mchar, fasttrun
```

### 3. Сервер 1С

```bash
docker exec -it 1c-server ps aux | grep -E "ragent|rmngr|rphost" | grep -v grep
# 3 процесса
docker exec -it 1c-server bash -c 'IP=$(hostname -i); (echo > /dev/tcp/$IP/1541) 2>/dev/null && echo "1541 OPEN" || echo "CLOSED"'
# OPEN
```

### 4. Сеть с Windows

```powershell
Test-NetConnection -ComputerName 192.168.0.173 -Port 5432  # True
Test-NetConnection -ComputerName 192.168.0.173 -Port 1540  # True
Test-NetConnection -ComputerName 192.168.0.173 -Port 1541  # True
```

### 5. Лицензия

```bash
docker exec -it 1c-server ls -la /opt/1cv8/conf/
# файл .lic
docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/conf/
# файл .lic
```

### 6. X11

```bash
echo $DISPLAY                # 192.168.0.129:0.0
xeyes                        # работает
```

---

## 📞 Что делать, если ничего не помогает

1. **Собрать логи:**
   ```bash
   docker compose logs > /tmp/logs.txt
   docker exec -it 1c-server ps aux > /tmp/ps.txt
   docker exec -it 1c-server ls -la /home/usr1cv8/.1cv8/1C/1cv8/ > /tmp/1c-data.txt
   ```

2. **Проверить свежие issues** на GitHub репозитория

3. **Искать по точному тексту ошибки** в интернете

4. **Радикальный вариант:** снести всё и пересобрать:
   ```bash
   docker compose down -v
   docker system prune -a -f
   docker compose build --no-cache
   docker compose up -d
   ```
   ⚠️ **Осторожно:** `-v` удалит все данные (БД, лицензии).

---

**Навигация:** [← Содержание](../README.md) | [Cheat Sheet →](cheat-sheet.md)
