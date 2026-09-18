# downloads default fasta database: https://github.com/qiita-spots/qp-meta/blob/6bf7f83a4586069f9426588a59ee26652768c6e6/.github/workflows/qiita-plugin-ci.yml#L98-L99
# and pre-compiles one of these databases into an index: https://github.com/qiita-spots/qp-meta/blob/6bf7f83a4586069f9426588a59ee26652768c6e6/qp_meta/sortmerna/sortmerna.py#L18-L19

$(DIR_REFERENCES)/qp-meta/rRNA_databases:
	mkdir -p $@/;
	if [ ! -f $@/smr_v4.3_default_db.fasta || ! -f $@/smr_v4.3_fast_db.fasta || ! -f $@/smr_v4.3_sensitive_db.fasta || ! -f $@/smr_v4.3_sensitive_db_rfam_seeds.fasta ]; then \
		cd $@; \
		wget https://github.com/sortmerna/sortmerna/releases/download/v4.3.4/database.tar.gz; \
		tar zxvf database.tar.gz; \
		rm -f database.tar.gz; \
	fi;
	for file in `echo "smr_v4.3_default_db.fasta"`; do \
		sortmerna --ref $@/$$file --idx-dir $@/idx/ --index 1 --threads `nproc --ignore 1`; \
	done;