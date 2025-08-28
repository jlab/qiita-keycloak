PODMAN_FLAGS =
PODMAN_BIN = docker buildx
CERTNAME=stefan
OPENSSL=/bin/openssl
DIR_REFERENCES=references
# docker compose prepends name of directory to containers

TMPDIR := $(shell mktemp -d)
ifeq ($(origin tmpdir), undefined)
tmpdir = $(TMPDIR)
endif

$(DIR_REFERENCES)/qiita_server_certificates: Images/plugin_collector/stefan_csr.conf Images/plugin_collector/stefan_cert.conf
	# === create own certificates ===
	mkdir -p $@
	# Generate a new root CA private key and certificate
	cd $@ && $(OPENSSL) req -x509 -sha256 -days 356 -nodes -newkey rsa:2048 -subj "/CN=tinqiita-nginx-1/C=DE/L=Giessen" -keyout $(CERTNAME)_rootca.key -out $(CERTNAME)_rootca.crt
	# Generate a new server private key
	cd $@ && $(OPENSSL) genrsa -out $(CERTNAME)_server.key 2048
	# Copy the following to a new file named csr.conf and modify to suit your needs
	# Copy the following to a new file named cert.conf and modify to suit your needs
	# Nils: alt_names is the important aspect. Make entries for all valid hostnames with which services shall be addressed
	for f in `echo "$^"`; do cat $$f > $@/`basename $$f`; done
	#cp $^ $@/
	# Generate a certificate signing request
	cd $@ && $(OPENSSL) req -new -key $(CERTNAME)_server.key -out $(CERTNAME)_server.csr -config $(CERTNAME)_csr.conf
	# Generate a new signed server.crt to use with your server.key
	cd $@ && $(OPENSSL) x509 -req -in $(CERTNAME)_server.csr -CA $(CERTNAME)_rootca.crt -CAkey $(CERTNAME)_rootca.key -CAcreateserial -out $(CERTNAME)_server.crt -days 365 -sha256 -extfile $(CERTNAME)_cert.conf
	# concat rootca and server certificates into one file
	cd $@ && cat $(CERTNAME)_rootca.crt $(CERTNAME)_server.crt > qiita_server_certificates.pem
	# === end: create own certificates ===

# a general target, executed for each plugin
plugin: Images/qtp-biom/trigger.py Images/qp-deblur/trigger_noconda.py $(DIR_REFERENCES)/qiita_server_certificates
	cp -r $^ $(tmpdir)/

.built_image_qtp-biom: Images/qtp-biom/qtp-biom.dockerfile Images/qtp-biom/start_qtp-biom.sh src/qiita-files/ src/qtp-biom/ Images/qtp-biom/requirements.txt
	test -d src/qtp-biom || git clone https://github.com/qiita-spots/qtp-biom.git src/qtp-biom
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp -r $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-sequencing: Images/qtp-sequencing/qtp-sequencing.dockerfile Images/qtp-sequencing/start_qtp-sequencing.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qp-target-gene: Images/qp-target-gene/qp-target-gene.dockerfile Images/qp-target-gene/start_qp-target-gene.sh Images/qp-target-gene/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-visualization: Images/qtp-visualization/qtp-visualization.dockerfile Images/qtp-visualization/start_qtp-visualization.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-diversity: Images/qtp-diversity/qtp-diversity.dockerfile Images/qtp-diversity/start_qtp-diversity.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

# download Silva and GG13.8 reference sets from bioconda fragment-insertion package, instead of storing these large files within the qp-deblur image ~1.3 GB
$(DIR_REFERENCES)/qp-deblur/reference-gg-raxml-bl.tre:
	mkdir -p $(DIR_REFERENCES)/tmp_sepp $(DIR_REFERENCES)/qp-deblur
	wget "https://anaconda.org/biocore/fragment-insertion/4.3.5/download/linux-64/fragment-insertion-4.3.5-py35_0.tar.bz2" -O $(DIR_REFERENCES)/tmp_sepp/fragment-insertion-4.3.5-py35_0.tar.bz2
	cd $(DIR_REFERENCES)/tmp_sepp && tar xjf fragment-insertion-4.3.5-py35_0.tar.bz2
	cp $(DIR_REFERENCES)/tmp_sepp/share/fragment-insertion/ref/* $(DIR_REFERENCES)/qp-deblur/
	rm -rf $(DIR_REFERENCES)/tmp_sepp/

.built_image_qp-deblur: Images/qp-deblur/qp-deblur.dockerfile Images/qp-deblur/start_qp-deblur.sh $(DIR_REFERENCES)/qp-deblur/reference-gg-raxml-bl.tre Images/qp-deblur/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qp-qiime2: Images/qp-qiime2/qp-qiime2.dockerfile Images/qp-qiime2/start_qp-qiime2.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-job-output-folder: Images/qtp-job-output-folder/qtp-job-output-folder.dockerfile Images/qtp-job-output-folder/start_qtp-job-output-folder.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_nginx: Images/nginx/nginx.dockerfile Images/nginx/start_nginx.sh Images/nginx/nginx_qiita.conf
	cd Images/nginx && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-nginx_qiita
	mkdir -p ./logs
	touch ./logs/nginx_access.log ./logs/nginx_error.log
	chmod a+rw ./logs/nginx_access.log ./logs/nginx_error.log
	touch .built_image_nginx

.built_image_qiita: Images/qiita/qiita.dockerfile Images/qiita/config_qiita_oidc.cfg Images/qiita/start_qiita.sh Images/qiita/start_qiita-initDB.sh Images/qiita/supervisor_foreground.conf Images/qiita/start_plugin.py Images/qiita/config_portal.cfg Images/qiita/drop_workflows.py
	test -d src/qiita || git clone -b auth_oidc https://github.com/jlab/qiita.git src/qiita
	# remove configuration and certificate files from upstream qiita repo
	rm -rf src/qiita/qiita_core/support_files
	cd Images/qiita && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qiita
	touch .built_image_qiita

.built_image_plugin_collector: Images/plugin_collector/plugin_collector.dockerfile Images/plugin_collector/fix_test_db.py Images/plugin_collector/collect_configs.py Images/plugin_collector/startup_plugin_collector.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-plugin_collector
	touch .built_image_plugin_collector

images: .built_image_qtp-biom .built_image_nginx .built_image_qiita .built_image_plugin_collector .built_image_qtp-sequencing .built_image_qp-target-gene .built_image_qtp-visualization .built_image_qtp-diversity .built_image_qp-deblur .built_image_qp-qiime2 .built_image_qp-qiime2 .built_image_qtp-job-output-folder

environments/qiita_db.env: environments/qiita_db.env.example
	cp environments/qiita_db.env.example environments/qiita_db.env
	sed -E -i "s/^POSTGRES_PASSWORD=.+$$/POSTGRES_PASSWORD=postgres/" environments/qiita_db.env

environments/qiita.env: environments/qiita.env.example
	cp environments/qiita.env.example environments/qiita.env

config: environments/qiita_db.env environments/qiita.env

make clean:
	rm .built_image_*
	rm -rf $(DIR_REFERENCES)
	rm -rf /var/lib/docker/volumes/tinqiita_server-certificates/_data/*
	rm -rf /var/lib/docker/volumes/tinqiita_server-plugin-configs/_data/*

all: config images
