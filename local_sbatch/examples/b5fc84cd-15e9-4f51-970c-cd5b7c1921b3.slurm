#!/bin/bash
#SBATCH	-p qiita
#SBATCH --mail-user "qiita.help@gmail.com"
#SBATCH --mail-type=FAIL,TIME_LIMIT_80,INVALID_DEPEND
#SBATCH --job-name b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --time 80:00:00
#SBATCH --mem 100g
#SBATCH --output /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3_%a.log
#SBATCH --error /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3_%a.err
#SBATCH --array 0-1%12
#SBATCH --constraint="amd"
cd /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
prep_full_path=/qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/prep_info.tsv
dummy
date
hostname
echo ${SLURM_JOBID} ${SLURM_ARRAY_TASK_ID}
dbbase=/databases/wol
dbname=WoLmin
output=/qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3
bt2_cores=6
mxdx mux --file-map /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/files_list.tsv --batch ${SLURM_ARRAY_TASK_ID} --batch-size 50000000 --paired-handling interleave | bowtie2 -p ${bt2_cores} -x /databases/wol/WoLmin --interleaved - --seed 42 --very-sensitive -k 16 --np 1 --mp "1,1" --rdg "0,1" --rfg "0,1" --score-min "L,0,-0.05" --no-head --no-unal --no-exact-upfront --no-1mm-upfront | cut -f1-9 | sed 's/$/	**/' | mxdx demux --file-map /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/files_list.tsv --batch ${SLURM_ARRAY_TASK_ID} --batch-size 50000000 --output-base /qiita_data/working_dir/b5fc84cd-15e9-4f51-970c-cd5b7c1921b3/alignments --extension sam.xz
date
