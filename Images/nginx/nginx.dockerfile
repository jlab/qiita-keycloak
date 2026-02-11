# VERSION: 2026.02.08

FROM yspreen/nginx

COPY nginx_qiita.conf /
COPY start_nginx.sh /

RUN chmod 777 nginx_qiita.conf
RUN chmod 777 start_nginx.sh

RUN mkdir -p /var/log/nginx

# for reference, if user wants to inspect image
COPY *.dockerfile /

CMD ["/start_nginx.sh"]
