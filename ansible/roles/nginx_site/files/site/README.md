# Лендинг Бориса Горелика

Статический одностраничный сайт на HTML, CSS и JavaScript. Не требует сборки и подходит для размещения на двух одинаковых nginx-серверах за Yandex Application Load Balancer.

## Локальный просмотр

```bash
python3 -m http.server 8080
```

Откройте `http://localhost:8080`.

## Размещение в nginx

Скопируйте содержимое каталога на каждую web-ВМ:

```bash
sudo rsync -av --delete ./ /var/www/expert-landing/
```

Минимальный server block:

```nginx
server {
    listen 80 default_server;
    server_name _;
    root /var/www/expert-landing;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~* \.(css|js|svg|jpg|jpeg|png|webp)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
```

Проверка:

```bash
curl -I http://localhost/
```
