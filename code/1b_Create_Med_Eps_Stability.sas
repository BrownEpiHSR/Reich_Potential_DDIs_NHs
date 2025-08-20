/**************************************************************************
Project Title: Prevalence and Duration of Potential Drug-Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create medication use episodes for the stability analysis by making the
following additions:
	1. Identify the last dispensing in each episode, and
	2. Assign a new end date for each medication episode = last
       dispensing date + 50% of its days' supply

Programmer: Laura Reich   
 
Date Last Modified: July 8, 2025
***************************************************************************/

/***************************************************************************
Loaded datasets:
- dcln2.&ddi._4_v2: DDI component Part D dispensing datase after removing 
                  days supply (DS) = 0, truncating DS > 90 to 90, and 
                  deduplicating records.
	- Generated in 1a_Create_Med_Eps.sas
- lrenroll.plevel_enroll: Continuous enrollment periods dataset. Each
                        record is a unique continuous enrollment period
                        for a cohort member.
	- Generated in 1a_Create_Med_Eps.sas
- lrenroll.observ_windows5_excl_set1: NH stay dataset. Each record
                                    represents a unique NH stay between 2018-2020 
                                    for cohort members after applying the exclusion 
                                    criteria. 
- names.macro_parameters: Dataset with names of the DDI components.
     - Generated in 0_Create_Dispensing_Datasets.sas
***************************************************************************/

/***************************************************************************
Key generated datasets:
- nhtm2.&ddi._c5_sens: Medication episodes for a given DDI component, 2018-2020, 
                       within NH stays. This includes an adjusted end date
                       that is the last dispensing date + 50% of its
                       days' supply. The original end date (max_enddt_nh) from the 
                       primary analysis is also included.
***************************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname drugs    "your/library/path"; /* Drug-level claims */
libname lrenroll "your/library/path"; /* Relevant NH time data set with exclusions applied */
libname dcln2    "your/library/path"; /* Cleaned DDI Component Data Sets, v2 */
libname clp2     "your/library/path"; /* Collapsed medication episode data sets, v2 */
libname nhtm2    "your/library/path"; /* Medication episodes during NH time data sets */
libname merged   "your/library/path"; /* Merged medication episode data sets */
libname prev     "your/library/path"; /* Data sets with all beneficiaries to estimate prevalence for each DDI */
libname ddi      "your/library/path"; /* Data sets with lists of ddis and their components drug categories */
libname smcncr   "your/library/path"; /* DDI prevalence summary info */
libname names    "your/library/path"; /* Names of each ddi component */

options mprint mlogic; 

/*************************************************************/
/*** Refine medication use episodes for stability analysis ***/
/*************************************************************/

%macro sens_med_eps(ddi_sheet);

	/*** Replace any '-' in the DDI sheet name to 'xx', since SAS data set names cannot include '-' ***/
	%let ddi = %sysfunc(tranwrd(&ddi_sheet., -, xx));

	/*** Write to RTF document ***/
	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** Limit dispensings to beneficiary's enrolled time by merging data set with lrenroll.plevel_enroll ***/

	proc sql; /* A given beneficiary may have more than one enrollment period */
		create table &ddi._5 as
		select a.*
		from dcln2.&ddi._4_v2 as a inner join lrenroll.plevel_enroll as b
		on a.bene_id_18900=b.bene_id_18900 &
		(b.enroll_start <= a.hdfrom <= b.enroll_end);
	quit;

	title1 "number of observations after restricting to dispensings to enrolled time";
	title2 "&ddi._5";
	proc sql;
		select count(bene_id_18900)
		from &ddi._5;
	quit;
	title;

	/*****************************************************/
	/*****  Create crude medication use episodes   *******/
	/*****************************************************/

	/*** Create medication start and end date variables based on the days of supply, assuming that the person starts their medication on the date of dispensing ***/

	/* Sort by beneficiary ID, core_drug, and dispensing date */
	proc sort data = &ddi._5; 
		by bene_id_18900 core_drug hdfrom;
	run;

	/* Create medication start and end date variables */
	data &ddi._6;
		set &ddi._5;
		
		/* Create start_fill_date, assuming that the person starts the medication on the day on the date of dispensing */
		start_fill_date = hdfrom;

		/* Create end_fill_date, assuming that the person stops taking the medication on the last day of the supply */
		end_fill_date = (start_fill_date - 1 + hddays);

		label
		start_fill_date = 'first day of med use in crude ep (hdfrom)'
		end_fill_date ='last day of med use in crude ep (start_fill_date - 1 + hddays)';

		format start_fill_date end_fill_date date9.;
	run;

	title1 "data set = &ddi._6, 20 obs";
	title2 "data set after creating start_fill_date and end_fill_date variables based on days of supply";
	proc print data = &ddi._6 (obs = 20);
		var bene_id_18900 core_drug hdfrom hddays start_fill_date end_fill_date;
	run;

	/*****************************************************************************/
	/********* Create adjusted start and end dates of medication use   ***********/
	/*****************************************************************************/

	proc format;
		value ep_flag_fmt
		1 = "first record for a person"
		2 = "new drug dispensing for a person"
		3 = "end fill date is on or before the previous dispensing's end fill date, will delete"
		4 = "start fill date before the previous dispensing's end fill date"
		4.5 = "start of med use is 1 day after previous dispensing's end fill date"
		5 = "no overlap with previous dispensing";
	run;

	data &ddi._7;
		set &ddi._6;
		by bene_id_18900 core_drug hdfrom;
		retain prev_bene_id prev_core_drug prev_adj_st_fill_date prev_adj_end_fill_date; /* Retain variables */ 

		/*** For a person's first-ever dispensing in the data, keep start_fill_date (medication start) and end_fill_date (supply end) unchanged ***/
		if first.bene_id_18900 then do;
			adj_st_fill_date = start_fill_date;
			adj_end_fill_date = end_fill_date;
			ep_flag = 1; /* first record of a given person */

			prev_bene_id = bene_id_18900;
			prev_core_drug = core_drug;
			prev_adj_st_fill_date = adj_st_fill_date;
			prev_adj_end_fill_date = adj_end_fill_date;
		end;

		/*** For the first dispensing of a particular drug for a person, keep start_fill_date (medication start) and end_fill_date (supply end) unchanged ***/
		else if (bene_id_18900 = prev_bene_id) and (core_drug ne prev_core_drug) then do;
			adj_st_fill_date = start_fill_date;
			adj_end_fill_date = end_fill_date;
			ep_flag = 2; /* new drug dispensing for a given person */

			prev_bene_id = bene_id_18900;
			prev_core_drug = core_drug;
			prev_adj_st_fill_date = adj_st_fill_date;
			prev_adj_end_fill_date = adj_end_fill_date;
		end;

		/*** Otherwise if the end fill date is on or before the previous dispensing's adjusted end fill date, flag to delete ***/
		else if end_fill_date <= prev_adj_end_fill_date then do;
			adj_st_fill_date = .;
			adj_end_fill_date = .;
			ep_flag = 3;
		end;

		/*** Otherwise, if the start of medication use is on or before the adjusted end supply date from the previous dispensing, set the adjusted start fill date to be one day after the previous dispensing's
		adjusted end supply date. Keep the end supply date unchanged ***/
		else if start_fill_date <= prev_adj_end_fill_date then do;
			adj_st_fill_date = prev_adj_end_fill_date + 1;
			adj_end_fill_date = end_fill_date;
			ep_flag = 4; /* partial overlap between dispensings */

			prev_bene_id = bene_id_18900;
			prev_core_drug = core_drug;
			prev_adj_st_fill_date = adj_st_fill_date;
			prev_adj_end_fill_date = adj_end_fill_date;
		end;

		/*** Otherwise, if the start of medication use is exactly one day after the previous dispensing's adjusted end supply date, keep start_fill_date (medication start) and end_fill_date (supply end) unchanged. 
		Make a unique flag value to help correctly collapse medication use episodes in later code ***/
		else if start_fill_date = (prev_adj_end_fill_date + 1) then do;
			adj_st_fill_date = start_fill_date;
			adj_end_fill_date = end_fill_date;
			ep_flag = 4.5; /* start fill date is exactly one day before the previous dispensing */

			prev_bene_id = bene_id_18900;
			prev_core_drug = core_drug;
			prev_adj_st_fill_date = adj_st_fill_date;
			prev_adj_end_fill_date = adj_end_fill_date;
		end;

		/*** Otherwise, if the start of medication use occurs any other time after the end of supply from the prior dispensing, keep start_fill_date (medication start) and end_fill_date (supply end) unchanged ***/
		else if start_fill_date > prev_adj_end_fill_date then do;
			adj_st_fill_date = start_fill_date;
			adj_end_fill_date = end_fill_date; /* Remember end_fill_date was calculated as end_fill_date = (start_fill_date - 1 + hddays) */
			ep_flag = 5; /* no overlap between previous dispensing */

			prev_bene_id = bene_id_18900;
			prev_core_drug = core_drug;
			prev_adj_st_fill_date = adj_st_fill_date;
			prev_adj_end_fill_date = adj_end_fill_date;
		end;

		format adj_st_fill_date date9. adj_end_fill_date date9. prev_adj_st_fill_date date9. prev_adj_end_fill_date date9. ep_flag ep_flag_fmt.;

		label 
		adj_st_fill_date = 'adjusted start fill date for medication, taking into account the days supply from prior dispensings'
		adj_end_fill_date = 'adjusted end fill date for medication, taking into account the days supply from prior dispensings'
		prev_bene_id = 'beneficiary id from the previous record'
		prev_core_drug = 'core drug name from the previous record'
		prev_adj_st_fill_date = 'start fill date from the previous record'
		prev_adj_end_fill_date = 'end supply date from the previous record';

	run;

	/**********************************************/
	/**** Create continuous medication episodes ***/
	/**********************************************/

	/*** Create medication episodes where, for a given beneficiary and a given drug, consecutive dispensings 1 day apart are considered to be part of the same medication episode ***/

	data &ddi._8;
		set &ddi._7;
		by bene_id_18900 core_drug;

		if ep_flag = 1 then episode = 1; /* New beneficiary in data set, so episode count starts over */
		else if ep_flag = 2 then episode + 1; /* New drug for beneficiary, so new episode */
		else if ep_flag = 3 then episode = episode; /* Dispensing fully overlaps with previous dispensing of drug, so same episode */
		else if ep_flag = 4 then episode = episode; /* Dispensing overlaps with previous dispensing of drug, so same episode */
		else if ep_flag = 4.5 then episode = episode; /* Start fill date of dispensing is 1 day after end fill date of previous dispensing, so same episode */
		else if ep_flag = 5 then episode + 1; /* Dispensing does not overlap with previous dispensing, so new episode */

	run;
	
	/*** Calculate a discontinue date for each dispensing record (where the last day of the 
		 continuous use episode is censored at 50% of the final dispensing's days' supply) ***/
		 /* NOTE: Next, we will calculate the latest discontinue date for each medication episode, which is the discontinue date of the last dispensing in that
	              episode. In rare cases, a prior dispensing may have a later discontinue date (e.g., if the last fill had a much shorter days' supply). For
	              consistency, we use the maximum discontinue date observed within the episode) */

	proc sort data = &ddi._8;
		by bene_id_18900 core_drug episode start_fill_date end_fill_date;
	run;

	data &ddi._9;
		set &ddi._8;
		by bene_id_18900 core_drug episode;

		half_hddays = ceil(hddays / 2); /* the ceil() function will round the result up to the nearest whole number */
										/* I chose to round up because in cases when hddays = 1, rounding down would result in half_hddays = 0 */
		discon_date = (start_fill_date - 1 + half_hddays);

		format discon_date date9.;

		label
			discon_date = "Last day of medication use if censored at 50% of final dispensing's days' supply"
		;

	run;

	/*** For every medication episode, create a minimum index date and maximum supply end date ***/

	proc sql;
	create table &ddi._10 as
	select  *, min(adj_st_fill_date) as min_index_date format=date9.,
		   max(adj_end_fill_date) as max_supply_enddt format=date9.,
		   max(start_fill_date) as max_start_fill_last format=date9., 
		   max(discon_date) as max_discon_date format=date9.

		   from &ddi._9
		   group by bene_id_18900, core_drug, episode
		   order by bene_id_18900, core_drug, episode, adj_st_fill_date, adj_end_fill_date;
	quit; 

	/*** Collapse medication episodes (i.e., medication episode is now 1 row in the data set) ***/

	proc sql;
	create table &ddi._11 as
		   select distinct bene_id_18900, core_drug, episode, min_index_date, max_supply_enddt, max_start_fill_last, max_discon_date,

		   count(*) as disp_number 

		   from &ddi._10
		   group by bene_id_18900, core_drug, episode;
	quit; 

	data clp2.&ddi._clp_s2;
		set &ddi._11;

		label
		disp_number = 'Number of dispensings in medication episode'
		episode = 'Episode # for a given beneficiary'
		max_supply_enddt = 'Max supply end date for a given medication episode'
		min_index_date = 'Start fill date for a given medication episode'
		max_start_fill_last = "start_fill_date for the last dispensing in an episode"
		max_discon_date = "Last day of use episode if censored at 50% of final dispensing's days' supply"
		;

	run; 

	/* Check the number of days between max_discon_date and max_supply_enddt */
	data &ddi._12_v2;
		set clp2.&ddi._clp_s2;

		num_days_discon = max_supply_enddt - max_discon_date;

		label
			num_days_discon = "The number of days between the original end of the medication use episode and the discontinue date"
		;

	run;

	title;
	proc means data = &ddi._12_v2 n nmiss mean std median q1 q3 min max;
		var num_days_discon;
	run;

	proc univariate data = &ddi._12_v2;
		var num_days_discon;
		histogram num_days_discon / normal;
		inset mean std="Std Dev" median q1 q3 min max / pos = ne;
		title "Histogram of num_days_discon variable, &ddi._12";
	run; 

	/**********************************************************************************/
	/*** Merge collapsed medication episode data set with NH episodes data set      ***/
	/**********************************************************************************/

	/* Implement a many-to-many merge with the collapsed medication episode data set and our NH episodes data set */

	proc sql;
		create table &ddi._comb as
		select a.*, b.eNH_ep_start, b.eNH_ep_end
		from clp2.&ddi._clp_s2 as a inner join lrenroll.observ_windows5_excl_set1 as b
		on (a.bene_id_18900 = b.bene_id_18900)
		order by bene_id_18900, core_drug, min_index_date, eNH_ep_start;
	quit; 

	/**********************************************************/
	/*** Limit medication use episodes to enrolled NH time  ***/
	/**********************************************************/

	data &ddi._comb2;
		set &ddi._comb;
		drop disp_number;

		/*** If the end of the medication episode is before the start of the NH episode, delete ***/
		if max_supply_enddt < eNH_ep_start then delete;

		/*** If the start of the medication episode is after the end of NH episode, delete ***/
		else if min_index_date > eNH_ep_end then delete;

		/*** If a medication episode starts before NH time but ends during NH time, adjust the start date
		to match the NH episode start date ***/
		else if ((min_index_date < eNH_ep_start) and (eNH_ep_start <= max_supply_enddt <= eNH_ep_end)) then do;
			min_index_nh = eNH_ep_start;
			max_enddt_nh = max_supply_enddt;
			med_rule = 2;
		end;

		/*** If a medication episode starts during NH time but ends after NH time, adjust the end date
		to match the NH episode end date ***/
		else if ((eNH_ep_start <= min_index_date <= eNH_ep_end) and (max_supply_enddt > eNH_ep_end)) then do;
			min_index_nh = min_index_date;
			max_enddt_nh = eNH_ep_end;
			med_rule = 3;
		end;

		/*** If the start of the medication episode is on or after the start of NH time AND the end of the medication episode is on or before the end
		of NH time, keep the medication episode as is ***/
		else if ((min_index_date >= eNH_ep_start) and (max_supply_enddt <= eNH_ep_end)) then do;
			min_index_nh = min_index_date;
			max_enddt_nh = max_supply_enddt;
			med_rule = 4;
		end;

		/*** If the start of the medication episode is before the start of the NH time AND the end of the medication
		episode after the end of NH time, adjust the start and end dates to match the NH episode start and end dates ***/
		else if ((min_index_date < eNH_ep_start) and (max_supply_enddt > eNH_ep_end)) then do;
			min_index_nh = eNH_ep_start;
			max_enddt_nh = eNH_ep_end;
			med_rule = 5;
		end;

		format min_index_nh max_enddt_nh date9.;

		label
		min_index_nh = 'medication use start date WITHIN NH time'
		max_enddt_nh = 'medication supply end date WITHIN NH time'
		med_rule = 'Flags for rules when creating min_index_nh and max_enddt_nh variables'
		;

	run;

	/* Although not shown in this GitHub program, med_rule was used to ensure min_index_nh and max_enddt_nh were being generated appropriately */

	/***********************************************************************************************/
	/*** Create refined medication use episodes during enrolled NH time based on max_discon_date ***/
	/***********************************************************************************************/

	data &ddi._comb3;
		set &ddi._comb2;

		/*** If the discontinue date is before the start of the NH episode, mark as med_use_sens = 0 ***/
		if max_discon_date < eNH_ep_start then do;
			med_use_sens = 0;
			refine_rule = 1;
		end;

		/*** If a medication episode starts before NH time but discontinues during NH time, adjust the start date
		to match the NH episode start date ***/
		else if ((min_index_date < eNH_ep_start) and (eNH_ep_start <= max_discon_date <= eNH_ep_end)) then do;
			min_index_nh_sens = eNH_ep_start;
			max_enddt_nh_sens = max_discon_date;
			med_use_sens = 1;
			refine_rule = 2;
		end;

		/*** If a medication episode starts during NH time but discontinues after NH time, adjust the discontinue date
		to match the NH episode end date ***/
		else if ((eNH_ep_start <= min_index_date <= eNH_ep_end) and (max_discon_date > eNH_ep_end)) then do;
			min_index_nh_sens = min_index_date;
			max_enddt_nh_sens = eNH_ep_end;
			med_use_sens = 1;
			refine_rule = 3;
		end;

		/*** If the start of the medication episode is on or after the start of NH time AND the discontinue date of the medication episode is on or before the end
		of NH time, keep the medication episode as is ***/
		else if ((min_index_date >= eNH_ep_start) and (max_discon_date <= eNH_ep_end)) then do;
			min_index_nh_sens = min_index_date;
			max_enddt_nh_sens = max_discon_date;
			med_use_sens = 1;
			refine_rule = 4;
		end;

		/*** If the start of the medication episode is before the start of the NH time AND the discontinue date is 
		after the end of NH time, adjust the start and end dates to match the NH episode start and end dates ***/
		else if ((min_index_date < eNH_ep_start) and (max_discon_date > eNH_ep_end)) then do;
			min_index_nh_sens = eNH_ep_start;
			max_enddt_nh_sens = eNH_ep_end;
			med_use_sens = 1;
			refine_rule = 5;
		end;

		format min_index_nh_sens max_enddt_nh_sens date9.;

		label
		min_index_nh_sens = 'medication use start date WITHIN NH time when using discontinue date'
		max_enddt_nh_sens = 'medication supply end date WITHIN NH time when using discontinue date'
		refine_rule = 'Flags for rules when creating min_index_nh_sens and max_enddt_nh_sens variables'
		med_use_sens = '1 = there is med use during nh time when using discontinuation date, 0 = no med use during nh time'
		;

	run;

	/* Although not shown in this GitHub program, refine_rule was used to ensure min_index_nh_sens and max_enddt_nh_sens were being generated appropriately */

	/*** Remove any duplicates ***/

	proc sort data = &ddi._comb3 nodupkey out = &ddi._comb4;
		by bene_id_18900 core_drug min_index_nh max_enddt_nh;
	run;

	title1 "Number of records after removing duplicates";
	proc sql;
		select count(*)
		from &ddi._comb4;
	quit;

	/*** Adjust the medication use episode count ***/

	proc sort data = &ddi._comb4;
		by bene_id_18900 core_drug episode;
	run;

	data nhtm2.&ddi._c5_sens; 
		set &ddi._comb4;
		by bene_id_18900 core_drug episode;
		drop episode;

		if first.bene_id_18900 then episode_new = 1;
		else episode_new + 1;

		label
		episode_new = 'Episode # for a given beneficiary, accounting for enrolled NH time';

	run; 

	/*** Conduct final checks on updated medication use dataset ***/

	/* Output number of records in nhtm2.&ddi._c5_sens */
	title1 "Total records in final medication use dataset: nhtm2.&ddi._c5_sens";
	proc sql;
		select count(*)
		from nhtm2.&ddi._c5_sens;
	quit;

	/* Output number of unique beneficiaries in nhtm2.&ddi._c5_sens */
	title1 "Number of unique beneficiaries in final medication use dataset: nhtm2.&ddi._comb5_sens";
	proc sql;
		select count(distinct bene_id_18900)
		from nhtm2.&ddi._c5_sens;
	quit;

	/* Output drugs found in nhtm2.&ddi._c5_sens */
	title1 "Frequency of different drugs in final medication use dataset: nhtm2.&ddi._c5_sens";
	proc freq data = nhtm2.&ddi._c5_sens;
		tables core_drug / list missing;
	run;

	/* Conduct checks to make sure med eps are not outside of enrolled time and not overlapping with date of death */

	proc sql;
		create table &ddi._checks as
		select a.*, b.enroll_start, b.enroll_end, b.hkdod
		from nhtm2.&ddi._c5_sens as a inner join lrenroll.plevel_enroll as b 
		on a.bene_id_18900=b.bene_id_18900 &
		(b.enroll_start <= a.eNH_ep_start <= b.enroll_end);
	quit;

	/* Are there any records where the medication use episode falls outside of enrolled time? */
	title1 "Number of records where the start of the medication use episode falls outside of enrolled time (nhtm2.&ddi._comb5_sens)";
	proc sql;
		select count(*)
		from &ddi._checks
		where min_index_nh < enroll_start or min_index_nh > enroll_end;
	quit;

	title1 "Number of records where the end of the medication use episode falls outside of enrolled time (nhtm2.&ddi._comb5_sens)";
	proc sql;
		select count(*)
		from &ddi._checks
		where max_enddt_nh < enroll_start or max_enddt_nh > enroll_end;
	quit;

	/* Are there any records where the medication use episode overlaps with the date of death? */
	title1 "Number of records where the date of death is before the end of the medication use episode (nhtm2.&ddi._comb5_sens)";
	proc sql;
		select count(*)
		from &ddi._checks
		where . < hkdod < max_enddt_nh;
	quit;
	title;

	/*** Delete datasets from work library ***/

	proc datasets library = work nolist;
		delete &ddi._: ;
	quit;

	/*** Close RTF document ***/

	ods rtf close;
	ods graphics off;
	ods results;

%mend;

/************************************/
/*** Run Macro for DDI Components ***/
/************************************/

data _null_;
	set names.macro_parameters;
	
	call execute(cats('%sens_med_eps(', ddi_sheet, ');'));

run;

/* END OF PROGRAM */
