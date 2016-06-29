// -------------------------------------------------------------------------- //
//               Age-structured model for Alaska herring stocks               //
//                                                                            //
//                               VERSION 0.1                                  //
//                                Jan  2015                                   //
//                                                                            //
//                                 AUTHORS                                    //
//                              Sherri Dressel                                //                                 
//                        sherri.dressel@alaska.gov                           //
//                               Sara Miller                                  //
//                          sara.miller@alaska.gov                            //
//                               Kray Van Kirk                                //
//                          kray.vankirk@alaska.gov                           //
//                                                                            //
//                   Built on code developed by Peter Hulson                  //
//                            pete.hulson@noaa.gov                            //
//                                                                            //
//                           Layout and references                            //
//                              Steven Martell                                //
//                          martell.steve@gmail.com                           //
//                                                                            //
// CONVENTIONS: Formatting conventions are based on                           //
//              The Elements of C++ Style (Misfeldt et al. 2004)              //
//                                                                            //
//                                                                            //
// NAMING CONVENTIONS:                                                        //
//             Macros       -> UPPERCASE                                      //
//             Constants    -> UpperCamelCase                                 //
//             Functions    -> lowerCamelCase                                 //
//             Variables    -> lowercase                                      //
//                                                                            //
//                                                                            //
//                                                                            //
// -------------------------------------------------------------------------- //
//-- CHANGE LOG:                                                             -//
//--  Jan 2015 - revision of legacy code::                                   -//
//--               :variable naming conventions                              -//
//--               :intra-annual calendar                                    -//
//--               :standardization of units across stocks                   -//
//--               :modification for potential code distribution             -//
//--  May 2015 - added code and scripts to a git-hub repo.                   -//
//--                                                                         -//
// -------------------------------------------------------------------------- //

DATA_SECTION

// |---------------------------------------------------------------------------|
// | CHECK FOR OPTIONAL COMMAND LINE ARGUMENTS & SET FLAGS
// |---------------------------------------------------------------------------|
// | b_simulation_flag	-> flag for running in simulation mode
// | rseed			-> random number seed for simulation 
	int b_simulation_flag;
	int rseed;
	LOCAL_CALCS
		int on = 0;
		b_simulation_flag = 0;
		if (ad_comm::argc > 1)
		{
			int on = 0;
			rseed  = 0;
			if ( (on=option_match(ad_comm::argc,ad_comm::argv,"-sim")) > -1 )
			{
				b_simulation_flag = 1;
				rseed = atoi(ad_comm::argv[on+1]);
			}
		}
	END_CALCS
// |---------------------------------------------------------------------------|


// |---------------------------------------------------------------------------|
// | STRINGS FOR INPUT FILES                                                   |
// |---------------------------------------------------------------------------|
// |- The files below are listed in the 'model.dat' file;
// |   nothing else should be in the 'model.dat' file
// |- These files should be named by the stock they are modeling;
// |   example: "sitka.dat", "seymour.dat"
// |- DO NOT use two word names such as "seymour cove.dat"
// |
// | DEBUG_FLAG             : Boolean Flag used for manual debugging
// | DataFile               : data to condition the assessment model    
// | ControlFile            : controls for years, phases, and block options 
	init_int DEBUG_FLAG;
	init_adstring DataFile;      
  init_adstring ControlFile;


// |---------------------------------------------------------------------------|
// | READ CONTENTS OF DATA FILE
// |---------------------------------------------------------------------------|
	!! ad_comm::change_datafile_name(DataFile);

// |---------------------------------------------------------------------------|
// | Model dimensions.
// |---------------------------------------------------------------------------|
// | dat_syr			-> first year of data
// | day_nyr			-> last year of data
// | mod_syr 			-> first year of model
// | mod_nyr			-> last year of model
// | sage					-> first age class
// | nage 				-> plus group age class
	init_int dat_syr;
	init_int dat_nyr;
	init_int mod_syr;
	init_int mod_nyr;
	init_int sage;
	init_int nage;
	int rec_syr;
	!!  rec_syr = mod_syr + sage;

	vector age(sage,nage);
	!! age.fill_seqadd(sage,1);

// |---------------------------------------------------------------------------|
// | Fecundity regression coefficients
// |---------------------------------------------------------------------------|
// | - 
	init_int nFecBlocks;
	init_ivector nFecBlockYears(1,nFecBlocks);
	init_vector fec_slope(1,nFecBlocks);
	init_vector fec_inter(1,nFecBlocks);
	// !!COUT(fec_slope)

// |---------------------------------------------------------------------------|
// | Time series data.  Catch in short tons. Comps in proportions.
// |---------------------------------------------------------------------------|
// | data_catch		-> Catch: colnames(Year,Catch,log.se) units are short tons
// | data_sp_waa 	-> Spawn Weight-at-age (Year,weight-at-age)
// | data_cm_waa	-> Commercial catch weight-at-age (Year, weight-at-age)
// | data_cm_comp	-> Commercial catch composition (Year, age proporitons)
// | data_sp_comp -> Spawn Sample age composition (Year, age proportions)
// | data_egg_dep -> Egg deposition survey (Year, Index, log.se)
// | avg_sp_waa   -> Average weight-at-age for spawning biomass.
	init_matrix   data_catch(dat_syr,dat_nyr,1,3);
	init_matrix  data_sp_waa(dat_syr,dat_nyr,sage-1,nage);
	init_matrix  data_cm_waa(dat_syr,dat_nyr,sage-1,nage);
	init_matrix data_cm_comp(dat_syr,dat_nyr,sage-1,nage);
	init_matrix data_sp_comp(dat_syr,dat_nyr,sage-1,nage);
	init_matrix data_egg_dep(dat_syr,dat_nyr,1,3);
	init_matrix data_mileday(dat_syr,dat_nyr,1,3);
	
	// Calculate average spawner weight-at-age for SR parameters
	vector avg_sp_waa(sage,nage);
	LOCAL_CALCS
		int n = data_sp_waa.rowmax() - data_sp_waa.rowmin() + 1;
		avg_sp_waa = colsum(data_sp_waa)(sage,nage) / n;
	END_CALCS

	// Calculate Fecundity-at-age based on regression coefficients.
	matrix Fij(mod_syr,mod_nyr,sage,nage);
	LOCAL_CALCS
		int iyr = mod_syr;
		
		for(int h = 1; h <= nFecBlocks; h++){
			do{
				Fij(iyr) = 1.e-6 *
								(data_sp_waa(iyr)(sage,nage) * fec_slope(h) - fec_inter(h));
				iyr ++;
			}while(iyr <= nFecBlockYears(h));
		}
	END_CALCS

// |---------------------------------------------------------------------------|
// | END OF DATA FILE
// |---------------------------------------------------------------------------|
	init_int dat_eof; 
	!! if(dat_eof != 999){cout<<"Error reading data file, aborting."<<endl; exit(1);}



// |---------------------------------------------------------------------------|
// | READ CONTENTS OF CONTROL FILE
// |---------------------------------------------------------------------------|
	!! ad_comm::change_datafile_name(ControlFile);


// |-------------------------------------------------------------------------|
// | DESIGN MATRIX FOR PARAMETER CONTROLS                                    |
// |-------------------------------------------------------------------------|
// | - theta_DM -> theta is a vector of estimated parameters.
  int n_theta;
  !! n_theta = 5;
  init_matrix theta_DM(1,n_theta,1,4);
  vector    theta_ival(1,n_theta);
  vector      theta_lb(1,n_theta);
  vector      theta_ub(1,n_theta);
  ivector    theta_phz(1,n_theta);
  !! theta_ival = column(theta_DM,1);
	!! theta_lb  = column(theta_DM,2);
	!! theta_ub  = column(theta_DM,3);
	!! theta_phz = ivector(column(theta_DM,4));
	

// |---------------------------------------------------------------------------|
// | Controls for time-varying maturity
// |---------------------------------------------------------------------------|
	init_int mat_phz;
	init_int nMatBlocks;
	init_ivector nMatBlockYear(1,nMatBlocks);

// |---------------------------------------------------------------------------|
// | Controls for natural mortality rate deviations in each block.
// |---------------------------------------------------------------------------|
	init_int mort_dev_phz;
	init_int nMortBlocks;
	init_ivector nMortBlockYear(1,nMortBlocks);
	

// |---------------------------------------------------------------------------|
// | Controls for selectivity parameters
// |---------------------------------------------------------------------------|
// | - nSlxCols 		» number of columns in selectivity design matrix
// | - nSlxBlks 			» number of selectivity blocks/patterns 
// | - selex_cont			» matrix of controls to be read in from control file.
	int nSlxCols;
	!! nSlxCols = 9;
	init_int nSlxBlks;
	init_matrix selex_cont(1,nSlxBlks,1,nSlxCols);
	ivector       nSelType(1,nSlxBlks);
	ivector       nslx_phz(1,nSlxBlks);
	ivector      nslx_rows(1,nSlxBlks);
	ivector      nslx_cols(1,nSlxBlks);
	ivector      	nslx_syr(1,nSlxBlks);
	ivector      	nslx_nyr(1,nSlxBlks);


	LOCAL_CALCS
		nSelType = ivector(column(selex_cont,2));
		nslx_phz = ivector(column(selex_cont,7));
		nslx_syr = ivector(column(selex_cont,8));
		nslx_nyr = ivector(column(selex_cont,9));

		// determine dimensions for log_slx_pars ragged object.
		for(int h = 1; h <= nSlxBlks; h++){
			nslx_rows(h) = 1;
			switch(nSelType(h)){
				case 1: // logistic 2-parameters
					nslx_cols = int(2);
				break;
			}
		}
	END_CALCS

// |---------------------------------------------------------------------------|
// | Miscellaneous Controls
// |---------------------------------------------------------------------------|
// | nMiscCont 	»	Number of controls to read in.
// | dMiscCont	»	Vector of miscelaneous controls,
// | pos 1 » Catch scaler.

	init_int nMiscCont;
	init_vector dMiscCont(1,nMiscCont);

	LOCAL_CALCS
		for( int i = dat_syr; i <= dat_nyr; i++ ) {
			data_catch(i,2) = dMiscCont(1) * data_catch(i,2);
		}
	END_CALCS


// |---------------------------------------------------------------------------|
// | END OF Control FILE
// |---------------------------------------------------------------------------|
	init_int ctl_eof;
	LOCAL_CALCS
		if(ctl_eof != 999){
			cout<<"Error reading control file, aborting."<<ctl_eof<<endl; 
			exit(1);
		}
	END_CALCS

INITIALIZATION_SECTION
	theta theta_ival;
  


PARAMETER_SECTION

// |---------------------------------------------------------------------------|
// | POPULATION PARAMETERS
// |---------------------------------------------------------------------------|
// | - theta(1) -> log natural mortality
// | - theta(2) -> log initial average age-3 recruitment for ages 4-9+ in dat_styr
// | - theta(3) -> log average age-3 recruitment from dat_styr to dat_endyr
// | - theta(4) -> log of unfished recruitment.
// | - theta(5) -> log of recruitment compensation (reck > 1.0)
  init_bounded_number_vector theta(1,n_theta,theta_lb,theta_ub,theta_phz);
	number log_natural_mortality;
  number log_rinit;
  number log_rbar;
  number log_ro;
  number log_reck;
  init_bounded_dev_vector log_rinit_devs(sage+1,nage,-15.0,15.0,2);
  init_bounded_dev_vector log_rbar_devs(mod_syr,mod_nyr+1,-15.0,15.0,2);


// |---------------------------------------------------------------------------|
// | MATURITY PARAMETERS
// |---------------------------------------------------------------------------|
// | - mat_params[1] -> Age at 50% maturity
// | - mat_params[2] -> Slope at 50% maturity
	init_bounded_matrix mat_params(1,nMatBlocks,1,2,0,10,mat_phz);
	matrix mat(mod_syr,mod_nyr,sage,nage);

// |---------------------------------------------------------------------------|
// | NATURAL MORTALITY PARAMETERS
// |---------------------------------------------------------------------------|
// | - log_m_dev 		-> deviations in natural mortality for each block.
// | - Mij					-> Array for natural mortality rate by year and age.
	init_bounded_dev_vector log_m_dev(1,nMortBlocks,-15.0,15.0,mort_dev_phz);
	matrix Mij(mod_syr,mod_nyr,sage,nage);

// |---------------------------------------------------------------------------|
// | SELECTIVITY PARAMETERS
// |---------------------------------------------------------------------------|
// | - log_slx_pars	» parameters for selectivity models (ragged object).
	init_bounded_matrix_vector log_slx_pars(1,nSlxBlks,1,nslx_rows,1,nslx_cols,-25,25,nslx_phz);
	matrix log_slx(mod_syr,mod_nyr,sage,nage);
	LOCAL_CALCS
		if( ! global_parfile ){
			for(int h = 1; h <= nSlxBlks; h++){
				switch(nSelType(h)){
					case 1: //logistic
						log_slx_pars(h,1,1) = log(selex_cont(h,3));
						log_slx_pars(h,1,2) = log(selex_cont(h,4));
					break; 
				}
			}	
		}

	END_CALCS


// |---------------------------------------------------------------------------|
// | VECTORS
// |---------------------------------------------------------------------------|
// | - ssb 			» spawning stock biomass at the time of spawning.
// | - recruits » vector of sage recruits predicted by S-R curve.
// | - spawners » vector of ssb indexed by brood year.
// | - resd_rec » vector of residual process error (log-normal).
	vector ssb(mod_syr,mod_nyr);
	vector recruits(rec_syr,mod_nyr+1);
	vector spawners(rec_syr,mod_nyr+1);
	vector resd_rec(rec_syr,mod_nyr+1);

	vector pred_egg_dep(mod_syr,mod_nyr);
	vector resd_egg_dep(mod_syr,mod_nyr);

// |---------------------------------------------------------------------------|
// | MATRIXES
// |---------------------------------------------------------------------------|
// | - Nij 			» numbers-at-age N(syr,nyr,sage,nage)
// | - Oij 			» mature numbers-at-age O(syr,nyr,sage,nage)
// | - Pij 			» numbers-at-age P(syr,nyr,sage,nage) post harvest.
// | - Sij 			» selectivity-at-age 
// | - Qij 			» vulnerable proportions-at-age
// | - Cij    	» predicted catch-at-age in numbers.
	matrix Nij(mod_syr,mod_nyr+1,sage,nage);
	matrix Oij(mod_syr,mod_nyr+1,sage,nage);
	matrix Pij(mod_syr,mod_nyr+1,sage,nage);
	matrix Sij(mod_syr,mod_nyr+1,sage,nage);
	matrix Qij(mod_syr,mod_nyr+1,sage,nage);
	matrix Cij(mod_syr,mod_nyr+1,sage,nage);

	matrix pred_cm_comp(mod_syr,mod_nyr,sage,nage);
	matrix resd_cm_comp(mod_syr,mod_nyr,sage,nage);
	matrix pred_sp_comp(mod_syr,mod_nyr,sage,nage);
	matrix resd_sp_comp(mod_syr,mod_nyr,sage,nage);

	objective_function_value f;

	number fpen;


PROCEDURE_SECTION
	
// |---------------------------------------------------------------------------|
// | RUN STOCK ASSEAAMENT MODEL ROUTINES
// |---------------------------------------------------------------------------|
// | PSUEDOCODE:
// | - initialize model parameters.
// | - initialize Maturity Schedule information.
// | - get natural mortality schedules.
// | - get fisheries selectivity schedules.
// | - initialize State variables
// | - update State variables
// | 		- calculate spawning stock biomass
// | 		- calculate age-composition residuals
// |---------------------------------------------------------------------------|
  
  initializeModelParameters();
  if(DEBUG_FLAG) cout<<"--> Ok after initializeModelParameters      <--"<<endl;

	initializeMaturitySchedules();
  if(DEBUG_FLAG) cout<<"--> Ok after initializeMaturitySchedules    <--"<<endl;

  calcNaturalMortality();
  if(DEBUG_FLAG) cout<<"--> Ok after calcNaturalMortality           <--"<<endl;
  
  calcSelectivity();
  if(DEBUG_FLAG) cout<<"--> Ok after calcSelectivity                <--"<<endl;
  
  initializeStateVariables();
  if(DEBUG_FLAG) cout<<"--> Ok after initializeStateVariables       <--"<<endl;
  
  updateStateVariables();
  if(DEBUG_FLAG) cout<<"--> Ok after updateStateVariables           <--"<<endl;
	
	calcSpawningStockRecruitment();
  if(DEBUG_FLAG) cout<<"--> Ok after calcSpawningStockRecruitment   <--"<<endl;

  calcAgeCompResiduals();
  if(DEBUG_FLAG) cout<<"--> Ok after calcAgeCompResiduals           <--"<<endl;

  calcEggSurveyResiduals();
  if(DEBUG_FLAG) cout<<"--> Ok after calcEggSurveyResiduals         <--"<<endl;

  calcObjectiveFunction();
  if(DEBUG_FLAG) cout<<"--> Ok after calcObjectiveFunction          <--"<<endl;
  
// |---------------------------------------------------------------------------|

	



FUNCTION void initializeModelParameters()
	fpen = 0;
  log_natural_mortality = theta(1);
  log_rinit             = theta(2);
  log_rbar              = theta(3);
  log_ro                = theta(4);
  log_reck              = theta(5);
  // COUT(theta);


FUNCTION void initializeMaturitySchedules() 
	int iyr = mod_syr;
	mat.initialize();
	for(int h = 1; h <= nMatBlocks; h++) {
		dvariable mat_a = mat_params(h,1);
		dvariable mat_b = mat_params(h,2);

		// fill maturity array using logistic function
		do{
			mat(iyr++) = plogis(age,mat_a,mat_b);
		} while(iyr <= nMatBlockYear(h));	
	}
	

FUNCTION void calcNaturalMortality()
	
	int iyr = mod_syr;
	Mij.initialize();
	for(int h = 1; h <= nMortBlocks; h++){
		dvariable mi = exp(log_natural_mortality + log_m_dev(h));

		// fill mortality array by block
		do{
			//cout<<iyr<<"\t"<<theta<<endl;
			Mij(iyr++) = mi;
		} while(iyr <= nMortBlockYear(h));
	}		


FUNCTION void calcSelectivity()
	/**
		- Loop over each of the selectivity block/pattern
		- Determine which selectivity type is being used.
		- get parameters from log_slx_pars
		- calculate the age-dependent selectivity pattern
		- fill selectivty array for that block.
		- selectivity is scaled to have a mean = 1 across all ages.
	*/
	dvariable p1,p2;
	dvar_vector slx(sage,nage);
	log_slx.initialize();
	
	for(int h = 1; h <= nSlxBlks; h++){

		switch(nSelType(h)){
			case 1: //logistic
				p1  = mfexp(log_slx_pars(h,1,1));
				p2  = mfexp(log_slx_pars(h,1,2));
				slx = plogis(age,p1,p2) + TINY;
			break;
		}
		

		for(int i = nslx_syr(h); i <= nslx_nyr(h); i++){
			log_slx(i) = log(slx) - log(mean(slx));
		}
	}
	Sij.sub(mod_syr,mod_nyr) = mfexp(log_slx);


FUNCTION void initializeStateVariables()
	/**
		- Set initial values for numbers-at-age matrix in first year
		  and sage recruits for all years.
		*/
	Nij.initialize();

	// initialize first row of numbers-at-age matrix
	// lx is a vector of survivorship (probability of surviving to age j)
	dvar_vector lx(sage,nage);

	for(int j = sage; j <= nage; j++){
		
		lx(j) = exp(-Mij(mod_syr,j)*(j-sage));
		if( j==nage ) lx(j) /= (1.0-exp(-Mij(mod_syr,j)));


		if( j > sage ){
			Nij(mod_syr)(j) = mfexp(log_rinit + log_rinit_devs(j)) * lx(j);			
		}
	} 
		


	// iniitialize first columb of numbers-at-age matrix
	for(int i = mod_syr; i <= mod_nyr + 1; i++){
		Nij(i,sage) = mfexp(log_rbar + log_rbar_devs(i));
	}
	//COUT(lx);
	//COUT(Nij);


FUNCTION void updateStateVariables()
	/**
		- Update the numbers-at-age conditional on the catch-at-age.
		- Assume a pulse fishery.
		- step 1 » calculate a vector of vulnerable-numbers-at-age
		- step 2 » calculate vulnerable proportions-at-age.
		- step 3 » calc average weight of catch (wbar) conditional on Qij.
		- step 4 » calc catch-at-age | catch in biomass Cij = Ct/wbar * Qij.
		- step 5 » update numbers-at-age (using a very dangerous difference eqn.)
		*/

		Qij.initialize();
		Cij.initialize();
		Pij.initialize();
		dvariable wbar;		// average weight of the catch.
		dvar_vector vj(sage,nage);
		dvar_vector pj(sage,nage);
		dvar_vector sj(sage,nage);
		

		for(int i = mod_syr; i <= mod_nyr; i++){

			// step 1.
			vj = elem_prod(Nij(i),Sij(i));

			// step 2.
			Qij(i) = vj / sum(vj);

			// step 3.
			dvector wa = data_cm_waa(i)(sage,nage);
			wbar = wa * Qij(i);
			
			// step 4.
			Cij(i) = data_catch(i,2) / wbar * Qij(i);

			// step 5.
			sj = mfexp(-Mij(i));
			Pij(i) = posfun(Nij(i) - Cij(i),0.001,fpen); // should use posfun here
			Nij(i+1)(sage+1,nage) =++ elem_prod(Pij(i)(sage,nage-1),sj(sage,nage-1));
			Nij(i+1)(nage) += Pij(i,nage) * sj(nage);
		}
		
		// cross check... Looks good.
		// COUT(Cij(mod_syr) * data_cm_waa(mod_syr)(sage,nage));


FUNCTION void calcSpawningStockRecruitment()
	/**
		- The functional form of the stock recruitment model follows that of a 
			Ricker model, where R = so * SSB * exp(-beta * SSB).  The two parameters
			so and beta where previously estimated as free parameters in the old
			herring model.  Herein this fucntion I derive so and beta from the 
			leading parameters Ro and reck; Ro is the unfished sage recruits, and reck
			is the recruitment compensation parameter, or the relative improvement in
			juvenile survival rates as the spawning stock SSB tends to 0.  Simply a 
			multiple of the replacement line Ro/Bo.

			At issue here is time varying maturity and time-varying natural mortality.
			When either of these two variables are assumed to change over time, then
			the underlying stock recruitment relationship will also change. This 
			results in a non-stationary distribution.  For the purposes of this 
			assessment model, I use the average mortality and maturity schedules to
			derive the spawning boimass per recruit, which is ultimately used in 
			deriving the parameters for the stock recruitment relationship.
		*/

	/*
		Spoke to Sherri about this. Agreed to change the equation to prevent
	*/
	for(int i = mod_syr; i <= mod_nyr; i++){
		//Oij(i) = elem_prod(mat(i),Nij(i));
		//ssb(i) = (Oij(i) - Cij(i)) * data_sp_waa(i)(sage,nage);

		Oij(i) = elem_prod(mat(i),Nij(i)-Cij(i));
		ssb(i) = Oij(i) * data_sp_waa(i)(sage,nage);
	}
	

	// average natural mortality
	dvar_vector mbar(sage,nage);
	int n = Mij.rowmax() - Mij.rowmin() + 1;
	mbar  = colsum(Mij)/n;

	// average maturity
	dvar_vector mat_bar(sage,nage);
	mat_bar = colsum(mat)/n;


	// unfished spawning biomass per recruit
	dvar_vector lx(sage,nage);
	lx(sage) = 1.0;
	for(int j = sage + 1; j <= nage; j++){
		lx(j) = lx(j-1) * mfexp(-mbar(j-1));
		if(j == nage){
			lx(j) /= 1.0 - mfexp(-mbar(j));
		}
	}
	dvariable phie = lx * elem_prod(avg_sp_waa,mat_bar);


	// Ricker stock-recruitment function 
	// so = reck/phiE; where reck > 1.0
	// beta = log(reck)/(ro * phiE)
	dvariable ro   = mfexp(log_ro);
	dvariable reck = mfexp(log_reck);
	dvariable so   = reck/phie;
	dvariable beta = log(reck) / (ro * phie);

	spawners = ssb(mod_syr,mod_nyr-sage+1).shift(rec_syr);
	recruits = elem_prod( so*spawners , mfexp(-beta*spawners) );
	resd_rec = log(column(Nij,sage)(rec_syr,mod_nyr+1)+TINY) - log(recruits+TINY);



FUNCTION void calcAgeCompResiduals()
	/**
		- Commercial catch-age comp residuals
		- Spawning survey catch-age comp residuals.
		*/

		resd_cm_comp.initialize();
		resd_sp_comp.initialize();
		for(int i = mod_syr; i <= mod_nyr; i++){
			
			// commercial age-comp prediction 
			pred_cm_comp(i) = Qij(i);
			if( data_cm_comp(i,sage) >= 0 ){
				resd_cm_comp(i) = data_cm_comp(i)(sage,nage) - pred_cm_comp(i);
			}

			// spawning age-comp prediction
			pred_sp_comp(i) = Oij(i) / sum(Oij(i));
			if( data_sp_comp(i,sage) >= 0 ){
				resd_sp_comp(i) = data_sp_comp(i)(sage,nage) - pred_sp_comp(i);
			}
		}

		//COUT(resd_sp_comp);
FUNCTION void calcEggSurveyResiduals()
	/**
		- Observed egg data is in trillions of eggs
		- Predicted eggs is the mature female numbers-at-age multiplied 
		  by the fecundity-at-age, which comes from a regession of 
		  fecundity = slope * obs_sp_waa - intercept
		- Note Fij is the Fecundity-at-age j in year i.
		*/
		resd_egg_dep.initialize();
		for(int i = mod_syr; i <= mod_nyr; i++){
			pred_egg_dep(i) = (0.5 * Oij(i)) * Fij(i);
			

			if(data_egg_dep(i,2) > 0){
				resd_egg_dep(i) = log(data_egg_dep(i,2)) - log(pred_egg_dep(i));
			}
		}

FUNCTION void calcObjectiveFunction()
	/**
		-	
		*/
		dvar_vector nll(1,6);

		nll(1) = norm2(resd_sp_comp);
		nll(2) = norm2(resd_cm_comp);
		nll(3) = norm2(resd_egg_dep);
		nll(4) = norm2(resd_rec);
		nll(5) = norm2(log_rinit_devs);
		nll(6) = norm2(log_rbar_devs);

		f = sum(nll);// + 1000.0 * fpen;
		if(DEBUG_FLAG){
			COUT(nll);
			COUT(fpen);
			COUT(f);
			if(fpen > 0 ){cout<<fpen<<endl;}
		}  


GLOBALS_SECTION
	#include <admodel.h>
	#include <string.h>
	#include <time.h>

	#undef EOF
	#define EOF 999

	#undef TINY
	#define TINY  1.0e-10

  #undef REPORT
  #define REPORT(object) report << #object "\n" << setw(8) \
  << setprecision(4) << setfixed() << object << endl;

  #undef COUT
  #define COUT(object) cout << #object "\n" << setw(6) \
  << setprecision(3) << setfixed() << object << endl;

  template<typename T>
  dvar_vector plogis(const dvector x, T location, T scale)
  {
  	return(1.0 / (1.0 + exp(-(x-location)/scale)));
  }


REPORT_SECTION
// Write out Raw Data (Useful for simulation studies)
// Note that I use a Macro called REPORT here to ensure a standard format.
	REPORT(dat_syr);
	REPORT(dat_nyr);
	REPORT(mod_syr);
	REPORT(mod_nyr);
	REPORT(sage);
	REPORT(nage);
	REPORT(nFecBlocks);
	REPORT(nFecBlockYears);
	REPORT(fec_slope);
	REPORT(fec_inter);
	REPORT(data_catch);
	REPORT(data_sp_waa);
	REPORT(data_cm_waa);
	REPORT(data_cm_comp);
	REPORT(data_sp_comp);
	REPORT(data_egg_dep);
	REPORT(data_mileday);
	REPORT(EOF)
// END of Replicated Data File. (run model with -noest to check data)

// Vectors of years.
	ivector year(mod_syr,mod_nyr+1);
	year.fill_seqadd(mod_syr,1);
	
	ivector years(mod_syr,mod_nyr+1);
	years.fill_seqadd(mod_syr,1);

	ivector rec_years(rec_syr,mod_nyr+1);
	rec_years.fill_seqadd(rec_syr,1);

	ivector iage = ivector(age);

	REPORT(iage);
	REPORT(year);
	REPORT(years);

// SSB, recruits, spawners,
	REPORT(ssb);
	REPORT(spawners);
	REPORT(recruits);

// Numbers-at-age of various flavors.
	REPORT(Nij);
	REPORT(Oij);
	REPORT(Pij);
	REPORT(Cij);

// Selectivity and vulnerable proportion-at-age.
	REPORT(Sij);
	REPORT(Qij);





























