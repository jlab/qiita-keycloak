PODMAN_FLAGS =
PODMAN_BIN = docker buildx
CERTNAME=stefan
OPENSSL=/bin/openssl

Certificates/: Images/plugin_collector/stefan_csr.conf Images/plugin_collector/stefan_cert.conf
	# === create own certificates ===
	mkdir -p Certificates/
	# Generate a new root CA private key and certificate
	cd $@/ && $(OPENSSL) req -x509 -sha256 -days 356 -nodes -newkey rsa:2048 -subj "/CN=qiita-container-anna-qiita-1/C=DE/L=Giessen" -keyout $(CERTNAME)_rootca.key -out $(CERTNAME)_rootca.crt
	# Generate a new server private key
	cd $@/ && $(OPENSSL) genrsa -out $(CERTNAME)_server.key 2048
	# Copy the following to a new file named csr.conf and modify to suit your needs
	# Copy the following to a new file named cert.conf and modify to suit your needs
	# Nils: alt_names is the important aspect. Make entries for all valid hostnames with which services shall be addressed
	cp $^ $@/
	# Generate a certificate signing request
	cd $@/ && $(OPENSSL) req -new -key $(CERTNAME)_server.key -out $(CERTNAME)_server.csr -config $(CERTNAME)_csr.conf
	# Generate a new signed server.crt to use with your server.key
	cd $@/ && $(OPENSSL) x509 -req -in $(CERTNAME)_server.csr -CA $(CERTNAME)_rootca.crt -CAkey $(CERTNAME)_rootca.key -CAcreateserial -out $(CERTNAME)_server.crt -days 365 -sha256 -extfile $(CERTNAME)_cert.conf
	# === end: create own certificates ===

TMPDIR=$(shell mktemp -d)
plugin: Images/qtp-biom/trigger.py Certificates/
	cp -r $^ $(TMPDIR)/
	cd $(TMPDIR)

.built_image_biom: Images/qtp-biom/qtp-biom.dockerfile Images/qtp-biom/start_qtp-biom.sh Images/qtp-biom/trigger.py Certificates/
	rm -rf Images/qtp-biom/Certificates && cp -r Certificates Images/qtp-biom/
	cd Images/qtp-biom && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qtp-biom
	touch .built_image_biom

.built_image_sequencing: Images/qtp-sequencing/qtp-sequencing.dockerfile Images/qtp-sequencing/start_qtp-sequencing.sh Images/qtp-biom/trigger.py Certificates/
	rm -rf Images/qtp-sequencing/Certificates && cp -r Certificates Images/qtp-sequencing/
	cp Images/qtp-biom/trigger.py Images/qtp-sequencing/
	cd Images/qtp-sequencing && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qtp-sequencing
	touch .built_image_sequencing

.built_image_target-gene: Images/qp-target-gene/qp-target-gene.dockerfile Images/qp-target-gene/start_qp-target-gene.sh Images/qtp-biom/trigger.py Certificates/
	rm -rf Images/qp-target-gene/Certificates && cp -r Certificates Images/qp-target-gene/
	cp Images/qtp-biom/trigger.py Images/qp-target-gene/
	cd Images/qp-target-gene && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qp-target-gene
	touch .built_image_target-gene

.built_image_nginx: Images/nginx/nginx.dockerfile Images/nginx/start_nginx.sh Images/nginx/nginx_qiita.conf
	cd Images/nginx && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-nginx_qiita
	mkdir -p ./logs
	touch ./logs/nginx_access.log ./logs/nginx_error.log
	chmod a+rw ./logs/nginx_access.log ./logs/nginx_error.log
	touch .built_image_nginx

.built_image_qiita: Images/qiita/qiita.dockerfile Images/qiita/config_qiita_oidc.cfg Images/qiita/start_qiita.sh Images/qiita/supervisor_foreground.conf Images/qiita/start_plugin.py
	test -d src/qiita || git clone -b auth_oidc https://github.com/jlab/qiita.git src/qiita
	# remove configuration and certificate files from upstream qiita repo
	rm -rf src/qiita/qiita_core/support_files
	cd Images/qiita && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qiita
	touch .built_image_qiita

.built_image_plugin_collector: Images/plugin_collector/plugin_collector.dockerfile Images/plugin_collector/fix_test_db.py Images/plugin_collector/collect_configs.py Images/plugin_collector/startup_plugin_collector.sh Certificates/
	cp -r Certificates/ Images/plugin_collector/
	cd Images/plugin_collector && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-plugin_collector
	touch .built_image_plugin_collector

images: .built_image_biom .built_image_nginx .built_image_qiita .built_image_plugin_collector .built_image_sequencing .built_image_target-gene

environments/qiita_db.env: environments/qiita_db.env.example
	cp environments/qiita_db.env.example environments/qiita_db.env
	sed -E -i "s/^POSTGRES_PASSWORD=.+$$/POSTGRES_PASSWORD=postgres/" environments/qiita_db.env

environments/qiita.env: environments/qiita.env.example
	cp environments/qiita.env.example environments/qiita.env

config: environments/qiita_db.env environments/qiita.env

all: config images
