#!/bin/bash
#SBATCH -p qiita
#SBATCH --mail-user "qiita.help@gmail.com"
#SBATCH --job-name 022820b8-4977-407c-ba75-ccb046180f87
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --time 12:00:00
#SBATCH --mem 5g
#SBATCH --output /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87/022820b8-4977-407c-ba75-ccb046180f87_%a.log
#SBATCH --error /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87/022820b8-4977-407c-ba75-ccb046180f87_%a.err
#SBATCH --array 1-1%12
cd /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87
set -e
mkdir -p reads/uneven sams
true
date
hostname
echo ${SLURM_JOBID} ${SLURM_ARRAY_TASK_ID}
dbbase=/databases
dbname=synDNA
output=/qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87
while read -r sn f;
  do
    fn=`basename $f`; 
    bowtie2 -p 8 -x /databases/pUC57 -q ${f} --seed 42 --very-sensitive -k 16 --np 1 --mp "1,1" --rdg "0,1" --rfg "0,1" --score-min "L,0,-0.05" --no-head --no-unal --no-exact-upfront --no-1mm-upfront | sam_filter -i 0.98 -r 0.90 | awk '{print $1}' > $PWD/reads/uneven/${fn/.gz/}.seqID.txt; seqkit grep -v -f $PWD/reads/uneven/${fn/.gz/}.seqID.txt ${f} > $PWD/reads/uneven/no-plasmid-${fn/.gz/}
    bowtie2 -p 8 -x /databases/synDNA -q $PWD/reads/uneven/no-plasmid-${fn/.gz/} -S $PWD/sams/${sn}.sam --seed 42 --very-sensitive -k 16 --np 1 --mp "1,1" --rdg "0,1" --rfg "0,1" --score-min "L,0,-0.05" --no-head --no-unal --no-exact-upfront --no-1mm-upfront --un $PWD/reads/uneven/no-plasmid-inserts-${fn/.gz/}
    bowtie2 -p 8 -x /databases/CP026085 -q $PWD/reads/uneven/no-plasmid-inserts-${fn/.gz/} -S $PWD/reads/uneven/no-plasmid-inserts-${sn}.sam --seed 42 --very-sensitive -k 16 --np 1 --mp "1,1" --rdg "0,1" --rfg "0,1" --score-min "L,0,-0.05" --no-head --no-unal --no-exact-upfront --no-1mm-upfront --un $PWD/reads/uneven/${fn/.gz/}
  done < sample_details_${SLURM_ARRAY_TASK_ID}.txt
