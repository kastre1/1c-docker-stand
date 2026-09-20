# Публикация проекта на GitHub

**Навигация:** [← Содержание](README.md)

---

## 📌 О чём этот документ

- Подготовка проекта к публикации
- Создание репозитория на GitHub
- Первый push
- Что попадёт в репозиторий, а что нет
- Рекомендации по оформлению

---

## 🔧 Шаг 1. Проверка `.gitignore`

Перед инициализацией git убедитесь, что `.gitignore` в корне проекта **исключает**:

- ✅ Дистрибутивы (`.run`, `.deb`, `.zip`, `.tar.bz2`) — большие, приватные
- ✅ Лицензии (`.lic`) — приватные
- ✅ Логи, временные файлы
- ✅ Архивы старых версий

**Проверка:**

```bash
cd ~/projects/1c-server
cat .gitignore
```

Если `.gitignore` ещё нет — создайте по шаблону из **Файла 14**.

---

## 🚀 Шаг 2. Инициализация репозитория

```bash
cd ~/projects/1c-server

# Инициализация git
git init

# Настройка user (если не настроен)
git config user.name "kastrel"
git config user.email "your-email@example.com"

# Проверка, что .gitignore работает
git status
```

**Что должно быть в `git status`:**
- **Untracked files:** `README.md`, `README.en.md`, `NOTES.md`, `docs/`, `docker-compose.yml`, `postgres/`, `1c-server/`, `LICENSE`, `.gitignore`, `.gitattributes`
- **NOT in status:** `distr/*.run`, `distr/*.deb`, `conf/*.lic`, `.archive/`

⚠️ **Если видите в `git status` большие файлы** — значит, `.gitignore` не работает. Проверьте его.

---

## 📝 Шаг 3. Первый коммит

```bash
git add .
git commit -m "Initial commit: 1C:Enterprise 8.3.26 + PostgreSQL 15.17 in Docker"
```

**Что коммитится:**
- Документация (`docs/`, `README.md`, `README.en.md`, `NOTES.md`)
- Docker-конфиги (`docker-compose.yml`, `postgres/Dockerfile`, `1c-server/Dockerfile`)
- Скрипты (`1c-server/scripts/entrypoint.sh`)
- Служебное (`LICENSE`, `.gitignore`, `.gitattributes`)

**Проверка:**

```bash
git log --oneline
git ls-files | head -30
```

---

## 🌐 Шаг 4. Создание репозитория на GitHub

1. Зайдите на [https://github.com](https://github.com)
2. Нажмите **New repository**
3. Заполните:
   - **Repository name:** `1c-docker-stand` (или другое)
   - **Description:** «Fault-tolerant 1C:Enterprise + PostgreSQL stand in Docker»
   - **Visibility:** **Public** (для портфолио) или **Private**
   - **❌ НЕ ставьте галочки** «Add a README file», «Add .gitignore», «Choose a license» — у нас они уже есть
4. Нажмите **Create repository**

**GitHub покажет команды** для подключения локального репозитория.

---

## 📤 Шаг 5. Push в GitHub

```bash
cd ~/projects/1c-server

# Связать локальный репозиторий с GitHub
git remote add origin https://github.com/<ваш-username>/1c-docker-stand.git

# Переименовать ветку в main
git branch -M main

# Запушить
git push -u origin main
```

⚠️ **Если используете SSH-ключи:**

```bash
git remote add origin git@github.com:<ваш-username>/1c-docker-stand.git
```

**Если нет SSH-ключа** — используйте HTTPS + **Personal Access Token** (GitHub требует токены вместо паролей).

**Как получить токен:**
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → выбрать scopes: `repo`, `workflow`
3. Скопировать токен (он показывается только один раз!)
4. При `git push` вместо пароля — вставить токен

---

## ✅ Шаг 6. Проверка на GitHub

Откройте `https://github.com/<username>/1c-docker-stand`.

**Что должно быть видно:**
- ✅ `README.md` — красивый, с оглавлением и ссылками на `docs/`
- ✅ `docs/` — папка с документацией
- ✅ `docker-compose.yml`, `postgres/`, `1c-server/`
- ✅ `LICENSE`, `.gitignore`
- ❌ **НЕ** должно быть: `.run`, `.deb`, `.lic`, больших архивов

**Проверьте размер репозитория:**

В настройках репозитория (Settings → General) → **Repository size**. Должно быть **< 5 МБ**.

---

## 📝 Шаг 7. Обновление документации

После каждого изменения документации:

```bash
cd ~/projects/1c-server

# 1. Посмотреть изменения
git status
git diff

# 2. Добавить файлы
git add docs/README.md  # или git add . для всего

# 3. Закоммитить
git commit -m "docs: обновил раздел 05 (X11 forwarding)"

# 4. Запушить
git push
```

### Рекомендации по коммитам

Используйте **префиксы** для ясности:

| Префикс | Что значит |
|---|---|
| `docs:` | Изменения в документации |
| `feat:` | Новая функциональность |
| `fix:` | Исправление ошибки |
| `chore:` | Служебные изменения (`.gitignore`, конфиги) |
| `refactor:` | Рефакторинг без изменения функционала |

**Примеры:**
- `docs: добавлен раздел про troubleshooting`
- `feat: добавлен бэкап скрипт`
- `fix: исправлена ошибка listen_addresses в compose`

---

## 🎨 Шаг 8. Оформление репозитория

### 8.1. Topics (теги)

На странице репозитория → **Settings** → **Topics**:
- `1c`
- `1c-enterprise`
- `postgresql`
- `docker`
- `docker-compose`
- `devops`
- `russian`

Помогает людям **найти** ваш проект.

### 8.2. About (описание)

На главной странице репозитория нажмите **⚙️** рядом с «About»:
- **Description:** «Fault-tolerant 1C:Enterprise + PostgreSQL stand in Docker»
- **Website:** (если есть)
- ✅ **Releases**, ✅ **Packages** (опционально)

### 8.3. README на главной

`README.md` **автоматически** показывается на главной странице. У нас он уже красивый, с эмодзи, схемой, ссылками.

---

## 📸 Шаг 9. Скриншоты (опционально, но рекомендуется)

Для портфолио **очень помогают** скриншоты. Добавьте папку `docs/screenshots/`:

```
docs/screenshots/
├── 01-architecture.png        # схема стенда
├── 02-obsidian.png            # документация в Obsidian
├── 03-1c-server-running.png   # docker compose ps
├── 04-thin-client.png         # тонкий клиент подключен
└── 05-license.png             # Community-лицензия
```

**Вставка в Markdown:**

```markdown
![Схема стенда](screenshots/01-architecture.png)
```

⚠️ **Не заливайте** скриншоты с **приватной информацией** (номера лицензий, пароли, IP, если критично).

---

## 🔄 Шаг 10. Релизы (опционально)

Если хотите отметить **стабильную версию**:

1. Репозиторий → **Releases** → **Create a new release**
2. **Tag:** `v1.0.0`
3. **Title:** `First stable release`
4. **Description:** описание изменений
5. **Publish release**

GitHub создаст **архив** репозитория для скачивания.

---

## ⚠️ Что НЕ заливать на GitHub

| Что | Почему |
|---|---|
| **Дистрибутивы 1С** (`.run`, `.zip`) | Большие (1.6 ГБ), приватные, требуют лицензии |
| **`.deb`-пакеты PostgreSQL** | Большие, приватные |
| **Файлы `.lic`** | Приватные, привязаны к железу |
| **Логи** | Большие, содержат чувствительные данные |
| **Пароли в открытом виде** | Дыра в безопасности |
| **Персональные данные** | Нарушение GDPR/152-ФЗ |

**Правило:** если сомневаетесь — добавляйте в `.gitignore`.

---

## 📋 Финальный чек-лист

- [ ] `.gitignore` создан и работает
- [ ] `git init` выполнен
- [ ] Первый коммит сделан
- [ ] Репозиторий создан на GitHub
- [ ] `git remote add origin ...` выполнен
- [ ] `git push -u origin main` выполнен
- [ ] Репозиторий виден на GitHub
- [ ] `README.md` рендерится красиво
- [ ] `docs/` доступна
- [ ] Размер репозитория **< 5 МБ**
- [ ] Topics добавлены
- [ ] Description заполнен
- [ ] (Опционально) Скриншоты добавлены
- [ ] (Опционально) Релиз `v1.0.0` создан

---

## 🎉 Поздравляю!

**Ваш пет-проект опубликован на GitHub.** Теперь:
- Его можно **показать** потенциальным работодателям
- **Ссылаться** в резюме
- **Развивать** совместно с другими
- **Использовать** как основу для новых проектов

---

## 💡 Что дальше

1. **Развивайте проект** — добавляйте новые разделы (Ansible, Frontol, ЕГАИС)
2. **Пишите статьи** — на Habr, на VC, на Medium
3. **Отвечайте на issues** — если кто-то найдёт баг
4. **Принимайте PR** — если кто-то захочет улучшить

**Удачи!** 🚀

---

**Навигация:** [← Содержание](README.md)
