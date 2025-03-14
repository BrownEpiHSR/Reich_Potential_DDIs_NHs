/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create output for the following tables:
eTable 4: Top 50 Individual Drug Combinations Under “Concomitant Use of >=3 CNS-Active Drugs” (Anrys et al).			
eTable 5: Top 50 Individual Drug Combinations Under “Any Combination of >=3 CNS-Active Drugs” (2023 Beers Criteria).			

Programmer: Laura Reich   
 
Date Last Modified: March 14, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- merged.&ddi._cncr: Episodes of concurrent use for the drugs involved in a given DDI
(i.e., each record has separate variables for the concurrently used drugs, along with
the start date of overlapping use, end date of overlapping use, and duration of overlapping use)
     - Generated in 2_Create_Concurrent_Med_Eps.sas
*********************************************************************/

/*********************************************************************
Key generated datasets:
- smcncr.&ddi._drugcomb2: Unique drug combination dataset for a given DDI
  (i.e., each record is a combination of drugs used concurrently by at least one beneficiary, 
  along with the number of beneficiaries who used the drugs concurrently and the total days
  of concurrent medication use across beneficiaries in the cohort)
- smcncr.ddi36_drugcomb_50: Output for eTable 4
- smcncr.ddi91_drugcomb_50: Output for eTable 5
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

/********************************************************************************************************************************************/
/*** Create concurrent medication use datasets where each record is a unique combination of the drugs used concurrently by at least one   ***/
/*** beneficiary during their NH time                                                                                                     ***/
/********************************************************************************************************************************************/

%macro group_drugs(ddi);

/*** For each record in the concurrent medication use dataset, create a variable, drugs_list, with a list of the 3 drugs being used concurrently in alphabetical order.
     Create a separate variable, classes_list, to list the class of each of these drugs in the order the drugs are listed in the drugs_list variable ***/
		/* NOTE: This code will only work for ddi36 and ddi91 (i.e., concurrent use of at least 3 CNS-active drugs), since the other DDIs involved concurrent use of only 2 medications */

	data merged.&ddi._cncr2;
	set merged.&ddi._cncr;

	if core_drug_1 < core_drug_2 < core_drug_3 then do;
		drugs_list = catx('/', core_drug_1, core_drug_2, core_drug_3);
		classes_list = catx('/', class_1, class_2, class_3);
	end;

	else if core_drug_1 < core_drug_3 < core_drug_2 then do;
		drugs_list = catx('/', core_drug_1, core_drug_3, core_drug_2);
		classes_list = catx('/', class_1, class_3, class_2);
	end;

	else if core_drug_2 < core_drug_1 < core_drug_3 then do;
		drugs_list = catx('/', core_drug_2, core_drug_1, core_drug_3);
		classes_list = catx('/', class_2, class_1, class_3);
	end;

	else if core_drug_2 < core_drug_3 < core_drug_1 then do;
		drugs_list = catx('/', core_drug_2, core_drug_3, core_drug_1);
		classes_list = catx('/', class_2, class_3, class_1);
	end;

	else if core_drug_3 < core_drug_1 < core_drug_2 then do;
		drugs_list = catx('/', core_drug_3, core_drug_1, core_drug_2);
		classes_list = catx('/', class_3, class_1, class_2);
	end;

	else if core_drug_3 < core_drug_2 < core_drug_1 then do;
		drugs_list = catx('/', core_drug_3, core_drug_2, core_drug_1);
		classes_list = catx('/', class_3, class_2, class_1);
	end;
	
	label
	drugs_list = 'Combination of drugs being used concurrently in alphabetical order'
	classes_list = 'Class of each drug, ordered according to drug_list';

	run;

	/* Collapse the concurrent medication use dataset so that each row is a unique combination of drugs */

proc sql;
	create table &ddi._drugcomb as
	select drugs_list, classes_list,
	count(distinct bene_id_18900) as unique_benes, sum(days_overlap_2) as total_days_use
	from merged.&ddi._cncr2
	group by drugs_list, classes_list;
quit; 

/*** Add labels to the collapsed unique drug combination dataset ***/

data smcncr.&ddi._drugcomb2;
set &ddi._drugcomb;

label
unique_benes = 'Number of beneficiaries with concurrent use of the particular combination of drugs'
total_days_use = 'Number of days beneficiaries used the particular combination of drugs concurrently';

run;

/*** Delete datasets in work library ***/

proc datasets library = work nolist;
	delete &ddi.: ;
quit;

%mend;

/**********************************************************/
/*** Run the group_drugs macro for the DDIs of interest ***/
/**********************************************************/

%group_drugs(ddi36); /* Anrys >= 3 CNS-active drugs */
%group_drugs(ddi91); /* Beers >= 3 CNS-active drugs */

/****************************************************************************************************************************/
/*** Calculate the prevalence and median duration of concurrent medication use for these unique drug combination datasets ***/
/****************************************************************************************************************************/

%macro calc_group_drugs(ddi);

/*** Calculate the number of beneficiaries who were exposed to the DDI and store the value in a macro variable ***/

title1 "Number of beneficiaries exposed to &ddi.";
proc sql;
select count(distinct bene_id_18900)
into :total_bene_ddi
from merged.&ddi._cncr;
quit; 

	/* Check the value of the macro variable in the log */

	%put Total beneficiaries with &ddi.: &total_bene_ddi.;

/*** Calculate the total person-years of follow-up among beneficiaries exposed to the DDI ***/

title1 "Person-years of follow-up among beneficiaries exposed to &ddi.";
proc sql;
select (sum(eNH_ep_length)/365.25) as prsn_yrs_total
from lrenroll.observ_windows5_excl_set1
where bene_id_18900 in (select bene_id_18900 from merged.&ddi._cncr);
quit;

/*** Use the &total_bene_ddi. macro variable to calculate the prevalence of each unique drug combination ***/

data &ddi._drugcomb4_2;
set smcncr.&ddi._drugcomb2;

	/* Prevalence */
	Perc = ((unique_benes / &total_bene_ddi.) * 100);

	label
	Perc = "(Number of beneficiaries with concurrent use of the drug combo / Number of beneficiaries who met the criteria for &ddi.) * 100";

run;

/*** Sort the dataset by the number of beneficiaries who used the drug combination concurrently ***/

proc sort data = &ddi._drugcomb4_2;
	by descending unique_benes;
run;

/*** Save the 50 most prevalent unique drug combinations to a new dataset ***/

data smcncr.&ddi._drugcomb5_2;
	set &ddi._drugcomb4_2 (obs = 50);
run;

/*** Calculate the median days of concurrent medication use for the top 50 drug combinations ***/

	/* Generate dataset that groups the 50 most common drugs_list values by beneficiary */

	proc sql;
		create table smcncr.&ddi._drugcomb6_2 as
		select bene_id_18900, drugs_list, sum(days_overlap_2) as days_use
		from merged.&ddi._cncr2
		where drugs_list in (select drugs_list from smcncr.&ddi._drugcomb5_2) 
		group by bene_id_18900, drugs_list;
	quit; 

	/* Calculate the median days of concurrent use for each of the 50 most common drug combinations, among those who had concurrent use */

	proc means data = smcncr.&ddi._drugcomb6_2 n nmiss median q1 q3 noprint;
		class drugs_list;
		var days_use;
		output out=&ddi._sumstat 
			n = n
			nmiss = nmiss
            median = median
            q1 = q1
            q3 = q3;
	run; 
	
	/* Delete records from &ddi._sumstat where drugs_list is missing */

	data &ddi._sumstat2;
	set &ddi._sumstat;

		if drugs_list = "" then delete;

	run; 

/*** Merge datasets to bring prevalence and median days of concurrent use together ***/

	/* Sort the datasets by drugs_list */

	proc sort data = smcncr.&ddi._drugcomb5_2 nodupkey;
		by drugs_list;
	run; 

	proc sort data = &ddi._sumstat2 nodupkey;
		by drugs_list;
	run; 

	/* Merge */

	data &ddi._drugcomb7;
		merge smcncr.&ddi._drugcomb5_2 (in=in1)
    	      &ddi._sumstat2 (in=in2 keep = drugs_list n median q1 q3);
		by drugs_list;
	run;

/*** Clean up the drugs_list variable ***/

data smcncr.&ddi._drugcomb_50;
set &ddi._drugcomb7;

	/* Change "/" to " + " in the drugs_list variable */
	drugs_list2 = tranwrd(drugs_list, "/", " + ");

	label
	drugs_list2 = "Combination of drugs being used concurrently in alphabetical order, clean"
	n = "Number of beneficiaries who used the drugs concurrently (should be identical to unique_benes)"
	median = "Median number of days of concurrent use among beneficiaries who used the drugs concurrently"
	q1 = "Quartile 1 for median"
	q3 = "Quartile 3 for median";

run;

/*************************/
/*** Output the eTable ***/
/*************************/

proc sort data = smcncr.&ddi._drugcomb_50;
by descending unique_benes;
run;

title1 "eTable: Top 50 unique drug combinations from &ddi.";
proc print data = smcncr.&ddi._drugcomb_50;
	var drugs_list2 unique_benes Perc median q1 q3;
	format Perc median q1 q3 8.1;
run;

/*** Delete datasets from the work library ***/

proc datasets library = work nolist;
	delete &ddi.: ;
quit;

%mend;

/***************************************************************************/
/*** Run calc_group_drugs macro for the unique drug combination datasets ***/
/***************************************************************************/

%calc_group_drugs(ddi36); /* Anrys >= 3 CNS-active drugs */
%calc_group_drugs(ddi91); /* Beers >= 3 CNS-active drugs */

/* END OF PROGRAM */
