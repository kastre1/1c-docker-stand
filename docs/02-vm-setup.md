# 02. Настройка виртуальной машины и подготовка дистрибутивов

**Навигация:** [← Предыдущий](01-intro.md) | [Содержание](README.md) | [Следующий →](03-docker-install.md)

---

## 📌 О чём этот раздел

Здесь описано:
- Создание виртуальной машины в VirtualBox
- Установка Ubuntu 24.04 LTS
- Базовая настройка системы
- Скачивание дистрибутивов 1С и PostgreSQL с `releases.1c.ru`
- Подготовка структуры проекта

**Что должно получиться в конце:** готовая Ubuntu VM с интернетом, SSH, и подготовленными дистрибутивами.

---

## 🖥️ Требования к Windows-хосту

Перед началом убедитесь, что у вас:

| Параметр | Минимум | Рекомендуется |
|---|---|---|
| **ОЗУ** | 16 ГБ | 32 ГБ |
| **Свободное место на диске** | 80 ГБ | 150 ГБ |
| **CPU** | 4 ядра | 8 ядер |
| **Сеть** | Ethernet или Wi-Fi | Ethernet |
| **Свободный IP** в локальной сети | — | Да (для VM) |

**Почему столько:** виртуальная машина будет использовать 6-8 ГБ ОЗУ и 50-60 ГБ диска. Остальное — для Windows.

---

## 📥 Шаг 1. Установка VirtualBox на Windows

1. Скачайте **VirtualBox** с официального сайта: [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)
2. Выберите **Windows hosts** — скачается `.exe`-установщик
3. Запустите и установите с настройками по умолчанию
4. **Также скачайте** «VirtualBox Extension Pack» — он нужен для USB-проброса (пригодится в Неделе 3)

**Проверка:** запустите VirtualBox — должно открыться окно менеджера.

---

## 🎯 Шаг 2. Создание виртуальной машины

### 2.1. Запустить мастер

В VirtualBox Manager: **Машина → Создать** (или `Ctrl+N`).

### 2.2. Заполнить базовые параметры

| Поле | Значение |
|---|---|
| **Имя** | `Ubuntu-1C-Stand` |
| **Тип** | Linux |
| **Версия** | Ubuntu (64-bit) |
| **Папка для машины** | Оставьте по умолчанию или укажите на быстром диске |

### 2.3. Выделить ресурсы

| Параметр | Значение |
|---|---|
| **ОЗУ** | **6144 МБ** (6 ГБ) или **8192 МБ** (8 ГБ), если хост позволяет |
| **CPU** | **4 ядра** |
| **☑ Включить EFI** | ❌ **НЕТ** (оставьте выключенным) |

### 2.4. Создать виртуальный диск

| Параметр | Значение |
|---|---|
| **Создать новый виртуальный жёсткий диск** | ✅ |
| **Тип** | VDI |
| **Формат хранения** | **Динамический** (растёт по мере заполнения) |
| **Размер** | **60 ГБ** |

**Почему 60 ГБ:**
- Ubuntu: ~10 ГБ
- Docker-образы: ~15 ГБ
- Дистрибутивы 1С и PostgreSQL: ~5 ГБ
- Запас: ~30 ГБ

### 2.5. Настроить сеть

**Настройки VM → Сеть → Адаптер 1:**

| Поле | Значение |
|---|---|
| **☑ Включить сетевой адаптер** | ✅ |
| **Тип подключения** | **Сетевой мост (Bridged Adapter)** |
| **Имя** | Ваш активный Ethernet/Wi-Fi адаптер |
| **Тип адаптера** | Intel PRO/1000 MT Desktop |

**Почему «Сетевой мост»:** VM получит IP в **той же подсети**, что и Windows-хост. Например, Windows `192.168.0.129`, VM `192.168.0.173`. Тогда:
- Из Windows можно обращаться к VM по IP
- Из VM видно Windows-хост
- Docker-контейнеры доступны по тому же IP

**Альтернатива — NAT:** не подходит, потому что при NAT VM «скрыта» за Windows, и нужен проброс портов.

---

## 💿 Шаг 3. Установка Ubuntu 24.04 LTS

### 3.1. Скачать ISO

Скачайте **Ubuntu Server 24.04 LTS** или **Ubuntu Desktop 24.04 LTS**:
- Server: [https://ubuntu.com/download/server](https://ubuntu.com/download/server) — **рекомендую** (легче, GUI не нужен)
- Desktop: [https://ubuntu.com/download/desktop](https://ubuntu.com/download/desktop) — если нужен GUI в самой VM

**Для нашего стенда — Server** достаточно: GUI мы пробрасываем через X11 только когда нужно.

### 3.2. Подключить ISO к VM

**Настройки VM → Носители → Контроллер IDE → Оптический привод → Выбрать ISO**.

### 3.3. Запустить VM

Нажмите **Запустить**. Начнётся установка Ubuntu.

### 3.4. Параметры установки

| Шаг | Значение |
|---|---|
| **Язык установки** | English (или Русский) |
| **Раскладка клавиатуры** | English (US) + Russian |
| **Тип установки** | Ubuntu Server (default) |
| **Сеть** | Оставьте DHCP — получите IP автоматически |
| **Proxy** | Пусто |
| **Mirror** | По умолчанию (`archive.ubuntu.com`) |
| **Разметка диска** | Use an entire disk (без LVM — проще) |
| **Имя пользователя** | `kastrel` |
| **Имя сервера** | `kasrtrelsrv` |
| **Username** | `kastrel` |
| **Пароль** | Ваш пароль |
| **☑ Install OpenSSH server** | ✅ **ОБЯЗАТЕЛЬНО** |
| **Snaps** | Docker **не** ставить здесь — поставим вручную |

**Почему OpenSSH:** через него будем подключаться с Windows (MobaXterm) и пробрасывать X11.

### 3.5. После установки

Перезагрузите VM, войдите под `kastrel`.

**Узнайте IP-адрес VM:**

```bash
ip -4 addr show | grep inet
```

**Ожидаемо:** что-то вроде `inet 192.168.0.173/24`. **Запишите IP** — он понадобится.

**Проверьте интернет:**

```bash
ping -c 3 8.8.8.8
ping -c 3 ya.ru
```

### 3.6. Обновить систему

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

---

## 🔧 Шаг 4. Базовая настройка Ubuntu

### 4.1. Установить полезные утилиты

```bash
sudo apt install -y \
  nano \
  htop \
  tree \
  net-tools \
  dnsutils \
  curl \
  wget \
  git \
  unzip \
  bzip2 \
  strace
```

**Что зачем:**
- `nano` — редактор файлов
- `htop` — мониторинг процессов
- `tree` — вывод дерева каталогов
- `net-tools` — `netstat`, `ifconfig`
- `dnsutils` — `dig`, `nslookup`
- `strace` — диагностика проблем

### 4.2. Зафиксировать IP-адрес (рекомендуется)

**Проблема:** при перезагрузке роутер может выдать **другой IP** через DHCP, и все настройки на Windows (DBeaver, hosts) сломаются.

**Решение — резервирование по MAC в роутере (проще):**

1. Зайдите в веб-интерфейс роутера (`http://192.168.0.1` обычно)
2. Найдите раздел **DHCP Reservations** / **Статические привязки**
3. Добавьте привязку: MAC VM → IP `192.168.0.173`

**MAC VM можно узнать командой:**
```bash
ip link show | grep ether
```

**Альтернатива — статический IP через netplan:**

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Замените на:

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses: [192.168.0.173/24]
      routes:
        - to: default
          via: 192.168.0.1
      nameservers:
        addresses: [192.168.0.1, 8.8.8.8]
```

Примените:

```bash
sudo netplan apply
ip -4 addr show
```

⚠️ **Осторожно:** проверьте, что `192.168.0.173` не занят другим устройством.

### 4.3. Проверить SSH

С Windows в PowerShell:

```powershell
ssh kastrel@192.168.0.173
```

Должно подключиться без пароля (если вы настроили ключи) или с паролем.

---

## 📥 Шаг 5. Скачивание дистрибутивов с releases.1c.ru

### 5.1. Что нужно скачать

**Два дистрибутива:**

1. **Сервер 1С:Предприятие 8.3.26.1540 для Linux (DEB-based)**
2. **PostgreSQL 15.17-1.1C для Ubuntu 24.04 x86_64** + дополнительные модули

### 5.2. Где искать на портале

**Сервер 1С:**

1. Зайдите на [https://releases.1c.ru](https://releases.1c.ru) под своей учётной записью
2. Раздел: **Технологическая платформа 8.3**
3. Выберите версию **8.3.26.1540**
4. Найдите: **«Сервер 1С:Предприятия (64-bit) для DEB-based Linux-систем»**
5. Скачайте архив: `server64_8_3_26_1540.zip` (~1.6 ГБ)

**PostgreSQL:**

1. На том же портале: **СУБД PostgreSQL для 1С:Предприятия**
2. Найдите группу: **Ubuntu x86 (64-bit)**
3. Скачайте **два архива** для **Ubuntu 24.04**:
   - `postgresql_15.17_1_ubuntu_24.04_x86_64_package.tar.bz2` (~19 МБ)
   - `postgresql_15.17_1_ubuntu_24.04_x86_64_package_addon.tar.bz2` (~26 МБ)

⚠️ **Важно:** выбирайте **Ubuntu x86 (64-bit)**, а **не ARM**! ARM-сборки не подойдут.

### 5.3. Перенести файлы в VM

**Способ 1 (через scp):** из Windows PowerShell:

```powershell
scp C:\Users\<твой_юзер>\Downloads\server64_8_3_26_1540.zip kastrel@192.168.0.173:~/
scp C:\Users\<твой_юзер>\Downloads\postgresql_15.17_*.tar.bz2 kastrel@192.168.0.173:~/
```

**Способ 2 (через MobaXterm):** просто перетащите файлы в окно терминала.

**Способ 3 (через общую папку VirtualBox):** если настроили.

### 5.4. Распаковать сервер 1С

```bash
mkdir -p ~/projects/1c-server/1c-server/distr
cd ~/projects/1c-server/1c-server/distr
mv ~/server64_8_3_26_1540.zip .
unzip server64_8_3_26_1540.zip
ls -lh
```

**Ожидаемо:** появится файл `setup-full-8.3.26.1540-x86_64.run` (~1.6 ГБ) и папки `docs/`, `licenses/`, `readme/`.

**Проверить, что установщик работает:**

```bash
chmod +x setup-full-8.3.26.1540-x86_64.run
./setup-full-8.3.26.1540-x86_64.run --help | head -40
```

**Ожидаемо:** список параметров установщика (`--mode`, `--enable-components`, и т.д.).

**Удалить ненужное** (zip-архив):

```bash
rm server64_8_3_26_1540.zip
```

### 5.5. Распаковать PostgreSQL

```bash
mkdir -p ~/projects/1c-server/postgres/distr
cd ~/projects/1c-server/postgres/distr
mv ~/postgresql_15.17_*.tar.bz2 .
tar -xjf postgresql_15.17_1_ubuntu_24.04_x86_64_package.tar.bz2
tar -xjf postgresql_15.17_1_ubuntu_24.04_x86_64_package_addon.tar.bz2
ls -lh *.deb
```

**Ожидаемо:** ~23 `.deb`-файла, включая:
- `postgresql-15_15.17-1.1C_amd64.deb` — **основной**
- `postgresql-client-15_15.17-1.1C_amd64.deb`
- `libpq5_15.17-1.1C_amd64.deb`
- `postgresql-common_290.pgdg24.04+1_all.deb`
- `postgresql-client-common_290.pgdg24.04+1_all.deb`
- и другие (dbg, dev, plperl, plpython3, pltcl, doc)

### 5.6. Собрать минимальный набор `.deb`

Для нашего стенда нужны **только 5 пакетов** — остальные не нужны (это инструменты разработки, документация, отладка).

```bash
cd ~/projects/1c-server/postgres
mkdir -p distr-min

cp distr/postgresql-15_15.17-1.1C_amd64.deb distr-min/
cp distr/postgresql-client-15_15.17-1.1C_amd64.deb distr-min/
cp distr/libpq5_15.17-1.1C_amd64.deb distr-min/
cp distr/postgresql-common_290.pgdg24.04+1_all.deb distr-min/
cp distr/postgresql-client-common_290.pgdg24.04+1_all.deb distr-min/

ls -lh distr-min/
```

**Ожидаемо:** 5 файлов, ~20 МБ.

**Что не берём** (и почему):
- `postgresql-15-dbg_*.deb` (22 МБ) — отладочные символы, не нужны
- `postgresql-doc-15_*.deb` — документация
- `postgresql-server-dev-15_*.deb` — заголовки для сборки расширений
- `postgresql-plperl-15_*.deb`, `-plpython3-15`, `-pltcl-15` — PL-языки
- `libecpg*` — библиотеки Embedded SQL
- `postgresql-all`, `postgresql`, `postgresql-client` — метапакеты

---

## 📁 Шаг 6. Структура проекта

После всех шагов у вас должна получиться такая структура:

```
~/projects/1c-server/
├── docker-compose.yml               # Главный compose-файл
├── README.md                        # Обзор проекта
├── README.en.md                     # Обзор (английский)
├── NOTES.md                         # Рабочие заметки
├── docs/                            # Документация
│   ├── README.md
│   ├── 01-intro.md
│   ├── 02-vm-setup.md               # ← этот файл
│   └── ...
├── postgres/                        # PostgreSQL
│   ├── Dockerfile                   # ← создадим в разделе 04
│   ├── .dockerignore
│   ├── distr/                       # Исходные дистрибутивы + .deb
│   │   ├── *.tar.bz2
│   │   └── *.deb
│   └── distr-min/                   # Только нужные .deb (5 файлов)
│       └── *.deb
└── 1c-server/                       # Сервер 1С
    ├── Dockerfile                   # ← создадим в разделе 04
    ├── .dockerignore
    ├── scripts/
    │   └── entrypoint.sh            # ← создадим в разделе 04
    ├── conf/                        # Сюда положится .lic
    └── distr/
        └── setup-full-8.3.26.1540-x86_64.run
```

### Создать структуру

```bash
cd ~/projects/1c-server
mkdir -p {postgres/{distr,distr-min},1c-server/{scripts,conf,distr},docs/appendix,backup,scripts}
tree -L 2 .
```

---

## ✅ Что должно быть готово

После этого раздела у вас:

- [x] Виртуальная машина Ubuntu 24.04 в VirtualBox
- [x] IP `192.168.0.173` (или свой) в режиме «Сетевой мост»
- [x] SSH работает с Windows
- [x] Базовые утилиты установлены
- [x] Дистрибутив **1С** распакован в `1c-server/distr/`
- [x] Дистрибутивы **PostgreSQL** распакованы
- [x] Минимальный набор `.deb` собран в `postgres/distr-min/`
- [x] Структура проекта создана

---

## ⚠️ Возможные проблемы

| Проблема | Решение |
|---|---|
| VM не получает IP | Проверьте режим «Сетевой мост» и что выбран правильный адаптер |
| Нет интернета в VM | Проверьте DNS (`resolvectl status`), попробуйте `ping 8.8.8.8` |
| SSH не подключается | Проверьте `sudo systemctl status ssh` в VM |
| Архив не распаковывается | Установите `unzip` и `bzip2` |
| Файлы не копируются через `scp` | Проверьте, что знаете пароль от `kastrel@192.168.0.173` |

**Все остальные проблемы** — в [приложении Troubleshooting](appendix/troubleshooting.md).

---

## 🗺️ Что дальше

Следующий раздел — [**03. Установка Docker и Docker Compose**](03-docker-install.md).

Там мы:
1. Установим Docker Engine и Compose
2. Настроим зеркало `mirror.gcr.io`
3. Проверим, что всё работает
4. Решим проблему с битыми образами (если возникнет)

---

**Навигация:** [← Предыдущий](01-intro.md) | [Содержание](README.md) | [Следующий →](03-docker-install.md)
