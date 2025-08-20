/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug-Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create episodes of medication use overlap (i.e., concurrent use) for 
the drugs associated with each DDI in the stability analysis. 
Use the discontinuation date (rather than the dispensing run-out date) 
for the drug that began first during NH time.

For drug-drug interactions involving 2 drugs, we applied the discontinuation
adjustment to the drug whose medication episode began first during
the NH stay. If the medication use episodes began on the same day,
we did not apply the discontinuation adjustment to either drug.

For drug-drug interactions involving 3 drugs, we applied the 
discontinuation adjustment to the drug(s) whose medication episode
began first during the NH stay. If all 3 medication use episodes
began on the same day, no discontinuation adjustment was applied.

Programmer: Laura Reich   
 
Date Last Modified: July 22, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets and files:
- nhtm2.&ddi._c5_sens: Medication episodes for a given DDI component, 2018-2020, 
                       within NH stays. This includes an adjusted end date
                       that is the last dispensing date + 50% of its
                       days' supply
- ddi.ddi_list_3a: List of DDIs to be run through the flag_concurrent_sens macro.
- ddi.ddi_list_3b: List of DDIs to be run through the flag_concurrent_2_sens macro.
- ddi.ddi_list_3c: List of DDIs to be run through the flag_concurrent_sens_3 macro.
- dlist.&ddi._cls: List of generic drugs (without specification of salt form) and 
                   their drug class for a given DDI component.
*********************************************************************/

/*********************************************************************
Key generated datasets:
- merged.&ddi._cncr_sens_only: Dataset of overlapping medication use episodes
                               (i.e., concurrent use) for a given DDI in the 
                               stability analysis.
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname drugs    "your/library/path"; /*Drug-level claims*/
libname dlist    "your/library/path"; /*Excel drug lists*/
libname lrenroll "your/library/path"; /* Relevant NH time data set with exclusions applied */
libname nhtm2    "your/library/path"; /* Medication episodes during NH time data sets */
libname merged   "your/library/path"; /* Merged medication episode data sets */
libname smcncr   "your/library/path"; /* DDI prevalence summary info */
libname ddi      "your/library/path"; /* Data sets with lists of ddis and their components drug categories */

options mprint mlogic; 

/**********************************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 2 distinct medication use datasets (stability analysis)  ***/
/**********************************************************************************************************************************************/

%macro flag_concurrent_sens(component_1, component_2, ddi);

	/* Writing to RTF document */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** Replace any '-' in the DDI sheet name to 'xx', since SAS data set names cannot include '-' ***/

	%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
	%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));

	/*** Merge medication use episode data sets together for a given DDI ***/

	/* If the ddi is not ddi20 or ddi30, merge the two medication use episode data sets without any modifications */
	%if &ddi. ne ddi20 and &ddi. ne ddi30 %then %do;

		/* Merge medication use episode data sets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
			create table merged.&ddi._sens as
			select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
			a.episode_new as episode_new_1, a.min_index_date as min_index_date_1, a.max_supply_enddt as max_supply_enddt_1, a.max_discon_date as max_discon_date_1,
			a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, 
			a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
		    a.med_use_sens as med_use_sens_1, b.core_drug as core_drug_2,
			b.episode_new as episode_new_2, b.min_index_date as min_index_date_2, b.max_supply_enddt as max_supply_enddt_2, b.max_discon_date as max_discon_date_2,
			b.max_start_fill_last as max_start_fill_last_2,
			b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
			b.med_use_sens as med_use_sens_2
			from nhtm2.&ddi_1._c5_sens as a inner join nhtm2.&ddi_2._c5_sens as b
			on ((a.bene_id_18900 = b.bene_id_18900) &
			(a.eNH_ep_start = b.eNH_ep_start) &
			(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/* If the ddi IS ddi20, delete any medication use episodes for aspirin in the two data sets before merging */
		/* NOTE: We removed aspirin from the ddi20 (antiplatelet drug (aspirin) + NSAID) medication use data sets because it can be considered both an antiplatelet drug and an NSAID. 
				 Therefore, we simply removed it. */

	%else %if &ddi. = ddi20 %then %do;

		data &ddi_1._comb6;
			set nhtm2.&ddi_1._c5_sens;

			if core_drug = 'aspirin' then delete;

		run;

		data &ddi_2._c6;
			set nhtm2.&ddi_2._c5_sens;

			if core_drug = 'aspirin' then delete;

		run;

		/* Merge medication use episode data sets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
			create table merged.&ddi._sens as
			select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
			a.episode_new as episode_new_1, a.min_index_date as min_index_date_1, a.max_supply_enddt as max_supply_enddt_1, a.max_discon_date as max_discon_date_1,
			a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, 
			a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
		    a.med_use_sens as med_use_sens_1, b.core_drug as core_drug_2,
			b.episode_new as episode_new_2, b.min_index_date as min_index_date_2, b.max_supply_enddt as max_supply_enddt_2, b.max_discon_date as max_discon_date_2,
			b.max_start_fill_last as max_start_fill_last_2,
			b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
			b.med_use_sens as med_use_sens_2
			from &ddi_1._comb6 as a inner join &ddi_2._c6 as b
			on ((a.bene_id_18900 = b.bene_id_18900) &
			(a.eNH_ep_start = b.eNH_ep_start) &
			(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/* If the ddi IS ddi30, delete any medication use episodes for diltiazem and verapamil from the CYP3A4-inhibitor data set before merging */
		/* NOTE: We removed diltiazem and verapamil from the list of CYP3A4-inhibitors in ddi30 (calcium channel blocker + CYP3A4-inhibitor) 
	             because they are both considered calcium channel blockers. */

	%else %if &ddi. = ddi30 %then %do;

		data &ddi_2._c6;
			set nhtm2.&ddi_2._c5_sens;

			if core_drug = 'diltiazem' or core_drug = 'verapamil' then delete;

		run;

		/* Merge medication use episode data sets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
			create table merged.&ddi._sens as
			select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
			a.episode_new as episode_new_1, a.min_index_date as min_index_date_1, a.max_supply_enddt as max_supply_enddt_1, a.max_discon_date as max_discon_date_1,
			a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, 
			a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
		    a.med_use_sens as med_use_sens_1, b.core_drug as core_drug_2,
			b.episode_new as episode_new_2, b.min_index_date as min_index_date_2, b.max_supply_enddt as max_supply_enddt_2, b.max_discon_date as max_discon_date_2,
			b.max_start_fill_last as max_start_fill_last_2,
			b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
			b.med_use_sens as med_use_sens_2
			from nhtm2.&ddi_1._c5_sens as a inner join &ddi_2._c6 as b
			on ((a.bene_id_18900 = b.bene_id_18900) &
			(a.eNH_ep_start = b.eNH_ep_start) &
			(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/*** Flag concurrent use in merged data set ***/

	data &ddi._2;
		set merged.&ddi._sens;

		/* If medication 1 ends before start of medication 2, flag as no concurrent use */
		if max_enddt_nh_1 < min_index_nh_2 then do;
			flag_no = 1;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
		else if min_index_nh_1 > max_enddt_nh_2 then do;
			flag_no = 2;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) and (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 3;
			concurrent_flag = 1;
		end;

		/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 4;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 5;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
		else if (min_index_nh_1 <= min_index_nh_2) and (max_enddt_nh_1 >= max_enddt_nh_2) then do;
			flag_no = 6;
			concurrent_flag = 1;
		end;

		/* Flag which medication use episode begins first during nh time */
		if min_index_nh_1 < min_index_nh_2 then med_1_first_nh = 1;
		else med_1_first_nh = 0;

		if min_index_nh_2 < min_index_nh_1 then med_2_first_nh = 1;
		else med_2_first_nh = 0;

		if min_index_nh_1 = min_index_nh_2 then drug_start_same_nh = 1;
		else drug_start_same_nh = 0;

		label
			flag_no = "Flags for relation btwn med 1 and 2 episodes"
			concurrent_flag = "1 = some overlap between medication use episodes, 0 = no overlap"
			med_1_first_nh = "Medication 1 episode began first in DONH time"
			med_2_first_nh = "Medication 2 episode began first in DONH time"
			drug_start_same_nh = "Medication 1 and 2 started on the same day in DONH time"
		;

	run;

	title1 "Crosstab of med_1_first_nh, med_2_first_nh, and drug_start_same_nh in &ddi._2 where concurrent_flag = 1";
	proc freq data = &ddi._2;
		where concurrent_flag = 1;
		tables med_1_first_nh*med_2_first_nh*drug_start_same_nh / list missing;
	run;

	/*** Flag concurrent use using the discontinuation date of each medication episode ***/
		/* Only use the adjusted discontinuation date for the "first" drug (i.e., the drug with the medication use episode that began first during the NH stay) */
		/* When medication use episodes begin on the same day, don't make any discontinuation date adjustments */

	data &ddi._3;
		set &ddi._2;

		/* If medication 1 began first, enter into the conditional block */
		if med_1_first_nh = 1 then do;

			/* If medication 1 has no use during NH time based on updated discontinuation date, flag as no concurrent use */
			if med_use_sens_1 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 discontinues before start of medication 2, flag as no concurrent use */
			else if max_enddt_nh_sens_1 < min_index_nh_2 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
			else if min_index_nh_sens_1 > max_enddt_nh_2 then do;
				flag_sens_no = 2;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_2 <= min_index_nh_sens_1 <= max_enddt_nh_2) and (min_index_nh_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= min_index_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (min_index_nh_sens_1 <= min_index_nh_2) and (max_enddt_nh_sens_1 >= max_enddt_nh_2) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 2 began first, enter into the conditional block */
		else if med_2_first_nh = 1 then do;

			/* If medication 2 has no use during NH time based on updated discontinuation date, flag as no concurrent use */
			if med_use_sens_2 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 ends before start of medication 2, flag as no concurrent use */
			else if max_enddt_nh_1 < min_index_nh_sens_2 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 begins after the discontinuation date of medication 2, flag as no concurrent use */
			else if min_index_nh_1 > max_enddt_nh_sens_2 then do;
				flag_sens_no = 2;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_1 <= max_enddt_nh_sens_2) and (min_index_nh_sens_2 <= max_enddt_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_2 <= max_enddt_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (min_index_nh_1 <= min_index_nh_sens_2) and (max_enddt_nh_1 >= max_enddt_nh_sens_2) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;
	
		/* If both medication 1 and medication 2 begin at the same time, do not apply the discontinuation adjustment */
		else if drug_start_same_nh = 1 then do;

			flag_sens_no = flag_no;
			concurrent_sens_flag = concurrent_flag;

		end;

		label
			flag_sens_no = "Flags for relation btwn med 1 and 2 episodes in the stability analysis"
			concurrent_sens_flag = "1 = some overlap between medication use episodes in stability analysis, 0 = no overlap in stability analysis"
		;

	run;

	title1 "&ddi._3";
	proc freq data = &ddi._3;
		tables concurrent_flag*concurrent_sens_flag concurrent_sens_flag*flag_sens_no / list missing;
	run;

	/*** Delete records where there is no concurrent use ***/

	data &ddi._4;
		set &ddi._3;

		if concurrent_flag = 0 then delete;

	run;

	/*** Calculate the start date of medication use overlap and the end date of medication use overlap ***/
		/* NOTE: These are the same as start date and end date of medication use overlap in the primary analysis. In a moment,
	             we will calculate the start and end of overlap for the stability analysis */

	data &ddi._5;
		set &ddi._4;

		/* If medication 1 starts and ends within the medication 2 episode, set the overlap start date to medication 1's start date 
		and the overlap end date to medication 1's end date */
		if flag_no = 3 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts during medication 2's episode, set the overlap start date to medication 1's start date
		and the overlap end date to medication 2's end date */
		else if flag_no = 4 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_2;
		end;

		/* Otherwise, if medication 1 ends within medication 2 episode, set the overlap start date to medication 2's start date and the 
		overlap end date to medication 1's end date */
		else if flag_no = 5 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts on or before medication 2's start AND ends on or after medication 2's end, set the overlap start date to 
		medication 2's start date and the overlap end date to medication 2's end date */
		else if flag_no = 6 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_2;
		end;

		format start_date_overlap end_date_overlap date9.;

		label
			start_date_overlap = "Start date of overlap between medication 1 and medication 2 episodes"
			end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes"
		;

	run;

	/*** Calculate the start date of medication use overlap and the end date of medication use overlap when concurrent_sens_flag = 1 ***/
		/* NOTE: We are applying the discontinuation adjustment here */

	data &ddi._6;
		set &ddi._5;

		/* If medication 1 began first and there is concurrent use, enter into the conditional block */
		if concurrent_sens_flag = 1 and med_1_first_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

		end;

		/* Otherwise, if medication 2 begins first and there is concurrent use, enter into the conditional block */
		else if concurrent_sens_flag = 1 and med_2_first_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

		end;

		/* Otherwise, if medication 1 and 2 began at the same time and there is concurrent use, enter into the conditional block */
			/* NOTE: No discontinuation adjustment is applied here */
		else if concurrent_sens_flag = 1 and drug_start_same_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_no = 3 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_no = 4 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_no = 5 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_no = 6 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

		end;

		format start_date_overlap_sens end_date_overlap_sens date9.;

	run;
		
	/*** Calculate the number of days of medication use overlap ***/

	data &ddi._7;
		set &ddi._6;

		days_overlap = end_date_overlap + 1 - start_date_overlap;

		if concurrent_sens_flag = 1 then do;
			days_overlap_sens = end_date_overlap_sens + 1 - start_date_overlap_sens;
		end;

		label
			days_overlap = "Days of medication use overlap"
			days_overlap_sens = "Days of medication use overlap in stability analysis"
		;

	run;

	title1 "Distribution of days_overlap and days_overlap_sens in &ddi._7";
	proc means data = &ddi._7 n nmiss mean std median q1 q3 min max;
		var days_overlap days_overlap_sens;
	run;

	proc univariate data = &ddi._7;
		var days_overlap days_overlap_sens;
		histogram days_overlap days_overlap_sens / normal;
		inset mean std="Std Dev" median q1 q3 min max / pos = ne;
		title "Histogram of days_overlap and days_overlap_sens variable, &ddi._7";
	run;

	/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

	proc sort data = &ddi._7;
		by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;
	run;

	data merged.&ddi._cncr_sens;
		set &ddi._7;
		by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;

		if first.bene_id_18900 then episode_cncr = 1;
		else episode_cncr + 1;

		label
			episode_cncr = 'Episode of concurrent use'
		;

	run; 

	/*** Create dataset that only contains records for which concurrent_sens_flag = 1 ***/

	data merged.&ddi._cncr_sens_only;
		set merged.&ddi._cncr_sens;

		if concurrent_sens_flag = 1;

	run;

	title1 "How many benes are in merged.&ddi._cncr_sens?";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens;
	quit;

	title1 "How many benes are in merged.&ddi._cncr_sens_only? (restricted to concurrent_sens_flag = 1)";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens_only;
	quit;

	title1 "Number of records where start_date_overlap_sens = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where start_date_overlap_sens = .;
	quit;

	title1 "Number of records where end_date_overlap_sens = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where end_date_overlap_sens = .;
	quit;

	/* End writing to RTF document */

	ods rtf close;
	ods graphics off;
	ods results;

	/*** Check the drug combinations flagged for concurrent use ***/

	title "Drug combinations with concurrent use";
	proc freq data = merged.&ddi._cncr_sens_only;
		tables core_drug_1*core_drug_2 / list missing out = freq_drug;
	run;

	/*** Delete data sets from the work library ***/

	proc datasets library = work nolist;
		delete &ddi_1._: &ddi_2._: &ddi._:;
	quit;

%mend;

/****************************************************************************************/
/*** Run the flag_concurrent_sens macro for the DDIs in the ddi.ddi_list_3a data set  ***/
/****************************************************************************************/
	
data _null_;
	set ddi.ddi_list_3a;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent_sens(', component_1, ', ', component_2, ', ', ddi, ');'));
run;

/***********************************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 2 identical medication use datasets (stability analysis)  ***/
/***********************************************************************************************************************************************/

%macro flag_concurrent_2_sens(component_1, component_2, ddi);

	/* Writing to RTF document */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** Replace any '-' in the DDI sheet names to 'xx', since SAS data set names cannot include '-' ***/

	%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
	%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));

	/*** Merge medication use episode data sets together ***/

	/* If the ddi is not ddi57 or ddi90, add the class variable to each record in the medication use episode data set before merging */

	%if &ddi. ne ddi57 and &ddi. ne ddi90 %then %do;

		/* Add the class variable to each medication episode record */
		proc sql;
			create table &ddi_1._c6_sens as
			select a.*, b.class
			from nhtm2.&ddi_1._c5_sens as a inner join dlist.&ddi_1._cls as b
			on (a.core_drug = b.core_drug);
		quit;

		/* Merge the two medication use episode data sets together by beneficiary ID and NH episode, making sure not to merge medication episodes for drugs of the same class */
		proc sql;
			create table merged.&ddi._sens as
			select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, a.class as class_1,
			a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, a.max_discon_date as max_discon_date_1,
			a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
		    a.med_use_sens as med_use_sens_1,
			b.core_drug as core_drug_2, b.class as class_2, b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2,
			b.max_discon_date as max_discon_date_2, b.max_start_fill_last as max_start_fill_last_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
		    b.med_use_sens as med_use_sens_2
			from &ddi_1._c6_sens as a inner join &ddi_2._c6_sens as b 
			on ((a.bene_id_18900 = b.bene_id_18900) &
			(a.eNH_ep_start = b.eNH_ep_start) &
			(a.class ne b.class));
		quit; 

	%end;

	/* If the ddi is ddi57 or ddi90, don't add the class variable to the medication use episode data sets. Merge the two medication use episode data sets, making sure not to merge
	medication episodes for the same drug */
		/* NOTE: ddi57 and ddi90 are both concomitant use of =2 anticholinergic drugs. We decided to identify concurrent use between any of our listed anticholinergic drugs, regardless of class. */

	%else %if &ddi. = ddi57 or &ddi. = ddi90 %then %do;

		/* Merge the two medication use episodes by beneficiary ID and NH episode, making sure not to merge together records with the same drug */
		proc sql;
			create table merged.&ddi._sens as
			select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1,
			a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, a.max_discon_date as max_discon_date_1,
			a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
		    a.med_use_sens as med_use_sens_1,
			b.core_drug as core_drug_2, b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2,
			b.max_discon_date as max_discon_date_2, b.max_start_fill_last as max_start_fill_last_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
		    b.med_use_sens as med_use_sens_2
			from nhtm2.&ddi_1._c5_sens as a inner join nhtm2.&ddi_1._c5_sens as b 
			on ((a.bene_id_18900 = b.bene_id_18900) &
			(a.eNH_ep_start = b.eNH_ep_start) &
			(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/*** Remove reverse duplicates from the merged dataset ***/

	/* Create a variable, drug_12, with the 2 medication episode numbers in numerical order */

	data &ddi._2;
		set merged.&ddi._sens;

		if episode_new_1 <= episode_new_2 then
			drug_12 = catx(' ', episode_new_1 , episode_new_2);
		else 
			drug_12 = catx(' ', episode_new_2, episode_new_1);

		label
		drug_12 = "Identifier for reverse duplicates"
		;

	run;

	/* Only keep the first instance of this drug_12 variable (for each beneficiary) in order to remove reverse duplicates */

	proc sort data = &ddi._2;
		by bene_id_18900 drug_12;
	run;

	data &ddi._3;
		set &ddi._2;
		by bene_id_18900 drug_12;

		if first.drug_12;

	run; /* This should reduce the data set by exactly half the number of records */

	/*** Flag concurrent medication use in merged dataset ***/

	data &ddi._4;
		set &ddi._3;

		/* If medication 1 ends before start of medication 2, flag as no concurrent use */
		if max_enddt_nh_1 < min_index_nh_2 then do;
			flag_no = 1;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
		else if min_index_nh_1 > max_enddt_nh_2 then do;
			flag_no = 2;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) and (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 3;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1's start date is between medication 2's start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 4;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1's end date is between medication 2's start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 5;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
		else if (min_index_nh_1 <= min_index_nh_2) and (max_enddt_nh_1 >= max_enddt_nh_2) then do;
			flag_no = 6;
			concurrent_flag = 1;
		end;

		/* Flag which medication use episode begins first during nh time */
		if min_index_nh_1 < min_index_nh_2 then med_1_first_nh = 1;
		else med_1_first_nh = 0;

		if min_index_nh_2 < min_index_nh_1 then med_2_first_nh = 1;
		else med_2_first_nh = 0;

		if min_index_nh_1 = min_index_nh_2 then drug_start_same_nh = 1;
		else drug_start_same_nh = 0;

		label
			flag_no = "Flags for relation btwn med 1 and 2 episodes"
			concurrent_flag = "1 = some overlap between medication use episodes, 0 = no overlap"
			med_1_first_nh = "Medication 1 episode began first in DONH time"
			med_2_first_nh = "Medication 2 episode began first in DONH time"
			drug_start_same_nh = "Medication 1 and 2 started on the same day in DONH time"
		;

	run;

	/* Check how many records have concurrent use */

	title1 "Distribution of flag_no in &ddi._4";
	proc freq data = &ddi._4;
		tables flag_no / list missing;
	run;

	title1 "Distribution of concurrent_flag in &ddi._4";
	proc freq data = &ddi._4;
		tables concurrent_flag / list missing;
	run;

	title1 "Crosstab of med_1_first_nh, med_2_first_nh, and drug_start_same_nh in &ddi._4 where concurrent_flag = 1";
	proc freq data = &ddi._4;
		where concurrent_flag = 1;
		tables med_1_first_nh*med_2_first_nh*drug_start_same_nh / list missing;
	run;

	/*** Flag concurrent use using the discontinuation date of each medication episode ***/
		/* Only use the adjusted discontinuation date for the "first" drug (i.e., the drug with the medication use episode that began first */
		/* When medication use episodes begin on the same day, don't make any discontinuation date adjustments */

	data &ddi._5;
		set &ddi._4;

		/* If medication 1 began first, enter into the conditional block */
		if med_1_first_nh = 1 then do;

			/* If medication 1 has no use during NH time based on updated discontinuation date, flag as no concurrent use */
			if med_use_sens_1 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 discontinues before start of medication 2, flag as no concurrent use */
			else if max_enddt_nh_sens_1 < min_index_nh_2 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
			else if min_index_nh_sens_1 > max_enddt_nh_2 then do;
				flag_sens_no = 2;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_2 <= min_index_nh_sens_1 <= max_enddt_nh_2) and (min_index_nh_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= min_index_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (min_index_nh_sens_1 <= min_index_nh_2) and (max_enddt_nh_sens_1 >= max_enddt_nh_2) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 2 began first, enter into the conditional block */
		else if med_2_first_nh = 1 then do;

			/* If medication 2 has no use during NH time based on updated discontinuation date, flag as no concurrent use */
			if med_use_sens_2 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 ends before start of medication 2, flag as no concurrent use */
			else if max_enddt_nh_1 < min_index_nh_sens_2 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
			else if min_index_nh_1 > max_enddt_nh_sens_2 then do;
				flag_sens_no = 2;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_1 <= max_enddt_nh_sens_2) and (min_index_nh_sens_2 <= max_enddt_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_2 <= max_enddt_nh_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (min_index_nh_1 <= min_index_nh_sens_2) and (max_enddt_nh_1 >= max_enddt_nh_sens_2) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* If both medication 1 and medication 2 begin at the same time, do not apply the discontinuation adjustment */
		else if drug_start_same_nh = 1 then do;

			flag_sens_no = flag_no;
			concurrent_sens_flag = concurrent_flag;

		end;

		label
			flag_sens_no = "Flags for relation btwn med 1 and 2 episodes in the stability analysis"
			concurrent_sens_flag = "1 = some overlap between medication use episodes, 0 = no overlap in stability analysis"
		;

	run;

	title1 "&ddi._5";
	proc freq data = &ddi._5;
		tables concurrent_flag*concurrent_sens_flag concurrent_sens_flag*flag_sens_no / list missing;
	run;

	/*** Delete records where there is no concurrent use ***/

	data &ddi._6;
		set &ddi._5;

		if concurrent_flag = 0 then delete;

	run;

	/*** Calculate the start date of medication use overlap and the end date of medication use overlap ***/
		/* NOTE: These are the same as start date and end date of medication use overlap in the primary analysis. In a moment,
	             we will calculate the start and end of overlap for the stability analysis */

	data &ddi._7;
		set &ddi._6;

		/* If medication 1 starts and ends within the medication 2 episode, set the overlap start date to medication 1's start date 
		and the overlap end date to medication 1's end date */
		if flag_no = 3 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts during medication 2's episode, set the overlap start date to medication 1's start date
		and the overlap end date to medication 2's end date */
		else if flag_no = 4 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_2;
		end;

		/* Otherwise, if medication 1 ends within medication 2 episode, set the overlap start date to medication 2's start date and the 
		overlap end date to medication 1's end date */
		else if flag_no = 5 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts on or before medication 2's start AND ends on or after medication 2's end, set the overlap start date to 
		medication 2's start date and the overlap end date to medication 2's end date */
		else if flag_no = 6 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_2;
		end;

		format start_date_overlap end_date_overlap date9.;

		label
			start_date_overlap = "Start date of overlap between medication 1 and medication 2 episodes"
			end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes"
		;

	run;

	/*** Calculate the start date of medication use overlap and the end date of medication use overlap when concurrent_sens_flag = 1 ***/
		/* NOTE: We are applying the discontinuation adjustment here */

	data &ddi._8;
		set &ddi._7;

		/* If medication 1 began first and there is concurrent use, enter into the conditional block */
		if concurrent_sens_flag = 1 and med_1_first_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

		end;

		/* If medication 2 begins first and there is concurrent use, enter into the conditional block */
		else if concurrent_sens_flag = 1 and med_2_first_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

		end;

		/* If medication 1 and 2 began at the same time and there is concurrent use, enter into the conditional block */
			/* NOTE: No discontinuation adjustment is applied here */
		else if concurrent_sens_flag = 1 and drug_start_same_nh = 1 then do;

			/* If medication 1 starts and ends within the medication 2 episode, use medication 1 start and end date */
			if flag_no = 3 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 1 starts within the medication 2 episode, use the medication 1 start date and medication 2 end date */
			else if flag_no = 4 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

			/* If medication 1 ends within the medication 2 episode, use the medication 2 start date and medication 1 end date */
			else if flag_no = 5 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

			/* If medication 2 starts and ends within the medication 1 episode, use the medication 2 start and end dates */
			else if flag_no = 6 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

		end;

		format start_date_overlap_sens end_date_overlap_sens date9.;

	run;

	/*** Calculate the number of days of medication use overlap ***/

	data &ddi._9;
		set &ddi._8;

		days_overlap = end_date_overlap + 1 - start_date_overlap;

		if concurrent_sens_flag = 1 then do;
			days_overlap_sens = end_date_overlap_sens + 1 - start_date_overlap_sens;
		end;

		label
			days_overlap = "Days of medication use overlap"
			days_overlap_sens = "Days of medication use overlap in stability analysis"
		;

	run;

	/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

	proc sort data = &ddi._9;
		by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;
	run;

	data merged.&ddi._cncr_sens;
		set &ddi._9;
		by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;

		if first.bene_id_18900 then episode_cncr = 1;
		else episode_cncr + 1;

		label
			episode_cncr = 'Episode of concurrent use'
		;

	run; 

	/*** Create dataset that only contains records for which concurrent_sens_flag = 1 ***/

	data merged.&ddi._cncr_sens_only;
		set merged.&ddi._cncr_sens;

		if concurrent_sens_flag = 1;

	run;

	title1 "How many benes are in merged.&ddi._cncr_sens?";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens;
	quit;

	title1 "How many benes are in merged.&ddi._cncr_sens_only? (restricted to concurrent_sens_flag = 1)";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens_only;
	quit;

	title1 "Number of records where start_date_overlap_sens = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where start_date_overlap_sens = .;
	quit;

	title1 "Number of records where end_date_overlap_sens = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where end_date_overlap_sens = .;
	quit;

	/*** Check the drug combinations flagged for concurrent use ***/

	title "Drug combinations with concurrent use";
	proc freq data = merged.&ddi._cncr_sens_only;
		tables core_drug_1*core_drug_2 / list missing out = freq_drug;
	run;

	/* End writing to RTF doc */

	ods rtf close;
	ods graphics off;
	ods results;

	/*** Delete datasets from the work library ***/

	proc datasets library = work nolist;
		delete &ddi_1._: &ddi._: ;
	quit;

%mend;

/*******************************************************************************************************/
/*** Run the flag_concurrent_2 macro for each DDI with 2 identical medication use episode data sets  ***/
/*******************************************************************************************************/

data _null_;
	set ddi.ddi_list_3b;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent_2_sens(', component_1, ', ', component_2, ', ', ddi, ');'));
run;

/**********************************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 3 identical medication use datasets (stability analysis) ***/
/**********************************************************************************************************************************************/

%macro flag_concurrent_sens_3(component_1, component_2, component_3, ddi);

	/* Writing to RTF document */

	ods graphics;
	ods noresults;
	ods rtf file = "your/rtf/path";

	/*** Replace any '-' in the DDI sheet names to 'xx', since SAS data set names cannot include '-' ***/

	%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
	%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));
	%let ddi_3 = %sysfunc(tranwrd(&component_3., -, xx));

	/*** Add the class variable to each medication use record in the medication use episode data set ***/

	proc sql;
		create table &ddi_1._c6_sens as
		select a.*, b.class
		from nhtm2.&ddi_1._c5_sens as a inner join dlist.&ddi_1._cls as b
		on (a.core_drug = b.core_drug);
	quit;

	/*** Merge the first 2 medication use episode data sets together ***/

	/* Merge the 2 medication use episode data sets together by beneficiary ID and NH episode, making sure not to merge medication episodes for drugs of the same class */
	proc sql;
		create table &ddi.x2 as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, a.class as class_1,
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, a.max_discon_date as max_discon_date_1,
		a.max_start_fill_last as max_start_fill_last_1, a.min_index_nh_sens as min_index_nh_sens_1, a.max_enddt_nh_sens as max_enddt_nh_sens_1,
	    a.med_use_sens as med_use_sens_1,
		b.core_drug as core_drug_2, b.class as class_2, b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2,
		b.max_discon_date as max_discon_date_2, b.max_start_fill_last as max_start_fill_last_2, b.min_index_nh_sens as min_index_nh_sens_2, b.max_enddt_nh_sens as max_enddt_nh_sens_2,
	    b.med_use_sens as med_use_sens_2
		from &ddi_1._c6_sens as a inner join &ddi_2._c6_sens as b 
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) & 
		(a.class ne b.class));
	quit; 

	/*** Remove reverse duplicates from the merged data set ***/

	/* Create a variable, drug_12, with the 2 medication episode numbers in numerical order */

	data &ddi.x22;
		set &ddi.x2;

		if episode_new_1 <= episode_new_2 then
			drug_12 = catx(' ', episode_new_1 , episode_new_2);
		else 
			drug_12 = catx(' ', episode_new_2, episode_new_1);

		label
			drug_12 = "Identifier for reverse duplicates"
		;

	run;

	/* Only keep the first instance of the drug_12 variable for each beneficiary in order to remove reverse duplicates */

	proc sort data = &ddi.x22;
		by bene_id_18900 drug_12;
	run;

	data &ddi.x23;
		set &ddi.x22;
		by bene_id_18900 drug_12;

		if first.drug_12;

	run; /* This should reduce the dataset by exactly half the number of records */

	/*** Flag concurrent medication use in merged data set ***/

	data &ddi.x24;
		set &ddi.x23;

		/* If medication 1 ends before start of medication 2, flag as no concurrent use */
		if max_enddt_nh_1 < min_index_nh_2 then do;
			flag_no = 1;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 begins after the end of medication 2, flag as no concurrent use */
		else if min_index_nh_1 > max_enddt_nh_2 then do;
			flag_no = 2;
			concurrent_flag = 0;
		end;

		/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) and (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 3;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1's start date is between medication 2's start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= min_index_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 4;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1's end date is between medication 2's start and end date, flag for concurrent use */
		else if (min_index_nh_2 <= max_enddt_nh_1 <= max_enddt_nh_2) then do;
			flag_no = 5;
			concurrent_flag = 1;
		end;

		/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
		else if (min_index_nh_1 <= min_index_nh_2) and (max_enddt_nh_1 >= max_enddt_nh_2) then do;
			flag_no = 6;
			concurrent_flag = 1;
		end;

		label
			flag_no = "Flags for relation btwn med 1 and 2 episodes"
			concurrent_flag = "1 = some overlap between medication use episodes, 0 = no overlap"
		;

	run;

	/*** Delete records where there is no concurrent use ***/

	data &ddi.x25;
		set &ddi.x24;

		if concurrent_flag = 0 then delete;

	run;

	/*** Calculate the start date of medication use overlap and the end date of medication use overlap ***/

	data &ddi.x26;
		set &ddi.x25;

		/* If medication 1 starts and ends within the medication 2 episode, set the overlap start date to medication 1's start date 
		and the overlap end date to medication 1's end date */
		if flag_no = 3 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts during medication 2's episode, set the overlap start date to medication 1's start date
		and the overlap end date to medication 2's end date */
		else if flag_no = 4 then do;
			start_date_overlap = min_index_nh_1;
			end_date_overlap = max_enddt_nh_2;
		end;

		/* Otherwise, if medication 1 ends within medication 2 episode, set the overlap start date to medication 2's start date and the 
		overlap end date to medication 1's end date */
		else if flag_no = 5 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_1;
		end;

		/* Otherwise, if medication 1 starts on or before medication 2's start AND ends on or after medication 2's end, set the overlap start date to 
		medication 2's start date and the overlap end date to medication 2's end date */
		else if flag_no = 6 then do;
			start_date_overlap = min_index_nh_2;
			end_date_overlap = max_enddt_nh_2;
		end;

		format start_date_overlap end_date_overlap date9.;

		label
			start_date_overlap = "Start date of overlap between medication 1 and medication 2 episodes"
			end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes"
		;

	run;

	/***  Merge the third medication use episode data set with the medication 1 and 2 dataset (&ddi.x25) ***/

	/* Merge data sets by beneficiary ID and NH episode, making sure that there are no matching classes between the 3 drugs in a given record */
	proc sql;
		create table merged.&ddi._sens as
		select ab.*, c.core_drug as core_drug_3, c.class as class_3, c.episode_new as episode_new_3, c.min_index_nh as min_index_nh_3,
		c.max_enddt_nh as max_enddt_nh_3, c.max_discon_date as max_discon_date_3,
		c.max_start_fill_last as max_start_fill_last_3, c.min_index_nh_sens as min_index_nh_sens_3, c.max_enddt_nh_sens as max_enddt_nh_sens_3,
		c.med_use_sens as med_use_sens_3
		from &ddi.x26 as ab inner join &ddi_3._c6_sens as c
		on ((ab.bene_id_18900 = c.bene_id_18900) &
		(ab.eNH_ep_start = c.eNH_ep_start) & 
		(ab.class_1 ne c.class) &
		(ab.class_2 ne c.class));
	quit; 

	/*** Remove reverse duplicates ***/

	/* Create a variable, drug_123, with the 3 medication episode numbers in numerical order */

	data &ddi._2;
		set merged.&ddi._sens;

		if episode_new_1 <= episode_new_2 <= episode_new_3 then
			drug_123 = catx(' ', episode_new_1, episode_new_2, episode_new_3);
		else if episode_new_1 <= episode_new_3 <= episode_new_2 then
			drug_123 = catx(' ', episode_new_1, episode_new_3, episode_new_2);
		else if episode_new_2 <= episode_new_1 <= episode_new_3 then
			drug_123 = catx(' ', episode_new_2, episode_new_1, episode_new_3);
		else if episode_new_2 <= episode_new_3 <= episode_new_1 then
			drug_123 = catx(' ', episode_new_2, episode_new_3, episode_new_1);
		else if episode_new_3 <= episode_new_1 <= episode_new_2 then
			drug_123 = catx(' ', episode_new_3, episode_new_1, episode_new_2);
		else if episode_new_3 <= episode_new_2 <= episode_new_1 then
			drug_123 = catx(' ', episode_new_3, episode_new_2, episode_new_1);

	run;

	/* Only keep the first instance of this drug_123 variable for each beneficiary in order to remove reverse duplicates */

	proc sort data = &ddi._2;
		by bene_id_18900 drug_123;
	run;

	data &ddi._3;
		set &ddi._2;
		by bene_id_18900 drug_123;

		if first.drug_123;

	run; /* Note this will not cut our records to 1/3 of the original size, 
	        since we already removed some "reverse duplicates" after merging two medication episodes together */

	/*** Flag concurrent use between the 3 medications in each row of the merged data set ***/ 

	data &ddi._4;
		set &ddi._3;

		/* If medication 1 and 2 overlap ends before start of medication 3, flag as no concurrent use */
		if end_date_overlap < min_index_nh_3 then do;
			flag_no_2 = 1;
			concurrent_flag_2 = 0;
		end;

		/* Otherwise, if medication 1 and 2 overlap begins after the end of medication 3, flag as no concurrent use */
		else if start_date_overlap > max_enddt_nh_3 then do;
			flag_no_2 = 2;
			concurrent_flag_2 = 0;
		end;

		/* Otherwise, if medication 1 and 2 overlap starts and ends within the medication 3 episode, flag for concurrent use */
		else if (min_index_nh_3 <= start_date_overlap <= max_enddt_nh_3) and (min_index_nh_3 <= end_date_overlap <= max_enddt_nh_3) then do;
			flag_no_2 = 3;
			concurrent_flag_2 = 1;
		end;

		/* Otherwise, if medication 1 and 2 overlap start date is between medication 3 start and end date, flag for concurrent use */
		else if (min_index_nh_3 <= start_date_overlap <= max_enddt_nh_3) then do;
			flag_no_2 = 4;
			concurrent_flag_2 = 1;
		end;

		/* Otherwise, if medication 1 and 2 overlap end date is between medication 3 start and end date, flag for concurrent use */
		else if (min_index_nh_3 <= end_date_overlap <= max_enddt_nh_3) then do;
			flag_no_2 = 5;
			concurrent_flag_2 = 1;
		end;

		/* Otherwise, if medication 1 and 2 overlap starts on or before the start of medication 3 and ends on or after the end of medication 3, flag for concurrent use */
		else if (start_date_overlap <= min_index_nh_3) and (end_date_overlap >= max_enddt_nh_3) then do;
			flag_no_2 = 6;
			concurrent_flag_2 = 1;
		end;

		label
			flag_no = "Flags for relation med 1,2 overlap and med 3 episode"
			concurrent_flag_2 = "1 = some overlap between medication use episodes, 0 = no overlap"
		;

	run;

	/*** Delete records where there is no concurrent medication use between the 3 drugs ***/

	data &ddi._5;
	set &ddi._4;

	if concurrent_flag_2 = 0 then delete;

	run; 

	/*** Ascertain order of the three medications ***/
		/* NOTE: We are doing this to determine which drug(s) will have the discontinuation adjustment applied */

	data &ddi._6;
		set &ddi._5;

		/* Find the latest start date of the 3 medications */
		latest_start = max(min_index_nh_1, min_index_nh_2, min_index_nh_3);

		/* Initalize indicator variables all to 0 */
		med_1_first_nh = 0;
		med_2_first_nh = 0;
		med_3_first_nh = 0;
		med12_same_b4_3 = 0;
		med13_same_b4_2 = 0;
		med23_same_b4_1 = 0;
		all_drugs_start_same_nh = 0;

		/* All equal start date */
		if min_index_nh_1 = min_index_nh_2 and min_index_nh_2 = min_index_nh_3 then do;
	    	all_drugs_start_same_nh = 1;
		end;

		/* Pairwise same-day starts */
		else if min_index_nh_1 = min_index_nh_2 and min_index_nh_1 < latest_start then do;
			med12_same_b4_3 = 1;
		end;

		else if min_index_nh_1 = min_index_nh_3 and min_index_nh_1 < latest_start then do;
			med13_same_b4_2 = 1;
		end;

		else if min_index_nh_2 = min_index_nh_3 and min_index_nh_2 < latest_start then do;
			med23_same_b4_1 = 1;
		end;

		/* Single drug starts */
		else if min_index_nh_1 < min_index_nh_2 and min_index_nh_1 < min_index_nh_3 then do;
			med_1_first_nh = 1;
		end;

		else if min_index_nh_2 < min_index_nh_1 and min_index_nh_2 < min_index_nh_3 then do;
			med_2_first_nh = 1;
		end;

		else if min_index_nh_3 < min_index_nh_1 and min_index_nh_3 < min_index_nh_2 then do;
			med_3_first_nh = 1;
		end;

		label
			med_1_first_nh = "Medication 1 started first during NH time"
			med_2_first_nh = "Medication 2 started first during NH time"
			med_3_first_nh = "Medication 3 started first during NH time"
			med12_same_b4_3 = "Medication 1 and 2 started first during NH time"
			med13_same_b4_2 = "Medication 1 and 3 started first during NH time"
			med23_same_b4_1 = "Medication 2 and 3 started first during NH time"
			all_drugs_start_same_nh = "Medication 1, 2, and 3 started at the same time during NH time"
		;

	run;

	title1 "Crosstab of order indicator variables, &ddi._6";
	proc freq data = &ddi._6;
		tables med_1_first_nh*med_2_first_nh*med_3_first_nh*med12_same_b4_3*med13_same_b4_2*med23_same_b4_1*all_drugs_start_same_nh / list missing;
	run;

	/*** Calculate the start date and end date of medication use overlap between the 3 drugs (no discontinuation adjustment) ***/

	data &ddi._7;
		set &ddi._6;

		/* If medication 1 and 2 overlap starts and ends within medication 3's episode, set the start date of overlap as the start of medication 1 and 2 and the 
		end date of overlap as the end of medication 1 and 2 */
		if flag_no_2 = 3 then do;
			start_date_overlap_2 = start_date_overlap;
			end_date_overlap_2 = end_date_overlap;
		end;

		/* Otherwise, if medication 1 and 2 overlap starts within medication 3's episode, set the start date of overlap as the start of medication 1 and 2 and the
		end date of overlap as the end of medication 3 */
		else if flag_no_2 = 4 then do;
			start_date_overlap_2 = start_date_overlap;
			end_date_overlap_2 = max_enddt_nh_3;
		end;

		/* Otherwise, if medication 1 and 2 overlap ends within medication 3's episode, set the start date of overlap as the start of medication 3 and the
		end date of overlap as the end of medication 1 and 2 */
		else if flag_no_2 = 5 then do;
			start_date_overlap_2 = min_index_nh_3;
			end_date_overlap_2 = end_date_overlap;
		end;

		/* Otherwise, if medication 1 and 2 overlap starts on or before the start of medication 3's episode AND ends on or after the end of medication 3's episode,
		set the start date of overlap as the start of medication 3 and the end date of overlap as the end of medication 3 */
		else if flag_no_2 = 6 then do;
			start_date_overlap_2 = min_index_nh_3;
			end_date_overlap_2 = max_enddt_nh_3;
		end;

		format start_date_overlap_2 end_date_overlap_2 date9.;

		label
		start_date_overlap_2 = "Start date of overlap between the 3 medications episodes"
		end_date_overlap_2 = "End date of overlap between the 3 medication episodes";

	run;

	/*** Calculate the start and end dates of overlap WITH discontinuation adjustment ***/

	/* Start by flagging concurrent use between 2 of the medications using the discontinuation adjustment */

	data &ddi._8;
		set &ddi._7;

		/* If medication 1 began first, enter into the conditional block */
		if med_1_first_nh = 1 then do; /* Apply discontinuation adjustment to medication 1 */

			/* If medication 1 has no use during NH time based on the updated discontinuation adjustment date, flag as no concurrent use */
			if med_use_sens_1 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 discontinues before start of medication 2, flag as concurrent use */
			else if max_enddt_nh_sens_1 < min_index_nh_2 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_2) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 1 starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (min_index_nh_sens_1 <= min_index_nh_2) and (max_enddt_nh_sens_1 >= max_enddt_nh_2) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 2 began first, enter into the conditional block */
		else if med_2_first_nh = 1 then do; /* Apply discontinuation adjustment to medication 2 */

			/* If medication 2 has no use during NH time based on updated discontinuation date, flag as no concurrent use */
			if med_use_sens_2 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 2 discontinues before start of medication 1, flag as no concurrent use */
			else if max_enddt_nh_sens_2 < min_index_nh_1 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 2 end date is between medication 1 start and end date, flag for concurrent use */
			else if (min_index_nh_1 <= max_enddt_nh_sens_2 <= max_enddt_nh_1) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 2 starts on or before the start of medication 1 and ends on or after the end of medication 1, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_1) and (max_enddt_nh_sens_2 >= max_enddt_nh_1) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 3 began first, enter into the conditional block */
		else if med_3_first_nh = 1 then do; /* Apply discontinuation adjustment to medication 3 */

			/* If medication 3 has no use during NH time based on the updated discontinuation adjustment date, flag as no concurrent use */
			if med_use_sens_3 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 3 discontinues before start of medication 1, flag as concurrent use */
			else if max_enddt_nh_sens_3 < min_index_nh_1 then do;
				flag_sens_no = 1;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 3 end date is between medication 1 start and end date, flag for concurrent use */
			else if (min_index_nh_1 <= max_enddt_nh_sens_3 <= max_enddt_nh_1) then do;
				flag_sens_no = 5;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if medication 3 starts on or before the start of medication 1 and ends on or after the end of medication 1, flag for concurrent use */
			else if (min_index_nh_sens_3 <= min_index_nh_1) and (max_enddt_nh_sens_3 >= max_enddt_nh_1) then do;
				flag_sens_no = 6;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 1 and 2 began first, enter into the conditional block */
		else if med12_same_b4_3 = 1 then do; /* Apply discontinuation adjustment to medication 1 AND 2 */

			/* If medication 1 or medication 2 has no use during NH time based on the updated discontinuation adjustment date, flag as no concurrent use */
			if med_use_sens_1 = 0 or med_use_sens_2 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_sens_1 <= max_enddt_nh_sens_2) and (min_index_nh_sens_2 <= max_enddt_nh_sens_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_2 <= min_index_nh_sens_1 <= max_enddt_nh_sens_2) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 1 and 3 began first, enter into the conditional block */
		else if med13_same_b4_2 = 1 then do; /* Apply discontinuation adjustment to medication 1 AND 3 */

			/* If medication 1 or medication 3 has no use during NH time based on the updated discontinuation adjustment date, flag as no concurrent use */
			if med_use_sens_1 = 0 or med_use_sens_3 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 1 starts and ends within the medication 3 episode, flag for concurrent use */
			else if (min_index_nh_sens_3 <= min_index_nh_sens_1 <= max_enddt_nh_sens_3) and (min_index_nh_sens_3 <= max_enddt_nh_sens_1 <= max_enddt_nh_sens_3) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 1 start date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_3 <= min_index_nh_sens_1 <= max_enddt_nh_sens_3) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if medication 2 and 3 began first, enter into the conditional block */
		else if med23_same_b4_1 = 1 then do; /* Apply discontinuation adjustment to medication 2 AND 3 */

			/* If medication 2 or medication 3 has no use during NH time based on the updated discontinuation adjustment date, flag as no concurrent use */
			if med_use_sens_2 = 0 or med_use_sens_3 = 0 then do;
				flag_sens_no = 0;
				concurrent_sens_flag = 0;
			end;

			/* Otherwise, if medication 2 starts and ends within the medication 3 episode, flag for concurrent use */
			else if (min_index_nh_sens_3 <= min_index_nh_sens_2 <= max_enddt_nh_sens_3) and (min_index_nh_sens_3 <= max_enddt_nh_sens_2 <= max_enddt_nh_sens_3) then do;
				flag_sens_no = 3;
				concurrent_sens_flag = 1;
			end;

			/* Otherwise, if the medication 2 start date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_sens_3 <= min_index_nh_sens_2 <= max_enddt_nh_sens_3) then do;
				flag_sens_no = 4;
				concurrent_sens_flag = 1;
			end;

		end;

		/* Otherwise, if all medications started at the same time, enter into the conditional block */
		else if all_drugs_start_same_nh = 1 then do; /* Do not apply discontinuation adjustment to any drugs */
			
			flag_sens_no = flag_no;
			concurrent_sens_flag = concurrent_flag;

		end;

	run;

	/* Calculate the start date and end date of medication use overlap (for the first 2 drugs) when concurrent_sens_flag = 1 */
		/* We are applying the discontinuation adjustment here (for whichever drug(s) began first) */

	data &ddi._9;
		set &ddi._8;

		/* If medication 1 began first and there is concurrent use between medication 1 and 2, set start and end dates of overlap */
		if concurrent_sens_flag = 1 and med_1_first_nh = 1 then do;

			/* If medication 1 ends between medication 2 start and end date, use medication 2 start date and medication 1 end date for overlap */
			if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;

			/* If medication 1 starts before medication 2 and ends after medication 2, use medication 2 start and end dates for overlap */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_2;
				end_date_overlap_sens = max_enddt_nh_2;
			end;

		end;

		/* If medication 2 began first and there is concurrent use between medication 1 and 2, set start and end dates of overlap */
		else if concurrent_sens_flag = 1 and med_2_first_nh = 1 then do;

			/* If medication 2 ends between medication 1 start and end date, use medication 1 start date and medication 2 end date for overlap */
			if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

			/* If medication 2 starts before medication 1 and ends after medication 1, use medication 1 start and end dates for overlap */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;
		
		end;

		/* If medication 3 began first and there is concurrent use between medication 1 and 3, set start and end dates of overlap */
		else if concurrent_sens_flag = 1 and med_3_first_nh = 1 then do;

			/* If medication 3 ends between medication 1 start and end date, use medication 1 start date and medication 3 end date */
			if flag_sens_no = 5 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_sens_3;
			end;

			/* If medication 3 starts before medication 1 and ends after medication 1, use medication 1 start and end dates */
			else if flag_sens_no = 6 then do;
				start_date_overlap_sens = min_index_nh_1;
				end_date_overlap_sens = max_enddt_nh_1;
			end;

		end;

		/* If medication 1 and 2 began first and there is concurrent use, set start and end dates of overlap */
		else if concurrent_sens_flag = 1 and med12_same_b4_3 = 1 then do;

			/* If medication 1 ends before medication 2, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;	

			/* If medication 2 ends before medication 1, use medication 1 start date and medication 2 end date */
				/* Note that the medication 1 and 2 start dates are identical because med12_same_b4_3 = 1 */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;

		end;

		/* If medication 1 and 3 began first and there is concurrent use, set start and end dates of overlap */
		else if concurrent_sens_flag = 1 and med13_same_b4_2 = 1 then do;

			/* If medication 1 ends before medication 3, use medication 1 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_1;
			end;	

			/* If medication 3 ends before medication 1, use medication 1 start date and medication 3 end date */
				/* Note that the medication 1 and 3 start dates are identical because med13_same_b4_2 = 1 */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_sens_1;
				end_date_overlap_sens = max_enddt_nh_sens_3;
			end;

		end;

		/* If medication 2 and 3 began first and there is concurrent use, set start and end dates of overlap */
		else if concurrent_sens_flag = 1 and med23_same_b4_1 = 1 then do;

			/* If medication 2 ends before medication 3, use medication 2 start and end date */
			if flag_sens_no = 3 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_sens_2;
			end;	

			/* If medication 3 ends before medication 2, use medication 2 start date and medication 3 end date */
				/* Note that the medication 2 and 3 start dates are identical because med23_same_b4_1 = 1 */
			else if flag_sens_no = 4 then do;
				start_date_overlap_sens = min_index_nh_sens_2;
				end_date_overlap_sens = max_enddt_nh_sens_3;
			end;

		end;

		/* If all drugs started at the same time and there is concurrent use, don't apply a discontinuation adjustment. Start_date_overlap_sens
	       and end_date_overlap_sens are the same as start_date_overlap and end_date_overlap */
		else if concurrent_sens_flag = 1 and all_drugs_start_same_nh = 1 = 1 then do;

			start_date_overlap_sens = start_date_overlap;
			end_date_overlap_sens = end_date_overlap;

		end;

		format start_date_overlap_sens end_date_overlap_sens date9.;

		label
			start_date_overlap_sens = "Start date of overlap between first two drugs when applying discontinuation adjustment"
			end_date_overlap_sens = "End date of overlap between first two drugs when applying discontinuation adjustment"
		;	

	run;

	/* Flag concurrent use between the 3 medications in each row of the merged data set (when applying discontinuation adjustment */

	data &ddi._10;
		set &ddi._9;

		/* If medication 1 began first, enter into the conditional block */
		if med_1_first_nh = 1 then do;

			/* If no concurrent use between medication 1 and 2 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 1 and 2 overlap ends before start of medication 3, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_3 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap begins after the end of medication 3, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_3 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts and ends within the medication 3 episode, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) and (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap start date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap end date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts on or before the start of medication 3 and ends on or after the end of medication 3, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_3) and (end_date_overlap_sens >= max_enddt_nh_3) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if medication 2 began first, enter into the conditional block */
		else if med_2_first_nh = 1 then do;

			/* If no concurrent use between medication 1 and 2 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 1 and 2 overlap ends before start of medication 3, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_3 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap begins after the end of medication 3, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_3 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts and ends within the medication 3 episode, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) and (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap start date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap end date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts on or before the start of medication 3 and ends on or after the end of medication 3, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_3) and (end_date_overlap_sens >= max_enddt_nh_3) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if medication 3 began first, enter into the conditional block */
		else if med_3_first_nh = 1 then do;

			/* If no concurrent use between medication 1 and 3 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 1 and 3 overlap ends before start of medication 2, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_2 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 3 overlap begins after the end of medication 2, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_2 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 3 overlap starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_2 <= start_date_overlap_sens <= max_enddt_nh_2) and (min_index_nh_2 <= end_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= start_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= end_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_2) and (end_date_overlap_sens >= max_enddt_nh_2) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if medication 1 and 2 began first, enter into the conditional block */
		else if med12_same_b4_3 = 1 then do;

			/* If no concurrent use between medication 1 and 2 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 1 and 2 overlap ends before start of medication 3, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_3 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap begins after the end of medication 3, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_3 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts and ends within the medication 3 episode, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) and (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap start date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= start_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap end date is between medication 3 start and end date, flag for concurrent use */
			else if (min_index_nh_3 <= end_date_overlap_sens <= max_enddt_nh_3) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 2 overlap starts on or before the start of medication 3 and ends on or after the end of medication 3, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_3) and (end_date_overlap_sens >= max_enddt_nh_3) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if medication 1 and 3 began first, enter into the conditional block */
		else if med13_same_b4_2 = 1 then do;

			/* If no concurrent use between medication 1 and 3 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 1 and 3 overlap ends before start of medication 2, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_2 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 3 overlap begins after the end of medication 2, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_2 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 1 and 3 overlap starts and ends within the medication 2 episode, flag for concurrent use */
			else if (min_index_nh_2 <= start_date_overlap_sens <= max_enddt_nh_2) and (min_index_nh_2 <= end_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap start date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= start_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap end date is between medication 2 start and end date, flag for concurrent use */
			else if (min_index_nh_2 <= end_date_overlap_sens <= max_enddt_nh_2) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 1 and 3 overlap starts on or before the start of medication 2 and ends on or after the end of medication 2, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_2) and (end_date_overlap_sens >= max_enddt_nh_2) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if medication 2 and 3 began first, enter into the conditional block */
		else if med23_same_b4_1 = 1 then do;

			/* If no concurrent use between medication 2 and 3 after discontinuation adjustment, flag as no concurrent use */
			if concurrent_sens_flag = 0 then do;
				flag_sens_no_2 = 0;
				concurrent_sens_flag_2 = 0;
			end;

			/* If medication 2 and 3 overlap ends before start of medication 1, flag as no concurrent use */
			else if end_date_overlap_sens < min_index_nh_1 then do;
				flag_sens_no_2 = 1;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 2 and 3 overlap begins after the end of medication 1, flag as no concurrent use */
			else if start_date_overlap_sens > max_enddt_nh_1 then do;
				flag_sens_no_2 = 2;
				concurrent_sens_flag_2 = 0;
			end;

			/* Otherwise, if medication 2 and 3 overlap starts and ends within the medication 1 episode, flag for concurrent use */
			else if (min_index_nh_1 <= start_date_overlap_sens <= max_enddt_nh_1) and (min_index_nh_1 <= end_date_overlap_sens <= max_enddt_nh_1) then do;
				flag_sens_no_2 = 3;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 2 and 3 overlap start date is between medication 1 start and end date, flag for concurrent use */
			else if (min_index_nh_1 <= start_date_overlap_sens <= max_enddt_nh_1) then do;
				flag_sens_no_2 = 4;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 2 and 3 overlap end date is between medication 1 start and end date, flag for concurrent use */
			else if (min_index_nh_1 <= end_date_overlap_sens <= max_enddt_nh_1) then do;
				flag_sens_no_2 = 5;
				concurrent_sens_flag_2 = 1;
			end;

			/* Otherwise, if medication 2 and 3 overlap starts on or before the start of medication 1 and ends on or after the end of medication 1, flag for concurrent use */
			else if (start_date_overlap_sens <= min_index_nh_1) and (end_date_overlap_sens >= max_enddt_nh_1) then do;
				flag_sens_no_2 = 6;
				concurrent_sens_flag_2 = 1;
			end;

		end;

		/* Otherwise, if all medications started on the same day, enter into the conditional block */
		else if all_drugs_start_same_nh = 1 then do;

			flag_sens_no_2 = flag_no_2;
			concurrent_sens_flag_2 = concurrent_flag_2;

		end;

			label
				flag_sens_no = "Flags for relation med 1,2 overlap and med 3 episode, with discontinuation adjustment"
				concurrent_flag_2 = "1 = some overlap between medication use episodes, 0 = no overlap, with discontinuation adjustment"
			;

	run;

	/* Calculate overlap between all three drugs, after applying discontinuation adjustment */

	data &ddi._11;
		set &ddi._10;

		/* If medication 1 began first, medication 2 began first, or medication 1 and 2 began first, enter the conditional block */
		if med_1_first_nh = 1 or med_2_first_nh = 1 or med12_same_b4_3 = 1 then do;

			/* If medication 1 and 2 overlap starts and ends within the medication 3 episode, use the medication 1 and 2 overlap start and end dates */
			if flag_sens_no_2 = 3 then do;
				start_date_overlap_sens_2 = start_date_overlap_sens;
				end_date_overlap_sens_2 = end_date_overlap_sens;
			end;

			/* If medication 1 and 2 overlap starts within medication 3's episode, use the medication 1 and 2 overlap start date and medication 3 end date */
			else if flag_sens_no_2 = 4 then do;
				start_date_overlap_sens_2 = start_date_overlap_sens;
				end_date_overlap_sens_2 = max_enddt_nh_3;
			end;

			/* If medication 1 and 2 overlap ends within medication 3's episode, use medication 3's start date and the medication 1 and 2 overlap start date */
			else if flag_sens_no_2 = 5 then do;
				start_date_overlap_sens_2 = min_index_nh_3;
				end_date_overlap_sens_2 = end_date_overlap_sens;
			end;

			/* If medication 3 starts and ends within medication 1 and 2 overlap, use medication 3's start and end date */
			else if flag_sens_no_2 = 6 then do;
				start_date_overlap_sens_2 = min_index_nh_3;
				end_date_overlap_sens_2 = max_enddt_nh_3;
			end;

		end;

		/* If medication 3 began first, or medication 1 and 3 began first, enter the conditional block */
		else if med_3_first_nh = 1 or med13_same_b4_2 = 1 then do;

			/* If medication 1 and 3 overlap starts and ends within the medication 2 episode, use the medication 1 and 3 overlap start and end dates */
			if flag_sens_no_2 = 3 then do;
				start_date_overlap_sens_2 = start_date_overlap_sens;
				end_date_overlap_sens_2 = end_date_overlap_sens;
			end;

			/* If medication 1 and 3 overlap starts within medication 2's episode, use the medication 1 and 3 overlap start date and medication 2 end date */
			else if flag_sens_no_2 = 4 then do;
				start_date_overlap_sens_2 = start_date_overlap_sens;
				end_date_overlap_sens_2 = max_enddt_nh_2;
			end;

			/* If medication 1 and 3 overlap ends within medication 2's episode, use medication 2's start date and medication 1 and 3 overlap end date */
			else if flag_sens_no_2 = 5 then do;
				start_date_overlap_sens_2 = min_index_nh_2;
				end_date_overlap_sens_2 = end_date_overlap_sens;
			end;

			/* If medication 2 starts and ends within medication 1 and 3 overlap, use medication 2's start and end date */
			else if flag_sens_no_2 = 6 then do;
				start_date_overlap_sens_2 = min_index_nh_2;
				end_date_overlap_sens_2 = max_enddt_nh_2;
			end;

		end;

		/* If medication 2 and 3 began first, enter the conditional block */
		else if med23_same_b4_1 = 1 then do;

			/* If medication 2 and 3 overlap ends within medication 1's episode, use medication 1 start date and medication 2 and 3 overlap end date */
			if flag_sens_no_2 = 5 then do;
				start_date_overlap_sens_2 = min_index_nh_1;
				end_date_overlap_sens_2 = end_date_overlap_sens;
			end;

			/* If medication 1 starts and ends within medication 2 and 3 overlap, use medication 1's start and end date */
			else if flag_sens_no_2 = 6 then do;
				start_date_overlap_sens_2 = min_index_nh_1;
				end_date_overlap_sens_2 = max_enddt_nh_1;
			end;

		end;

		/* If all drugs began at the same time, start and end dates of overlap are the same as in the primary analysis */
		else if all_drugs_start_same_nh = 1 then do;

			start_date_overlap_sens_2 = start_date_overlap_2;
			end_date_overlap_sens_2 = end_date_overlap_2;

		end;

		format start_date_overlap_sens_2 end_date_overlap_sens_2 date9.;

		label
			start_date_overlap_sens_2 = "Start date of overlap between the 3 medication episodes, after applying discontinuation adjustment"
			end_date_overlap_sens_2 = "End date of overlap between the 3 medication episodes, after applying the discontinuation adjustment"
		;

	run;

	/*** Calculate the number of days of medication use overlap ***/

	data &ddi._12;
		set &ddi._11;

		days_overlap_2 = end_date_overlap_2 + 1 - start_date_overlap_2;

		if concurrent_sens_flag_2 = 1 then do;
			days_overlap_sens_2 = end_date_overlap_sens_2 + 1 - start_date_overlap_sens_2;
		end;

		label
			days_overlap_2 = "Days of medication use overlap"
			days_overlap_sens_2 = "Days of medication use overlap in stability analysis"
		;

	run;

	/* Checking generation of days_overlap and days_overlap_sens variables */

	title1 "&ddi._12, after computing number of days of medication use overlap";
	proc freq data = &ddi._12;
		tables concurrent_sens_flag_2*days_overlap_2*days_overlap_sens_2 / list missing;
		format days_overlap_2 days_overlap_sens_2 missing_fmt.;
	run;

	proc means data = &ddi._12 n nmiss mean std median q1 q3 min max;
		var days_overlap_2 days_overlap_sens_2;
	run;
	title;

	/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

	proc sort data = &ddi._12;
		by bene_id_18900 core_drug_1 core_drug_2 core_drug_3 start_date_overlap_2 end_date_overlap_2;
	run;

	data merged.&ddi._cncr_sens;
		set &ddi._12;
		by bene_id_18900 core_drug_1 core_drug_2 core_drug_3 start_date_overlap_2 end_date_overlap_2;

		if first.bene_id_18900 then episode_cncr = 1;
		else episode_cncr + 1;

		label
			episode_cncr = 'Episode of concurrent use'
		;

	run; 

	/*** Create dataset that only contains records for which concurrent_sens_flag_2 = 1 ***/

	data merged.&ddi._cncr_sens_only;
	set merged.&ddi._cncr_sens;

		if concurrent_sens_flag_2 = 1;

	run;

	title1 "How many benes are in merged.&ddi._cncr_sens?";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens;
	quit;

	title1 "How many benes are in merged.&ddi._cncr_sens_only? (restricted to concurrent_sens_flag_2 = 1)";
	proc sql;
		select count(distinct bene_id_18900)
		from merged.&ddi._cncr_sens_only;
	quit;

	title1 "Number of records where start_date_overlap_sens_2 = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where start_date_overlap_sens_2 = .;
	quit;

	title1 "Number of records where end_date_overlap_sens_2 = . in merged.&ddi._cncr_sens_only";
	proc sql;
		select count(*)
		from merged.&ddi._cncr_sens_only
		where end_date_overlap_sens_2 = .;
	quit;

	/*** Check the drug combinations flagged for concurrent use ***/

	title "Drug combinations with concurrent use";
	proc freq data = merged.&ddi._cncr_sens_only;
		tables core_drug_1*core_drug_2*core_drug_3 / list missing out = freq_drug;
	run;

	/* End writing to RTF doc */

	ods rtf close;
	ods graphics off;
	ods results;

	/*** Delete datasets from the work library ***/

	proc datasets library = work nolist;
		delete &ddi_1._comb4 &ddi.x2 &ddi.x22 &ddi.x23 &ddi.x24 &ddi.x25 &ddi.x26 &ddi.x27 &ddi.x28 &ddi._: freq_drug;
	quit;

%mend;

/********************************************************************************************************/
/*** Run flag_concurrent_sens_3 macro for each DDI with 3 identical medication use episode data sets  ***/
/********************************************************************************************************/

data _null_;
	set ddi.ddi_list_3c;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent_sens_3(', component_1, ', ', component_2, ', ', component_3, ', ', ddi, ');'));
run;

/* END OF PROGRAM */
