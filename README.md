# Robust MAC-snSMART
### Example data analysis `R` code for paper "Use of natural history data for drug evaluation in Duchenne muscular dystrophy: a Bayesian small sample, sequential, multiple assignement randomized trial design" 

We propose a small sample (n), sequential, multiple assignment, randomized trial (snSMART) design that integrates natural history data with data from the placebo arm to increase efficiency. The proposed approach is a multi-stage design evaluating multiple doses of a promising drug versus placebo. To efficiently estimate treatment effects in a snSMART design, we present a robust MAC-snSMART, a robust exchangeable hierarchical model (HM). We reanalyze data from a DMD trial using the proposed method and external control data from the Duchenne Natural History Study (DNHS). Our method's estimators show improved efficiency compared to the original trial. 

Five files are provided:
- `robust_MAC_snSMART.bugs` - `JAGS` code of our proposed robust MAC-snSMART method;
- `traditional.bugs` - `JAGS` code of traditional method;
- `JointStageBayes_mixture.bug` - `JAGS` code of the Bayesian joint stage model proposed by [Fang Fang](https://www.tandfonline.com/doi/abs/10.1080/19466315.2022.2118162);
- `simulation_function.R` - simulate sample snSMART trial data;
- `example_data_analysis.R` - the original `R` code used to reproduce the results presented in `Section 6` of our paper (NSAA only).

To conduct the example data anlaysis yourself, please put all files under one folder, set working directory to that folder, and run `example_data_analysis.R`. The current number of simulations is set to 30,000. Please edit the number of simulations and computing cores according to your needs. DNHS study data is not provided and only summary level data is used in the example data analysis. Details on the RO7239361 trial can be found [here](https://clinicaltrials.gov/ct2/show/NCT03039686).

Contact: sidiwang@umich.edu
