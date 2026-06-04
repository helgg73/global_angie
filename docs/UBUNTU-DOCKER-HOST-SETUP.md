# 🐳 Настройка Ubuntu под Docker-host с UFW

> **Цель**: Безопасная настройка Docker с контролем сетевого доступа через UFW  
> **Требования**: Ubuntu 22.04/24.04, root/sudo доступ, интернет

---

## 1. 🔐 Проверка и настройка UFW

```bash
# Проверка статуса UFW
sudo ufw status

# Разрешаем необходимые порты
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw route allow 80/tcp comment 'HTTP'
# Если нужен HTTPS
# sudo ufw route allow 443/tcp comment 'HTTPS'

# Включаем UFW (подтверждаем "y")
sudo ufw enable

# Проверяем правила
sudo ufw status verbose
sudo ufw status numbered
```

> 💡 `systemctl status ufw` может не показывать актуальное состояние правил — используйте `ufw status verbose`.

---

## 2. 🐋 Установка Docker

### Вариант А: Последняя стабильная версия (рекомендуется)
```bash
# Стандартная установка через официальный скрипт
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Проверка установки
docker --version
```

### Вариант Б: Конкретная версия через apt-репозиторий
```bash
# Установка зависимостей
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Добавление GPG-ключа Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Добавление репозитория
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновление и просмотр доступных версий
sudo apt update
apt-cache madison docker-ce | head -10

# Установка конкретной версии (пример для 5:29.5.2-1 buntu.24.04 oble)
# Замените <VERSION_STRING> на нужную версию из списка выше
sudo apt install -y docker-ce=<VERSION_STRING> docker-ce-cli=<VERSION_STRING> \
  containerd.io docker-buildx-plugin docker-compose-plugin

# Блокировка обновления (опционально)
sudo apt-mark hold docker-ce docker-ce-cli

# Проверка
docker --version
```

> 📌 Версию можно посмотреть в списке `apt-cache madison docker-ce`. Формат: `5:29.5.2-1 buntu.24.04 oble`

---

## 3. 🛡️ Установка ufw-docker

```bash
# Скачиваем скрипт из официального репозитория (chaifeng)
sudo wget -O /usr/local/bin/ufw-docker \
  https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker

# Даём права на выполнение
sudo chmod +x /usr/local/bin/ufw-docker

# Применяем настройки (добавляет правила в /etc/ufw/after.rules)
sudo ufw-docker install

# 🔁 Перезагружаем UFW через systemctl для гарантированного применения правил
sudo systemctl restart ufw

# Проверяем, что правила DOCKER-USER применены
sudo iptables -L DOCKER-USER -n -v

# Дополнительная проверка через утилиту
sudo ufw-docker check
```

> ⚠️ **Важно**: После `ufw-docker install` используйте `systemctl restart ufw`, а не `ufw reload` — это гарантирует применение правил из `after.rules`.

---

## 4. 👤 Добавление пользователя в группу docker

```bash
# Добавляем текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Применяем изменения группы без выхода из сессии
newgrp docker

# Проверяем, что пользователь в группе
groups
```

> 🔐 **Безопасность**: Членство в группе `docker` эквивалентно root-доступу. Используйте только для доверенных пользователей.

---

## 5. 📁 Создание директории для проектов

```bash
# Создаём папку для Docker-проектов
sudo mkdir -p /opt/docker

# Меняем владельца и группу
sudo chown root:docker /opt/docker

# Даём права с setgid битом для наследования группы
sudo chmod 2775 /opt/docker

# Проверяем результат
ls -ld /opt/docker
# Ожидаемый вывод: drwxrwsr-x 2 root docker 4096 ...

# --- Работа с проектами ---

# Переходим в директорию
cd /opt/docker

# Клонируем проект (группа автоматически будет docker благодаря setgid)
git clone https://github.com/user/myproject.git

# Если нужно исправить права для существующего проекта:
sudo chown -R root:docker /opt/docker/myproject
sudo chmod -R 2775 /opt/docker/myproject

# Проверяем права
ls -ld /opt/docker/myproject
# Ожидаемый вывод: drwxrwsr-x ... root docker ...
```

---

## ✅ Итоговая проверка

```bash
# 1. UFW активен и правила на месте
sudo ufw status numbered

# 2. Docker работает
docker --version
docker run --rm hello-world

# 3. ufw-docker применил правила (должны быть правила с комментарием ufw-docker)
sudo iptables -L DOCKER-USER -n -v | grep -E "ufw|RETURN"

# 4. Пользователь в группе docker
groups $USER  # Должно содержать 'docker'

# 5. Директория /opt/docker имеет правильные права
ls -ld /opt/docker  # drwxrwxr-x root docker
```

---

## 🧪 Тестирование изоляции портов (опционально, но рекомендуется)

```bash
# Запускаем тестовый контейнер на порту 9999
docker run -d --name test-ufw -p 9999:80 nginx

# Пробуем подключиться с внешней машины или через curl с другого хоста:
# curl http://<ВАШ_ВНЕШНИЙ_IP>:9999
# → Должно таймаутить, если UFW работает корректно

# Разрешаем доступ к порту контейнера (пример)
sudo ufw-docker allow test-ufw 80/tcp

# Проверяем снова — теперь должно работать
# curl http://<ВАШ_ВНЕШНИЙ_IP>:9999

# Удаляем тестовый контейнер
docker rm -f test-ufw
```

---

## 📋 Сводная таблица ожидаемого состояния

| Компонент | Ожидаемый статус | Команда для проверки |
| :--- | :--- | :--- |
| **UFW** | Активен, разрешены порты 22, 80, 443 | `sudo ufw status verbose` |
| **Docker** | Установлен и запущен | `docker --version` |
| **ufw-docker** | Установлен, правила применены в цепочке `DOCKER-USER` | `sudo iptables -L DOCKER-USER -n -v` |
| **Группа docker** | Текущий пользователь добавлен в группу | `groups $USER` |
| **/opt/docker** | Владелец: `root:docker`, права: `2775` (setgid установлен) | `ls -ld /opt/docker` |
| **Проекты** (напр. `myproject`) | Владелец: `root:docker`, права: `2775` (группа наследуется) | `ls -ld /opt/docker/myproject` |

---

## 🔄 Полезные команды для дальнейшего управления

```bash
# Разрешить порт для конкретного контейнера
sudo ufw-docker allow <container_name> <port>/tcp

# Запретить доступ извне для всех контейнеров (по умолчанию уже так)
sudo ufw default deny incoming

# Просмотр правил ufw-docker
sudo ufw-docker list

# Обновление ufw-docker (если нужно)
sudo wget -O /usr/local/bin/ufw-docker \
  https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
sudo chmod +x /usr/local/bin/ufw-docker
```

---

> 🛡️ **Финальный совет**: После настройки всегда тестируйте доступность портов с внешней машины. Локальный `curl` может обходить правила фаервола через loopback-интерфейс.
