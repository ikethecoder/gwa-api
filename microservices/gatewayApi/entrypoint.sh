#!/bin/sh

mkdir -p ./config

cat > "${CONFIG_PATH:-./config/default.json}" <<EOF
{
    "logLevel": "${LOG_LEVEL:-DEBUG}",
    "apiPort": ${PORT:-2000},
    "oidcBaseUrl": "$OIDC_BASE_URL",
    "tokenMatch": {
        "aud": "$TOKEN_MATCH_AUD"
    },
    "kongAdminUrl": "$KONG_ADMIN_URL",
    "workingFolder": "$WORKING_FOLDER",
    "keycloak": {
        "serverUrl": "$KC_SERVER_URL",
        "realm": "$KC_REALM",
        "clientId": "$KC_CLIENT_ID",
        "clientSecret": "$KC_CLIENT_SECRET",
        "userRealm": "$KC_USER_REALM",
        "username": "$KC_USERNAME",
        "password": "$KC_PASSWORD"
    },
    "resourceAuthServer": {
        "serverUrl": "$KC_SERVER_URL",
        "realm": "$KC_REALM",
        "clientId": "$KC_RES_SVR_CLIENT_ID",
        "clientSecret": "$KC_RES_SVR_CLIENT_SECRET"
    },
    "applyAporetoNSP": ${NSP_ENABLED:-true},
    "protectedKubeNamespaces": "${PROTECTED_KUBE_NAMESPACES:-[]}",
    "hostTransformation": {
        "enabled": ${HOST_TRANSFORM_ENABLED:-false},
        "baseUrl": "${HOST_TRANSFORM_BASE_URL}"
    },
    "portal": {
        "url": "${PORTAL_ACTIVITY_URL:-""}",
        "token": "${PORTAL_ACTIVITY_TOKEN}"
    },
    "plugins": {
        "rate_limiting": {
            "redis_database": 0,
            "redis_host": "redis-master",
            "redis_port": 6379,
            "redis_password": "${PLUGINS_RATELIMITING_REDIS_PASSWORD}",
            "redis_timeout": 2000
        }
    }
}
EOF

cat > /tmp/deck.yaml <<EOF
kong-addr: $KONG_ADMIN_URL
EOF

python3 wsgi.py
