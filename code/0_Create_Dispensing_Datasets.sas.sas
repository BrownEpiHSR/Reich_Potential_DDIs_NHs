/**************************************************************************
Project Title: Prevalence and Duration of Potential Drug-Drug Interactions
Among US Nursing Home Residents, 2018-2020

Program Purpose: 
Create drug-level claims datasets for each DDI component.

Programmer: Laura Reich   
 
Date Last Modified: March 5, 2025
***************************************************************************/

/***************************************************************************
Loaded datasets and files:
- /DDIs_List_v5.xlsx: Excel spreadsheet where each sheet is a list of 
                      the generic drug names to be included for a given
                      DDI component.
- limited.partd_limitedexcl_&year.: Part D dispensings for cohort 
                                    members during a specific year.
***************************************************************************/

/***************************************************************************
Key generated datasets:
- names.macro_parameters: Dataset with names of the DDI components.
- dlist.&ddi.: List of generic drug names associated with a given DDI component.
- drugs.&ddi._w2017: Dataset with cohort members' 
                     Part D dispensings (between October 4, 2017 to December 31, 2020)
                     for a given DDI component. 
***************************************************************************/

/*****************************/
/*** Libraries and Options ***/
/*****************************/

libname limited "your/library/path"; /* limited library contains Medicare Part D dispensing datasets consisting of individuals with at least one NH stay between 2018-2020 (after applying exclusion criteria) */
libname drugs   "your/library/path"; /* DDI component Part D dispensing datasets */
libname dlist   "your/library/path"; /* Excel drug lists */
libname names   "your/library/path"; /* Names of each DDI component */

options mprint mlogic;

/*******************************************/
/*** Define study period macro variables ***/
/*******************************************/

%let yr_start = 2017;
%let yr_end   = 2020;

/********************************************************/
/*** Create dataset with all the DDI component names  ***/
/********************************************************/

/* NOTE: We consider a "DDI component" to be one pair in a DDI. For example, DDI1 is digoxin + amiodarone. Digoxin would be considered the first component of this DDI, amiodarone
         is the second component. See "DDI_List" in the data_documentation folder in the GitHub Repository for the full list of DDIs and their component names */

data names.macro_parameters;
	length ddi_sheet $255;
	input ddi_sheet;
	label
		ddi_sheet = "Name of DDI component"
	;
	datalines;
anrys33x34a
capiau17a
capiau18a
anrys46b
anrys31a
capiau5a
anrys58a_capiau19a
anrys17a
capiau3a
anrys35b
capiau4a
capiau6a
anrys59a
capiau16a
anrys54b
anrys8x51b_beers10b
anrys61a
capiau11a
capiau8a
anrys55a
anrys62-64a
anrys41-43a_beers6x7a
anrys3b
anrys58b_capiau9a
anrys51-54a_beers10x11a
anrys25b
capiau7a
anrys4b
anrys48x49a_capiau10a
anrys29x49x53x59b
anrys31b
capiau12a_beers9a
anrys16a
capiau20b
capiau19b
anrys60a
anrys45a
capiau20a
capiau13a
anrys44x46x47a
anrys7b
anrys40b
anrys40a
anrys1-6a
anrys9b
anrys1x10x28x33b
anrys45b
anrys18a
anrys55b
anrys61b
anrys44b
anrys16x17b
anrys2x26x32x48b
anrys7-10x13-15a_62b
capiau1a
anrys64b
anrys27a
anrys37a
anrys12b_20a
capiau2a
anrys19a
beers8a
anrys11x20x23x24x56b_39a
anrys41b_capiau14a
anrys63b
anrys5b
anrys15b
anrys50a
beers9b
anrys13b
capiau5x6b
anrys34x60b
capiau1-4x7-18b
anrys18x19x30x37b
beers3b
beers11b
anrys11x12a
anrys56a
beers2b
anrys27b
anrys22b
anrys14x52b
anrys38x66a
anrys30a
anrys35a
beers7x8b
anrys26x28x29a
anrys39b
capiau15a
beers6b
anrys23a_43b
beers2x3a
beers1a_1b
anrys38b
anrys25a
anrys32a
anrys22a
anrys6x66b
anrys24a_42b
anrys50b
anrys57a_57b_beers4a_4b
anrys47b
beers12b
anrys65a_65b
anrys21a_21b
beers5a_5b_5c
anrys36a_36b_36c
;
run;

/*** Define a macro that will take a sheet from the Excel file and save it to a SAS dataset ***/

%macro import_excel(ddi_sheet);

	/* Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' */
	%let ddi = %sysfunc(tranwrd(&ddi_sheet., -, xx));

	/* Import the DDI component sheet from the Excel file and save it to a SAS dataset */
    proc import out=dlist.&ddi. (keep = drug core_drug)
		datafile='P:\nhddi\lareich\Descriptive_DDI\Workflow_and_Protocols\1_identifying_DDIs\DDIs_List_v5.xlsx'
        dbms=xlsx
        replace;  /* Replace existing dataset if it exists */
        sheet="&ddi_sheet.";
		getnames = yes;
    run;
	
	/* Standardize the SAS DDI drug list by setting variable lengths, converting all characters to lowercase, and trimming leading/trailing spaces */
	data dlist.&ddi.;
		length drug $255 core_drug $255; /* Setting length to match the length of hdl_gdname, and hdl_ai_name1 - hdl_ai_name4 (will be necessary later) */
		set dlist.&ddi.;
		drug = lowcase(strip(drug)); /* lowcase() makes all characters lowercase, and strip() removes leadings and trailing spaces */
		core_drug = lowcase(strip(core_drug));
		if drug="" then delete; /* Sometimes there are errors reading in Excel files, so make sure to delete any drugs that are empty strings */

		label
		drug = 'Drug name, includes salt forms'
		core_drug = 'Drug name without specifying salt form';
	run;
	
	/* Remove duplicate drug names */
	proc sort data = dlist.&ddi. nodupkey;
		by drug;
	run;

%mend import_excel;

/*** Call the %import_excel macro for each sheet in the Excel DDI list. ***/

data _null_;
	set names.macro_parameters;
	
	call execute(cats('%import_excel(', ddi_sheet, ');'));

run;

/********************************************************************************************************************************/
/*** Generate drug-level claims datasets (DDI component datasets), with dispensings from October 4, 2017 to December 31, 2020 ***/
/********************************************************************************************************************************/

/* NOTE: The limited.partd_limitedexcl_2017 dataset only has dispensings from October 4, 2017 to December 31, 2017.
		 Including dispensings from October 4, 2017 onward ensures we capture prevalent medication use that began before 2018.  
         Any dispensings with a days supply > 90 will later be trimmed to 90 in 1a_Create_Med_Eps.sas, making this start date sufficient. */

/*** Define macro to extract dispensings from the limited Medicare Part D datasets for drugs in dlist.&ddi. with an oral route of administration */

%macro pull_drugs(ddi_sheet);

	/* Replace any '-' in the DDI sheet name to 'xx', since SAS dataset names cannot include '-' */
	%let ddi = %sysfunc(tranwrd(&ddi_sheet., -, xx));

	/* For each year (2017-2020), create a dataset that only contains the dispensings from the drugs of interest for this DDI component */

	%do year = &yr_start. %to &yr_end.;

		data &ddi._&year.;

			if 0 then set dlist.&ddi.; /* Forces SAS to define all variables in this dataset */

			/* Define the hash object with the list of drugs from dlist.&ddi. */
			if _n_ = 1 then do;
				declare hash drug_list(dataset: "dlist.&ddi.");
				drug_list.defineKey('Drug');
				drug_list.defineData('Drug');
				drug_list.defineDone(); /* This essentially creates a list of the specific drugs to include for this DDI component */
			end;

			/* Initialize the variable to store the matched drug */
			length Drug $255;
			Drug = '';

			set limited.partd_limitedexcl_&year. end=eof; /* Use end=eof to detect the last record */

				/* Find if any of the hdl variables match a drug name, and store the matched drug */
				if drug_list.find(key: hdl_gdname) = 0 then drug = hdl_gdname; /* If the find method finds a match, it returns 0 */
				else if drug_list.find(key: hdl_ai_name1) = 0 then drug = hdl_ai_name1;
				else if drug_list.find(key: hdl_ai_name2) = 0 then drug = hdl_ai_name2;
				else if drug_list.find(key: hdl_ai_name3) = 0 then drug = hdl_ai_name3;
				else if drug_list.find(key: hdl_ai_name4) = 0 then drug = hdl_ai_name4; 
				else delete; /* Delete the record if no match is found */

			if _n_ = eof then drug_list.delete(); /* ensures the delete() method is called at the end of dataset processing */

		run;

	%end;

	/* Stack datasets for each year AND only keep drugs that are orally administered */
	data drugs.&ddi._w2017;
		set &ddi._2017 &ddi._2018 &ddi._2019 &ddi._2020;
		if hdl_route = 'oral';
	run;

	/* Delete datasets from the work library */
	proc datasets library=work nolist; 
		delete &ddi._2017 &ddi._2018 &ddi._2019 &ddi._2020; 
	quit;

%mend;

/*** Call the pull_drugs macro for each SAS DDI list ***/

data _null_;
	set names.macro_parameters;
	
	call execute(cats('%pull_drugs(', ddi_sheet, ');'));

run;

/* END OF PROGRAM */
