ILE=$(shell which integrate_likelihood_extrinsic)
POST_GENERIC=$(shell which util_ConstructIntrinsicPosterior_GenericCoordinates.py)
PWD=$(shell pwd)

NPTS_START=1000
NPTS_IT=20
NPTS_PER_JOB=1000
DMAX=1000
N_IT=5

ILE_MEM=4096
CIP_MEM=4096

LNL_OFFSET=100000 # because we are fitting in low dimensions, we should keep more.

EVENT_TIME=1000000014.236547946
#APPROX=SEOBNRv4
APPROX=TaylorT4
APPROX_BNS=TaylorT4


###
### BBH 
###

FMIN_INJ_BH=8
FMIN_TEMPLATE_BH=10

### other stuff
#ECC=0.05
DIST=40.0
#ECC=0.0
FMIN_ECC=20.0
APPROX_ECC=taylorf2ecc
#APPROX_ECC=EccentricTD

### use for m1=20, m2=10
#M1=20.0
#M2=10.0
#MC_RANGE='[8.0,15.0]'
#ETA_RANGE='[0.2,0.249999999]'

### use for m1=6, m2 = 5
#M1=6.0
#M2=5.0
#MC_RANGE='[2.0,8.0]'
#ETA_RANGE='[0.2,0.249999999]'

### use for general case
#M1=5.0
#M2=5.0
MC_RANGE='[2.0,20.0]'
ETA_RANGE='[0.1,0.249999999]'

ECC_RANGE='[0.0,0.25]'


NEFF_ILE=1000
NEFF_CIP=1000

APPROX=${APPROX_ECC}
FMIN=${FMIN_ECC}

mdc.xml.gz:
	util_WriteInjectionFile.py --parameter eccentricity --parameter-value ${ECC} --parameter m1 --parameter-value ${M1} --parameter m2 --parameter-value ${M2} --fname mdc --approx ${APPROX} --parameter tref --parameter-value ${EVENT_TIME} --parameter dist --parameter-value ${DIST} --parameter fmin --parameter-value ${FMIN}

zero_noise.cache: mdc.xml.gz
	util_WriteFrameAndCacheFromXML.sh mdc.xml.gz 0 zero_noise ${APPROX}

#snr_table.dat: zero_noise.cache
#	util_FrameZeroNoiseSNR.py --cache zero_noise.cache --psd-file H1=HLV-ILIGO_PSD.xml.gz  --psd-file L1=HLV-ILIGO_PSD.xml.gz  > snr_table.dat

snr_table.dat:
	util_FrameZeroNoiseSNR.py --cache ${CACHE} --psd-file H1=HLV-ILIGO_PSD.xml.gz  --psd-file L1=HLV-ILIGO_PSD.xml.gz  > snr_table.dat


HLV-ILIGO_PSD.xml.gz:
	./generate_iligo_psd

HLV-aLIGO_PSD.xml.gz:
	./generate_iligo_psd


STANDARD_ILE_OPTS=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 100.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --cache-file ${PWD}/zero_noise.cache --fmin-template ${FMIN_TEMPLATE_BH} --n-max 2000000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff 100  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=${PWD}/HLV-ILIGO_PSD.xml.gz --psd-file L1=${PWD}/HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler

ECC_ILE_OPTS=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 20.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --fmin-template ${FMIN_TEMPLATE_BH} --n-max 500000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff ${NEFF_ILE}  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=${PWD}/HLV-ILIGO_PSD.xml.gz --psd-file L1=${PWD}/HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler

# should do this with a shell script!
# note cache file name
STANDARD_ILE_OPTS_SINGULARITY=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 100.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --cache-file local.cache --fmin-template ${FMIN_TEMPLATE_BH} --n-max 2000000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff 50  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=HLV-ILIGO_PSD.xml.gz --psd-file L1=HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler 


# eccentric test
test_workflow_batch_gpu_eccentric: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range ${ECC_RANGE} --parameter mc --parameter-range ${MC_RANGE} --random-parameter eta --random-parameter-range ${ETA_RANGE} --grid-cartesian-npts ${NPTS_START} --skip-overlap
	#util_ManualOverlapGrid.py --parameter eccentricity --parameter-range '[0.0,0.5]' --parameter mc --parameter-range ${MC_RANGE} --random-parameter delta_mc --random-parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	(cd $@${LABEL}; echo X --mc-range ${MC_RANGE} --eta-range ${ETA_RANGE} --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method rf --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff ${NEFF_CIP} --n-max 1e7 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0 --srate 4096 --save-eccentricity --cache-file ${PWD}/$@${LABEL}/zero_noise.cache > args_ile.txt)
	(cd $@${LABEL}; echo X --parameter mc --parameter eta --fmin ${FMIN} --fref 20.0 --parameter eccentricity --downselect-parameter eta --downselect-parameter-range ${ETA_RANGE} --downselect-parameter eccentricity --downselect-parameter-range ${ECC_RANGE} --puff-factor 1 --enforce-duration-bound 256 > args_puff.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_PER_JOB} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT} --puff-exe `which util_ParameterPuffball.py` --puff-args args_puff.txt --puff-max-it 5 --puff-cadence 1)
	cp mdc.xml.gz $@${LABEL}/true.xml.gz
	cp zero_noise.cache $@${LABEL}/zero_noise.cache
	mkdir $@${LABEL}/zero_noise_mdc/
	cp zero_noise_mdc/* $@${LABEL}/zero_noise_mdc/
	./cleanup.sh
	sed -i 's/^.*gz/& --export-eccentricity/' $@${LABEL}/convert.sub
	sed -i 's/^.*Capstone_Examples*/&\/$@${LABEL}/' $@${LABEL}/zero_noise.cache

test_workflow_batch_gpu_eccentricity_only: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range ${ECC_RANGE} --grid-cartesian-npts ${NPTS_START} --skip-overlap --mass1 ${M1} --mass2 ${M2}
	(cd $@${LABEL}; echo X --parameter eccentricity --fixed-parameter m1 --fixed-parameter-value ${M1} --fixed-parameter m2 --fixed-parameter-value ${M2} --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff ${NEFF_CIP} --use-eccentricity  > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0 --srate 4096 --save-eccentricity --cache-file ${PWD}/$@${LABEL}/zero_noise.cache > args_ile.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
	(cd $@${LABEL}; echo X  --fmin ${FMIN} --fref 20.0 --parameter eccentricity --downselect-parameter eccentricity --downselect-parameter-range ${ECC_RANGE} --puff-factor 1 --enforce-duration-bound 256 > args_puff.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_PER_JOB} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT} --puff-exe `which util_ParameterPuffball.py` --puff-args args_puff.txt --puff-max-it 5 --puff-cadence 1)
	cp mdc.xml.gz $@${LABEL}/true.xml.gz
	cp zero_noise.cache $@${LABEL}/zero_noise.cache
	mkdir $@${LABEL}/zero_noise_mdc/
	cp zero_noise_mdc/* $@${LABEL}/zero_noise_mdc/
	./cleanup.sh
	sed -i 's/^.*gz/& --export-eccentricity/' $@${LABEL}/convert.sub
	sed -i 's/^.*Capstone_Examples*/&\/$@${LABEL}/' $@${LABEL}/zero_noise.cache

## Low latency configuration
##   - do not adapt in distance 
##   - disable sky localization adaptation after iteration 1
##
# eccentric test
test_workflow_batch_gpu_lowlatency_eccentric: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	#util_ManualOverlapGrid.py --phase-order 3 --parameter eccentricity --parameter-range '[0.0,0.5]' --parameter mc --parameter-range ${MC_RANGE_BH} --parameter delta_mc --parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range ${ECC_RANGE} --parameter mc --parameter-range ${MC_RANGE} --random-parameter delta_mc --random-parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	(cd $@${LABEL}; echo X --mc-range ${MC_RANGE} --eta-range ${ETA_RANGE} --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff ${NEFF_CIP} --use-eccentricity > args_cip.txt)
	#(cd $@; echo X --mc-range '[28.0,29.0]' --eta-range '[0.20,0.24999]' --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 10000 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0  --no-adapt-after-first --no-adapt-distance --srate 4096 --save-eccentricity --cache-file ${PWD}/$@${LABEL}/zero_noise.cache > args_ile.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
#	(cd $@; ls ${PWD}/*psd.xml.gz  ${PWD}/*.cache  > file_names_transfer.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_PER_JOB} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT})
	cp mdc.xml.gz $@${LABEL}/true.xml.gz
	cp zero_noise.cache $@${LABEL}/zero_noise.cache
	mkdir $@${LABEL}/zero_noise_mdc/
	cp zero_noise_mdc/* $@${LABEL}/zero_noise_mdc/
	./cleanup.sh
	sed -i 's/^.*gz/& --export-eccentricity/' $@${LABEL}/convert.sub
	sed -i 's/^.*Capstone_Examples*/&\/$@${LABEL}/' $@${LABEL}/zero_noise.cache
