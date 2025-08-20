/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug-Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create continuous episodes of exposure for each DDI in the stability
analysis.                    

Programmer: Laura Reich   
 
Date Last Modified: July 21, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- merged.&ddi._cncr_sens_only: Dataset of overlapping medication use episodes
                             (i.e., concurrent use) for a given DDI in the 
                             stability analysis.
- ddi.ddi_list_3abc: SAS dataset with the DDI numbers associated with
                   the DDIs that were processed in 2b_Create_Concurrent_Med_Eps_Stability.sas
*********************************************************************/

/*********************************************************************
Key generated datasets:
- merged.&ddi._dyswddi_sens_only: Dataset of collapsed concurrent medication use
                        episodes for a given DDI in the stability analysis
                        (i.e., each record is episode of DDI exposure,
                        regardless of the specific medications being 
                        used concurrently)
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname merged   "your/library/path"; /* Merged medication episode data sets */
libname ddi      "your/library/path"; /* Data sets with lists of ddis and their components drug categories */
libname smcncr   "your/library/path"; /* DDI summary info */

options mprint mlogic; 

/****************************************************************************************************************************************************/
/*** Create macro to calculate the total number of days a beneficiary met the DDI criteria (i.e., was exposed to the DDI) during enrolled NH time ***/
/****************************************************************************************************************************************************/

%macro days_meet_ddi_sens(ddi);

	/* Writing to RTF document */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** If ddi IS ddi36 or ddi91, enter into a separate do block ***/
		/* NOTE: These two DDIs measured concurrent use between 3 medications, so the code will be slightly different because some of the variable names are different */

	%if &ddi. = ddi36 or &ddi. = ddi91 %then %do;

			/* Sort the concurrent use data set by beneficiary ID and the start and end date of medication use overlap */
		proc sort data = merged.&ddi._cncr_sens_only;
		by bene_id_18900 start_date_overlap_sens_2 end_date_overlap_sens_2;
		run;

			/* For a given beneficiary, adjust the start date of concurrent use so that there is no overlap with the previous record's concurrent medication use episode. Flag to delete
						  any concurrent medication use episodes that completely overlap with the previous record. */
		data &ddi._cncr2;
			set merged.&ddi._cncr_sens_only;
			by bene_id_18900 start_date_overlap_sens_2 end_date_overlap_sens_2;
			retain prev_bene_id prev_st_overlap prev_end_overlap;

			/* If this is the first record for the beneficiary, do not adjust the start and end date of medication use overlap */
			if first.bene_id_18900 then do;
				adj_st_overlap = start_date_overlap_sens_2;
				adj_end_overlap = end_date_overlap_sens_2;
				cncr_flag = 1;

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the end date of overlap for this record is on or before the adjusted end date of overlap for the previous record, flag to delete */
			else if end_date_overlap_sens_2 <= prev_end_overlap then do;
				adj_st_overlap = .;
				adj_end_overlap = .;
				cncr_flag = 2;
			end;

			/* Otherwise, if the start of overlap for this record is on or before the adjusted end overlap date from the previous record, set the adjusted start overlap date to be one
			 day after the previous record's end overlap date. Don't make any adjustments to the end overlap date for this record */
			else if start_date_overlap_sens_2 <= prev_end_overlap then do;
				adj_st_overlap = prev_end_overlap + 1;
				adj_end_overlap = end_date_overlap_sens_2;
				cncr_flag = 3; /* partial overlap between records */

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the start of overlap is exactly one day after the previous record's end overlap date, do not adjust the start and end of overlap. Give unique flag to help
			   correctly collapse concurrent use episodes in later code */
			else if start_date_overlap_sens_2 = (prev_end_overlap + 1) then do;
				adj_st_overlap = start_date_overlap_sens_2;
				adj_end_overlap = end_date_overlap_sens_2;
				cncr_flag = 3.5; /* start date of overlap is exactly 1 day after previous record's end date of overlap */

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the start of overlap occurs any time after the previous record's end date of overlap, do not adjust the start and end of overlap */
			else if start_date_overlap_sens_2 > prev_end_overlap then do;
				adj_st_overlap = start_date_overlap_sens_2;
				adj_end_overlap = end_date_overlap_sens_2;
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

	%end;

	/*** If the ddi IS NOT ddi36 or ddi91, enter into a separate do block */

	%else %if &ddi. ne ddi36 and &ddi. ne ddi91 %then %do;

		/* Sort the concurrent use data set by beneficiary ID and the start and end date of medication use overlap */

		proc sort data = merged.&ddi._cncr_sens_only;
			by bene_id_18900 start_date_overlap_sens end_date_overlap_sens;
		run;
			
		/* For a given beneficiary, adjust the start date of concurrent use so that there is no overlap with the previous record's concurrent medication use episode. Flag to delete
	       any concurrent medication use episodes that completely overlap with the previous record. */
		data &ddi._cncr2;
			set merged.&ddi._cncr_sens_only (drop = start_date_overlap end_date_overlap);
			by bene_id_18900 start_date_overlap_sens end_date_overlap_sens;
			retain prev_bene_id prev_st_overlap prev_end_overlap;

			/* If this is the first record for the beneficiary, do not adjust the start and end date of medication use overlap */
			if first.bene_id_18900 then do;
				adj_st_overlap = start_date_overlap_sens;
				adj_end_overlap = end_date_overlap_sens;
				cncr_flag = 1;

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the end date of overlap for this record is on or before the adjusted end date of overlap for the previous record, flag to delete */
			else if end_date_overlap_sens <= prev_end_overlap then do;
				adj_st_overlap = .;
				adj_end_overlap = .;
				cncr_flag = 2;
			end;

			/* Otherwise, if the start of overlap for this record is on or before the adjusted end overlap date from the previous record, set the adjusted start overlap date to be one
			 day after the previous record's end overlap date. Don't make any adjustments to the end overlap date for this record */
			else if start_date_overlap_sens <= prev_end_overlap then do;
				adj_st_overlap = prev_end_overlap + 1;
				adj_end_overlap = end_date_overlap_sens;
				cncr_flag = 3; /* partial overlap between records */

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the start of overlap is exactly one day after the previous record's end overlap date, do not adjust the start and end of overlap. Give unique flag to help
			   correctly collapse concurrent use episodes in later code */
			else if start_date_overlap_sens = (prev_end_overlap + 1) then do;
				adj_st_overlap = start_date_overlap_sens;
				adj_end_overlap = end_date_overlap_sens;
				cncr_flag = 3.5; /* start date of overlap is exactly 1 day after previous record's end date of overlap */

				prev_bene_id = bene_id_18900;
				prev_st_overlap = adj_st_overlap;
				prev_end_overlap = adj_end_overlap;
			end;

			/* Otherwise, if the start of overlap occurs any time after the previous record's end date of overlap, do not adjust the start and end of overlap */
			else if start_date_overlap_sens > prev_end_overlap then do;
				adj_st_overlap = start_date_overlap_sens;
				adj_end_overlap = end_date_overlap_sens;
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

	/* Sort the concurrent use data set by beneficiary ID, adjusted start of concurrent medication use, and adjusted end of concurrent medication use */
		/* NOTE: Remember that the end date of concurrent medication use actually wasn't changed for any records in part 1a and 1c, so adj_end_overlap should be identical to end_date_overlap */

	proc sort data = &ddi._cncr3;
		by bene_id_18900 adj_st_overlap adj_end_overlap;
	run;

	/* Create continuous concurrent use episodes where, for a given beneficiary, 
	   any consecutive concurrent use episodes 1 day apart are considered to be part of the same concurrent medication use episode */

	data &ddi._cncr4;
		set &ddi._cncr3;
		by bene_id_18900 adj_st_overlap adj_end_overlap;

		if cncr_flag = 1 then ep_cncr_2 = 1; /* New beneficiary in data set, so episode count starts over */
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

	data merged.&ddi._dyswddi_sens_only;
		set &ddi._cncr7;

		days_with_ddi = (max_enddt + 1) - min_index_date;

		label
		days_with_ddi = "Number of days during enrolled NH time where bene meets criteria for the DDI";

	run;

	/* Close RTF document */

	ods rtf close;
	ods graphics off;
	ods results;

%mend;

/*************************************************************/
/*** Run macro for each concurrent medication use data set ***/
/*************************************************************/

data _null_;
	set ddi.ddi_list_3abc;

	/* Generate macro call for each record */
	call execute(cats('%days_meet_ddi_sens(', ddi, ');'));

run;

/* END OF PROGRAM */
