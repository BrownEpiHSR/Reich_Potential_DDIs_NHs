/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
1. Estimate the prevalence of each DDI in the stability analysis.
2. Calculate the median days of concurrent medication use for each
   potential DDI, among beneficiaries with at least one day of concurrent
   medication use for the DDI, in the stability analysis.
3. Create output for the following tables:
Table S2: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Anrys et al., 2018-2020.
Table S3: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by the 2023 AGS Beers Criteria(R), 2018-2020.
Table S4: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Capiau et al., 2018-2020.

Programmer: Laura Reich   
 
Date Last Modified: March 14, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- merged.&ddi._dyswddi_sens_only: Dataset of overlapping medication use episodes
                                 (i.e., concurrent use) for a given DDI in the 
                                 stability analysis.
- ddi.ddi_list_3d: List of DDIs to run through %estimate_prev_sens macro and
                   %median_days_sens macro
- smcncr.calc_all_2: DDI-level prevalence and median days of DDI exposure dataset
     - Generated in 4_Table2.sas
*********************************************************************/

/*********************************************************************
Key generated datasets:
- smcncr.calc_all_anrys_sens: DDI-level prevalence and median duration of DDI exposure in the primary and stability analysis (Anrys DDIs)
- smcncr.calc_all_beers_sens: DDI-level prevalence and median duration of DDI exposure in the primary and stability analysis (Beers DDIs)
- smcncr.calc_all_capiau_sens: DDI-level prevalence and median duration of DDI exposure in the primary and stability analysis (Capiau DDIs)
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname lrenroll "your/library/path"; /* Relevant NH time data set with exclusions applied */
libname merged   "your/library/path"; /* Merged medication episode data sets */
libname prev     "your/library/path"; /* DDI prevalence data sets */
libname ddi      "your/library/path"; /* Data sets with lists of ddis and their components drug categories */
libname smcncr   "your/library/path"; /* DDI summary info */

options mprint mlogic;

/*********************************************************************/
/*** Estimate the prevalence of each DDI in the stability analysis ***/
/*********************************************************************/

%macro estimate_prev_sens(ddi);

	/* Writing to RTF doc */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** Create data set where each record is a unique beneficiary and their total days of concurrent medication use 
	     (i.e., person-level concurrent medication use data set) ***/

	proc sql;
		create table &ddi._lap as
		select bene_id_18900, sum(days_with_ddi) as sum_overlap
		from merged.&ddi._dyswddi_sens_only
		group by bene_id_18900;
	quit;

	/*** Make flag for the DDI in the person-level concurrent medication use data set ***/

	data merged.&ddi._lap_sens_only;
		set &ddi._lap;

		&ddi. = 1;

		label
		sum_overlap = "Total days of concurrent use for this potential DDI"
		&ddi. = "DDI Flag, 1 = beneficiary had concurrent use of meds for this potential DDI";

	run;

	/*** Merge the person-level concurrent medication use data set with the person-level NH time data set (with sex variables added) ***/

	proc sql;
		create table &ddi._prev as
		select a.&ddi., a.sum_overlap, b.*
		from merged.&ddi._lap_sens_only as a full join lrenroll.nh_person_days_sex as b
		on a.bene_id_18900 = b.bene_id_18900;
	quit;

	/*** Estimate the prevalence of this DDI and calculate the 95% CLs using the Clopper-Pearson (exact) formula ***/

	/* If the the ddi is ddi94 (i.e., Beers8, or peripheral alpha-1 blockers + loop diuretics, which the paper specifically said to avoid concurrent use in older women), 
	         restrict to beneficiaries with sex listed as female */

	%if &ddi. = ddi94 %then %do;

		data prev.&ddi._prev2_sens_only;
			set &ddi._prev;

			/* Here we remove any beneficiaries where sex is listed as male */
			if hksex_prs ne 2 then delete;

			/* For the records remaining, any records where the value for &ddi. is missing, replace with 0 (i.e., beneficiary does not have this potential DDI) */
			if &ddi. = . then &ddi. = 0;

		run;

	%end;

	/* If the ddi is not equal to ddi94, don't make any exclusions based on beneficiary's sex */

	%else %if &ddi. ne ddi94 %then %do;

		data prev.&ddi._prev2_sens_only;
			set &ddi._prev;

			if &ddi. = . then &ddi. = 0;

		run;

	%end;

	/* Calculate prevalence and 95% confidence limits using proc freq */

	ods output Binomial = ci_output;
	ods output BinomialCLs = ci_limits_output;

	proc freq data = prev.&ddi._prev2_sens_only; 
		tables &ddi. / binomial(level = '1' exact) alpha = 0.05 out = prev_ci;
		title "Prevalence of &ddi. among cohort";
	run;

	ods output close;

	/*** Put the results from the proc freq into a single record ***/

	/* Delete unnecessary variables and records from each proc freq table */

	/* Remove row from ci_output data set with information about the proportion (this is already captured by a different table) */
	data ci_output2;
		set ci_output;
		drop Table Name1;

		if Label1 = "Proportion" then delete;

	run;

	/* Drop the Table variable from the ci_limits_output data set */
	data ci_limits_output2;
		set ci_limits_output;
		drop Table;
	run;

	/* Sort prev_ci by &ddi. (this way &ddi. = 0 is listed first) */
	proc sort data = prev_ci;
		by &ddi.;
	run;

	/* Rename variables in the prev_ci data set */
	data prev_ci2;
		set prev_ci;
		rename &ddi. = concurrent_1 COUNT = count_1 PERCENT = percent_1;
	run;

	/* Condense the information in prev_ci to one row */
	data prev_ci3;
		set prev_ci2;
		by concurrent_1;
		retain concurrent_0 count_0 percent_0;

		if concurrent_1 = 0 then do;
			concurrent_0 = concurrent_1;
			count_0 = count_1;
			percent_0 = percent_1;
		end;

	run;

	/* Delete the row in prev_ci where concurrent_1 = 0 (so now we just have one row with all of the information from the table) */
	data prev_ci4;
		set prev_ci3;

		if concurrent_1 = 0 then delete;

	run;

	/* Merge the 3 proc freq tables together */

	data ci_sum;
		merge prev_ci4 ci_limits_output2 ci_output2;
	run;

	/* Add variable to identify the ddi */

	data ci_sum2;
		length ddi $20;
		set ci_sum;

		ddi = "&ddi.";

	run;

	/*** Append results to summary data set with all ddis ***/

	proc append base = smcncr.ddi_prev_info_sens_only data = ci_sum2 force;
	run;

	/*** Delete data sets from the work library */

	proc datasets library = work nolist;
		delete &ddi._lap &ddi._prev ci_output ci_output2 ci_limits_output ci_limits_output2 prev_ci prev_ci2 prev_ci3 prev_ci4 ci_sum ci_sum2;
	quit;

	/* End writing to RTF doc */

	ods rtf close;
	ods graphics off;
	ods results;

%mend; 

/*********************************************************************************************************/
/***  Run the estimate_prev_sens macro for the DDIs where at least one beneficiary had concurrent use  ***/
/*********************************************************************************************************/
	
data _null_;
	set ddi.ddi_list_3d;

	/* Generate macro call for each record */

	call execute(cats('%estimate_prev_sens(', ddi, ');'));
run;

/***************************************************************************************************/
/***  Clean up summary data set and perform summary statistics (smcncr.ddi_prev_info_sens_only)  ***/
/***************************************************************************************************/

/*** Sort the data set by ddi and delete any duplicate records ***/

proc sort data = smcncr.ddi_prev_info_sens_only nodupkey;
	by ddi;
run;

/*** Capitalize characters in the ddi variable ***/

data ddi_prev_info_sens_only_2;
	set smcncr.ddi_prev_info_sens_only;

	ddi = upcase(ddi);

run;

/*** Add the ddi paper variable to the summary data set ***/

proc sql;
	create table smcncr.ddi_prev_info_sens_only2 as
	select a.*, b.ddi_paper
	from ddi_prev_info_sens_only_2 as a inner join ddi.full_ddi_list as b
	on a.ddi = b.ddi;
quit;

/*** Identify which DDIs are missing from smcncr.ddi_prev_info_sens_only ***/

data missing_ddis;
	set smcncr.ddi_prev_info_sens_only2 end=eof;

	/* Create a temporary array of expected DDI variable names: "ddi1" through "ddi98" */
	array expected[98] $8 _temporary_;

	/* On the first iteration only, populate the expected array */
	if _n_ = 1 then do i = 1 to 98;
		expected[i] = cats("DDI", i);
	end;

	/* For each variable name found in the dataset, check if it's in the expected array */
	do i = 1 to 98;
		if ddi = expected[i] then expected[i] = ''; /* Mark this expected DDI variable as found by clearing it out */
	end;

	/* After the last observation, output the names of any expected DDI variables that were not found */
	if eof then do;
		do i = 1 to 98;
			if expected[i] ne '' then do;
				missing_ddi = expected[i];
				output;
			end;
		end;
	end;

	keep missing_ddi; /* Keep only the column with the missing variable names */
run;

proc print data = missing_ddis noobs;
	title "DDI variables missing from dataset";
run;
	/* 
	DDI31 
	DDI33 
	DDI34 
	DDI46 
	DDI51 
	DDI54 
	DDI58 
	DDI83 
	DDI84 
	DDI85 
	DDI96 
	*/

/*** Add records for the DDIs with no concurrent use (so prevalence is 0) ***/

/* Write macro to add a record to the summary data set for each potential DDI where there was no concurrent use for any beneficiaries */

%macro add_ddis(ddi);

	/* Create a data set with the same variables as the summary data set. Populate the values to indicate no concurrent use */
	data &ddi._sum;
		length ddi $20;

		ddi = "&ddi.";
		concurrent_1 = 1;
		count_1 = 0;
		percent_1 = 0;
		concurrent_0 = 0;
		count_0 = 485251;
		percent_0 = 100;
		Proportion = 0;
		LowerCL = 0;
		UpperCL = 0;

	run;

	/* Add data set as a record to the summary data set */
	proc append base = smcncr.ddi_prev_info_sens_only2 data = &ddi._sum force;
	run;

	/* Delete data set from work library */
	proc datasets library = work nolist;
		delete &ddi._sum;
	quit;

%mend;

/* Run the macro for each DDI where no beneficiaries had concurrent medication use */

%add_ddis(DDI31);
%add_ddis(DDI33);
%add_ddis(DDI34);
%add_ddis(DDI46);
%add_ddis(DDI51);
%add_ddis(DDI54);
%add_ddis(DDI58);
%add_ddis(DDI83);
%add_ddis(DDI84);
%add_ddis(DDI85);
%add_ddis(DDI96);

/* Sort the summary data set again and delete duplicate records */

proc sort data = smcncr.ddi_prev_info_sens_only2 nodupkey;
	by ddi;
run;

/*****************************************************************************************************************************************************************/
/*** Calculate the median number of days of concurrent medication use for each potential DDI, among beneficiaries exposed to the DDI in the stability analysis ***/
/*****************************************************************************************************************************************************************/
	
%macro median_days_sens(ddi);

	/* Writing to RTF doc */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** For the potential ddi, reduce the prev.&ddi._prev2 data set to only include beneficiaries who meet the criteria for the ddi ***/

	data &ddi._met;
		set prev.&ddi._prev2_sens_only;

		if &ddi. = 0 then delete;

	run;

	/*** Calculate median, q1, and q3 of sum_overlap ***/

	title1 "Median, Q1, and Q3 of &ddi._met";
	proc means data = &ddi._met n median q1 q3 noprint;
		var sum_overlap;
		output out=&ddi._sumstat 
				n = n
	            median = median
	            q1 = q1
	            q3 = q3;
	run;

	/*** Add ddi variable to the outputted data set from proc means ***/

	data &ddi._sumstat2;
		length ddi $255;
		set &ddi._sumstat;

		ddi = "&ddi.";

	run;

	/*** Append results to summary data set ***/

	proc append base = smcncr.ddi_median_info_sens_only data = &ddi._sumstat2 force;
	run;

	/*** Delete data sets from work library ***/

	proc datasets library = work nolist;
		delete &ddi.: ;
	quit;

	/* End writing to RTF doc */

	title1;
	ods rtf close;
	ods graphics off;
	ods results;

%mend;

/********************************************************************/
/********** Run the macro above (%median_days_sens) **************/
/********************************************************************/

data _null_;
	set ddi.ddi_list_3d;

	/* Generate macro call for each record */

	call execute(cats('%median_days_sens(', ddi, ');'));
run;

/*** Identify which DDIs are missing from smcncr.ddi_median_info_sens_only ***/

data missing_ddis;
	set smcncr.ddi_median_info_sens_only end=eof;

	/* Create a temporary array of expected DDI variable names: "ddi1" through "ddi98" */
	array expected[98] $8 _temporary_;

	/* On the first iteration only, populate the expected array */
	if _n_ = 1 then do i = 1 to 98;
		expected[i] = cats("ddi", i);
	end;

	/* For each variable name found in the dataset, check if it's in the expected array */
	do i = 1 to 98;
		if ddi = expected[i] then expected[i] = ''; /* Mark this expected DDI variable as found by clearing it out */
	end;

	/* After the last observation, output the names of any expected DDI variables that were not found */
	if eof then do;
		do i = 1 to 98;
			if expected[i] ne '' then do;
				missing_ddi = expected[i];
				output;
			end;
		end;
	end;

	keep missing_ddi; /* Keep only the column with the missing variable names */
run;

proc print data = missing_ddis noobs;
	title "DDI variables missing from dataset";
run;
/*
ddi31 
ddi33 
ddi34 
ddi46 
ddi51 
ddi54 
ddi58 
ddi83 
ddi84 
ddi85 
ddi96 
*/

/**********************************************************************************************/
/********** Clean up summary median data set and perform descriptive statistics  **************/
/**********************************************************************************************/

/*** Sort the data set by the variable ddi and delete any duplicate records ***/

proc sort data = smcncr.ddi_median_info_sens_only nodupkey;
	by ddi;
run;

/*** Add records for the DDIs with no concurrent use (so median is 0) ***/

/* Write macro to add a record to the summary data set for each potential DDI where there was no concurrent use for any beneficiaries */

%macro add_ddis3(ddi);

	/* Create a data set with the same variables as the summary data set. Populate the values to indicate no concurrent use */
	data &ddi._sumstat2;
		length ddi $255;

		ddi = "&ddi.";

		n = 0;
		median = 0;
		q1 = 0;
		q3 = 0;

	run;

	/* Add data set as a record to the summary data set */
	proc append base = smcncr.ddi_median_info_sens_only data = &ddi._sumstat2 force;
	run;

	/* Delete data set from work library */
	proc datasets library = work nolist;
		delete &ddi._sumstat2;
	quit;

%mend;

/* Run the macro for each DDI with no concurrent use */

%add_ddis3(ddi31);
%add_ddis3(ddi33);
%add_ddis3(ddi34);
%add_ddis3(ddi46);
%add_ddis3(ddi51);
%add_ddis3(ddi54);
%add_ddis3(ddi58);
%add_ddis3(ddi83);
%add_ddis3(ddi84);
%add_ddis3(ddi85);
%add_ddis3(ddi96);

/*** Capitalize characters in the ddi variable (so that we can merge with ddi.full_ddi_list) ***/

data ddi_median_info_sens_only_2;
	set smcncr.ddi_median_info_sens_only;

	ddi = upcase(ddi);

run;

/*** Add paper DDI name to each record in the ddi.full_ddi_list data set ***/
	/* NOTE: the ddi variable just lists the ddis from ddi1-ddi98. The paper ddi names specify what paper the ddi is from. 
			I added this just to make it a little easier to identify what ddi the observation is referring to */

proc sql;
	create table smcncr.ddi_median_info_sens_only2 as
	select a.ddi, b.ddi_paper, a.n, a.median, a.q1, a.q3
	from ddi_median_info_sens_only_2 as a inner join ddi.full_ddi_list as b
	on a.ddi = b.ddi;
quit;

/**************************************************************************************************************************************************************/
/********** Bring in information from our 2 calculations (prevalence and median days of concurrent medication us) for each DDI into one data set **************/
/**************************************************************************************************************************************************************/
	/* Our summary data sets for each calculation are as follows:                             */
	/*    1. Summary of prevalence calculations:         smcncr.ddi_prev_info_sens_only2      */
	/*    2. Summary of median days calculations:        smcncr.ddi_median_info_sens_only2    */
		
/*** Merge the summary data sets together ***/

/* Change the length of the ddi variable in smcncr.ddi_prev_info2 so that it's the same as the other summary data sets */

data ddi_prev_info_sens_only3;
	length ddi_new $255;
	set smcncr.ddi_prev_info_sens_only2;

	ddi_new = ddi;

	drop ddi;

run;

data ddi_prev_info_sens_only4;
	set ddi_prev_info_sens_only3;

	ddi = ddi_new;

	drop ddi_new;

run;

/* Make sure the summary data sets are sorted by the ddi variable */

proc sort data = ddi_prev_info_sens_only4 nodupkey;
	by ddi;
run;

proc sort data = smcncr.ddi_median_info_sens_only2 nodupkey;
	by ddi;
run;

/* Merge the summary data sets together by the ddi variable (i.e., one-to-one-to-one merge) */

data calc_all_0;
	merge ddi_prev_info_sens_only4 (in=in1 keep=ddi count_1 count_0 percent_1 Proportion LowerCL UpperCL) 
	      smcncr.ddi_median_info_sens_only2 (in=in3 keep=ddi ddi_paper n median q1 q3);
	by ddi;
run; /* each summary data set has 98 observations, and the merged data set has 98 observations */

/* Rename some variables and add labels for clarity */

data smcncr.calc_all_sens;
	set calc_all_0;

	/* Rename variables from prevalence dataset */
	Prop_LowerCL = LowerCL;
	Prop_UpperCL = UpperCL;

		/* Generate Perc variables based on the value of Proportion */
		Perc = Proportion * 100;
		Perc_LowerCL = LowerCL * 100;
		Perc_UpperCL = UpperCL * 100;

	/* Rename variables from median days concurrent use dataset */
	Median_Days = median;
	Median_Days_Q1 = q1;
	Median_Days_Q3 = q3;

	/* Flag if DDI violates the CMS cell size suppression policy */
	if 1 <= count_1 <= 10 then small_cell_size = 1; /* A value of 0 does not violate the minimum cell size policy */
	else small_cell_size = 0;

	drop percent_1 n LowerCL UpperCL median q1 q3;

	label
	small_cell_size = "1 if the number of benes who had concurrent medication use is between 1 and 10. 0 otherwise"
	Proportion = "Number of benes with at least one day of concurrent medication use / Number of benes in cohort"
	Prop_LowerCL = "'Proportion' lower 95% CL using binomial distribution + Clopper-Pearson formula"
	Prop_UpperCL = "'Proportion' upper 95% CL using binomial distribution + Clopper-Pearson formula"
	Perc = "'Proportion' * 100"
	Perc_LowerCL = "'Prop_LowerCL' * 100"
	Perc_UpperCL = "'Prop_UpperCL' * 100"
	Median_Days = "Median number of days of concurrent med use, among benes who had at least 1 day of concurrent med use"
	Median_Days_Q1 = "'Median_Days' quartile 1"
	Median_Days_Q3 = "'Median_Days' quartile 3"
	count_0 = "Number of benes who did not have any concurrent med use"
	count_1 = "Number of benes with at least one day of concurrent med use"
	percent_1 = "Percent of benes in the cohort with at least one day of concurrent med use"
	ddi = "DDI number"
	ddi_paper = "DDI paper number (just a slightly different naming scheme from the ddi variable)";

run;

/****************************************************************************************/
/*** Merge consensus list datasets with those from the main results to easily compare ***/
/****************************************************************************************/

/*** Change the values of the ddi variable in smcncr.calc_all_sens back to lowercase ***/

data calc_all_sens_2;
	set smcncr.calc_all_sens;

	ddi = lowcase(ddi);

run;

/*** Merge final calculation datasets together ***/

proc sql;
	create table smcncr.calc_all_anrys_comb as
	select a.*, b.count_1 as count_1_sens, b.count_0 as count_0_sens, b.Perc as Perc_sens, b.Perc_LowerCL as Perc_LowerCL_sens,
	       b.Perc_UpperCL as Perc_UpperCL_sens, b.Median_Days as Median_Days_sens, b.Median_Days_Q1 as Median_Days_Q1_sens, b.Median_Days_Q3 as Median_Days_Q3_sens,
		   b.small_cell_size as small_cell_size_sens
	from smcncr.calc_all as a
	inner join calc_all_sens_2 as b
	on a.ddi = b.ddi;
quit;

/*** Calculate the relative change in percentages and median days concurrent medication use between the primary and stability analysis ***/

data smcncr.calc_all_anrys_comb_2;
	set smcncr.calc_all_anrys_comb;

	/* Calculate the absolute relative change in percentages */
	perc_diff_rel = (abs(Perc - Perc_sens) / Perc) * 100;

	/* Calculate the absolute relative change in median days */
	days_diff_rel = (abs(Median_Days - Median_Days_sens)) / Median_Days * 100;

	label
		perc_diff_rel = "Absolute relative change between Perc and Perc_sens"
		days_diff_rel = "Absolute relative change between Median_Days and Median_Days_sens"
	;

run;

/****************************************************************************/
/*** Partition the smcncr.calc_all_anrys_comb_2 dataset by consensus list ***/
/****************************************************************************/

data smcncr.calc_all_anrys_sens smcncr.calc_all_beers_sens smcncr.calc_all_capiau_sens;
set smcncr.calc_all_anrys_comb_2;

	/* If DDI_paper contains "anrys", output the DDI into the anrys data set */
	if index(DDI_paper, "anrys") = 1 then do;
		output smcncr.calc_all_anrys_sens;
	end;

	/* If DDI_paper contains "beers", output the DDI into the beers data set */
	if index(DDI_paper, "beers") = 1 then do;
		output smcncr.calc_all_beers_sens;
	end;

	/* If DDI_paper contains "capiau", output the DDI into the capiua data set */
	if index(DDI_paper, "capiau") = 1 then do;
		output smcncr.calc_all_capiau_sens;
	end;

run;

/***************************/
/*** Output Tables S2-S4 ***/
/***************************/

%macro tables_ddi(data);

	proc sort data = smcncr.calc_all_&data._sens;
		by descending count_1;
	run;

	title1 "SUPPLEMENTARY TABLE: &data. DDIs";
	proc print data = smcncr.calc_all_&data._sens;
		var ddi ddi_paper count_1 Perc Perc_LowerCL Perc_UpperCL count_1_sens Perc_sens Perc_LowerCL_sens Perc_UpperCL_sens perc_diff_rel Median_Days Median_Days_Q1 Median_Days_Q3 Median_Days_sens Median_Days_Q1_sens Median_Days_Q3_sens days_diff_rel;
	run;

%mend;

%tables_ddi(anrys);
%tables_ddi(capiau);
%tables_ddi(beers);

/* END OF PROGRAM */
