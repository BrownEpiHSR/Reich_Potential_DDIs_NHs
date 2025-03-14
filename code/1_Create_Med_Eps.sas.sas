/**************************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create medication use episodes for the drugs associated with each DDI.

Programmer: Laura Reich   
 
Date Last Modified: March 10, 2025
***************************************************************************/

/***************************************************************************
Loaded datasets:
- lrenroll.observ_windows5_excl_set1: NH stay dataset. Each record
                                      represents a unique NH stay between 2018-2020 
                                      for cohort members after applying the exclusion 
                                      criteria. 
- dlist.&ddi.: List of generic drug names associated with a given DDI component.
     - Generated in 0_Create_Dispensing_Datasets.sas
- drugs.&ddi._w2017: Dataset with cohort members' 
                     Part D dispensings (between October 4, 2017 to December 31, 2020)
                     for a given DDI component. 
     - Generated in 0_Create_Dispensing_Datasets.sas
- names.macro_parameters: Dataset with names of the DDI components.
     - Generated in 0_Create_Dispensing_Datasets.sas
***************************************************************************/

/***************************************************************************
Key generated datasets:
- lrenroll.plevel_enroll: Continuous enrollment periods dataset. Each
                          record is a unique continuous enrollment period
                          for a cohort member.
- cmbfx.&ddi._crf: DDI component Part D dispensing dataset with core_drug 
                   variable (i.e., generic drug name without specification 
                   of salt form) added AFTER fixing combination drug records.
- dcln2.&ddi._4_v2: DDI component Part D dispensing datase after removing 
                    days supply (DS) = 0, truncating DS > 90 to 90, and 
                    deduplicating records.
- nhtm2.&ddi._comb3: Medication episodes for a given DDI component, 2018-2020, 
                     within NH stays.
***************************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname dlist    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_list";  /* Excel drug lists */
libname drugs    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files"; /* DDI component Part D dispensing datasets */
libname dclean   "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files_clean"; /* Cleaned DDI component Part D dispensing datasets */
libname dcln2    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files_clean\v2"; /* Cleaned DDI Component Part D dispensing datasets, v2 */
libname cmbfx    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files_clean\combo_fix"; /* Cleaned DDI component datasets with fixed combination drugs */
libname lrenroll "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\enrollment"; /* NH stays dataset with exclusions applied */
libname sum      "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files\summary_info"; /* DDI component datasets summary info, v2*/
libname names    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_list\ddi_component_names"; /* Names of each DDI component */
libname clp2     "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\med_ep\collapsed\v2"; /* Collapsed medication episode datasets, v2 */
libname nhtm2    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\med_ep\nh_time\v2"; /* Medication episodes during NH stays datasets */

options mprint; 

/********************************************************************/
/***** Create enrollment time + date of death (hkdod) dataset *******/
/********************************************************************/

	/* NOTE: We will use this dataset later in order to limit dispensings to continuous enrollment periods */

/*** Create a dataset with beneficiary IDs and their continuous enrollment periods + date of death */

proc sort data = lrenroll.observ_windows5_excl_set1;
by bene_id_18900 enroll_start enroll_end;
run;

data lrenroll.plevel_enroll;
set lrenroll.observ_windows5_excl_set1;
by bene_id_18900 enroll_start enroll_end;
keep bene_id_18900 enroll_start enroll_end hkdod; 

if first.enroll_start;

run;

	/* NOTE: Some beneficiaries have more than one continuous enrollment period, so the number of records in this dataset
             may not be the same as the number of residents in the cohort */

/**************************************************************************************/
/***  Write a macro to create core_drug variable in each dispensing dataset         ***/
/*** (which we will use to create continuous medication use episodes)               ***/
/**************************************************************************************/

	/* NOTE: The core_drug variable is simply the name of the generic drug without specification of salt form */

	/* NOTE: Some combination drugs have more than one active ingredient that fits into the DDI component category. In this step we will be duplicating
	these combination drugs so that, later on, we can create medication use episodes separately for these active ingredients */

%macro combo_drug(ddi_sheet);

/*** Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' ***/

%let ddi = %sysfunc(tranwrd(&ddi_sheet., -, xx));

/*** Add the core_drug variable to the DDI component dataset by merging with the DDI list ***/

proc sql;
create table dclean.&ddi._core as
select a.bene_id_18900, a.hdl_gdname, a.hdl_ai_name1, a.hdl_ai_name2, a.hdl_ai_name3, a.hdl_ai_name4,
a.drug, a.hddays, a.hdfrom, b.core_drug
from drugs.&ddi._w2017 as a inner join dlist.&ddi. as b
on a.drug = b.drug;
quit;

/*** Identify combination drugs in dclean.&ddi._core ***/

data &ddi._core2;
set dclean.&ddi._core;

	/* If the value of hdl_gdname is 'sulfamethoxazole-trimethoprim', we don't want to treat it like the other combination drugs.
	   This is because some DDIs specifically listed 'sulfamethoxazole-trimethoprim', rather than an active ingredient within it. Flag as combo_drug = 0.5 */

	if hdl_gdname = 'sulfamethoxazole-trimethoprim' then combo_flag = 0.5;

	/* Otherwise, if the value of hdl_gdname has a '/' or '-' in it, it is a combination drug. Flag as combo_drug = 1 */

	else if index(hdl_gdname, '/') > 0 or index(hdl_gdname, '-') > 0 then do;
		combo_flag = 1;
	end;

	/* Otherwise, the drug is not a combination drug. Flag as combo_drug = 0 */

	else combo_flag = 0;

label
combo_flag = "Flag for combination drug, 0.5 means sulfamethoxazole-trimethoprim";

run;

/*** Scan through the flagged combination drugs and identify those containing more than one active
	 ingredient from the DDI list (dlist.&ddi.)  ***/

data &ddi._combo;

	if 0 then set dlist.&ddi.; /* Forces SAS to define all variables in this dataset */

		/* Define a hash object with the list of drugs from dlist.&ddi. */

		if _n_ = 1 then do;
			declare hash drug_list(dataset: "dlist.&ddi.");
			drug_list.defineKey('Drug');
			drug_list.defineData('Drug');
			drug_list.defineDone(); /* This essentially creates a list of the specific drugs to include for this DDI component */
		end;

		/* Initialize the variable to store the matched drug */

		length combo_drug $255;
		combo_drug = '';

	set &ddi._core2;

	/* Output records for a combination drug each time an active ingredient matches with one of the drugs in the DDI list */

	if combo_flag = 1 then do;
		core_drug = '';
		if drug_list.find(key: hdl_ai_name1) = 0 then do;
			combo_drug = hdl_ai_name1;
			output;
		end;
		if drug_list.find(key: hdl_ai_name2) = 0 then do;
			combo_drug = hdl_ai_name2;
			output;
		end;
		if drug_list.find(key: hdl_ai_name3) = 0 then do;
			combo_drug = hdl_ai_name3;
			output;
		end;
		if drug_list.find(key: hdl_ai_name4) = 0 then do
			combo_drug = hdl_ai_name4; 
			output;
		end;
	end;

label
combo_drug = 'Active ingredient identified from combination drug as being part of DDI';

run;

/*** Merge combination drugs dataset with the ddi list to obtain the core_drug variable for each relevant active ingredient ***/

proc sql noprint;
create table &ddi._combo2 as
select a.bene_id_18900, a.hdl_gdname, a.hdl_ai_name1, a.hdl_ai_name2, a.hdl_ai_name3, a.hdl_ai_name4,
a.drug, a.hddays, a.hdfrom, a.combo_drug, b.core_drug
from &ddi._combo as a inner join dlist.&ddi. as b
on a.combo_drug = b.drug;
quit;

/*** Write the correct value for core_drug when hdl_gdname = 'amphetamine-dextroamphetamine' ***/

	/* NOTE: This is a special case where the only active ingredient when hdl_gdname = 'amphetamine-dextroamphetamine' has the active ingredient listed as 'amphetamine mixed salts' (based on the Lexicomp variable values),
	   but we want to split this into the active ingredients 'amphetamine' and 'dextroamphetamine' */

	data &ddi._combo3;
	set &ddi._combo2;

	/* Output original record */
		/* NOTE: Dispensings with hdl_gdname = 'amphetamine-dextroamphetamine' will have the core_drug value of 'amphetamine' */
	output;

	/* If hdl_gdname = 'amphetamine-dextroamphetamine', duplicate the record and make the value of core_drug 'dextroamphetamine' */
		if hdl_gdname = 'amphetamine-dextroamphetamine' then do;
			core_drug = 'dextroamphetamine';
			output;
		end;

	run;

/*** Stack the combination drug dataset with the original DDI component dataset ***/

	/* Remove the combination drugs from the original DDI component dataset before stacking (in order to prevent
	   unintentional duplicate records */

	data &ddi._core3;
	set  &ddi._core2;

	if combo_flag = 1 then delete;

	run;

	/* Stack the datasets */

	data cmbfx.&ddi._crf;
	set &ddi._core3 &ddi._combo3;
	run;

/*** Delete datasets from work library ***/

proc datasets library = work nolist;
	delete &ddi._core2 &ddi._core3 &ddi._combo &ddi._combo2 &ddi._combo3;
quit;

%mend;

/*********************************************************************/
/****** Run the combo_drug macro for each DDI component dataset ******/
/*********************************************************************/

data _null_;
	set names.macro_parameters;
	
	call execute(cats('%combo_drug(', ddi_sheet, ');'));

run;

/*****************************************************************************************/
/***** Write macro to create medication use episodes for each DDI component dataset  *****/
/*****************************************************************************************/

%macro create_drug_eps(ddi_sheet);

/*** Perform preparatory tasks before cleaning drug variables ***/

	/* Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' */
	%let ddi = %sysfunc(tranwrd(&ddi_sheet., -, xx));

	/* Format variables */
	proc format;
	value cat1_f
	.= 'missing'
	-99999999999--1='<0'
	0= '0'
	1-90='1-90'
	91-high = '>=91';
	run;

/*** Clean up the days of supply (DS) variable (hddays) ***/

	/* Check for dispensings with DS >90day, <=0 or missing */
	title1 "cleaning data";
	title2 "dataset: cmbfx.&ddi._crf";
	title3 "check for dispensings with DS >90day, <=0 or missing";
	title4 "those >90 will be set to 90. those <=0 or missing will be deleted";
	proc freq data = cmbfx.&ddi._crf;
	table hddays/missing;
	format hddays cat1_f.;
	run;
	title3; title4; 

	/* Remove observations where DS <= 0 and trim any DS that is >90 to 90 */
	data &ddi._2;
	set cmbfx.&ddi._crf;
	if hddays >90 then hddays =90;
	if hddays <=0  then delete;
	if hddays =.  then delete;
	run;

/*** Drop duplicate rows according to matching bene_id_18900, core_drug, hdfrom, and hddays ***/
		/* NOTE: hdfrom is the date of the dispensing */

	/* Sort the dataset by bene_id_18900, core_drug, hdfrom, and hddays */
	proc sort data = &ddi._2;
		by bene_id_18900 core_drug hdfrom hddays;
	run;

	/* Only keep the first observation of duplicate records */
	data &ddi._3;
		set &ddi._2;
		by bene_id_18900 core_drug hdfrom hddays;
		if first.hddays;
	run;

	/* If core_drug and hdfrom are the same, but DS is different, take the longest DS */
	proc sort data = &ddi._3;
	by bene_id_18900 core_drug hdfrom descending hddays;
	run;

	data dcln2.&ddi._4_v2; 
	set &ddi._3;
	by bene_id_18900 core_drug hdfrom descending hddays;
	if first.hdfrom;

	label
	core_drug = "Drug name (no specification of salt form)";

	run; 

/**********************************************/
/***** Limit dispensings to enrolled time *****/
/**********************************************/

/*** Limit dispensings to beneficiary's enrolled time by merging dataset with lrenroll.plevel_enroll ***/
	/* NOTE: We created the lrenroll.plevel_enroll dataset on lines 48-59 */
	/* NOTE: A given beneficiary may have more than one continuous enrollment period */

proc sql; 
create table &ddi._5 as
select a.*
from dcln2.&ddi._4_v2 as a inner join lrenroll.plevel_enroll as b
on a.bene_id_18900=b.bene_id_18900 &
(b.enroll_start <= a.hdfrom <= b.enroll_end);
quit;

	/* NOTE: It is not necessary to limit dispensings to enrolled time. Later in the code, we will limit medication use episodes to NH time.
             However, this can reduce the size of the dispensing dataset to improve efficiency */

/**************************************************/
/***** Create crude medication use episodes *******/
/**************************************************/

/*** Create medication start and end date variables based on the days of supply, assuming that the person starts their medication on the date of dispensing ***/

	/* Sort by beneficiary ID, core_drug, and dispensing date */
	proc sort data = &ddi._5; 
	by bene_id_18900 core_drug hdfrom;
	run;

	/* Create medication start and end date variables */
	data &ddi._5;
		set &ddi._5;
		
		/* Create start_fill_date, assuming that the person starts the medication on the date of dispensing */
		start_fill_date = hdfrom;

		/* Create end_fill_date, assuming that the person stops taking the medication on the last day of the supply */
		end_fill_date = (start_fill_date - 1 + hddays);

		label
		start_fill_date = 'first day of med use in crude episode (hdfrom)'
		end_fill_date = 'last day of med use in crude episode (start_fill_date - 1 + hddays)';

		format start_fill_date end_fill_date date9.;
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

data &ddi._6;
set &ddi._5;
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
		adj_end_fill_date = end_fill_date; 
		ep_flag = 5; /* no overlap between previous dispensing */

		prev_bene_id = bene_id_18900;
		prev_core_drug = core_drug;
		prev_adj_st_fill_date = adj_st_fill_date;
		prev_adj_end_fill_date = adj_end_fill_date;
	end;

format adj_st_fill_date date9. adj_end_fill_date date9. prev_adj_st_fill_date date9. prev_adj_end_fill_date date9. ep_flag ep_flag_fmt.;

label 
adj_st_fill_date = 'adjusted start fill date for medication, taking into account the days supply from prior dispensings'
adj_end_fill_date = 'adjusted end fill date for medication, which is the same as end_fill_date'
prev_bene_id = 'beneficiary id from the previous record'
prev_core_drug = 'core drug name from the previous record'
prev_adj_st_fill_date = 'start fill date from the previous record'
prev_adj_end_fill_date = 'end supply date from the previous record';

run;

/************************************************************************************************/
/********* Delete dispensings where the end fill date was before the previous                ****/
/********* dispensing's end fill date (for a given beneficiary ID and core_drug)             ****/
/************************************************************************************************/

data &ddi._7;
set &ddi._6;

if ep_flag = 3 then delete;

run;

/**********************************************/
/**** Create continuous medication episodes ***/
/**********************************************/

/*** Create medication episodes where, for a given beneficiary and a given drug, consecutive dispensings 1 day apart are considered to be part of the same medication episode ***/

data &ddi._8;
set &ddi._7;
by bene_id_18900 core_drug;

	if ep_flag = 1 then episode = 1; /* New beneficiary in dataset, so episode count starts over */
	else if ep_flag = 2 then episode + 1; /* New drug for beneficiary, so new episode */
	else if ep_flag = 4 then episode = episode; /* Dispensing overlaps with previous dispensing of drug, so same episode */
	else if ep_flag = 4.5 then episode = episode; /* Start fill date of dispensing is 1 day after end fill date of previous dispensing, so same episode */
	else if ep_flag = 5 then episode + 1; /* Dispensing does not overlap with previous dispensing, so new episode */

run;

/*** For every medication episode, create a minimum index date and maximum supply end date ***/

proc sql;
create table &ddi._9 as
select  *, min(adj_st_fill_date) as min_index_date format=date9.,
	   max(adj_end_fill_date) as max_supply_enddt format=date9.

	   from &ddi._8
	   group by bene_id_18900, core_drug, episode
	   order by bene_id_18900, core_drug, episode, adj_st_fill_date, adj_end_fill_date;
quit; 

/*** Collapse medication episodes (i.e., medication episode is now 1 row in the dataset) ***/

proc sql;
create table &ddi._10 as
	   select distinct bene_id_18900, core_drug, hdl_gdname, episode, min_index_date, max_supply_enddt, 

	   count(*) as disp_number 

	   from &ddi._9
	   group by bene_id_18900, core_drug, episode;
quit; /* This will make multiple copies of a continuous medication use episode if it had dispensings from more than one hdl_gdname. Later I remove duplicates by core_drug. Removing the hdl_gdname will remedy this, as well */

data clp2.&ddi._clp;
set &ddi._10;

label
disp_number = 'Number of dispensings in medication episode'
episode = 'Episode # for a given beneficiary'
max_supply_enddt = 'Max supply end date for a given medication episode'
min_index_date = 'Start fill date for a given medication episode';

run; 

/***************************************************************************/
/*** Merge collapsed medication episode dataset with NH stays dataset    ***/
/***************************************************************************/

/*** Implement a many-to-many merge with the collapsed medication episode dataset and our NH stays dataset ***/

proc sql;
	create table &ddi._comb as
	select a.*, b.eNH_ep_start, b.eNH_ep_end
	from clp2.&ddi._clp as a inner join lrenroll.observ_windows5_excl_set1 as b
	on (a.bene_id_18900 = b.bene_id_18900)
	order by bene_id_18900, core_drug, min_index_date, eNH_ep_start;
quit; 

/*************************************************/
/*** Limit medication use episodes to NH time  ***/
/*************************************************/

data &ddi._comb2;
set &ddi._comb;
drop disp_number;

/*** If the end of the medication episode is before the start of the NH stay, delete ***/
if max_supply_enddt < eNH_ep_start then delete;

/*** If the start of the medication episode is after the end of NH stay, delete ***/
else if min_index_date > eNH_ep_end then delete;

/*** If a medication episode starts before NH time but ends during NH time, adjust the start date
to match the NH stay start date ***/
else if ((min_index_date < eNH_ep_start) and (eNH_ep_start <= max_supply_enddt <= eNH_ep_end)) then do;
	min_index_nh = eNH_ep_start;
	max_enddt_nh = max_supply_enddt;
end;

/*** If a medication episode starts during NH time but ends after NH time, adjust the end date
to match the NH stay end date ***/
else if ((eNH_ep_start <= min_index_date <= eNH_ep_end) and (max_supply_enddt > eNH_ep_end)) then do;
	min_index_nh = min_index_date;
	max_enddt_nh = eNH_ep_end;
end;

/*** If the start of the medication episode is on or after the start of NH time AND the end of the medication episode is on or before the end
of NH time, keep the medication episode as is ***/
else if ((min_index_date >= eNH_ep_start) and (max_supply_enddt <= eNH_ep_end)) then do;
	min_index_nh = min_index_date;
	max_enddt_nh = max_supply_enddt;
end;

/*** If the start of the medication episode is before the start of the NH time AND the end of the medication
episode after the end of NH time, adjust the start and end dates to match the NH stay start and end dates ***/
else if ((min_index_date < eNH_ep_start) and (max_supply_enddt > eNH_ep_end)) then do;
	min_index_nh = eNH_ep_start;
	max_enddt_nh = eNH_ep_end;
end;

format min_index_nh max_enddt_nh date9.;

label
min_index_nh = 'medication use start date WITHIN NH time'
max_enddt_nh = 'medication supply end date WITHIN NH time';

run;

/*** Remove any duplicates ***/
	/* NOTE: There may be duplicates because I left the hdl_gdname variable when collapsing medication episodes */

proc sort data = &ddi._comb2 nodupkey;
by bene_id_18900 core_drug min_index_nh max_enddt_nh;
run;

title1 "Number of records after removing duplicates";
proc sql;
select count(*)
from &ddi._comb2;
quit;

/*** Adjust the medication use episode count ***/

proc sort data = &ddi._comb2;
by bene_id_18900 core_drug episode;
run;

data nhtm2.&ddi._comb3; 
set &ddi._comb2;
by bene_id_18900 core_drug episode;
drop episode min_index_date max_supply_enddt;

if first.bene_id_18900 then episode_new = 1;
else episode_new + 1;

label
episode_new = 'Episode # for a given beneficiary, accounting for NH time';

run; 

/*************************************************/
/*** Conduct checks on medication use episodes ***/
/*************************************************/

/*** Conduct checks to make sure medication episodes are not outside of enrolled time and not overlapping with date of death ***/

	proc sql;
	create table &ddi._checks as
	select a.*, b.enroll_start, b.enroll_end, b.hkdod
	from nhtm2.&ddi._comb3 as a inner join lrenroll.plevel_enroll as b 
	on a.bene_id_18900=b.bene_id_18900 &
	(b.enroll_start <= a.eNH_ep_start <= b.enroll_end);
	quit;

	/* Are there any records where the medication use episode falls outside of enrolled time? */
	title1 "Number of records where the start of the medication use episode falls outside of enrolled time";
	proc sql;
	select count(*)
	from &ddi._checks
	where min_index_nh < enroll_start or min_index_nh > enroll_end;
	quit;

	title1 "Number of records where the end of the medication use episode falls outside of enrolled time";
	proc sql;
	select count(*)
	from &ddi._checks
	where max_enddt_nh < enroll_start or max_enddt_nh > enroll_end;
	quit;

	/* Are there any records where the medication use episode overlaps with the date of death? */
	title1 "Number of records where the date of death is before the end of the medication use episode";
	proc sql;
	select count(*)
	from &ddi._checks
	where . < hkdod < max_enddt_nh;
	quit;
	title1;

/************************************************/
/*** Delete &ddi. datasets from work library  ***/
/************************************************/

proc datasets library = work nolist;
	delete &ddi._2 &ddi._3 &ddi._5 &ddi._6 &ddi._7 &ddi._8 &ddi._9 &ddi._10 &ddi._comb &ddi._comb2 &ddi._checks;
quit;

%mend;

/*****************************************************/
/*** Run the macro for each DDI component dataset  ***/
/*****************************************************/

data _null_;
	set names.macro_parameters;
	
	call execute(cats('%create_drug_eps(', ddi_sheet, ');'));

run;

/* END OF PROGRAM */
