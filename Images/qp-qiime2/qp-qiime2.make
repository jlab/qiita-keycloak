$(DIR_REFERENCES)/qp-qiime2/gg/2024.09/2024.09.taxonomy.asv.nwk.qza:
	mkdir -p `dirname $@`;
	if [ ! -f $@ ]; then \
		wget -O $@ https://ftp.microbio.me/greengenes_release/2024.09/2024.09.taxonomy.asv.nwk.qza; \
	fi;
