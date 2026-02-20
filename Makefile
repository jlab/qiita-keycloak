DIR_REFERENCES=references
# docker compose prepends name of directory to containers

include Configuration/makefile
include Images/makefile

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

# download Silva and GG13.8 reference sets from bioconda fragment-insertion package, instead of storing these large files within the qp-deblur image ~1.3 GB
$(DIR_REFERENCES)/qp-deblur/reference-gg-raxml-bl.tre:
	mkdir -p $(DIR_REFERENCES)/tmp_sepp $(DIR_REFERENCES)/qp-deblur
	wget "https://anaconda.org/biocore/fragment-insertion/4.3.5/download/linux-64/fragment-insertion-4.3.5-py35_0.tar.bz2" -O $(DIR_REFERENCES)/tmp_sepp/fragment-insertion-4.3.5-py35_0.tar.bz2
	cd $(DIR_REFERENCES)/tmp_sepp && tar xjf fragment-insertion-4.3.5-py35_0.tar.bz2
	cp $(DIR_REFERENCES)/tmp_sepp/share/fragment-insertion/ref/* $(DIR_REFERENCES)/qp-deblur/
	rm -rf $(DIR_REFERENCES)/tmp_sepp/

clean: clean_config
	rm -f .built_image_*
	rm -rf $(DIR_REFERENCES)
	rm -rf /var/lib/docker/volumes/tinqiita_server-certificates/_data/*
	rm -rf /var/lib/docker/volumes/tinqiita_server-plugin-configs/_data/*

all: propagate_configuration images

run-harbor: propagate_configuration
	# use harbor images instead of locally built ones
	sed -i "s|image: local-\(.*\)\(:\?\)|image: harbor.computational.bio.uni-giessen.de/tinqiita/\1\2|" compose.yaml

	# point qiita to the right certificate bundle of the self signed keycloak certificat
	if ! grep -q REQUESTS_CA_BUNDLE Configuration/qiita_db.env; then \
		echo "REQUESTS_CA_BUNDLE=/keycloak_certificates/keycloak_server_certificates.pem" >> Configuration/qiita_db.env; \
		echo "SSL_CERT_FILE=/keycloak_certificates/keycloak_server_certificates.pem" >> Configuration/qiita_db.env; \
	fi;
	#docker compose -f compose.yaml up
