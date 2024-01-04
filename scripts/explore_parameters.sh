#!/bin/bash

BASEPATH=$(pwd)
CODEPATH=${BASEPATH}/code
OUTPATH=${BASEPATH}/test
INPATH=${BASEPATH}/input
SUMMARY=${INPATH}/summaries.csv
TO_PREDICT=${INPATH}/to_predict.csv

PREDICT=${CODEPATH}/predict

cutoff_list="90 140"
exp_list="65"
ptw_list=$(seq 950 5 975)
ydw_list="4 5 6"
iter_list="1 2 3"
bowl_list=$(seq 70 5 95)
decay_list=$(seq 910 10 990)

for iter in ${iter_list}
do
  iter_p=${iter}
  for cutoff in ${cutoff_list}
  do
    cutoff_p=${cutoff}
    for exp in ${exp_list}
    do
      exp_p="2.${exp}"
      for ptw in ${ptw_list}
      do
        ptw_p="0.${ptw}"
        for ydw in ${ydw_list}
        do
          ydw_p="0.00${ydw}"
          for bowl in ${bowl_list}
          do
            bowl_p="0.${bowl}"
            for decay in ${decay_list}
            do
              decay_p="0.${decay}"
              params="${cutoff}_${exp}_${ptw}_${ydw}_${iter}_${bowl}_${decay}"
#              echo ${params}
              outfile=${OUTPATH}/${params}.out
              errfile=${OUTPATH}/${params}.err
              ${PREDICT} -s ${SUMMARY} -t ${TO_PREDICT} -e ${exp_p} -w ${decay_p} \
                -b ${bowl_p} -p ${ptw_p} -y ${ydw_p} -c ${cutoff_p} \
                -a ${iter_p} > ${outfile} 2> ${errfile}
              bzip2 ${outfile}
              bzip2 ${errfile}
              echo -n .
            done
          done
        done
      done
    done
  done &
done
