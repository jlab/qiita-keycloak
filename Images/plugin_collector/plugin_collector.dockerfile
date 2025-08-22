FROM ubuntu:24.04

RUN apt-get -y update
RUN apt-get -y --fix-missing install \
	curl \
	python3 \
	python3-requests \
	python3-psycopg2

COPY collect_configs.py /collect_configs.py
COPY fix_test_db.py /fix_test_db.py
COPY startup_plugin_collector.sh /startup_plugin_collector.sh
RUN chmod u+x /startup_plugin_collector.sh

CMD /startup_plugin_collector.sh