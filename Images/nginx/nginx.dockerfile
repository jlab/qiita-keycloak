# VERSION: 2025.08.28

FROM yspreen/nginx

COPY nginx_qiita.conf /
COPY start_nginx.sh /

RUN chmod 777 nginx_qiita.conf
RUN chmod 777 start_nginx.sh

RUN mkdir -p /var/log/nginx

CMD ["nginx", "/start_nginx.sh"]
