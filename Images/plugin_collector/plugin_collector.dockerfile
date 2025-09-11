# VERSION: 2025.09.02

FROM ubuntu:24.04

RUN apt-get -y update
RUN apt-get -y --fix-missing install \
	curl \
	python3 \
	python3-requests \
	python3-psycopg2

COPY collect_configs.py /collect_configs.py
COPY fix_test_db.py /fix_test_db.py
COPY start_plugin_collector.sh /start_plugin_collector.sh
RUN chmod u+x /start_plugin_collector.sh

CMD /start_plugin_collector.sh