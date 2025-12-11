FROM quay.io/nginx/nginx-unprivileged:1.29.3-alpine
# nginx uid=101
USER nginx
COPY --chown=101:101 index.html /usr/share/nginx/html/index.html
EXPOSE 8080
ENTRYPOINT ["nginx", "-g", "daemon off;"]