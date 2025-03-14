/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create continuous episodes of exposure for each DDI.                    

Programmer: Laura Reich   
 
Date Last Modified: March 10, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- merged.&ddi._cncr: Dataset of overlapping medication use episodes
                     (i.e., concurrent use) for a given DDI
     - Generated in 2_Create_Concurrent_Med_Eps.sas 
*********************************************************************/

/*********************************************************************
Key generated datasets:
- merged.&ddi._dyswddi: Dataset of collapsed concurrent medication use
                        episodes for a given DDI
                        (i.e., each record is episode of DDI exposure,
                        regardless of the specific medications being 
                        used concurrently)
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname merged   "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files"; /* Merged medication episode datasets */
libname ddi      "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\concurrent_use\ddi_lists"; /* Datasets with lists of ddis and their components drug categories */
libname smcncr   "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files\summary_info"; /* DDI prevalence summary info */

options mprint; 

/*************************************************************************************************************************/
/*** Create macro to calculate the total number of days a beneficiary was exposed to a given DDI during their NH stays ***/
/*************************************************************************************************************************/

%macro days_meet_ddi(ddi);

/*** If ddi IS ddi36 or ddi91, enter into a separate do block ***/
	/* NOTE: These two DDIs measured concurrent use between 3 medications, so the code will be slightly different because some of the variable names are different */

%if &ddi. = ddi36 or &ddi. = ddi91 %then %do;

	/* Sort the concurrent use dataset by beneficiary ID and the start and end date of medication use overlap */
	proc sort data = merged.&ddi._cncr;
	by bene_id_18900 start_date_overlap_2 end_date_overlap_2;
	run;

	/* For a given beneficiary, adjust the start date of concurrent use so that there is no overlap with the previous record's concurrent medication use episode. Flag to delete
	   any concurrent medication use episodes that completely overlap with the previous record. */

	data &ddi._cncr2;
	set merged.&ddi._cncr;
	by bene_id_18900 start_date_overlap_2 end_date_overlap_2;
	retain prev_bene_id prev_st_overlap prev_end_overlap;

		/* If this is the first record for the beneficiary, do not adjust the start and end date of medication use overlap */
		if first.bene_id_18900 then do;
			adj_st_overlap = start_date_overlap_2;
			adj_end_overlap = end_date_overlap_2;
			cncr_flag = 1;

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the end date of overlap for this record is on or before the adjusted end date of overlap for the previous record, flag to delete */
		else if end_date_overlap_2 <= prev_end_overlap then do;
			adj_st_overlap = .;
			adj_end_overlap = .;
			cncr_flag = 2;
		end;

		/* Otherwise, if the start of overlap for this record is on or before the adjusted end overlap date from the previous record, set the adjusted start overlap date to be one
		 day after the previous record's end overlap date. Don't make any adjustments to the end overlap date for this record */
		else if start_date_overlap_2 <= prev_end_overlap then do;
			adj_st_overlap = prev_end_overlap + 1;
			adj_end_overlap = end_date_overlap_2;
			cncr_flag = 3; /* partial overlap between records */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the start of overlap is exactly one day after the previous record's end overlap date, do not adjust the start and end of overlap. Give unique flag to help
		   correctly collapse concurrent use episodes in later code */
		else if start_date_overlap_2 = (prev_end_overlap + 1) then do;
			adj_st_overlap = start_date_overlap_2;
			adj_end_overlap = end_date_overlap_2;
			cncr_flag = 3.5; /* start date of overlap is exactly 1 day after previous record's end date of overlap */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the start of overlap occurs any time after the previous record's end date of overlap, do not adjust the start and end of overlap */
		else if start_date_overlap_2 > prev_end_overlap then do;
			adj_st_overlap = start_date_overlap_2;
			adj_end_overlap = end_date_overlap_2;
			cncr_flag = 4; /* no overlap between records */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

	format adj_st_overlap date9. adj_end_overlap date9. prev_st_overlap date9. prev_end_overlap date9.;

	label
	adj_st_overlap = "adjusted start date of medication use overlap"
	adj_end_overlap = "adjusted end date of medication use overlap"
	cncr_flag = "flag for concurrent use (i.e., whether the record overlaps with previous record's episode of concurrent use)";

	run;

	/* Delete any records with cncr_flag = 2 (complete overlap between concurrent medication use episodes) */

	data &ddi._cncr3;
	set &ddi._cncr2;
	drop core_drug_1 core_drug_2 core_drug_3 class_1 class_2 class_3 prev_bene_id prev_st_overlap prev_end_overlap;

	if cncr_flag = 2 then delete;

	run;

	/* Exit out of the do block */

%end;

/*** If the ddi IS NOT ddi36 or ddi91, enter into a separate do block */

%else %if &ddi. ne ddi36 and &ddi. ne ddi91 %then %do;

	/* Sort the concurrent use dataset by beneficiary ID and the start and end date of medication use overlap */

	proc sort data = merged.&ddi._cncr;
	by bene_id_18900 start_date_overlap end_date_overlap;
	run;
	
	/* For a given beneficiary, adjust the start date of concurrent use so that there is no overlap with the previous record's concurrent medication use episode. Flag to delete
	   any concurrent medication use episodes that completely overlap with the previous record. */
	data &ddi._cncr2;
	set merged.&ddi._cncr;
	by bene_id_18900 start_date_overlap end_date_overlap;
	retain prev_bene_id prev_st_overlap prev_end_overlap;

		/* If this is the first record for the beneficiary, do not adjust the start and end date of medication use overlap */
		if first.bene_id_18900 then do;
			adj_st_overlap = start_date_overlap;
			adj_end_overlap = end_date_overlap;
			cncr_flag = 1;

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the end date of overlap for this record is on or before the adjusted end date of overlap for the previous record, flag to delete */
		else if end_date_overlap <= prev_end_overlap then do;
			adj_st_overlap = .;
			adj_end_overlap = .;
			cncr_flag = 2;
		end;

		/* Otherwise, if the start of overlap for this record is on or before the adjusted end overlap date from the previous record, set the adjusted start overlap date to be one
		 day after the previous record's end overlap date. Don't make any adjustments to the end overlap date for this record */
		else if start_date_overlap <= prev_end_overlap then do;
			adj_st_overlap = prev_end_overlap + 1;
			adj_end_overlap = end_date_overlap;
			cncr_flag = 3; /* partial overlap between records */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the start of overlap is exactly one day after the previous record's end overlap date, do not adjust the start and end of overlap. Give unique flag to help
		   correctly collapse concurrent use episodes in later code */
		else if start_date_overlap = (prev_end_overlap + 1) then do;
			adj_st_overlap = start_date_overlap;
			adj_end_overlap = end_date_overlap;
			cncr_flag = 3.5; /* start date of overlap is exactly 1 day after previous record's end date of overlap */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

		/* Otherwise, if the start of overlap occurs any time after the previous record's end date of overlap, do not adjust the start and end of overlap */
		else if start_date_overlap > prev_end_overlap then do;
			adj_st_overlap = start_date_overlap;
			adj_end_overlap = end_date_overlap;
			cncr_flag = 4; /* no overlap between records */

			prev_bene_id = bene_id_18900;
			prev_st_overlap = adj_st_overlap;
			prev_end_overlap = adj_end_overlap;
		end;

	format adj_st_overlap date9. adj_end_overlap date9. prev_st_overlap date9. prev_end_overlap date9.;

	label
	adj_st_overlap = "adjusted start date of medication use overlap"
	adj_end_overlap = "adjusted end date of medication use overlap"
	cncr_flag = "flag for concurrent use (i.e., whether the record overlaps with previous record's episode of concurrent use)";

	run;

	/* Delete any records with cncr_flag = 2 (complete overlap between concurrent medication use episodes) */

	data &ddi._cncr3;
	set &ddi._cncr2;
	drop core_drug_1 core_drug_2 prev_bene_id prev_st_overlap prev_end_overlap;

	if cncr_flag = 2 then delete;

	run;

	/* Exit out of the do block */

%end;

/*** Create variable for continuous episodes of concurrent use ***/

	/* Sort the concurrent use dataset by beneficiary ID, adjusted start of concurrent medication use, and adjusted end of concurrent medication use */

	proc sort data = &ddi._cncr3;
	by bene_id_18900 adj_st_overlap adj_end_overlap;
	run;

	/* Create continuous concurrent use episodes where, for a given beneficiary, 
	   any consecutive concurrent use episodes 1 day apart are considered to be part of the same concurrent medication use episode */

	data &ddi._cncr4;
	set &ddi._cncr3;
	by bene_id_18900 adj_st_overlap adj_end_overlap;

		if cncr_flag = 1 then ep_cncr_2 = 1; /* New beneficiary in dataset, so episode count starts over */
		else if cncr_flag = 3 then ep_cncr_2 = ep_cncr_2; /* Record overlaps with previous record, so same episode */
		else if cncr_flag = 3.5 then ep_cncr_2 = ep_cncr_2; /* Overlap start date is 1 day after end overlap date of previous record, so same episode */
		else if cncr_flag = 4 then ep_cncr_2 + 1; /* No overlap between records, so new episode */

	label
	ep_cncr_2 = "concurrent use episode count, irrespective of drug";

	run;

/*** For every continuous concurrent use episode, create a minimum index date and maximum end date ***/

proc sql;
create table &ddi._cncr5 as
select  *, min(adj_st_overlap) as min_index_date format=date9.,
	   max(adj_end_overlap) as max_enddt format=date9.

	   from &ddi._cncr4
	   group by bene_id_18900, ep_cncr_2
	   order by bene_id_18900, ep_cncr_2, adj_st_overlap, adj_end_overlap;
quit; 

/*** Collapse concurrent use episodes into 1 row ***/

proc sql;
create table &ddi._cncr6 as
	   select distinct bene_id_18900, ep_cncr_2, min_index_date, max_enddt

	   from &ddi._cncr5
	   order by bene_id_18900, ep_cncr_2;
quit; 

data &ddi._cncr7;
set &ddi._cncr6;

label
max_enddt = 'End date for concurrent medication use'
min_index_date = 'Start of concurrent medication use';

run; 

/*** For each continuous concurrent use episode, calculate the total days where the beneficiary met the criteria for the DDI ***/

data merged.&ddi._dyswddi;
set &ddi._cncr7;

days_with_ddi = (max_enddt + 1) - min_index_date;

label
days_with_ddi = "Number of days during NH time where bene meets criteria for the DDI";

run;

/*** Delete datasets from work library ***/

proc datasets library = work nolist;
	delete &ddi._cncr: ;
quit;

%mend;

/**************************************************************/
/***  Run macro for each concurrent medication use dataset  ***/
/**************************************************************/

data _null_;
	set ddi.full_ddi_list;

	/* Generate macro call for each record */
	call execute(cats('%days_meet_ddi(', ddi, ');'));

run;

/* END OF PROGRAM */
