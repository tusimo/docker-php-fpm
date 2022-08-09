FROM php:7.2-fpm-alpine

ENV GRPC_RELEASE_TAG v1.31.x
ENV PROTOBUF_RELEASE_TAG 3.13.x
ENV SKYWALKING_RELEASE_TAG v4.2.0
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/local/lib64
ENV LD_RUN_PATH=$LD_RUN_PATH:/usr/local/lib:/usr/local/lib64

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.cloud.tencent.com/g' /etc/apk/repositories

RUN apk add -u --no-cache tzdata \
 && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

RUN apk upgrade && \
    apk add --no-cache curl \
        boost-dev \
        git \
        ca-certificates \
        automake \
        libtool \
        file \
        linux-headers \
        re2c \
        pkgconf \
        openssl-dev \
        curl-dev \
        autoconf \
        openssl \
        gcc \
        make \
        g++ \
        zlib-dev \
        graphviz \
        libpng-dev \
        libpq \
        icu-dev \
        libffi-dev \
        freetype-dev \
        libxslt-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libmemcached-dev \
        libmcrypt-dev \
        libzip-dev \
        librdkafka-dev && \
    docker-php-ext-configure gd \
      --with-gd \
      --with-freetype-dir=/usr/include/ \
      --with-png-dir=/usr/include/ \
      --with-jpeg-dir=/usr/include/ \
      --with-webp-dir=/usr/include/ && \
    docker-php-ext-install fileinfo pdo_mysql mysqli gd exif intl xsl soap zip opcache sockets bcmath pcntl && \
    docker-php-source delete

RUN pecl install redis-5.0.2 memcached-3.1.4 rdkafka yaf-3.0.8 yar-2.0.5 mcrypt hprose-1.6.8 \
    && docker-php-ext-enable redis memcached rdkafka yaf yar mcrypt hprose


RUN wget https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.1.0.tar.gz -O /tmp/libwebp-1.1.0.tar.gz \
    && tar -C /tmp -zxvf /tmp/libwebp-1.1.0.tar.gz \
    && cd /tmp/libwebp-1.1.0 \
    && ./configure --prefix=/usr/local/libwebp --enable-everything \
    && make && make install

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

RUN set -ex \
    && mkdir -p /tmp/git \
    && echo "--- clone grpc ---" \
    && git clone --depth 1 -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /tmp/git/grpc \
    && cd /tmp/git/grpc \
    && git submodule update --init --recursive \
    && echo "--- download cmake ---" \
    && cd /tmp/git \
    && curl -L -o cmake-3.19.1.tar.gz  https://github.com/Kitware/CMake/releases/download/v3.19.1/cmake-3.19.1.tar.gz \
    && tar zxf cmake-3.19.1.tar.gz \
    && cd cmake-3.19.1 && ./bootstrap && make -j$(nproc) && make install \
    && echo "--- installing grpc ---" \
    && cd /tmp/git/grpc \
    && mkdir -p cmake/build && cd cmake/build && cmake ../.. \
    && make -j$(nproc) \
    && echo "--- installing skywalking php ---" \
    && cd /tmp/git \
    && git clone --depth 1 -b  ${SKYWALKING_RELEASE_TAG} https://github.com/SkyAPM/SkyAPM-php-sdk.git /tmp/git/skywalking \
    && cd /tmp/git/skywalking \
    && phpize && ./configure --with-grpc=/tmp/git/grpc && make && make install \
    && rm -fr /tmp/git


RUN apk del autoconf gcc make g++ \
    && rm -fr /var/cache/apk/* /tmp/* /usr/share/man

WORKDIR /var/www/html


ENV TZ=Asia/Shanghai
ENV APP_ENV=product
ENV PHP_DATE_TIMEZONE="Asia/Shanghai"
ENV PHP_ERROR_LOG="/proc/self/fd/2"
ENV PHP_LOG_LEVEL="notice"
ENV PHP_PROCESS_MAX=0
ENV PHP_RLIMIT_FILES=51200
ENV PHP_RLIMIT_CORE=0
ENV PHP_USER=www-data
ENV PHP_GROUP=www-data
ENV PHP_LISTEN=0.0.0.0:9000
ENV PHP_PM=static
ENV PHP_PM_MAX_CHILDREN=20
ENV PHP_PM_START_SERVERS=4
ENV PHP_PM_MIN_SPARE_SERVERS=2
ENV PHP_PM_MAX_SPARE_SERVERS=10
ENV PHP_PM_PROCESS_IDLE_TIMEOUT=10s
ENV PHP_PM_MAX_REQUESTS=10000
ENV PHP_SLOWLOG="/proc/self/fd/2"
ENV PHP_REQUEST_SLOWLOG_TIMEOUT="2s"
ENV PHP_REQUEST_TERMINATE_TIMEOUT="120s"
ENV PHP_MAX_EXECUTION_TIME=600
ENV PHP_MAX_INPUT_TIME=60
ENV PHP_MEMORY_LIMIT=384M
ENV PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"
ENV PHP_DISPLAY_ERRORS="Off"
ENV PHP_DISPLAY_STARTUP_ERRORS="Off"
ENV PHP_POST_MAX_SIZE=100M
ENV PHP_UPLOAD_MAX_FILESIZE=50M
ENV PHP_MAX_FILE_UPLOADS=20
ENV PHP_ACCESS_LOG="/dev/null"
ENV PHP_TRACK_ERRORS=Off
ENV PHP_ACCESS_FORMAT="{ \"type\": \"access\", \"time\": \"%t\", \"environment\": \"%{APP_ENV}e\", \"method\": \"%m\", \"request_uri\": \"%r%Q%q\", \"status_code\": \"%s\", \"cost_time\": %{mili}d, \"cpu_usage\": { \"user\" : %{user}C, \"system\": %{system}C, \"total\": %{total}C }, \"memory_usage\": %{bytes}M, \"remote_ip\": \"%R\", \"module\": \"php-fpm\", \"log_type\": \"access-log\" }"


ENV PHP_YAF_USE_NAMESPACE=Off
ENV PHP_YAF_USE_SPL_AUTOLOAD=On
ENV PHP_YAR_CONNECT_TIMEOUT=1000
ENV PHP_YAR_TIMEOUT=5000
ENV PHP_YAR_DEBUG=off

ENV PHP_OPCACHE_ENABLE=1
ENV PHP_OPCACHE_ENABLE_CLI=1
ENV PHP_OPCACHE_MEMORY_CONSUMPTION=128
ENV PHP_OPCACHE_INTERNED_STRINGS_BUFFER=8
ENV PHP_OPCACHE_MAX_ACCELERATED_FILES=100000
ENV PHP_OPCACHE_MAX_WASTED_PERCENTAGE=5
ENV PHP_OPCACHE_USE_CWD=1
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
ENV PHP_OPCACHE_REVALIDATE_FREQ=0
ENV PHP_OPCACHE_FAST_SHUTDOWN=1
ENV PHP_OPCACHE_CONSISTENCY_CHECKS=0
ENV PHP_OPCACHE_BLACKLIST_FILENAME=/var/www/html/.opcacheignore

ENV BLACKFIRE_CLIENT_ID="c9838c89-051d-445e-8d67-6e53e26aca6a"
ENV BLACKFIRE_CLIENT_TOKEN="0cb6cb6bf59aed0510db0d4957ed17441c31adc27d28d8f22709f563c95acabd"
ENV BLACKFIRE_SERVER_ID="b42d01d2-efd6-462f-a051-a4a5a8080237"
ENV BLACKFIRE_SERVER_TOKEN="ce2d1a38cfbd7a3f6317e32afeadc4fe723746ee4baae8a08fb36cc5b1ed1d03"
ENV BLACKFIRE_AGENT_SOCKET="tcp://blackfire:8307"
ENV BLACKFIRE_ENDPOINT="https://blackfire.io"
ENV BLACKFIRE_LOG_LEVEL=4
ENV BLACKFIRE_LOG_FILE=/tmp/probe.log

ENV APP_NAME="test"
ENV APP_PREFIX=""
ENV PHP_SKYWALKING_ENABLE=1
ENV PHP_SKYWALKING_VERSION=8
ENV PHP_SKYWALKING_GRPC="skywalking-oap.istio-system.svc.cluster.local:11800"
ENV PHP_SKYWALKING_ERROR_HANDLER_ENABLE=0
ENV PHP_SKYWALKING_SAMPLE_N_PER_3_SEC=3
ENV PHP_SKYWALKING_INSTANCE_NAME=""
ENV PHP_SKYWALKING_LOG_ENABLE=0
ENV PHP_SKYWALKING_AUTHENTICATION=""
ENV PHP_SKYWALKING_MQ_MAX_MESSAGE_LENGTH=204800

COPY php-config/php.ini "$PHP_INI_DIR"
COPY php-config/conf.d/ "$PHP_INI_DIR"/conf.d/
COPY php-config/php-fpm.conf /usr/local/etc/
COPY php-config/www.conf /usr/local/etc/php-fpm.d/

EXPOSE 9000

RUN rm -fr /usr/local/etc/php-fpm.d/zz-docker.conf
COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm"]

