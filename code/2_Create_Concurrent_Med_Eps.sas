/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug-Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create episodes of medication use overlap (i.e., concurrent use) for 
the drugs associated with each DDI.

Programmer: Laura Reich   
 
Date Last Modified: March 14, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets and files:
- nhtm2.&ddi_1._comb3: Medication episodes for a given DDI component, 
                       2018-2020, within NH stays.
     - Generated in 1_Create_Med_Eps.sas
- \DDI_List_To_SAS_v2.xlsx: Excel spreadsheet that contains:
                            - A row with the names of each DDI.
                            - Rows listing the components of each DDI.
                            - Rows specifying which macro should process the DDI.
- \DDIs_List_v5.xlsx: Excel spreadsheet where each sheet is a list of 
                      the generic drug names (and their respective drug class) 
                      to be included for a given DDI component.
*********************************************************************/

/*********************************************************************
Key generated datasets:
- ddi.full_ddi_list: SAS dataset equivalent of \DDI_List_To_SAS_v2.xlsx
- ddi.ddi_list_3a: List of DDIs to be run through the flag_concurrent macro.
- dlist.&ddi._cls: List of generic drugs (without specification of salt form) and 
                   their drug class for a given DDI component.
- ddi.ddi_list_3b3c: List of DDIs to be run through the import_class macro.
- ddi.ddi_list_3b: List of DDIs to be run through the flag_concurrent_2 macro.
- ddi.ddi_list_3c: List of DDis to be run through the flag_concurrent_3 macro.
- merged.&ddi._cncr: Dataset of overlapping medication use episodes
                     (i.e., concurrent use) for a given DDI.
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname drugs    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_files"; /* DDI component Part D dispensing datasets */
libname lrenroll "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\enrollment"; /* Relevant NH time dataset with exclusions applied */
libname nhtm2    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\med_ep\nh_time\v2"; /* Medication episodes during NH time datasets */
libname merged   "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files"; /* Merged medication episode datasets */
libname prev     "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\est_prev"; /* Datasets with all beneficiaries to estimate prevalence for each DDI */
libname ddi      "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\concurrent_use\ddi_lists"; /* Datasets with lists of ddis and their components drug categories */
libname smcncr   "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files\summary_info"; /* DDI prevalence summary info */
libname dlist    "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\drug_list";  /* Excel drug lists */

options mprint; 

/*************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 2 distinct medication use datasets  ***/
/*************************************************************************************************************************/

%macro flag_concurrent(component_1, component_2, ddi);

/*** Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' ***/

%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));

/*** Merge medication use episode datasets together for a given DDI ***/

	/* If the ddi is not ddi20 or ddi30, merge the two medication use episode datasets without any modifications */
	%if &ddi. ne ddi20 and &ddi. ne ddi30 %then %do;

		/* Merge medication use episode datasets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
		create table merged.&ddi. as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1,
		a.max_enddt_nh as max_enddt_nh_1, b.core_drug as core_drug_2,
		b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
		from nhtm2.&ddi_1._comb3 as a inner join nhtm2.&ddi_2._comb3 as b
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) &
		(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/* If the ddi IS ddi20, delete any medication use episodes for aspirin in the two datasets before merging */
		/* NOTE: We removed aspirin from the ddi20 (antiplatelet drug (aspirin) + NSAID) medication use datasets because it can be considered both an antiplatelet drug and an NSAID. 
				 Therefore, we simply removed it. */

	%else %if &ddi. = ddi20 %then %do;

		data &ddi_1._comb4;
		set nhtm2.&ddi_1._comb3;

		if core_drug = 'aspirin' then delete;

		run;

		data &ddi_2._comb4;
		set nhtm2.&ddi_2._comb3;

		if core_drug = 'aspirin' then delete;

		run;

		/* Merge medication use episode datasets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
		create table merged.&ddi. as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1,
		a.max_enddt_nh as max_enddt_nh_1, b.core_drug as core_drug_2,
		b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
		from &ddi_1._comb4 as a inner join &ddi_2._comb4 as b
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) &
		(a.core_drug ne b.core_drug));
		quit; 

	%end;

	/* If the ddi IS ddi30, delete any medication use episodes for diltiazem and verapamil from the CYP3A4-inhibitor dataset before merging */
		/* NOTE: We removed diltiazem and verapamil from the list of CYP3A4-inhibitors in ddi30 (calcium channel blocker + CYP3A4-inhibitor) 
	             because they are both considered calcium channel blockers. */

	%else %if &ddi. = ddi30 %then %do;

		data &ddi_2._comb4;
		set nhtm2.&ddi_2._comb3;

		if core_drug = 'diltiazem' or core_drug = 'verapamil' then delete;

		run;

		/* Merge medication use episode datasets by beneficiary ID and NH episode, making sure not to merge records with the same core_drug */
		proc sql;
		create table merged.&ddi. as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, 
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1,
		a.max_enddt_nh as max_enddt_nh_1, b.core_drug as core_drug_2,
		b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
		from nhtm2.&ddi_1._comb3 as a inner join &ddi_2._comb4 as b
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) &
		(a.core_drug ne b.core_drug));
		quit; 

	%end;

/*** Flag concurrent use in merged dataset ***/

	data &ddi._2;
	set merged.&ddi.;

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

	label
	flag_no = "Flags for relation btwn med 1 and 2 episodes"
	concurrent_flag = "1 = some overlap between medication use episodes, 0 = no overlap";

	run;

/*** Delete records where there is no concurrent use ***/

data &ddi._3;
set &ddi._2;

if concurrent_flag = 0 then delete;

run;

/*** Calculate the start date of medication use overlap and the end date of medication use overlap ***/

	data &ddi._4;
	set &ddi._3;

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
	end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes";

	run;

/*** Calculate the number of days of medication use overlap ***/

data &ddi._5;
set &ddi._4;
drop episode_new_1 episode_new_2;

days_overlap = end_date_overlap + 1 - start_date_overlap;

label
days_overlap = "Days of medication use overlap";

run;

/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

proc sort data = &ddi._5;
by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;
run;

data merged.&ddi._cncr;
set &ddi._5;
by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;

if first.bene_id_18900 then episode_cncr = 1;
else episode_cncr + 1;

label
episode_cncr = 'Episode of concurrent use';

run; 

/*** Delete datasets from the work library ***/

proc datasets library = work nolist;
	delete &ddi_1._comb4 &ddi_2._comb4 &ddi._2 &ddi._3 &ddi._4 &ddi._5;
quit;

%mend;

/*************************************************************************************************/
/***  Import Excel spreadsheet with full list of DDIs and their correspondings DDI components  ***/
/*************************************************************************************************/

/*** Import the excel file ***/

    proc import out=ddi.full_ddi_list (keep = ddi_paper ddi component_1 component_2 component_3 include_3a include_3b include_3c include_3d)
		datafile='P:\nhddi\lareich\Descriptive_DDI\Workflow_and_Protocols\3_concurrent_use\DDI_List_To_SAS_v2.xlsx'
        dbms=xlsx
        replace;  /* Replace existing dataset if it exists */
        sheet="Sheet1";
		getnames = yes;
    run;
	
/*** Only keep records to be run through the flag_concurrent macro (i.e., only DDIs that require merging 2 distinct medication use episode datasets) ***/

	data ddi.ddi_list_3a;
		set ddi.full_ddi_list;
		drop component_3;

		ddi = lowcase(strip(ddi));
		component_1 = lowcase(strip(component_1)); 
		component_2 = lowcase(strip(component_2));
		if include_3a = 0 then delete;
	run;

/**********************************************************************************/
/*** Run the flag_concurrent macro for the DDIs in the ddi.ddi_list_3a dataset  ***/
/**********************************************************************************/

data _null_;
	set ddi.ddi_list_3a;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent(', component_1, ', ', component_2, ', ', ddi, ');'));
run;

/***************************************************************************/
/*** Import Excel drug list in order to save class names to the datasets ***/
/***************************************************************************/

/*** Define a macro that will take a sheet from the Excel file and save it to a SAS dataset ***/

%macro import_class(component_1);

	/* Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' */

	%let ddi = %sysfunc(tranwrd(&component_1., -, xx));

	/* Import the Excel file, keeping the core_drug and class columns */
    proc import out=dlist.&ddi._cls (keep = core_drug class)
		datafile='P:\nhddi\lareich\Descriptive_DDI\Workflow_and_Protocols\1_identifying_DDIs\DDIs_List_v5.xlsx'
        dbms=xlsx
        replace;  /* Replace existing dataset if it exists */
        sheet="&component_1.";
		getnames = yes;
    run;
	
	/* Format variables to lowercase and delete any leading or trailing spaces */
	data dlist.&ddi._cls;
		length core_drug $255 class $255; 
		set dlist.&ddi._cls;

		core_drug = lowcase(strip(core_drug)); /* lowcase() makes all characters lowercase, and strip() removes leadings and trailing spaces */

		class = lowcase(strip(class));

		if core_drug="" then delete; /* Sometimes there are errors when reading in Excel files, so delete any drugs that are empty strings */
	run;

	/* Remove duplicate records with the same core_drug value */
	proc sort data = dlist.&ddi._cls nodupkey;
	by core_drug;
	run;

 %mend import_class;

/**************************************************************************************************************/
/*** Run the import_class macro for the DDIs that require merging 2 or 3 identical medication use datasets  ***/
/*** NOTE: We DO NOT want to identify concurrent use for drugs of the same class, so we need to bring in    ***/
/*** the class variable for these cases                                                                     ***/
/**************************************************************************************************************/

data ddi.ddi_list_3b3c;
		set ddi.full_ddi_list;

		ddi = lowcase(strip(ddi));
		component_1 = lowcase(strip(component_1)); 
		component_2 = lowcase(strip(component_2));
		component_3 = lowcase(strip(component_3));
		if include_3b = 0 and include_3c = 0 then delete;
	run;

data _null_;
	set ddi.ddi_list_3b3c;

	/* Generate macro call for each record */

	call execute(cats('%import_class(', component_1, ');'));

run;

/**************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 2 identical medication use datasets  ***/
/**************************************************************************************************************************/

%macro flag_concurrent_2(component_1, component_2, ddi);

/*** Replace any '-' in the DDI sheet names to 'xx', since SAS dataset names cannot include '-' ***/

%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));

/*** Merge medication use episode datasets together ***/

	/* If the ddi is not ddi57 or ddi90, add the class variable to each record in the medication use episode dataset before merging */

	%if &ddi. ne ddi57 and &ddi. ne ddi90 %then %do;

		/* Add the class variable to each medication episode record */
		proc sql;
		create table &ddi_1._comb4 as
		select a.*, b.class
		from nhtm2.&ddi_1._comb3 as a inner join dlist.&ddi_1._cls as b
		on (a.core_drug = b.core_drug);
		quit;

		/* Merge the two medication use episode datasets together by beneficiary ID and NH episode, making sure not to merge medication episodes for drugs of the same class */
		proc sql;
		create table merged.&ddi. as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, a.class as class_1,
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, 
		b.core_drug as core_drug_2, b.class as class_2, b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
		from &ddi_1._comb4 as a inner join &ddi_2._comb4 as b 
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) &
		(a.class ne b.class));
		quit; 

	%end;

	/* If the ddi is ddi57 or ddi90, don't add the class variable to the medication use episode datasets. Merge the two medication use episode datasets, making sure not to merge
	medication episodes for the same core drug */
		/* NOTE: ddi57 and ddi90 are both concomitant use of at least 2 anticholinergic drugs. We decided to identify concurrent use between any of our listed anticholinergic drugs, regardless of class. */

	%else %if &ddi. = ddi57 or &ddi. = ddi90 %then %do;

		/* Merge the two medication use episodes by beneficiary ID and NH episode, making sure not to merge together records with the same drug */
		proc sql;
		create table merged.&ddi. as
		select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1,
		a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1, a.max_enddt_nh as max_enddt_nh_1, 
		b.core_drug as core_drug_2, b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
		from nhtm2.&ddi_1._comb3 as a inner join nhtm2.&ddi_2._comb3 as b 
		on ((a.bene_id_18900 = b.bene_id_18900) &
		(a.eNH_ep_start = b.eNH_ep_start) &
		(a.core_drug ne b.core_drug));
		quit; 

	%end;

/*** Remove reverse duplicates from the merged dataset ***/
	/* NOTE: By reverse duplicates we mean that,
	         when merging 2 identical medication use episode datasets together, 
	         we will get 2 records for a given combination of medication episodes. */

	/* Create a variable, drug_12, with the 2 medication episode numbers listed in numerical order */

	data &ddi._2;
	set merged.&ddi.;

	if episode_new_1 <= episode_new_2 then
		drug_12 = catx(' ', episode_new_1 , episode_new_2);
	else 
		drug_12 = catx(' ', episode_new_2, episode_new_1);

	label
	drug_12 = "Identifier for reverse duplicates";

	run;

	/* Only keep the first instance of this drug_12 variable (for each beneficiary) in order to remove reverse duplicates */

	proc sort data = &ddi._2;
	by bene_id_18900 drug_12;
	run;

	data &ddi._3;
	set &ddi._2;
	by bene_id_18900 drug_12;

	if first.drug_12;

	run; /* This should reduce the dataset by exactly half the number of records */

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

	label
	flag_no = "Flags for relation btwn med 1 and 2 episodes"
	concurrent_flag = "1 = some overlap between medication use episodes, 0 = no overlap";

	run;

/*** Delete records where there is no concurrent use ***/

data &ddi._5;
set &ddi._4;

if concurrent_flag = 0 then delete;

run;

/*** Calculate the start date of medication use overlap and the end date of medication use overlap ***/

	data &ddi._6;
	set &ddi._5;

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
	end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes";

	run;

/*** Calculate the number of days of medication use overlap ***/

data &ddi._7;
set &ddi._6;

days_overlap = end_date_overlap + 1 - start_date_overlap;

label
days_overlap = "Days of medication use overlap";

run;

/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

proc sort data = &ddi._7;
by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;
run;

data merged.&ddi._cncr;
set &ddi._7;
by bene_id_18900 core_drug_1 core_drug_2 start_date_overlap end_date_overlap;

if first.bene_id_18900 then episode_cncr = 1;
else episode_cncr + 1;

label
episode_cncr = 'Episode of concurrent use';

run; 

/*** Delete datasets from the work library ***/

proc datasets library = work nolist;
	delete &ddi_1._comb4 &ddi._2 &ddi._3 &ddi._4 &ddi._5 &ddi._6 &ddi._7;
quit;

%mend;

/*******************************************************************************************************/
/*** Run the flag_concurrent_2 macro for each DDI with 2 identical medication use episode datasets  ***/
/*******************************************************************************************************/

/*** Create dataset with the list of DDIs and their corresponding DDI components to be run through
the flag_concurrent_2 macro ***/

data ddi.ddi_list_3b;
	set ddi.full_ddi_list;

	ddi = lowcase(strip(ddi));
	component_1 = lowcase(strip(component_1)); 
	component_2 = lowcase(strip(component_2));
	component_3 = lowcase(strip(component_3));
	if include_3b = 0 then delete;
run;

/*** Run the macro for each relevant DDI ***/

data _null_;
	set ddi.ddi_list_3b;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent_2(', component_1, ', ', component_2, ', ', ddi, ');'));
run;

/*************************************************************************************************************************/
/*** Macro to create concurrent medication use episodes for DDIs in which we merge 3 identical medication use datasets ***/
/*************************************************************************************************************************/

%macro flag_concurrent_3(component_1, component_2, component_3, ddi);

/*** Replace any '-' in the DDI sheet names to 'xx', since SAS dataset names cannot include '-' ***/

%let ddi_1 = %sysfunc(tranwrd(&component_1., -, xx));
%let ddi_2 = %sysfunc(tranwrd(&component_2., -, xx));
%let ddi_3 = %sysfunc(tranwrd(&component_3., -, xx));

/*** Add the class variable to each medication use record in the medication use episode dataset ***/

proc sql;
create table &ddi_1._comb4 as
select a.*, b.class
from nhtm2.&ddi_1._comb3 as a inner join dlist.&ddi_1._cls as b
on (a.core_drug = b.core_drug);
quit;

/*** Merge the first 2 medication use episode datasets together ***/

	/* Merge 2 medication use episode datasets together by beneficiary ID and NH stay, making sure not to merge medication episodes for drugs of the same class */
	proc sql;
	create table &ddi.x2 as
	select a.bene_id_18900, a.eNH_ep_start, a.eNH_ep_end, a.core_drug as core_drug_1, a.class as class_1,
	a.episode_new as episode_new_1, a.min_index_nh as min_index_nh_1,
	a.max_enddt_nh as max_enddt_nh_1, b.core_drug as core_drug_2, b.class as class_2,
	b.episode_new as episode_new_2, b.min_index_nh as min_index_nh_2, b.max_enddt_nh as max_enddt_nh_2
	from &ddi_1._comb4 as a inner join &ddi_2._comb4 as b 
	on ((a.bene_id_18900 = b.bene_id_18900) &
	(a.eNH_ep_start = b.eNH_ep_start) & 
	(a.class ne b.class));
	quit; 

/*** Remove reverse duplicates from the merged dataset ***/

	/* Create a variable, drug_12, with the 2 medication episode numbers listed in numerical order */

	data &ddi.x22;
	set &ddi.x2;

	if episode_new_1 <= episode_new_2 then
		drug_12 = catx(' ', episode_new_1 , episode_new_2);
	else 
		drug_12 = catx(' ', episode_new_2, episode_new_1);

	label
	drug_12 = "Identifier for reverse duplicates";

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

/*** Flag concurrent medication use in merged dataset ***/

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
	concurrent_flag = "1 = some overlap between med 1 and 2 episodes, 0 = no overlap";

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
	end_date_overlap = "End date of overlap between medication 1 and medication 2 episodes";

	run;

/*** Calculate the number of days of medication use overlap ***/

data &ddi.x27;
set &ddi.x26;

days_overlap = end_date_overlap + 1 - start_date_overlap;

label
days_overlap = "Days of medication use overlap btwn 2 med eps";

run; 

/*** Merge the third medication use episode dataset with the medication 1 and 2 overlap dataset (&ddi.x27) ***/

	/* Merge datasets by beneficiary ID and NH stay, making sure that there are no matching classes between the 3 drugs in a given record */
	proc sql;
	create table merged.&ddi. as
	select ab.*, c.core_drug as core_drug_3, c.class as class_3, c.episode_new as episode_new_3, c.min_index_nh as min_index_nh_3,
	c.max_enddt_nh as max_enddt_nh_3
	from &ddi.x27 as ab inner join &ddi_3._comb4 as c
	on ((ab.bene_id_18900 = c.bene_id_18900) &
	(ab.eNH_ep_start = c.eNH_ep_start) & 
	(ab.class_1 ne c.class) &
	(ab.class_2 ne c.class));
	quit; 

/*** Remove reverse duplicates ***/

	/* Create a variable, drug_123, with the 3 medication episode numbers listed in numerical order */

		data &ddi._2;
		set merged.&ddi.;

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

		label
		drug_123 = "Identifier for 3-way reverse duplicates";

		run;

	/* Only keep the first instance of this drug_123 variable for each beneficiary in order to remove reverse duplicates */

	proc sort data = &ddi._2;
	by bene_id_18900 drug_123;
	run;

	data &ddi._3;
	set &ddi._2;
	by bene_id_18900 drug_123;

	if first.drug_123;

	run; /* Note that this will not cut our records to 1/3 of the original size, 
	        since we already removed some "reverse duplicates" after merging two medication episode datasets together */

/*** Flag concurrent use between the 3 medications in each row of the merged dataset ***/ 

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
	flag_no_2 = "Flags for relation med 1,2 overlap and med 3 episode"
	concurrent_flag_2 = "1 = some overlap between medication use episodes, 0 = no overlap";

	run;

/*** Delete records where there is no concurrent medication use between the 3 drugs ***/

data &ddi._5;
set &ddi._4;

if concurrent_flag_2 = 0 then delete;

run; 

/*** Calculate the start date and end date of medication use overlap between the 3 drugs ***/

	data &ddi._6;
	set &ddi._5;

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

/*** Calculate days of overlap between the 3 medications ***/

data &ddi._7;
set &ddi._6;

days_overlap_2 = end_date_overlap_2 + 1 - start_date_overlap_2;

label
days_overlap_2 = "Days of medication use overlap between the 3 meds";

run;

/*** Make a new variable to count each episode of medication use overlap, by beneficiary ***/

proc sort data = &ddi._7;
by bene_id_18900 core_drug_1 core_drug_2 core_drug_3 start_date_overlap_2 end_date_overlap_2;
run;

data merged.&ddi._cncr;
set &ddi._7;
by bene_id_18900 core_drug_1 core_drug_2 core_drug_3 start_date_overlap_2 end_date_overlap_2;

if first.bene_id_18900 then episode_cncr = 1;
else episode_cncr + 1;

label
episode_cncr = 'Episode of concurrent use between 3 medications';

run; 

/*** Delete datasets from the work library ***/

proc datasets library = work nolist;
	delete &ddi_1._comb4 &ddi.x2 &ddi.x22 &ddi.x23 &ddi.x24 &ddi.x25 &ddi.x26 &ddi.x27 &ddi._2 &ddi._3 &ddi._4 &ddi._5 &ddi._6 &ddi._7;
quit;

%mend;

/**************************************************************************************************/
/*** Run flag_concurrent_3 macro for each DDI with 3 identical medication use episode datasets  ***/
/**************************************************************************************************/

/*** Create dataset with the list of DDIs and their corresponding DDI components to be run through
the flag_concurrent_3 macro ***/

data ddi.ddi_list_3c;
	set ddi.full_ddi_list;

	ddi = lowcase(strip(ddi));
	component_1 = lowcase(strip(component_1)); 
	component_2 = lowcase(strip(component_2));
	component_3 = lowcase(strip(component_3));
	if include_3c = 0 then delete;
run;

/*** Run the macro for each DDI in ddi.ddi_list_3c ***/

data _null_;
	set ddi.ddi_list_3c;

	/* Generate macro call for each record */

	call execute(cats('%flag_concurrent_3(', component_1, ', ', component_2, ', ', component_3, ', ', ddi, ');'));
run;

/* END OF PROGRAM */
