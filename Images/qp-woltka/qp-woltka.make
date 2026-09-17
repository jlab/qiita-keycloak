# read up about different databases: https://qiita.ucsd.edu/static/doc/html/processingdata/processing-recommendations.html#reference-databases

# obtains KEGG functional mappings from wol2 knightlab FTP server.
# This set of files can be used for wol_107 as well as WoLr2
$(DIR_REFERENCES)/qp-woltka/WoLr2/function/kegg:
	mkdir -p $@/raw;
	cd $@; \
	for file in `echo "compound_name.txt disease_name.txt ko-to-cog.map ko-to-disease.map ko-to-ec.map ko-to-go.map ko-to-module.map ko-to-pathway.map ko-to-reaction.map ko_name.txt module-to-class.map module-to-compound.map module-to-ko.map module-to-pathway.map module-to-reaction.map module_name.txt orf-to-ko.map.md5 orf-to-ko.map.xz pathway-to-class.map pathway-to-compound.map pathway-to-disease.map pathway-to-ko.map pathway-to-module.map pathway_name.txt rclass_name.txt reaction-to-ko.map reaction-to-left_compound.map reaction-to-module.map reaction-to-pathway.map reaction-to-rclass.map reaction-to-right_compound.map reaction_enzyme.txt reaction_equation.txt reaction_name.txt raw/kofamscan.tsv.md5 raw/kofamscan.tsv.xz"`; do \
		if [ ! -f $$file ]; then \
			wget -O $$file https://ftp.microbio.me/pub/wol2/function/kegg/$$file; \
		fi; \
	done;

# a test database: ~70 MB
$(DIR_REFERENCES)/qp-woltka/rep82:
	mkdir -p `dirname $@`
	wget -q -O - https://github.com/qiita-spots/qp-woltka/raw/refs/heads/main/qp_woltka/databases/woltka/rep82.tar.gz | tar xvz -C `dirname $@`

# another test database: ~54 MB
$(DIR_REFERENCES)/qp-woltka/wol:
	mkdir -p `dirname $@`
	wget -q -O - https://github.com/qiita-spots/qp-woltka/raw/refs/heads/main/qp_woltka/databases/woltka/wol.tar.gz | tar xvz -C `dirname $@`

# a medium test database of "only" 107 selected genomes, not necessary for production: ~855 MB
$(DIR_REFERENCES)/qp-woltka/wol_107: $(DIR_REFERENCES)/qp-woltka/WoLr2/function/kegg
	mkdir -p $@/tmp
	cd $@/tmp; \
	if [ ! -f nucl2g.txt ]; then \
		wget https://raw.githubusercontent.com/qiyunzhu/woltka/refs/heads/main/woltka/tests/data/taxonomy/nucl/nucl2g.txt; \
	fi; \
	while IFS= read -r entry; do \
		acc=`echo "$$entry" | cut -f 1`; \
		gid=`echo "$$entry" | cut -f 2`; \
		if [ ! -f $${acc}.fasta ]; then \
			wget -O $${acc}.fasta "https://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?id=$${acc}&db=nuccore&report=fasta&retmode=text"; \
		fi; \
		if [ ! -f $${acc}.fasta.mapped ]; then \
			echo ">$$gid" > $${acc}.fasta.mapped; \
			tail -n +2 $${acc}.fasta >> $${acc}.fasta.mapped; \
 		fi; \
	done < nucl2g.txt;
	cd $@/tmp && \
		if [ ! -f all107.fasta ]; then \
			cat *.fasta.mapped > all107.fasta; \
		fi;
	cd $@ && \
		if [ ! -f wol_107.4.bt2 ]; then \
			bowtie2-build -f --threads `nproc --ignore 1` tmp/all107.fasta ./wol_107; \
		fi;
	cd $@/tmp && \
		if [ ! -d woltka-main ]; then \
			wget https://github.com/qiyunzhu/woltka/archive/refs/heads/main.zip && unzip main.zip && rm main.zip; \
		fi;
	cd $@ && \
		cp -vfr tmp/woltka-main/woltka/tests/data/taxonomy/lineages.txt $(notdir $@).tax; \
		mkdir -p genomes; \
		cp -vfr tmp/woltka-main/woltka/tests/data/taxonomy/length.map genomes/length.map; \
		xz -dc tmp/woltka-main/woltka/tests/data/function/coords.txt.xz > $(notdir $@).coords;
	cp -v -r $(DIR_REFERENCES)/qp-woltka/WoLr2/function $@

# the most important database, i.e. Web of Life release 2. This DB is ~90 GB
# Some insight from Antonio
# genomes/length.map
#- Yours is built from checkm.tsv (columns 1 and 9). Ours is
#  https://ftp.microbio.me/pub/wol2/genomes/length.map
#- Yours has a header line, and the length differs for 13,872 of 15,953 genomes.
#- It is not used for the alignment. It is used for the micov coverage output and
#  the cell-count command.
#- To get ours, replace the checkm.tsv line in your Makefile with:
#  wget -q -O $$file https://ftp.microbio.me/pub/wol2/genomes/length.map
#Versions
#bowtie2 2.5.4, woltka 0.1.7, polars 1.9.0, qp-woltka 2024.9 (commit d58f231, plus
#local edits to job resources and error messages that do not change the mxdx/bowtie2
#or woltka classify commands). mxdx and micov are installed from source and report
#"0+unknown".
#There is no written guide for building the database. The expected layout is defined
#in _process_database_files (qp_woltka/woltka.py) and the test database in
#qp_woltka/databases/woltka/wol.
$(DIR_REFERENCES)/qp-woltka/WoLr2: $(DIR_REFERENCES)/qp-woltka/WoLr2/function/kegg
	mkdir -p $@
	for file in `echo "WoLr2.1.bt2l WoLr2.2.bt2l WoLr2.3.bt2l WoLr2.4.bt2l WoLr2.rev.1.bt2l WoLr2.rev.2.bt2l"`; do \
		if [ ! -f $@/$$file ]; then \
			wget -q -P $@/ https://ftp.microbio.me/pub/wol2/databases/bowtie2/$$file; \
		fi; \
	done; \
	file=$(notdir $@).tax; if [ ! -f $$file ]; then \
		wget -q -O $$file https://ftp.microbio.me/pub/wol2/taxonomy/lineages.txt; \
	fi; \
	file=$@/genomes/length.map; if [ ! -f $$file ]; then \
		mkdir -p `dirname $$file`; \
		wget -q https://ftp.microbio.me/pub/wol2/genomes/length.map -O $$file; \
		
	fi; \
	file=$(notdir $@).coords; if [ ! -f $$file ]; then \
		wget -q https://ftp.microbio.me/pub/wol2/proteins/coords.txt.xz -O - | xz -dc > $$file; \
	fi;

# an even larger DB: 304G
# I currently don't know if there is KEGG mapping?!
$(DIR_REFERENCES)/qp-woltka/RS225:
	mkdir -p $@
	for file in `echo "RS225.1.bt2l RS225.2.bt2l RS225.3.bt2l RS225.4.bt2l RS225.rev.1.bt2l RS225.rev.2.bt2l"`; do \
		if [ ! -f $@/$$file ]; then \
			wget -q -P $@/ https://ftp.microbio.me/pub/RS225/bowtie2/$$file; \
		fi; \
	done; \
	file=$(notdir $@).tax; if [ ! -f $$file ]; then \
		wget -q -O $$file https://ftp.microbio.me/pub/RS225/lineages.txt; \
	fi; \
	file=$@/genomes/length.map; if [ ! -f $$file ]; then \
		mkdir -p `dirname $$file`; \
		wget -q https://ftp.microbio.me/pub/RS225/length.map -O - > $$file; \
	fi;

	
# a target to make all databases
$(DIR_REFERENCES)/qp-woltka: $(DIR_REFERENCES)/qp-woltka/wol $(DIR_REFERENCES)/qp-woltka/rep82 $(DIR_REFERENCES)/qp-woltka/wol_107 $(DIR_REFERENCES)/qp-woltka/WoLr2 $(DIR_REFERENCES)/qp-woltka/RS225
