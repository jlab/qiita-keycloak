PODMAN_FLAGS =
PODMAN_BIN = docker buildx
DIR_REFERENCES=references
# docker compose prepends name of directory to containers

TMPDIR := $(shell mktemp -d)
ifeq ($(origin tmpdir), undefined)
tmpdir = $(TMPDIR)
endif

include Configuration/makefile

# a general target, executed for each plugin
plugin: Images/trigger.py Images/start_plugin.sh $(DIR_REFERENCES)/qiita_server_certificates Images/test_plugin.sh
	cp -r $^ $(tmpdir)/

.built_image_qtp-biom: Images/qtp-biom/qtp-biom.dockerfile src/qiita-files/ src/qtp-biom/ Images/qtp-biom/requirements.txt
	test -d src/qtp-biom || git clone https://github.com/qiita-spots/qtp-biom.git src/qtp-biom
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp -r $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-sequencing: Images/qtp-sequencing/qtp-sequencing.dockerfile Images/qtp-sequencing/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

# download GG13.8 reference sets from ftp://ftp.microbio.me/greengenes_release/gg_13_8_otus, instead of storing these large files within the qp-target-gene image 149 MB
$(DIR_REFERENCES)/qp-target-gene:
	mkdir -p $(DIR_REFERENCES)/qp-target-gene
	echo '56ef15dccf2e931ec173f4f977ed649b  97_otu_taxonomy.txt' > $(DIR_REFERENCES)/qp-target-gene/exp.md5
	echo '50b2269712b3738afb41892bed936c29  97_otus.fasta' >> $(DIR_REFERENCES)/qp-target-gene/exp.md5
	echo 'b7e76593bce82913af1cfb06edf15732  97_otus.tree' >> $(DIR_REFERENCES)/qp-target-gene/exp.md5
	wget 'ftp://ftp.microbio.me/greengenes_release/gg_13_8_otus/trees/97_otus.tree' -O $(DIR_REFERENCES)/qp-target-gene/97_otus.tree
	wget 'ftp://ftp.microbio.me/greengenes_release/gg_13_8_otus/taxonomy/97_otu_taxonomy.txt' -O $(DIR_REFERENCES)/qp-target-gene/97_otu_taxonomy.txt
	wget 'ftp://ftp.microbio.me/greengenes_release/gg_13_8_otus/rep_set/97_otus.fasta' -O $(DIR_REFERENCES)/qp-target-gene/97_otus.fasta
	cd $(DIR_REFERENCES)/qp-target-gene/ && md5sum -c exp.md5 || rm -rf $(DIR_REFERENCES)/qp-target-gene/

.built_image_qp-target-gene: Images/qp-target-gene/qp-target-gene.dockerfile $(DIR_REFERENCES)/qp-target-gene Images/qp-target-gene/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp -r $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-visualization: Images/qtp-visualization/qtp-visualization.dockerfile Images/qtp-visualization/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-diversity: Images/qtp-diversity/qtp-diversity.dockerfile Images/qtp-diversity/requirements.txt
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

.built_image_qp-deblur: Images/qp-deblur/qp-deblur.dockerfile $(DIR_REFERENCES)/qp-deblur/reference-gg-raxml-bl.tre Images/qp-deblur/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qp-qiime2: Images/qp-qiime2/qp-qiime2.dockerfile
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_qtp-job-output-folder: Images/qtp-job-output-folder/qtp-job-output-folder.dockerfile Images/qtp-job-output-folder/requirements.txt
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-`basename $< | cut -d "." -f 1`
	touch .built_image_`basename $< | cut -d "." -f 1`

.built_image_nginx: Images/nginx/nginx.dockerfile Images/nginx/start_nginx.sh Configuration/nginx_qiita.conf
	cd Images/nginx && cp ../../Configuration/nginx_qiita.conf . && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-nginx
	mkdir -p ./logs
	touch ./logs/nginx_access.log ./logs/nginx_error.log
	chmod a+rw ./logs/nginx_access.log ./logs/nginx_error.log
	touch .built_image_nginx

.built_image_qiita: Images/qiita/qiita.dockerfile Configuration/config_qiita_oidc.cfg Images/qiita/start_qiita.sh Images/qiita/start_qiita-initDB.sh Images/qiita/supervisor_foreground.conf Images/qiita/start_plugin.py Configuration/config_portal.cfg Images/qiita/drop_workflows.py
	test -d src/qiita || git clone -b auth_oidc https://github.com/jlab/qiita.git src/qiita
	# remove configuration and certificate files from upstream qiita repo
	rm -rf src/qiita/qiita_core/support_files
	cd Images/qiita && $(PODMAN_BIN) build . -f `basename $<` $(PODMAN_FLAGS) -t local-qiita
	touch .built_image_qiita

.built_image_plugin_collector: Images/plugin_collector/plugin_collector.dockerfile Images/plugin_collector/fix_test_db.py Images/plugin_collector/collect_configs.py Images/plugin_collector/start_plugin_collector.sh
	tmpdir=$(TMPDIR) $(MAKE) plugin
	cp $^ $(TMPDIR)
	$(PODMAN_BIN) build $(TMPDIR)/ -f $(TMPDIR)/`basename $<` $(PODMAN_FLAGS) -t local-plugin_collector
	touch .built_image_plugin_collector

images: .built_image_qtp-biom .built_image_nginx .built_image_qiita .built_image_plugin_collector .built_image_qtp-sequencing .built_image_qp-target-gene .built_image_qtp-visualization .built_image_qtp-diversity .built_image_qp-deblur .built_image_qp-qiime2 .built_image_qp-qiime2 .built_image_qtp-job-output-folder

make clean:
	rm -f .built_image_*
	rm -rf $(DIR_REFERENCES)
	git checkout Configuration/config_qiita_oidc.cfg Configuration/tinqiita_cert.conf Configuration/tinqiita_csr.conf
	rm -f Configuration/qiita_db.env Configuration/redis.env
	rm -rf /var/lib/docker/volumes/tinqiita_server-certificates/_data/*
	rm -rf /var/lib/docker/volumes/tinqiita_server-plugin-configs/_data/*

all: propagate_configuration images
