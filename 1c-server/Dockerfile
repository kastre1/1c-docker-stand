# ============================================================
# Dockerfile: Сервер 1С:Предприятие 8.3.26.1540
# Базовый образ: Ubuntu 24.04 LTS
# ============================================================

FROM ubuntu:24.04

# --- Метаданные ---
LABEL maintainer="kastrel" \
      description="1C:Enterprise Server 8.3.26.1540 on Ubuntu 24.04" \
      version="1.0"

# --- Переменные окружения ---
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8 \
    TZ=Europe/Moscow

# --- 1. Установка базовых зависимостей и локали ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Локали и шрифты
    locales \
    fontconfig \
    # Библиотеки, требуемые 1С:Сервером
    libfreetype6 \
    libgsf-1-114 \
    libglib2.0-0 \
    libodbc2 \
    libkrb5-3 \
    libgssapi-krb5-2 \
    # Дополнительно для 1С
    libenchant-2-2 \
    liblcms2-2 \
    libwebkit2gtk-4.1-0 \
    libgtk-3-0 \
    # Утилиты
    gosu \
    curl \
    wget \
    # Сетевые утилиты (нужны 1С для диагностики, в т.ч. /sbin/ip)
    iproute2 \
    # Для работы с внешними источниками данных
    unixodbc \
    # Для PDF/диаграмм
    ghostscript \
    imagemagick \
    # Сертификаты (системное хранилище + утилита update-ca-certificates)
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# --- 2. Генерация русской локали ---
RUN sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen

# --- 3. Установка сертификатов Минцифры для Центра Лицензирования ---
# ВАЖНО: этот шаг идёт ПОСЛЕ установки ca-certificates, иначе update-ca-certificates
# не найдёт системное хранилище.
RUN curl -o /usr/local/share/ca-certificates/russian_trusted_root_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_root_ca_pem.crt \
 && curl -o /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt \
      https://gu-st.ru/content/lending/russian_trusted_sub_ca_pem.crt \
 && update-ca-certificates

# --- 4. Копирование и установка сервера 1С ---
COPY distr/setup-full-8.3.26.1540-x86_64.run /tmp/1c-installer.run

RUN chmod +x /tmp/1c-installer.run \
 && /tmp/1c-installer.run \
      --mode unattended \
      --unattendedmodeui none \
      --enable-components server,server_admin,ws,client_full,liberica_jre,ru \
 && rm -f /tmp/1c-installer.run

# --- 5. Создание пользователя и группы для сервера 1С ---
RUN usermod -d /home/usr1cv8 -m -s /bin/bash usr1cv8 || true

# --- 6. Каталоги для данных и конфигурации ---
RUN mkdir -p /home/usr1cv8/.1cv8/1C/1cv8/conf \
             /home/usr1cv8/.1cv8/1C/1cv8/logs \
             /home/usr1cv8/.1cv8/1C/1cv8/tmp \
             /opt/1cv8/conf \
 && chown -R usr1cv8:grp1cv8 /home/usr1cv8 /opt/1cv8/conf

# --- 7. Точка входа ---
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# --- 8. Порты, которые слушает сервер 1С ---
EXPOSE 1540 1541 1560-1591

# --- 9. Точка входа и рабочая директория ---
WORKDIR /home/usr1cv8
ENTRYPOINT ["/entrypoint.sh"]
CMD ["ragent"]
