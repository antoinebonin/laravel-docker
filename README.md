# Laravel Docker
<a href="/LICENSE"><img alt="License" src="https://img.shields.io/github/license/antoinebonin/laravel-docker"></a>

Dockerfiles prêts pour la production pour des services web et microservices propulsés par Laravel Octane.

Ce Dockerfile propose les configurations suivante :
- Images officielles de PHP 8.2 et 8.3 basées sur Alpine
- Compilateur JIT et OPcache préconfigurés

## Utilisation

### Ajouter à son projet l'image Docker

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/antoinebonin/laravel-docker/main/install.sh)"
```

### Lancer le container Docker

```bash
# HTTP mode
docker run -p <port>:80 --rm <image-name>:<tag>

# HTTP avec un Scheduler
docker run -e WITH_SCHEDULER=true -p <port>:80 --rm <image-name>:<tag>

# Lancer uniquement une commande
docker run --rm <image-name>:<tag> php artisan about
```

## Notes

- Laravel Octane logs request information only in the `local` environment.
- Please be aware of `.dockerignore` content
