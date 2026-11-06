#!/bin/bash
#SBATCH -p qiita
#SBATCH --mail-user "qiita.help@gmail.com"
#SBATCH --job-name finish-022820b8-4977-407c-ba75-ccb046180f87
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --time 15
#SBATCH --mem 6g
#SBATCH --output /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87/finish-022820b8-4977-407c-ba75-ccb046180f87.log
#SBATCH --error /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87/finish-022820b8-4977-407c-ba75-ccb046180f87.err
cd /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87
set -e
true
date
hostname
echo $SLURM_JOBID
sruns=`grep 'overall alignment rate' *.err | wc -l`
sjobs=`ls sams/*.sam | wc -l`
if [[ $sruns -eq $((3*sjobs)) ]]; then
  mkdir -p sams/final
  while read -r fwd rev; do echo "fastq_pair -t 50000000 reads/uneven/${fwd} reads/uneven/${rev}; mv reads/uneven/${fwd}.paired.fq reads/${fwd}; mv reads/uneven/${rev}.paired.fq reads/${rev}; gzip reads/${fwd} reads/${rev}"; done < finish_sample_details.txt | parallel -j 8
  for f in `ls sams/fwd_*`;
    do
      fn=`basename $f`;
      lines=`head $f | wc -l`
      if [[ "$lines" != "0" ]]; then echo cp ${f} sams/final/${fn:4} ; fi ;
  done | parallel -j 8
  for f in `ls sams/rev_*`;
    do
      fn=`basename $f`;
      lines=`head $f | wc -l`
      if [[ "$lines" != "0" ]]; then echo "cat ${f} >> sams/final/${fn:4}" ; fi ;
  done | parallel -j 8
  woltka classify -i sams/final/ -o syndna.biom --no-demux
  for f in `ls sams/final/*.sam`;
    do
      echo "cat ${f} | cut -f1-9 | sed 's/$/	*	*/' | xz -1 -T1 > ${f}.xz; rm ${f}"
  done | parallel -j 8
  cd sams/final/; tar -cvf alignment.tar *.sam.xz; cd ../../;
fi
finish_woltka https://qiita-dev.jlab.bio 022820b8-4977-407c-ba75-ccb046180f87 /qiita_data/working_dir/022820b8-4977-407c-ba75-ccb046180f87
