# Accepted values: 8.3 - 8.2
ARG PHP_VERSION=8.3
ARG FRANKENPHP_VERSION=latest
ARG COMPOSER_VERSION=lts
ARG NODE_VERSION=20-alpine



FROM node:${NODE_VERSION} AS node_build

ENV WWW_ROOT=/var/www/html

WORKDIR ${WWW_ROOT}

RUN npm config set update-notifier false && npm set progress=false

COPY --link package*.json ./

RUN if [ -f $ROOT/package-lock.json ]; \
    then \
    npm ci --loglevel=error --no-audit; \
    else \
    npm install --loglevel=error --no-audit; \
    fi

COPY --link . .

RUN npm run build



# On ne peux pas dans le COPY mettre de variable, c'est pour ça que l'on créer un stage avec le composer de la version souhaité
FROM composer:${COMPOSER_VERSION} AS vendor



FROM dunglas/frankenphp:${FRANKENPHP_VERSION}-php${PHP_VERSION}-alpine

LABEL maintainer="Antoine BONIN <contact@antoinebonin.fr>"

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC
ARG APP_DIR=/var/www/html

ENV TERM=xterm-color \
    WITH_SCHEDULER=false \
    OCTANE_SERVER=frankenphp \
    USER=octane \
    WWW_ROOT=${APP_DIR} \
    COMPOSER_FUND=0 \
    COMPOSER_MAX_PARALLEL_HTTP=24 \
    XDG_CONFIG_HOME=${APP_DIR}/.config \
    XDG_DATA_HOME=${APP_DIR}/.data

WORKDIR ${WWW_ROOT}

# Mettre en erreur toutes les commandes qui n'ont pas une réponse positive
SHELL ["/bin/sh", "-eou", "pipefail", "-c"]

# Mise à jour du timezone
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# On met à jour l'os et on télécharge les dépendances
RUN apk update; \
    apk upgrade; \
    apk add --no-cache curl wget nano git ncdu procps ca-certificates supervisor libsodium-dev \
    # Install PHP extensions (included with dunglas/frankenphp)
    && install-php-extensions bz2 pcntl mbstring bcmath sockets pgsql pdo_pgsql opcache exif pdo_mysql zip intl gd redis rdkafka memcached igbinary ldap \
    && docker-php-source delete \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# On cherche notre architecture et on recupère la version de supercronic qui correspond
RUN arch="$(apk --print-arch)" \
    && case "$arch" in \
    armhf) _cronic_fname='supercronic-linux-arm' ;; \
    aarch64) _cronic_fname='supercronic-linux-arm64' ;; \
    x86_64) _cronic_fname='supercronic-linux-amd64' ;; \
    x86) _cronic_fname='supercronic-linux-386' ;; \
    *) echo >&2 "error: unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/${_cronic_fname}" \
    -O /usr/bin/supercronic \
    && chmod +x /usr/bin/supercronic \
    && mkdir -p /etc/supercronic \
    && echo "*/1 * * * * php ${WWW_ROOT}/artisan schedule:run --no-interaction" > /etc/supercronic/laravel

# On créer un groupe et un utilisateur qui ne sont pas root pour éviter de lancer le container en tant que root
RUN addgroup -g ${WWWGROUP} ${USER} \
    && adduser -D -h ${WWW_ROOT} -G ${USER} -u ${WWWUSER} -s /bin/sh ${USER}

# On créer les dossier avec les bons droits pour les logs
RUN mkdir -p /var/log/supervisor /var/run/supervisor \
    && chown -R ${USER}:${USER} ${WWW_ROOT} /var/log /var/run \
    && chmod -R a+rw ${WWW_ROOT} /var/log /var/run

# On prend la configuration de production de php
RUN cp ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini

# On utilise un utilisateur non root dans le container
USER ${USER}

# On importe composer et la liste de vendor
COPY --link --chown=${USER}:${USER} --from=vendor /usr/bin/composer /usr/bin/composer
COPY --link --chown=${USER}:${USER} composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-autoloader \
    --no-ansi \
    --no-scripts

# On importe nos vendors node
COPY --link --chown=${USER}:${USER} . .
COPY --link --chown=${USER}:${USER} --from=node_build ${WWW_ROOT}/public public

# On créer la structure de base de Laravel, avec les bons droits
RUN mkdir -p \
    storage/framework/sessions \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/testing \
    storage/logs \
    bootstrap/cache && chmod -R a+rw storage

COPY --link --chown=${USER}:${USER} deploy/supervisord.conf /etc/supervisor/
COPY --link --chown=${USER}:${USER} deploy/supervisord.frankenphp.conf /etc/supervisor/conf.d/
COPY --link --chown=${USER}:${USER} deploy/supervisord.scheduler.conf /etc/supervisor/conf.d/
COPY --link --chown=${USER}:${USER} deploy/start-container /usr/local/bin/start-container
COPY --link --chown=${USER}:${USER} deploy/php.ini ${PHP_INI_DIR}/conf.d/99-octane.ini

# Configuration de FrankenPHP
COPY --link --chown=${USER}:${USER} deploy/php.ini /lib/php.ini

# Installation de nos vendors php
RUN composer install \
    --classmap-authoritative \
    --no-interaction \
    --no-ansi \
    --no-dev \
    && composer clear-cache

# On vérifie que le start container soit executable
RUN chmod +x /usr/local/bin/start-container

# On écrit des alias utiles pour notre terminal
RUN cat deploy/utilities.sh >> ~/.bashrc

EXPOSE 80

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1