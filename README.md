# Angie Reverse Proxy (angie-proxy)

Обратный прокси на базе Angie для проксирования сервисов в Docker контейнерах.

## Предварительные условия

- Перед Angie стоит другой reverse proxy с SSL termination
- Angie получает только HTTP трафик на порту 80
- Все заголовки X-Forwarded-* передаются бэкендам

## Требования

- Docker Engine 20.10+
- Docker Compose V2
- Пользователь в группе `docker`
- Сеть Docker `global_proxy` (создаётся автоматически)

## Структура проекта

```txt
angie-docker/
├── docker-compose.yml
├── .gitignore
├── README.md
├── angie/
│   ├── angie.conf
│   └── http.p/
│       └── project.conf
├── systemd/
│   ├── docker-network-global_proxy.service
│   └── scripts/
│       └── create-global-proxy-network.sh
│       └── setup-logrotate.sh
├── logs/
│   └── .gitkeep
└── examples/
    └── client-project/
        ├── docker-compose.yml
        └── html/
            └── index.html
```

## Установка и активация

### 1. Создать директорию проекта

```bash
mkdir -p ~/angie-docker
cd ~/angie-docker
```

### 2. (разместить файлы из репозитория)

### 3. Установить systemd сервис
```bash
sudo cp systemd/docker-network-global_proxy.service /etc/systemd/system/
sudo cp systemd/scripts/docker-network-ensure.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-network-ensure.sh
sudo systemctl daemon-reload
sudo systemctl enable docker-network-global_proxy.service
sudo systemctl start docker-network-global_proxy.service
```
### 4. Ротация логов

Логи Angie пишутся в каталог `./logs` внутри проекта. Для настройки ротации:

```bash
sudo chmod +x ./systemd/scripts/setup-logrotate.sh
sudo ./systemd/scripts/setup-logrotate.sh
```

#### Проверка конфигурации logrotate:
```bash
# Проверить конфигурацию на ошибки (без выполнения)
sudo logrotate -d /etc/logrotate.d/angie-proxy

# Пример вывода (успешно):
# reading config file /etc/logrotate.d/angie-proxy
# Handling 1 logs
# rotating pattern: /путь/к/проекту/global_angie/logs/*.log  after 1 days (14 rotations)
```
#### Проверка расписания logrotate:
```bash
# Посмотреть задачи cron для logrotate
sudo cat /etc/cron.daily/logrotate

# Проверить статус последней ротации
sudo cat /var/lib/logrotate/status | grep angie
```

#### Остановка/запуск ротации вручную
```bash
# Остановка
sudo mv /etc/logrotate.d/angie-proxy /etc/logrotate.d/angie-proxy.disabled

# Запуск
sudo mv /etc/logrotate.d/angie-proxy.disabled /etc/logrotate.d/angie-proxy
```

### 5. Запустить Angie
`docker compose up -d`

### 6. Проверить статус
```bash
docker compose ps
docker logs angie-proxy
curl -I http://localhost
docker compose exec angie curl http://127.0.0.1:8080/status/upstreams
docker compose exec angie curl http://127.0.0.1:8080/status/
```

## Подключение другого проекта к сети

Для того чтобы сервисы вашего проекта были автоматически обнаружены Angie, необходимо:

### 1. Подключить проект к сети `global_proxy`, добавить метки к вашему сервису:

В `docker-compose.yml` вашего проекта добавьте:

```yaml
name: myapp

networks:
  global_proxy:
    external: true

services:
  nginx:
    networks:
      - global_proxy
    labels:
      - "angie.http.upstreams.myapp.port=80"
    # ... остальная конфигурация
```
Формат меток:
angie.http.upstreams.<имя>.port=<порт> — порт сервиса

### 2. После запуска проекта проверьте, что сервис виден из контейнера Angie:
```bash
# Из контейнера Angie
docker compose exec angie curl -I http://myapp-nginx:80
```

### 3. После подключения проекта, добавьте upstream в angie/http.p/myapp.conf:

```angie
upstream myapp {
    zone myapp 1m;
}

server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://myapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }
}
```

