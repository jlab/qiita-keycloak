#!/bin/bash
#SBATCH -p qiita
#SBATCH --mail-user "qiita.help@gmail.com"
#SBATCH --job-name merge-b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
#SBATCH -N 1
#SBATCH -n 12
#SBATCH --time 25:00:00
#SBATCH --mem 80g
#SBATCH --output /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/merge-b5fc84cd-15e9-4f51-970c-cd5b7c1921b3.log
#SBATCH --error /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/merge-b5fc84cd-15e9-4f51-970c-cd5b7c1921b3.err
cd /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
dummy
date
hostname
echo $SLURM_JOBID
set -e
sruns=`grep 'overall alignment rate' *.err | wc -l`
if [[ ! -f "errors.log" && $sruns -eq "2" ]]; then
woltka_merge mxdx --base /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
mkdir -p /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/bioms
for f in `ls /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/alignments/*.sam.xz`; do bname=`basename ${f/.sam.xz/}`; mkdir -p /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/bioms/${bname}; echo woltka classify -i $f -o /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/bioms/${bname}/none.biom --no-demux --lineage /databases/wol/WoLmin.tax --rank none --outcov /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/coverages/; done | parallel -j 12
wait
for f in `ls /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/alignments/*.sam.xz`; do bname=`basename ${f/.sam.xz/}`; mkdir -p /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/bioms/${bname}; echo woltka classify -i $f -o /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/bioms/${bname}/per-gene.biom --no-demux -c /databases/wol/WoLmin.coords; done | parallel -j 12
wait
woltka_merge biom --base /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
cd /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3;

cd alignments; tar -cvf ../alignment.tar *.sam.xz; cd ..;
fi
finish_woltka https://tinqiita-nginx-1:8383 b5fc84cd-15e9-4f51-970c-cd5b7c1921b3 /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
date
