/*********************************************************************
Project Title: Prevalence and Duration of Potential Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create output for the following tables:
eTable 1: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Anrys et al, 2018-2020.
eTable 2: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by the 2023 Beers Criteria, 2018-2020.
eTable 3: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Capiau et al, 2018-2020.

Programmer: Laura Reich   
 
Date Last Modified: March 14, 2025
*********************************************************************/

/*********************************************************************
Loaded datasets:
- smcncr.calc_all_2: DDI-level prevalence and median days of DDI exposure dataset
     - Generated in 4_Table2.sas
*********************************************************************/

/*********************************************************************
Key generated datasets:
- smcncr.calc_all_anrys_2: DDI-level prevalence, median duration of DDI exposure, proportion with ADRD (Anrys DDIs)
- smcncr.calc_all_beers_2: DDI-level prevalence, median duration of DDI exposure, proportion with ADRD (Beers DDIs)
- smcncr.calc_all_capiau_2: DDI-level prevalence, median duration of DDI exposure, proportion with ADRD (Capiau DDIs)
*********************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname lrenroll "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\enrollment"; 
libname prev "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\est_prev"; 
libname ddi "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\concurrent_use\ddi_lists"; 
libname smcncr "P:\nhddi\lareich\Descriptive_DDI\Data\DerivedData\merged_drug_files\summary_info"; 

options mprint;
	
/*********************************************************/
/*** Partition the smcncr.calc_all_2 by consensus list ***/
/*********************************************************/

data smcncr.calc_all_anrys_2 smcncr.calc_all_beers_2 smcncr.calc_all_capiau_2;
set smcncr.calc_all_2;

	/* If DDI_paper contains "anrys", output the DDI into the anrys dataset */
	if index(lowcase(DDI_paper), "anrys") = 1 then do;
		output smcncr.calc_all_anrys_2;
	end;

	/* If DDI_paper contains "beers", output the DDI into the beers dataset */
	if index(lowcase(DDI_paper), "beers") = 1 then do;
		output smcncr.calc_all_beers_2;
	end;

	/* If DDI_paper contains "capiau", output the DDI into the capiua dataset */
	if index(lowcase(DDI_paper), "capiau") = 1 then do;
		output smcncr.calc_all_capiau_2;
	end;

run;

/*******************************/
/*** Output eTables 1-3 data ***/
/*******************************/

%macro etables_ddi(data);

proc sort data = smcncr.calc_all_&data._2;
by descending count_1;
run;

title1 "ETABLE: &data. DDIs";
proc print data = smcncr.calc_all_&data._2;
var ddi ddi_paper count_1 perc perc_lowercl perc_uppercl median_days median_days_q1 median_days_q3;
format perc perc_uppercl perc_lowercl 8.4 median_days median_days_q1 median_days_q3 8.1;
run;

%mend;

%etables_ddi(anrys);
%etables_ddi(capiau);
%etables_ddi(beers);

/* END OF PROGRAM */
