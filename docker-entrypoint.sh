#!/bin/sh

export APP_ENV=${APP_ENV:-production}

export EXEC_CMD="${EXEC_CMD:-date}"
php -v
echo "检测当前环境:${APP_ENV}"

echo "执行自定义命令${EXEC_CMD}"
${EXEC_CMD}

exec "$@"

