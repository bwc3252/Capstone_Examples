ILE=$(shell which integrate_likelihood_extrinsic)
POST_GENERIC=$(shell which util_ConstructIntrinsicPosterior_GenericCoordinates.py)
PWD=$(shell pwd)

NPTS_START=500
NPTS_IT=500
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
ECC=0.05
#ECC=0.0
FMIN_ECC=20.0
APPROX_ECC=taylorf2ecc

APPROX=${APPROX_ECC}
FMIN=${FMIN_ECC}

mdc.xml.gz:
	util_WriteInjectionFile.py --parameter eccentricity --parameter-value ${ECC} --parameter m1 --parameter-value 20.0 --parameter m2 --parameter-value 10.0 --fname mdc --approx ${APPROX} --parameter tref --parameter-value ${EVENT_TIME} --parameter dist --parameter-value 20 --parameter fmin --parameter-value ${FMIN}

zero_noise.cache: mdc.xml.gz
	util_WriteFrameAndCacheFromXML.sh mdc.xml.gz 0 zero_noise ${APPROX}

snr_table.dat: zero_noise.cache
	util_FrameZeroNoiseSNR.py --cache zero_noise.cache --psd-file H1=HLV-ILIGO_PSD.xml.gz  --psd-file L1=HLV-ILIGO_PSD.xml.gz  > snr_table.dat


HLV-ILIGO_PSD.xml.gz:
	./generate_iligo_psd

HLV-aLIGO_PSD.xml.gz:
	./generate_iligo_psd


STANDARD_ILE_OPTS=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 100.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --cache-file ${PWD}/zero_noise.cache --fmin-template ${FMIN_TEMPLATE_BH} --n-max 2000000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff 100  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=${PWD}/HLV-ILIGO_PSD.xml.gz --psd-file L1=${PWD}/HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler

ECC_ILE_OPTS=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 20.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --fmin-template ${FMIN_TEMPLATE_BH} --n-max 500000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff 100  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=${PWD}/HLV-ILIGO_PSD.xml.gz --psd-file L1=${PWD}/HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler

# should do this with a shell script!
# note cache file name
STANDARD_ILE_OPTS_SINGULARITY=--n-chunk 10000 --time-marginalization --sim-xml overlap-grid.xml.gz --reference-freq 100.0 --adapt-weight-exponent 0.1  --event-time ${EVENT_TIME} --save-P 0.1 --cache-file local.cache --fmin-template ${FMIN_TEMPLATE_BH} --n-max 2000000 --fmax 1700.0 --save-deltalnL inf --l-max 2  --n-eff 50  --approximant ${APPROX} --adapt-floor-level 0.1 --maximize-only  --d-max ${DMAX}  --psd-file H1=HLV-ILIGO_PSD.xml.gz --psd-file L1=HLV-ILIGO_PSD.xml.gz --channel-name H1=FAKE-STRAIN --channel-name L1=FAKE-STRAIN --inclination-cosine-sampler --declination-cosine-sampler 


MC_RANGE_BH=[23,35]
# eccentric test
test_workflow_batch_gpu_eccentric: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range '[0.0,0.1]' --parameter mc --parameter-range '[10.0,15.0]' --random-parameter delta_mc --random-parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	#(cd $@${LABEL}; echo X --mc-range '[1.5,8.0]' --eta-range '[0.15,0.24999]' --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 10000 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X --mc-range '[10.0,15.0]' --eta-range '[0.15,0.24999]' --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 100 --n-max 1e7 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --distance 20.0 --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0 --srate 4096 --save-eccentricity --cache-file ${PWD}/$@${LABEL}/zero_noise.cache > args_ile.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_IT} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT})
	cp mdc.xml.gz $@${LABEL}/true.xml.gz
	cp zero_noise.cache $@${LABEL}/zero_noise.cache
	mkdir $@${LABEL}/zero_noise_mdc/
	cp zero_noise_mdc/* $@${LABEL}/zero_noise_mdc/
	./cleanup.sh
	sed -i 's/^.*gz/& --export-eccentricity/' $@${LABEL}/convert.sub
	sed -i 's/^.*Capstone_Examples*/&\/$@${LABEL}/' $@${LABEL}/zero_noise.cache

test_workflow_batch_gpu_eccentricity_only: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap --mass1 6.0 --mass2 5.0
	(cd $@${LABEL}; echo X --parameter eccentricity --fixed-parameter m1 --fixed-parameter-value 6.0 --fixed-parameter m2 --fixed-parameter-value 5.0 --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 10000 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0 --srate 4096 --save-eccentricity > args_ile.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_IT} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT})

## Low latency configuration
##   - do not adapt in distance 
##   - disable sky localization adaptation after iteration 1
##
# eccentric test
test_workflow_batch_gpu_lowlatency_eccentric: Makefile HLV-ILIGO_PSD.xml.gz zero_noise.cache
	(mkdir $@${LABEL}; exit 0)
	#util_ManualOverlapGrid.py --phase-order 3 --parameter eccentricity --parameter-range '[0.0,0.5]' --parameter mc --parameter-range ${MC_RANGE_BH} --parameter delta_mc --parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	util_ManualOverlapGrid.py --parameter eccentricity --parameter-range '[0.0,0.5]' --parameter mc --parameter-range ${MC_RANGE_BH} --parameter delta_mc --parameter-range '[0.0,0.5]' --grid-cartesian-npts ${NPTS_START} --skip-overlap
	(cd $@${LABEL}; echo X --mc-range ${MC_RANGE_BH} --eta-range '[0.20,0.24999]' --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 10000 --use-eccentricity > args_cip.txt)
	#(cd $@; echo X --mc-range '[28.0,29.0]' --eta-range '[0.20,0.24999]' --parameter mc --parameter eccentricity --parameter-implied eta --parameter-nofit delta_mc  --fit-method gp --verbose  --lnL-offset ${LNL_OFFSET} --cap-points 12000  --n-output-samples 10000 --no-plots --n-eff 10000 --use-eccentricity > args_cip.txt)
	(cd $@${LABEL}; echo X   ${ECC_ILE_OPTS}  --data-start-time 1000000008 --data-end-time 1000000016 --inv-spec-trunc-time 0  --no-adapt-after-first --no-adapt-distance --srate 4096 --save-eccentricity > args_ile.txt)
	(cd $@${LABEL}; echo X  --always-succeed --method lame  --parameter m1 > args_test.txt)
	(cd $@${LABEL}; echo X  --parameter m1 --parameter m2  > args_plot.txt)
#	(cd $@; ls ${PWD}/*psd.xml.gz  ${PWD}/*.cache  > file_names_transfer.txt)
	(cd $@${LABEL};  create_event_parameter_pipeline_BasicIteration --request-gpu-ILE --ile-n-events-to-analyze ${NPTS_IT} --input-grid overlap-grid-0.xml.gz  --ile-exe `which integrate_likelihood_extrinsic_batchmode`  --ile-args args_ile.txt --cip-args args_cip.txt  --test-args args_test.txt --plot-args args_plot.txt --request-memory-CIP ${CIP_MEM} --request-memory-ILE ${ILE_MEM}  --input-grid ${PWD}/overlap-grid.xml.gz --n-samples-per-job ${NPTS_IT} --working-directory ${PWD}/$@${LABEL} --n-iterations ${N_IT})

