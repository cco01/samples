/*
*Title: 1a_research_metco_applicant_database_refdates_cleaning
*Created by: Clive Myrie Co
*Created on: 07/16/2021
*Last modified on:
*Checked by: Sara Ji

*Purpose: Clean up Electronic Database for Referral Date additions
### First goal is to clean up data just to add referral dates to those without one and have one in either of the status notes
*/


/***************************************************************************
Setup
***************************************************************************/
clear all
set more off
cap log close
set mem 8000m

/***************************************************************************
Set paths
***************************************************************************/
* Path locations
do "E:\METCO\programs\headers\RQ2_header_and_paths.do"

* Take the most recent full_metco applicant data and find people who have referred == 1 and no referral data. Take those kids and merge them with the dataset Clive is working with - so she can check the status notes.
use "${merge_sims}\full_metco.dta", clear
keep if referred_all==1 & refer_date_all == .
* Limit the data to observations only from the electronic database
drop if setren_id1 >= 9000000
tempfile full_applicant
save `full_applicant'

use "${electronic_data}\electronic_database.dta", clear
ren setren_id_app_database setren_id1
merge 1:1 setren_id1 using `full_applicant'

keep if _merge == 3
assert date_referred_str_app_database == ""
drop if statusnotes1 == "" & statusnotes2 == "" & statusnotes3 == "" // 859 obs without any status notes
keep if ((strpos(statusnotes1, "ref") > 0) | (strpos(statusnotes2, "ref") > 0) | (strpos(statusnotes3, "ref") > 0)) //1,425 obs to be checked

* Exclude the observations that has already been checked
ren metco_district_app_database metco_district
ren date_referred_str_app_database date_referred
do "${programs}\1_research_metco_applicant_database_refdates.do" // nothing has been checked

* Save file *
save "${electronic_data}\electronic_database_temp.dta", replace
