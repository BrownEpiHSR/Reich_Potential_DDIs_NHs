# Description
This repository contains data documentation and code for the analysis in the manuscript titled "Prevalence and Duration of Potential Drug-Drug Interactions Among US Nursing Home Residents, 2018-2020."

## Repository Contents
- `data_documentation/` - Contains files describing the data sources, key variables, and steps to identify drug-drug interaction (DDI) exposure among beneficiaries.
- `code/` - The programs used for data management and analysis.
- `LICENSE` - The license under which this repository is shared.
- `README.md` - This file, providing an overview of the repository.

## Data Documentation
The `data_documentation/` directory contains the following files:
- `Data_Documentation.xlsx` - Contains the list of input datasets and years of data used in the analysis; steps to identify DDI exposure among beneficiaries; description of key variables in source datasets and some derived datasets.
- `DDIs_List.xlsx` - Includes the names of drugs to be included for each potential drug-drug interaction.

## Code
The `code/` directory contains the following programs:
- `0_Create_Dispensing_Datasets.sas` - Creating drug-level claims datasets for each drug-drug interaction component.
- `1_Create_Med_Eps.sas` - Creating medication use episodes for the drugs associated with each potential drug-drug interaction.
- `2_Create_Concurrent_Med_Eps.sas` - Creating episodes of medication use overlap (i.e., concurrent use) for the drugs associated with each potential drug-drug interaction.
- `3_Create_DDI_Exposure_Eps.sas` - Creating continuous episodes of exposure for each potential drug-drug interaction.
- `4_Table2.sas` - Generating output for **Table 2**: Top 12 Potential Drug-Drug Interactions Among Nursing Home Residents, 
   2018-2020 (N = 485,251 Residents).
- `5_eTable1-3.sas` - Generating output for the following tables:
  - **eTable 1**: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Anrys et al., 2018-2020.
  - **eTable 2**: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by the 2023 Beers Criteria, 2018-2020.
  - **eTable 3**: Potential Drug-Drug Interactions Among Nursing Home Residents Identified by Capiau et al., 2018-2020.
- `6_eTable4-5.sas` - Generating output for the following tables:
  - **eTable 4**: Top 50 Individual Drug Combinations Under “Concomitant Use of At Least CNS-Active Drugs” (Anrys et al.).
  - **eTable 5**: Top 50 Individual Drug Combinations Under “Any Combination of At Least CNS-Active Drugs” (2023 Beers Criteria).

Programs were run in sequence to produce the study findings. Cohort creation programs and programs used to produce Table 1 have not been included; a broad description of these steps can be found in the manuscript.

Additional information (and code) for identifying nursing home time with observable Part D prescription drug data can be found in the upcoming publication from Harris et al. "Identifying observable medication time for US nursing home residents using Medicare claims: a tutorial and case study" (doi.org/10.5281/zenodo.15012812). 

