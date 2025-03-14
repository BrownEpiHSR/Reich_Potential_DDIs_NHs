/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
1. Estimate the prevalence of each DDI.
2. Calculate the median days of concurrent medication use for each
   potential DDI, among beneficiaries with at least one day of concurrent
   medication use for the DDI.
3. Create output for Table 2 
   (Top 20 Potential Drug Interactions Among Nursing Home Residents, 
   2018-2020 (N = 485,251 Residents)).

Programmer: Laura Reich   
 
Date Last Modified: March 14, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- merged.&ddi._dyswddi: Episodes of concurrent medication use for the given potential DDI
 (i.e., each record is an episode of a concurrent medication use and includes the beneficiary ID, start 
  date of the episode, end date of the episode, and the length of the episode (days_with_ddi))
     - Generated in 3_Create_DDI_Exposure_Eps.sas
- lrenroll.nh_person_days_sex: Person-level cohort dataset with sex variable included
  (i.e., includes beneficiary ID, sex, and total days in the NH)
- ddi.full_ddi_list: Dataset with the list of the names for the 98 DDIs considered for this analysis
     - Generated in 2_Create_Concurrent_Med_Eps.sas
*********************************************************************/

/*********************************************************************
Key generated datasets:
- merged.&ddi._lap: Person-level concurrent medication use dataset 
  (i.e., each record is a unique beneficiary and their total days of concurrent medication use for the given potential DDI)
- prev.&ddi._prev2: Person-level DDI-specific dataset, lists whether or not a beneficiary met the criteria for the DDI
- smcncr.ddi_prev_info2: DDI-level prevalence estimates dataset 
  (i.e., each record is a prevalence estimate for a given potential DDI)
- ddi.ddi_list_3d: Dataset with the list of DDIs to be run through the estimate_prev macro
  (i.e., only includes DDIs where at least one beneficiary in the cohort was exposed to the DDI)
- smcncr.ddi_median_info: DDI-level median days of DDI exposure dataset
  (i.e., each record is the median number of days of concurrent medication use for a given potential DDI)
- smcncr.calc_all_2: DDI-level prevalence and median days of DDI exposure dataset
- smcncr.calc_top20: Top 20 DDIs, prevalence and median days of DDI exposure
- smcncr.calc_table2_2: Table 2 output
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname lrenroll "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\enrollment"; 
libname merged "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files"; 
libname prev "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\est_prev"; 
libname ddi "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\concurrent_use\ddi_lists"; 
libname smcncr "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files\summary_info"; 

options mprint;

/*******************************************/
/*** Estimate the prevalence of each DDI ***/
/*******************************************/

%macro estimate_prev(ddi);

/*** Create dataset where each record is a unique beneficiary and their total days of concurrent medication use 
     (i.e., person-level concurrent medication use dataset) ***/

proc sql;
create table &ddi._lap as
select bene_id_18900, sum(days_with_ddi) as sum_overlap
from merged.&ddi._dyswddi
group by bene_id_18900;
quit;
run;

/*** Make flag for the DDI in the person-level concurrent medication use dataset ***/
	/* NOTE: If a beneficiary is in the &ddi._lap dataset, they experienced at least one day of concurrent medication use for the given DDI */

data merged.&ddi._lap;
set &ddi._lap;

	&ddi. = 1;

	label
	sum_overlap = "Total days of concurrent use for this potential DDI"
	&ddi. = "DDI Flag, 1 = beneficiary had concurrent use of meds for this potential DDI";

run;

/*** Merge the person-level concurrent medication use dataset with the person-level cohort dataset (with sex variable included) ***/
	/* NOTE: Because we are using a full join, &ddi._prev will include beneficiaries that had no concurrent use for the given DDI */

proc sql;
	create table &ddi._prev as
	select a.&ddi., a.sum_overlap, b.*
	from merged.&ddi._lap as a full join lrenroll.nh_person_days_sex as b
	on a.bene_id_18900 = b.bene_id_18900;
quit;

/*** Estimate the prevalence of this DDI and calculate the 95% CLs using the Clopper-Pearson (exact) formula ***/

	/* If the the ddi is ddi94 (i.e., Beers8, or peripheral alpha-1 blockers + loop diuretics, which the paper specifically said to avoid concurrent use in older women), 
	   restrict to beneficiaries with sex listed as female */

%if &ddi. = ddi94 %then %do;

	data prev.&ddi._prev2;
	set &ddi._prev;

		/* Here we remove any beneficiaries where sex is listed as male */
		if hksex_prs ne 2 then delete; /* 1 is male, 2 is female */

		/* For the records remaining, any records where the value for &ddi. is missing, replace with 0 (i.e., beneficiary was not exposed to this potential DDI) */
		if &ddi. = . then &ddi. = 0;

	run;

%end;

	/* If the ddi is not equal to ddi94, don't make any exclusions based on beneficiary's sex */

%else %if &ddi. ne ddi94 %then %do;

	data prev.&ddi._prev2;
	set &ddi._prev;

	/* For any records where the value of &ddi. is missing, replace with 0 (i.e., beneficiary was not exposed to this potential DDI) */
	if &ddi. = . then &ddi. = 0;

	run;

%end;

	/* Calculate prevalence and 95% confidence limits using proc freq */

ods output Binomial = ci_output;
ods output BinomialCLs = ci_limits_output;

proc freq data = prev.&ddi._prev2; /* If there were no beneficiaries with concurrent use for the given DDI, this will result in an error */
tables &ddi. / binomial(level = '1' exact) alpha = 0.05 out = prev_ci;
title "Prevalence of &ddi. among cohort";
run;

ods output close;

/*** Put the results from the proc freq into a single record ***/

	/* Delete unnecessary variables and records from each proc freq table */

		/* Remove row from ci_output dataset with information about the proportion (this is already captured by a different table) */
		data ci_output2;
			set ci_output;
			drop Table Name1;

			if Label1 = "Proportion" then delete;

		run;

		/* Drop the Table variable from the ci_limits_output dataset */
		data ci_limits_output2;
			set ci_limits_output;
			drop Table;
		run;

		/* Sort prev_ci by &ddi. (this way &ddi. = 0 is listed first) */
		proc sort data = prev_ci;
		by &ddi.;
		run;

		/* Rename variables in the prev_ci dataset */
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
		run; /* no by statement - this is a one-to-one-to-one merge */

			/* Add variable to identify the DDI */

		data ci_sum2;
			length ddi $255;
			set ci_sum;

			ddi = "&ddi.";

		run;

/*** Append results to summary dataset with all DDI ***/

proc append base = smcncr.ddi_prev_info data = ci_sum2 force;
run;

/*** Delete datasets from the work library ***/

proc datasets library = work nolist;
	delete &ddi._lap &ddi._prev ci_output ci_output2 ci_limits_output ci_limits_output2 prev_ci prev_ci2 prev_ci3 prev_ci4 ci_sum ci_sum2;
quit;

%mend; 

/**************************************************************************************************/
/*** Run the estimate_prev macro for the DDIs where at least one beneficiary had concurrent use ***/
/**************************************************************************************************/

data ddi.ddi_list_3d;
	set ddi.full_ddi_list;

	ddi = lowcase(strip(ddi));
	component_1 = lowcase(strip(component_1)); 
	component_2 = lowcase(strip(component_2));
	component_3 = lowcase(strip(component_3));
	if include_3d = 0 then delete;
run; /* This dataset only includes the names of DDIs where at least one beneficiary had concurrent medication use (i.e., medication use overlap) */

data _null_;
	set ddi.ddi_list_3d;

	/* Generate macro call for each record */

	call execute(cats('%estimate_prev(', ddi, ');'));
run;

/*******************************************************/
/*** Clean up summary dataset (smcncr.ddi_prev_info) ***/
/*******************************************************/

/*** Add records for the potential DDIs where 0 beneficiaries had concurrent medication use (so prevalence is 0) ***/

%macro add_ddis(ddi);

	/* Create a dataset with the same variables as the summary dataset. Populate the values to indicate no concurrent use */
data &ddi._sum;
length ddi $255;

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

	/* Add dataset as a record to the summary dataset */

proc append base = smcncr.ddi_prev_info data = &ddi._sum force;
run;

	/* Delete dataset from work library */

proc datasets library = work nolist;
	delete &ddi._sum;
quit;

%mend;

	/* Run the macro for each DDI where no beneficiaries had concurrent medication use */

%add_ddis(ddi51);
%add_ddis(ddi54);
%add_ddis(ddi58);
%add_ddis(ddi96);
%add_ddis(ddi85);
%add_ddis(ddi31);
%add_ddis(ddi33);
%add_ddis(ddi34);
%add_ddis(ddi83);
%add_ddis(ddi84);
%add_ddis(ddi46);

	/* Sort the summary dataset and delete duplicate records */

proc sort data = smcncr.ddi_prev_info nodupkey;
by ddi;
run;

/*** Add the DDI paper variable to the summary dataset ***/
	/* NOTE: the ddi variable just lists the ddis from ddi1-ddi98. The paper ddi names specify what consensus list the DDI is from (e.g., Beers8, Anrys36). 
	   This was added to make it a little easier to identify what DDI the observation is referring to */

proc sql;
	create table smcncr.ddi_prev_info2 as
	select a.*, b.ddi_paper
	from smcncr.ddi_prev_info as a inner join ddi.full_ddi_list as b
	on lowcase(a.ddi) = lowcase(b.ddi);
quit;

/***************************************************************************************************************************************/
/*** Calculate the median number of days of concurrent medication use for each potential DDI, among beneficiaries exposed to the DDI ***/
/***************************************************************************************************************************************/
	/* NOTE: Days of DDI exposure are not required to be consecutive */

%macro absolute_value(ddi);

/*** For the potential DDI, reduce the prev.&ddi._prev2 dataset to only include beneficiaries who were exposed to the DDI ***/

data &ddi._met;
set prev.&ddi._prev2;

if &ddi. = 0 then delete;

run;

/*** Produce histogram of sum_overlap (i.e., number of days of concurrent medication use for the given beneficiary)
in the dataset restricted to beneficiaries who were exposed to the DDI ***/

proc univariate data = &ddi._met;
	var sum_overlap;
	histogram sum_overlap / normal;
	inset mean std="Std Dev" median q1 q3 min max / pos = ne;
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

/*** Add ddi variable to the outputted dataset from proc means ***/

data &ddi._sumstat2;
length ddi $255;
set &ddi._sumstat;

	ddi = "&ddi.";

run;

/*** Append results to summary dataset ***/

proc append base = smcncr.ddi_median_info data = &ddi._sumstat2 force;
run;

/*** Delete datasets from work library ***/

proc datasets library = work nolist;
	delete &ddi.: ;
quit;

%mend;

/****************************************************************************************************/
/*** Run the absolute_value macro for the DDIs where at least one beneficiary had concurrent use  ***/
/****************************************************************************************************/

data _null_;
	set ddi.ddi_list_3d;

	/* Generate macro call for each record */

	call execute(cats('%absolute_value(', ddi, ');'));
run;

/*********************************************************/
/*** Clean up summary dataset (smcncr.ddi_median_info) ***/
/*********************************************************/

/*** Sort the dataset by the DDI variable and delete any duplicate records ***/

proc sort data = smcncr.ddi_median_info nodupkey;
by ddi;
run;

/*** Add records for the DDIs with no concurrent use (so median is 0) ***/

%macro add_ddis3(ddi);

	/* Create a dataset with the same variables as the summary dataset. Populate the values to indicate no concurrent use */

data &ddi._sumstat2;
length ddi $255;

ddi = "&ddi.";

n = 0;
median = 0;
q1 = 0;
q3 = 0;
_TYPE_ = .;
_FREQ_ = .;

run;

	/* Add dataset as a record to the summary dataset */

proc append base = smcncr.ddi_median_info data = &ddi._sumstat2 force;
run;

	/* Delete dataset from work library */

proc datasets library = work nolist;
	delete &ddi._sumstat2;
quit;

%mend;

	/* Run the macro for each DDI with no concurrent use */

%add_ddis3(ddi51);
%add_ddis3(ddi54);
%add_ddis3(ddi58);
%add_ddis3(ddi96);
%add_ddis3(ddi85);
%add_ddis3(ddi31);
%add_ddis3(ddi33);
%add_ddis3(ddi34);
%add_ddis3(ddi83);
%add_ddis3(ddi84);
%add_ddis3(ddi46);

/******************************************************************************************/
/*** Bring DDI prevalence and median days of DDI exposure calculations into one dataset ***/
/******************************************************************************************/

	/* Make sure the summary datasets are sorted by the DDI variable */

proc sort data = smcncr.ddi_prev_info2 nodupkey;
	by ddi;
run;

proc sort data = smcncr.ddi_median_info nodupkey;
	by ddi;
run;

	/* Merge the summary datasets together by the ddi variable (i.e., one-to-one merge) */

data calc_all_0;
merge smcncr.ddi_prev_info2  (in=in1 keep=ddi ddi_paper count_1 count_0 percent_1 Proportion LowerCL UpperCL) 
      smcncr.ddi_median_info (in=in2 keep=ddi n median q1 q3);
by ddi;
run; /* each summary dataset has 98 observations, and the merged dataset has 98 observations */

/********************************************************************************/
/*** Rename some variables and add labels to the combined dataset for clarity ***/
/********************************************************************************/

data smcncr.calc_all_2;
set calc_all_0;

	/* Rename variables from smcncr.ddi_prev_info2 */
	Prop_LowerCL = LowerCL;
	Prop_UpperCL = UpperCL;

		/* Generate Perc variables based on the value of Proportion */
		Perc = Proportion * 100;
		Perc_LowerCL = LowerCL * 100;
		Perc_UpperCL = UpperCL * 100;

	/* Rename variables from smcncr.ddi_median_info */
	Median_Days = median;
	Median_Days_Q1 = q1;
	Median_Days_Q3 = q3;

	/* Flag if DDI violates the CMS cell size suppression policy */
	if 1 <= count_1 <= 10 then small_cell_size = 1;
	else small_cell_size = 0;

	drop n LowerCL UpperCL median q1 q3;

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

/***************************************************/
/*** Limit dataset to the 20 most prevalent DDIs ***/
/***************************************************/

/*** Sort the dataset in descending order by DDI prevalence ***/

proc sort data = smcncr.calc_all_2;
by descending perc;
run;

/*** Limit dataset to the 20 most prevalent DDIs ***/

data smcncr.calc_top20_2;
	set smcncr.calc_all_2 (obs = 20);
run;

/***************************/
/*** Output Table 2 data ***/
/***************************/

/*** Keep the variables for Table 2 ***/

data smcncr.calc_table2_2;
	set smcncr.calc_top20;

	keep ddi ddi_paper count_1 perc perc_lowercl perc_uppercl median_days median_days_q1 median_days_q3;

run;

/*** Sort the new dataset in descending order by DDI prevalence ***/

proc sort data = smcncr.calc_table2_2;
	by descending perc;
run;

/*** Print the dataset ***/

title1 "TABLE 2: Prevalence and median days of exposure for top 20 DDIs";
proc print data = smcncr.calc_table2_2;
	var ddi ddi_paper count_1 perc perc_lowercl perc_uppercl median_days median_days_q1 median_days_q3;
	format perc perc_lowercl perc_uppercl 8.1 median_days median_days_q1 median_days_q3 8.;
run;

/* END OF PROGRAM */
