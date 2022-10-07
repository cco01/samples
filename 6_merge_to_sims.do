/*
*Title: 6_merge_to_sims
*Created by: Savannah Kochinke
*Created on: 5/5/2021
*Last modified on: 4/7/2022
*Last modified by: Sara Ji

*Purpose: Merge PDFs/Google Forms/Electronic Database to SIMS
*/


/***************************************************************************
Setup
***************************************************************************/
clear all
set more off
cap log close
set mem 8000m
sysdir set PLUS "E:\METCO\ado\plus"

/***************************************************************************
Set paths
***************************************************************************/
* Path locations
do "E:\METCO\programs\headers\RQ2_header_and_paths.do"

/***************************************************************************
Switches
***************************************************************************/
local install_subprograms                = 0
             
local prepare_sims                         = 0
	local prepare_sims_setup               = 0
	local prepare_sims_datasets            = 0
local merge_to_sims                        = 0
	local merge_to_sims_V1a                = 0 // V1a: Exact Match on Full Name and Birthday 
	local merge_to_sims_V1b                = 0 // V1b: Exact Match on Concatenated Full Name and Birthday
	local merge_to_sims_V1c                = 0 // V1c: Exact Match on Last Name, First Name, and Birthday
	local merge_to_sims_V1d                = 0 // V1d: Exact Match on Last Name, Concat(F+M) and Birthday
	local merge_to_sims_V1                 = 0
	local merge_to_sims_V2_dtalink         = 0 // V2: Fuzzy Match on Last, First, Middle Name and Birthday (Drop if DOB Missing)
		local merge_to_sims_V2_dtalink_x   = 0 // Only update if there have been changes to names or dates
	local merge_to_sims_Vs                 = 0
	local sims_only_metco                  = 0
	local combine_with_without_sims        = 0
	local final_dedup                      = 0
	local manual_matches                   = 0
		local fuzzymatch_to_sims           = 0
		local cleaning_manual_matches      = 0
	local create_variables                 = 1
		local race_explore                 = 1

/***************************************************************************
Locals
***************************************************************************/
	if `install_subprograms' ==1 {
		net install strgroup, from("https://raw.githubusercontent.com/reifjulian/strgroup/master") replace
		net from https://raw.githubusercontent.com/kkranker/dtalink/master/
	}
				   
local clean_vars_n  application_day interview_date academic_test_date gf_application_day ///
                    gf_refer_date pdf_application_day ed_application_day ed_refer_date refer_date_sims
local clean_vars_s  child_id fam_id present_school neighborhoods_city neighborhoods_zip_elecdata			  
local numeric_vars  sibling metco_sib total_metco_sibs twin app_complete ///
                    interview participating_766 ///
					evaluated_766 mid_year sped phys_disabilities special_help_check ///
					academic_test teacher_eval transfer_form noref_info enrolled_col ///
					interview_form declined withdrawn graduated referred pending incomplete ///
					active asian black hispanic nat_american other white sex_m sex_f sex_na ///
					withdraw_date source_google_form source_electronic source_pdfs ///
					gf_metco gf_NE gf_ref_process gf_newton NE_updates gf_b_NE_updates ///
					gf_referred pdf_referred placement indicator_status_notes ed_referred ///
					hisp_sims black_sims white_sims asian_sims otherrace_sims partic ///
					female male
local clean_vars_s_nomatch child_id present_school neighborhoods_city neighborhoods_zip_elecdata						
local clean_vars_n_nomatch  application_day interview_date academic_test_date gf_application_day ///
                    gf_refer_date pdf_application_day ed_application_day ed_refer_date 
				   
/*******************************************************************************
 Prepare the SIMS Dataset for the merge
*******************************************************************************/
if `prepare_sims' ==1 {
	if `prepare_sims_setup' ==1 {
	use sasid fname mname lname dob year grade race gender masscode attend rfe_oc rfe_eoy ///
		using "${simssave}/simsbig_${simsdate}.dta", replace

		keep sasid fname mname lname dob year grade race gender masscode attend rfe_oc rfe_eoy
		
		do "${ppi_programs}\manual_edits_6_merge_to_sims_setup.do"

			* Get data to student level								
				* Generally clean names (For match to METCO)
					foreach var in lname fname mname {
						replace `var' = lower(`var')
					}
						
				* Clean names	
					foreach var in lname fname mname {
						replace `var' = subinstr(`var', "-", "", .)
						replace `var' = subinstr(`var', ".", "", .)
						replace `var' = subinstr(`var', "'", "", .)
						replace `var' = subinstr(`var', ",", "", .)
						replace `var' = regexr(`var', " ii$", "")
						replace `var' = regexr(`var', " iii$", "")
						replace `var' = regexr(`var', " iv$", "")
						replace `var' = regexr(`var', " lv$", "")
						replace `var' = regexr(`var', "iiii$", "")
						replace `var' = regexr(`var', " v$", "")
						replace `var' = regexr(`var', " ll$", "")
						replace `var' = regexr(`var', " lll$", "")
						replace `var' = regexr(`var', " iil$", "")
						replace `var' = regexr(`var', " ivo$", "")
						replace `var' = subinstr(`var', " jr ", "", .)
						replace `var' = regexr(`var', " jr$", "")
						replace `var' = regexr(`var', " junior$", "")
						replace `var' = regexr(`var', " sr$", "")
						replace `var' = subinstr(`var', " ", "", .)
					}	
				
				* Fix Name (Sometimes different across SASID)
				preserve	
					* Sort by most popular name
					sort sasid lname fname mname
					by sasid: generate n1 = _N
					by sasid lname fname mname: generate n2 = _N					
					
						gsort sasid -n2 lname fname mname
						keep sasid lname fname mname 
							duplicates drop
							quietly by sasid : gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0						
							
								reshape wide lname fname mname, i(sasid)  j(dup)
									
								tempfile fix_name
									save `fix_name'					
				restore
					drop lname fname mname
					merge m:1 sasid using `fix_name'
					order fname1 mname1 lname1 ///
						 fname2 mname2 lname2 ///
						 fname3 mname3 lname3 ///
						 fname4 mname4 lname4 ///
						 fname5 mname5 lname5 ///
						 fname6 mname6 lname6, a(sasid)
					drop _merge		
					
				duplicates drop	
				
				* Fix Birthday (Sometimes Different across SASID)
				preserve
					sort sasid dob
					
					* first, drop if dob == . if there are other dobs for the sasid
					by sasid: generate n1 = _N
					by sasid dob: generate n2 = _N
					gen flag = 1 if dob == . & n2 < n1
					drop if flag == 1
						drop n1 n2 flag
					
					
					* Generate the DOB order by the most common DOB
					sort sasid dob
					by sasid: generate n1 = _N
					by sasid dob: generate n2 = _N
						gsort sasid -n2 dob
						keep sasid dob 
							duplicates drop
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0						
							
								reshape wide dob, i(sasid)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'					
				restore
					drop dob
					merge m:1 sasid using `fix_dob'
					drop _merge
						order dob*, a(lname6)			
				
	* Fix Race and Gender (Sometimes different across SASID)
		preserve
			keep sasid fname1 mname1 lname1 gender year
			sort sasid gender fname1 mname1 lname1 year

			* first, pick the modal
			by sasid: generate n1 = _N
			by sasid gender: generate n2 = _N
				bysort sasid: egen max_n2 = max(n2)
			
			gen flag = 1 if n1 != n2
			
			drop if flag == 1 & n2 != max_n2
			
				drop n1 n2 max_n2 flag 
			
			*With remaining, pick the bline
			sort sasid year	
				by sasid: generate n1 = _n
				by sasid: generate n2 = _N
					keep if n1 == 1		
					
					drop fname1 mname1 lname1 n1 n2 year 
							
						tempfile fix_gender
							save `fix_gender'					
		restore
			drop gender
			merge m:1 sasid using `fix_gender'
			drop _merge
				rename gender gender_sims

		*Chris/Sarah 6/24/2010:  Put native americans in other race category
			* RACE
				qui g byte hisp_sims      = race==99 if race!=. 
				qui g byte black_sims     = race==3 if race!=. 
				qui g byte white_sims     = race==5 if race!=. 
				qui g byte asian_sims     = race==2 if race!=. 
				qui g byte otherrace_sims = race==1 | race==4 if race!=. 	
				
				foreach x in hisp_sims black_sims white_sims asian_sims otherrace_sims {
					bys sasid: egen `x'_temp = max(`x')
						drop `x'
						rename `x'_temp `x'
				}	
				drop race
				duplicates drop	
				
	* Similar to local firstround from 5_combine_sims_and_mcas, we need to pick year/grade by attendance.
	*****************************************************************************************************
			* Copied code here 
				*Limit sample 
				drop if grade == .
				drop if sasid == . 
				drop if masscode == . 

				*Compute attendance weights for collapsing
				rename attend days_attend
				gen attend = days_attend/180
				drop if attend == .
				drop if attend == 0
				bysort sasid year : egen totattend = sum(attend)

				/* We do this because some school years are longer than others so totattend is > 1
				if the school year is longer than 180 days */
				replace totattend = 1 if totattend > 1

				gen propattend = attend/totattend
				/* We do this because dividing by 0 gives us a missing number and we want to give these
				observations 0 weight */
				replace propattend = 0 if propattend == .

				*Gather the variables to collapse at the school-grade level
				  *Diversity exposure
				  gen temp = rfe_oct == 4 | rfe_eoy == 4
				  bysort sasid : egen partic = max(temp)
					
					* Generate refered date
					preserve
						gen refer_date_sims1 = .
						format refer_date_sims1 %td
						
						keep if partic == 1
						keep if rfe_oct == 4 | rfe_eoy == 4
						bysort sasid : egen min_year = min(year)
						
						gen imputed_year = min_year -1
							replace refer_date_sims1 = mdy(6,1,imputed_year)
												
							format refer_date_sims1 %td
							
						keep sasid refer_date_sims1
							duplicates drop
							
							tempfile refer_date_sims
							save `refer_date_sims'
					
					restore
					
					merge m:1 sasid using `refer_date_sims'
						drop _merge
					
					drop temp rfe_oct rfe_eoy

					*Student characteristics
					gen attend_rate = days_attend/(180*propattend)
					bysort sasid year : egen max_propattend = max(propattend)
					bysort sasid year : egen attend_rate_total = sum(days_attend/180)

					gen grade_for_fes = .
					replace grade_for_fes = grade if propattend == max_propattend
					bysort sasid year : egen temp = max(grade_for_fes) 
					replace grade_for_fes = temp
					drop temp 	
					
			* End Copied Code	
			*****************************************************************************************************
			
					keep if propattend == max_propattend
					drop masscode days_attend attend totattend propattend attend_rate max_propattend attend_rate_total grade
						duplicates drop
						
			* Get Year In 1st Grade
			gen year_in_first = year if grade == 1
				bysort sasid: egen temp_year_in_first = min(year_in_first)
				
			gen year_in_0 = year if grade == 0
				bysort sasid: egen temp_year_in_0 = min(year_in_0)		

			gen year_in_m1 = year if grade == -1
				bysort sasid: egen temp_year_in_m1 = min(year_in_m1)		
				
			forval x = 2/12 {
			gen year_in_`x' = year if grade == `x'
				bysort sasid: egen temp_year_in_`x' = min(year_in_`x')	
			}				
				
			gen est_year_in_first = temp_year_in_first
			
			drop year_in_first
			rename temp_year_in_first year_in_first	
			
			replace est_year_in_first = temp_year_in_0 + 1 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_2 - 1 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_3 - 2 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_4 - 3 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_5 - 4 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_6 - 5 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_7 - 6 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_8 - 7 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_9 - 8 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_10 - 9 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_11 - 10 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_12 - 11 if est_year_in_first == .
			replace est_year_in_first = temp_year_in_m1 + 2 if est_year_in_first == .
		
			drop year_in_0  temp_year_in_0 year_in_m1 temp_year_in_m1 year_in_2  temp_year_in_2 ///
			     year_in_3  temp_year_in_3 year_in_4  temp_year_in_4  year_in_5  temp_year_in_5 ///
				 year_in_6  temp_year_in_6 year_in_7  temp_year_in_7  year_in_8  temp_year_in_8 ///
				 year_in_9  temp_year_in_9 year_in_10 temp_year_in_10 year_in_11 temp_year_in_11 ///
				 year_in_12 temp_year_in_12
			drop grade year	
			
		duplicates drop
		isid sasid		
		
	* Update: 5/20/2022
		* This student has the same name and DOB as a Boston student, confuses the merge. Drop students & other edits
			do "${ppi_programs}\manual_edits_6_merge_to_sims_samename.do"
		
		save "${temp}\simsbig_${simsdate}_setup.dta", replace
		
		save "${simssave}\sims_for_TargetSmart_${simsdate}.dta", replace
		
	} // End Setup

	if `prepare_sims_datasets' ==1 {	
	* One dataset at the sasid level, with all the SIMS vars we want
	use "${temp}\simsbig_${simsdate}_setup.dta", replace

	preserve
		keep sasid dob*
		
		save "${merge_sims}\simsbig_${simsdate}_dobs.dta", replace
	restore
	
	cap drop _merge
		rename sasid  sasid_sims
		rename dob1   dob_sims1
		rename dob2   dob_sims2
		rename dob3   dob_sims3
		rename dob4   dob_sims4
		rename fname1 fname_sims1
		rename mname1 mname_sims1
		rename lname1 lname_sims1
		rename fname2 fname_sims2
		rename mname2 mname_sims2
		rename lname2 lname_sims2
		rename fname3 fname_sims3
		rename mname3 mname_sims3
		rename lname3 lname_sims3
		rename fname4 fname_sims4
		rename mname4 mname_sims4
		rename lname4 lname_sims4
		rename fname5 fname_sims5
		rename mname5 mname_sims5
		rename lname5 lname_sims5
		rename fname6 fname_sims6
		rename mname6 mname_sims6
		rename lname6 lname_sims6
		
	* For the purpose of the Merge, set missing DOBs and Names to something that 
	* can be dropped later (otherwise you have incorrect merges)
		foreach var in dob_sims1 dob_sims2 dob_sims3 dob_sims4 {
			replace `var' = -10000 if `var' == .
		}
		forval i = 1/6 {
			gen flag = 1 if fname_sims`i' == "" & mname_sims`i' == "" & lname_sims`i' == ""
			replace fname_sims`i' = "." if fname_sims`i' == "" & flag == 1
			replace mname_sims`i' = "." if mname_sims`i' == "" & flag == 1
			replace lname_sims`i' = "." if lname_sims`i' == "" & flag == 1	
				drop flag
			gen name_full_sims`i' = lname_sims`i' + fname_sims`i' + mname_sims`i'
			order name_full_sims`i', a(lname_sims`i')
			
			gen m_init`i' = substr(mname_sims`i',1,1) 
			gen first_middle_sims`i' = fname_sims`i' + m_init`i'
			order first_middle_sims`i', a(name_full_sims`i')
				drop m_init`i'			
		}			

	save "${merge_sims}\simsbig_${simsdate}_for_merge_fuzzy.dta", replace
		
		forval i = 1/6 {
			replace mname_sims`i' = "-" if mname_sims`i' == ""
		}	
				
	save "${merge_sims}\simsbig_${simsdate}_for_merge.dta", replace		

	* One dataset that is long and only names, dob and sasid	
	* ### Makes the assumption that people with the exact same name and DOB are the same person.
	use "${temp}\simsbig_${simsdate}_setup.dta", replace
	
	* Some students have the same name and DOB!!
		* This student in particular I know is not the METCO match so just add temp to their first name for now. 
		replace fname1 = "christopher_temp" if sasid == 1094405401		
		
	cap drop _merge
		gen expand = .
			order expand
				replace expand = 6 if (lname6 != "" | mname6 != "" | fname6 != "") & expand == .
				replace expand = 5 if (lname5 != "" | mname5 != "" | fname5 != "") & expand == .
				replace expand = 4 if (lname4 != "" | mname4 != "" | fname4 != "") & expand == .
				replace expand = 3 if (lname3 != "" | mname3 != "" | fname3 != "") & expand == .
				replace expand = 2 if (lname2 != "" | mname2 != "" | fname2 != "") & expand == .
				replace expand = 1 if (lname1 != "" | mname1 != "" | fname1 != "") & expand == .
				
			expand expand

				sort sasid
				gen fname_sims = ""
				gen mname_sims = ""
				gen lname_sims = ""				
					quietly by sasid :  gen dup = cond(_N==1,0,_n)
						tab dup		
							order dup fname_sims mname_sims lname_sims
								replace dup = 1 if dup == 0	
								
								foreach var in fname mname lname {
									replace `var'_sims = `var'1 if dup == 1
									replace `var'_sims = `var'2 if dup == 2
									replace `var'_sims = `var'3 if dup == 3
									replace `var'_sims = `var'4 if dup == 4
									replace `var'_sims = `var'5 if dup == 5
									replace `var'_sims = `var'6 if dup == 6
								}
			drop expand dup fname1 mname1 lname1 fname2 mname2 lname2 fname3 mname3 lname3 fname4 mname4 lname4 fname5 mname5 lname5 fname6 mname6 lname6

		gen expand = .
			order expand
				replace expand = 4 if dob4 != . & expand == .
				replace expand = 3 if dob3 != . & expand == .
				replace expand = 2 if dob2 != . & expand == .
				replace expand = 1 if dob1 != . & expand == .
				replace expand = 1 if dob1 == . & expand == .
				
			expand expand

				sort sasid fname_sims mname_sims lname_sims
				gen dob_sims = .
					quietly by sasid fname_sims mname_sims lname_sims :  gen dup = cond(_N==1,0,_n)
						tab dup		
							order dup dob_sims
								replace dup = 1 if dup == 0	
								
								foreach var in dob {
									replace `var'_sims = `var'1 if dup == 1
									replace `var'_sims = `var'2 if dup == 2
									replace `var'_sims = `var'3 if dup == 3
									replace `var'_sims = `var'4 if dup == 4
								}
								format dob_sims %td
			drop expand dup dob1 dob2 dob3 dob4

	* Fix if multiple SASIDS for the same name and dob	
			preserve
				keep fname_sims mname_sims lname_sims dob_sims sasid
					duplicates drop
						
							sort fname_sims mname_sims lname_sims dob_sims sasid
							quietly by fname_sims mname_sims lname_sims dob_sims :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup
									local max = r(max)
									di in red "`max'"																
							
								reshape wide sasid, i(fname_sims mname_sims lname_sims dob_sims)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore		
			merge m:1 fname_sims mname_sims lname_sims dob_sims using `fix_sasid'
				order sasid1 sasid2 sasid3 sasid4, a(sasid)
				drop _merge
					drop sasid
					duplicates drop	
					
			* Standardize Numeric Variables
				gen female = 0
					replace female = 1 if gender_sims ==0
				gen male = 0
					replace male = 1 if gender_sims == 1	
				drop gender_sims
					
				foreach var in hisp_sims black_sims white_sims asian_sims otherrace_sims partic female male {
					bysort sasid1 : egen max_`var' = max(`var')
						replace  `var' = max_`var'
							drop max_`var'
				}	
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}				
				duplicates drop						
					
			gen name_full_sims = lname_sims + fname_sims + mname_sims
						
			gsort fname_sims mname_sims lname_sims dob_sims		
				quietly by fname_sims mname_sims lname_sims dob_sims : gen dup = cond(_N==1,0,_n)				
					tab dup
					order dup
					*br if dup > 0 
						assert dup == 0
							drop dup
					
			gsort sasid1		
				quietly by sasid1 : gen dup = cond(_N==1,0,_n)				
					tab dup
					order dup
					*br if dup > 0 					
						drop dup
						
			duplicates drop
		order sasid1 fname_sims mname_sims lname_sims dob_sims
	save "${merge_sims}\simsbig_${simsdate}_for_merge_longA.dta", replace
		
		keep if partic == 1
		
	* Fix Name (keeping different versions)
		preserve
			keep sasid1 fname_sims mname_sims lname_sims
				duplicates drop
		
				gsort sasid1 fname_sims mname_sims lname_sims
					drop if fname_sims == fname_sims[_n+1] & lname_sims == lname_sims[_n+1]  ///
							& sasid1 == sasid1[_n+1] & mname_sims == ""
							
				quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
					tab dup		
				
					replace dup = 1 if dup == 0	
						sum dup
						local max = r(max)
						di in red "`max'"						
					foreach var in fname_sims mname_sims lname_sims {
						rename `var' `var'_
					}							
				
					reshape wide fname_sims_ mname_sims_ lname_sims_, i(sasid1)  j(dup)
						
					tempfile fix_name
						save `fix_name'				
		restore	
		
		drop fname_sims mname_sims lname_sims
		merge m:1 sasid1 using `fix_name'
			order fname_sims_1 mname_sims_1 lname_sims_1 fname_sims_2 mname_sims_2 lname_sims_2 ///
				  fname_sims_3 mname_sims_3 lname_sims_3 fname_sims_4 mname_sims_4 lname_sims_4
			drop _merge  name_full_sims
			duplicates drop	
		
	* Fix DOB
	preserve
		keep sasid1 dob_sims
		duplicates drop

		sort sasid1 dob_sims
		quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup		
			
			replace dup = 1 if dup == 0	
			sum dup
			local max = r(max)
			di in red "`max'"									
			rename dob_sims dob_sims_
			reshape wide dob_sims_, i(sasid1)  j(dup)
				
			tempfile fix_dob
				save `fix_dob'				
	restore		

	merge m:1 sasid1 using `fix_dob'
		order dob_sims_* , a(dob_sims)
		drop _merge dob_sims	
	
	* Fix SASID
		gsort sasid1 -sasid2 -sasid3 -sasid4
			bysort sasid1 : carryforward sasid2, replace	
			bysort sasid1 : carryforward sasid3, replace
			bysort sasid1 : carryforward sasid4, replace
			duplicates drop	
		
	isid sasid1
	
	save "${merge_sims}\all_metco_sims.dta", replace

	use "${merge_sims}\simsbig_${simsdate}_for_merge_longA.dta", replace	
	drop lname mname fname
		duplicates drop
		
		* Fix SASID
			preserve
				keep name_full_sims dob_sims sasid*
				duplicates drop
				gen id = _n
			 
				reshape long sasid , i(name_full_sims dob_sims id) j(refer_num) 					
					drop refer_num id	
						drop if sasid == .
							duplicates drop
							sort name_full_sims dob_sims sasid
							quietly by name_full_sims dob_sims :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup
									local max = r(max)
									di in red "`max'"									
								rename sasid sasid_
								reshape wide sasid_, i(name_full_sims dob_sims)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore		
			
			merge m:1 name_full_sims dob_sims using `fix_sasid'
				foreach var in sasid {
				di in red "forval i = 1/`max'"
					forval i = 1/`max' {
						replace `var'`i' = `var'_`i' if _merge == 3
					}
				}	
				drop _merge sasid_*			
		duplicates drop	
		
			* Standardize Numeric Variables					
				foreach var in hisp_sims black_sims white_sims asian_sims otherrace_sims partic female male {
					bysort sasid1 : egen max_`var' = max(`var')
						replace  `var' = max_`var'
							drop max_`var'
				}	
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}	
				duplicates drop					
		
			gsort name_full_sims dob_sims		
				quietly by name_full_sims dob_sims : gen dup = cond(_N==1,0,_n)				
					tab dup
					order dup
					*br if dup > 0 
						assert dup == 0
							drop dup	
			
	save "${merge_sims}\simsbig_${simsdate}_for_merge_longB.dta", replace	
	
	use "${merge_sims}\simsbig_${simsdate}_for_merge_longA.dta", replace	
	drop mname name
		duplicates drop
		
		* Fix SASID
			preserve
				keep lname fname dob_sims sasid*
				duplicates drop
				gen id = _n
			 
				reshape long sasid , i(lname fname dob_sims id) j(refer_num) 					
					drop refer_num id	
						drop if sasid == .
							duplicates drop
							sort lname fname dob_sims sasid
							quietly by lname fname dob_sims :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup
									local max = r(max)
									di in red "`max'"									
								rename sasid sasid_
								reshape wide sasid_, i(lname fname dob_sims)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore		
			
			merge m:1 lname fname dob_sims using `fix_sasid'
				foreach var in sasid {
				di in red "forval i = 1/`max'"
					forval i = 1/`max' {
						replace `var'`i' = `var'_`i' if _merge == 3
					}
				}	
				drop _merge sasid_*			
		duplicates drop
		
			* Standardize Numeric Variables					
				foreach var in hisp_sims black_sims white_sims asian_sims otherrace_sims partic female male {
					bysort sasid1 : egen max_`var' = max(`var')
						replace  `var' = max_`var'
							drop max_`var'
				}					
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}	
				duplicates drop					
		
			gsort lname fname dob_sims		
				quietly by lname fname dob_sims : gen dup = cond(_N==1,0,_n)				
					tab dup
					order dup
					*br if dup > 0 
						assert dup == 0
							drop dup
			
	save "${merge_sims}\simsbig_${simsdate}_for_merge_longC.dta", replace	
	
	use "${merge_sims}\simsbig_${simsdate}_for_merge_longA.dta", replace
	gen first_middle_sims = fname + mname
	drop mname name fname
		duplicates drop
		
		* Fix SASID
			preserve
				keep lname first_middle_sims dob_sims sasid*
				duplicates drop
				gen id = _n
			 
				reshape long sasid , i(lname first_middle_sims dob_sims id) j(refer_num) 					
					drop refer_num id	
						drop if sasid == .
							duplicates drop
							sort lname first_middle_sims dob_sims sasid
							quietly by lname first_middle_sims dob_sims :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup
									local max = r(max)
									di in red "`max'"									
								rename sasid sasid_
								reshape wide sasid_, i(lname first_middle_sims dob_sims)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore		
			
			merge m:1 lname first_middle_sims dob_sims using `fix_sasid'
				foreach var in sasid {
				di in red "forval i = 1/`max'"
					forval i = 1/`max' {
						replace `var'`i' = `var'_`i' if _merge == 3
					}
				}	
				drop _merge sasid_*			
		duplicates drop	
		
			* Standardize Numeric Variables					
				foreach var in hisp_sims black_sims white_sims asian_sims otherrace_sims partic female male {
					bysort sasid1 : egen max_`var' = max(`var')
						replace  `var' = max_`var'
							drop max_`var'
				}	
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}	
				duplicates drop
		
			gsort lname first_middle_sims dob_sims		
				quietly by lname first_middle_sims dob_sims : gen dup = cond(_N==1,0,_n)				
					tab dup
					order dup
					*br if dup > 0 
						assert dup == 0
							drop dup
			
	save "${merge_sims}\simsbig_${simsdate}_for_merge_longD.dta", replace	

	} // End create datasets		

} // End prepare_sims

/*******************************************************************************
 Merge onto SIMS dataset from above to get SASIDs
*******************************************************************************/
if `merge_to_sims' ==1 {

* V1a: Exact Match on Full Name and Birthday
	if `merge_to_sims_V1a' ==1 {
		use "${matching}\full_student_level_dataset_new.dta", replace

	forval name_elec = 1/9     /*9*/ {
		forval dob_elec = 1/3  /*3*/ {
			di in red "A: name_elec = `name_elec' & dob_elec = `dob_elec'"
			preserve	
			
				foreach var in fname mname lname {
					quietly gen `var'_sims = `var'`name_elec'
				}	
				
					quietly gen dob_sims = dob`dob_elec'
				
				order fname_sims mname_sims lname_sims dob_sims

				drop if fname_sims == "" & mname_sims == "" & lname_sims == "" & dob_sims == .
				drop if fname_sims == "" & mname_sims == "" & lname_sims == ""				

				quietly merge m:1 fname_sims mname_sims lname_sims dob_sims using "${merge_sims}\simsbig_${simsdate}_for_merge_longA.dta"

					*tab _merge
					keep if _merge == 3
						drop _merge
					
					tempfile V1a_dob`dob_elec'_ne`name_elec'
						save `V1a_dob`dob_elec'_ne`name_elec''		
					
			restore	
		} // End dob_elec
	} // End name_elec

	use `V1a_dob1_ne1', replace
	forval name_elec = 1/9     /*9*/ {
		forval dob_elec = 1/3  /*3*/ {
			append using `V1a_dob`dob_elec'_ne`name_elec''
		} // End dob_elec
	} // End name_elec
	
duplicates drop		
		
sort setren_id1 lname1 fname1 mname1	

save "${temp}\merge_to_sims_V1a.dta", replace	
	
	} // End merge_to_sims_V1a

* V1b: Exact Match on Concatenated Full Name and Birthday	
	if `merge_to_sims_V1b' ==1 {
		use "${matching}\full_student_level_dataset_new.dta", replace	
		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1a.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12
			
forval name_elec = 1/9     /*9*/ {
	forval dob_elec = 1/3  /*3*/ {
		di in red "B: name_elec = `name_elec' & dob_elec = `dob_elec'"
		preserve	
		
				foreach var in fname mname lname {
					quietly gen `var'_sims = `var'`name_elec'
				}	
				
					quietly gen dob_sims = dob`dob_elec'
					
				order fname_sims mname_sims lname_sims dob_sims

				drop if fname_sims == "" & mname_sims == "" & lname_sims == "" & dob_sims == .
				drop if fname_sims == "" & mname_sims == "" & lname_sims == ""				

			quietly gen name_full_sims = lname`name_elec' + fname`name_elec' + mname`name_elec'
		
			quietly merge m:1 name_full_sims dob_sims using "${merge_sims}\simsbig_${simsdate}_for_merge_longB.dta"
				tab _merge
				keep if _merge == 3
					drop _merge
								
				tempfile V1b_dob`dob_elec'_ne`name_elec'
					save `V1b_dob`dob_elec'_ne`name_elec''		
				
		restore	
	} // End dob_elec
} // End name_elec

	use `V1b_dob1_ne1', replace
	forval name_elec = 1/9     /*9*/ {
		forval dob_elec = 1/3  /*3*/ {
			append using `V1b_dob`dob_elec'_ne`name_elec''
		} // End dob_elec
	} // End name_elec
		
duplicates drop
		
sort setren_id1 lname1 fname1 mname1	 

save "${temp}\merge_to_sims_V1b.dta", replace
	} // End merge_to_sims_V1b
	
* V1c: Exact Match on Last Name, First Name, and Birthday	
	if `merge_to_sims_V1c' ==1 {
		use "${matching}\full_student_level_dataset_new.dta", replace
		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1a.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12
		*		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1b.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12		
		
forval name_elec = 1/9     /*9*/ {
	forval dob_elec = 1/3  /*3*/ {
		di in red "C: name_elec = `name_elec' & dob_elec = `dob_elec'"
		preserve
		
				foreach var in fname mname lname {
					quietly gen `var'_sims = `var'`name_elec'
				}	
				
					quietly gen dob_sims = dob`dob_elec'
					
				order fname_sims mname_sims lname_sims dob_sims		
		
			drop if fname`name_elec' == "" & mname`name_elec' == "" & lname`name_elec' == "" & dob`dob_elec' == .
			drop if fname`name_elec' == "" & mname`name_elec' == "" & lname`name_elec' == ""				
		
			quietly merge m:1 fname_sims lname_sims dob_sims using "${merge_sims}\simsbig_${simsdate}_for_merge_longC.dta"
				tab _merge
				keep if _merge == 3
					drop _merge
				
				tempfile V1c_dob`dob_elec'_ne`name_elec'
					save `V1c_dob`dob_elec'_ne`name_elec''		
				
		restore	
	} // End dob_elec
} // End name_elec

	use `V1c_dob1_ne1', replace
	forval name_elec = 1/9             /*9*/ {
		forval dob_elec = 1/3  /*3*/ {
			append using `V1c_dob`dob_elec'_ne`name_elec''
		} // End dob_elec
	} // End name_elec
	
duplicates drop	
		
sort setren_id1 lname1 fname1 mname1			
		
cap drop name_full_sims*
	
save "${temp}\merge_to_sims_V1c.dta", replace	
	} // End merge_to_sims_V1c

* V1d: Exact Match on Last Name, First Name+mname, and Birthday	
	if `merge_to_sims_V1d' ==1 {
		use "${matching}\full_student_level_dataset_new.dta", replace	
		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1a.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12
		*		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1b.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12	
		*		
		*sort lname1 mname1 fname1 dob1
		*merge lname1 mname1 fname1 dob1 using "${temp}\merge_to_sims_V1c.dta"
		*	drop if _merge == 3
		*		drop _merge sasid_sims-year_gr_12				
		
forval name_elec = 1/9     /*9*/ {
	forval dob_elec = 1/3  /*3*/ {
		di in red "D: name_elec = `name_elec' & dob_elec = `dob_elec'"
		preserve
		
				foreach var in fname mname lname {
					quietly gen `var'_sims = `var'`name_elec'
				} 
				
			quietly gen first_middle_sims = fname`name_elec' + mname`name_elec'	
			
			quietly gen dob_sims = dob`dob_elec'
				
			order fname_sims mname_sims lname_sims first_middle_sims dob_sims			
		
			drop if fname`name_elec' == "" & mname`name_elec' == "" & lname`name_elec' == "" & dob`dob_elec' == .
			drop if fname`name_elec' == "" & mname`name_elec' == "" & lname`name_elec' == ""				
		
			quietly merge m:1 lname_sims first_middle_sims dob_sims using "${merge_sims}\simsbig_${simsdate}_for_merge_longD.dta"
				tab _merge
				keep if _merge == 3
					drop _merge
				
				tempfile V1d_dob`dob_elec'_ne`name_elec'
					save `V1d_dob`dob_elec'_ne`name_elec''		
				
		restore	
	} // End dob_elec
} // End name_elec

	use `V1d_dob1_ne1', replace
	forval name_elec = 1/9     /*9*/ {
		forval dob_elec = 1/3  /*3*/ {
			append using `V1d_dob`dob_elec'_ne`name_elec''
		} // End dob_elec
	} // End name_elec
drop first_middle_sims*	
duplicates drop	
		
sort setren_id1 lname1 fname1 mname1	
		
cap drop  name_full_sims*

save "${temp}\merge_to_sims_V1d.dta", replace	
	} // End merge_to_sims_V1d
	
	if `merge_to_sims_V1' ==1 {
		use "${temp}\merge_to_sims_V1a.dta", replace		
			append using "${temp}\merge_to_sims_V1b.dta"			
			append using "${temp}\merge_to_sims_V1c.dta"
			append using "${temp}\merge_to_sims_V1d.dta"
			drop name_full_sims
			duplicates drop
			
		* Fix SASID			
		preserve
			keep setren_id1 sasid*
			duplicates drop
			gen id = _n
		 
			reshape long sasid, i(setren_id1 id) j(refer_num) 	
				drop refer_num id
				drop if sasid == .
					duplicates drop
							
				sort setren_id1 sasid
				quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
					tab dup		
					
					replace dup = 1 if dup == 0	
						sum dup
						local max = r(max)
						di in red "`max'"								
							foreach var in sasid {
								rename `var' `var'__
							}							
						
							reshape wide sasid__, i(setren_id1)  j(dup)
								
							tempfile fix_sasid
								save `fix_sasid'				
		restore		
		
		merge m:1 setren_id1 using `fix_sasid'
			foreach var in sasid {
			di in red "forval i = 1/`max'"
				forval i = 1/`max' {
					replace `var'`i' = `var'__`i' if _merge == 3
				}
			}		
			drop _merge sasid__*			
				duplicates drop				
			
* Fix SIMS Name (keeping different versions)
	preserve
		keep sasid1 fname_sims mname_sims lname_sims
			duplicates drop
 
				gsort sasid1 lname_sims fname_sims -mname_sims
					quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
						tab dup		
						
						replace dup = 1 if dup == 0	
							sum dup
							local max = r(max)
							di in red "`max'"						
												
						reshape wide fname_sims mname_sims lname_sims, i(sasid1)  j(dup)
							
						tempfile fix_name
							save `fix_name'				
	restore	
	
	drop fname_sims mname_sims lname_sims
	merge m:1 sasid1 using `fix_name'

	foreach var in fname_sims mname_sims lname_sims {
		forval i = 1/`max' {
			format `var'`i' %15s
		}
	}
	
	foreach var in fname mname lname {
		forval i = 1/9 {
			format `var'`i' %15s
		}
	}	
		drop _merge 		
		duplicates drop	
		
	* Standardize Numeric Variables					
		foreach var in hisp_sims black_sims white_sims asian_sims otherrace_sims partic female male {
			bysort sasid1 : egen max_`var' = max(`var')
				replace  `var' = max_`var'
					drop max_`var'
		}	
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}	
				duplicates drop
		
	* Fix DOB SIMS
	format dob_sims %td
		preserve
			keep setren_id1 dob_sims
			duplicates drop
		 
			sort setren_id1 dob_sims
			quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
				tab dup		
				
				replace dup = 1 if dup == 0	
					sum dup
					local max = r(max)
					di in red "`max'"									
				reshape wide dob_sims, i(setren_id1)  j(dup)
					
				tempfile fix_dob
					save `fix_dob'				
		restore		
		
		drop dob_sims
		merge m:1 setren_id1 using `fix_dob'			
			drop _merge			
				duplicates drop		
		
		
	gsort setren_id1 sasid1 
		quietly by setren_id1 sasid1 : gen dup = cond(_N==1,0,_n)
			tab dup							
			order dup			
			*br if dup > 0
				assert dup == 0
				drop dup
							
save "${temp}\merge_to_sims_V1.dta", replace			
	} // End merge_to_sims_V1

	if `merge_to_sims_V2_dtalink' ==1 {
		
		 use "${matching}\full_student_level_dataset_new.dta", replace	

		* Remove instances that are already matched.
		merge 1:m setren_id1 using "${temp}\merge_to_sims_V1.dta"
			tab _merge			
			keep if _merge == 1			
				drop _merge sasid1-dob_sims2			

		* Match when DOB is not missing
		drop if dob1 == .
		drop if fname1 == "" & mname1 == "" & lname1 == ""
				
		if `merge_to_sims_V2_dtalink_x' ==1 { 
		*Only run if changes occured to name or dob as this takes + 7.5 Hours to run					
			preserve
				keep lname1 fname1 mname1 dob1
				
				gen lname_sims1 = lname1
				gen fname_sims1 = fname1
				gen mname_sims1 = mname1
				gen dob_sims1   = dob1 
				gen day_sims1   = day(dob1)
				gen month_sims1 = month(dob1)
				gen year_sims1  = year(dob1)
		
			* Note that there are still some duplicates where setren_ids have not been connected. 
				sort lname1 fname1 mname1 dob1
				quietly by lname1 fname1 mname1 dob1:  gen dup = cond(_N==1,0,_n)
					tab dup
					order dup
						*br if dup > 0		
						drop dup

		duplicates drop
		
		gen type = 0
			
		append using "${merge_sims}\simsbig_${simsdate}_for_merge_fuzzy.dta"
		
		keep lname_sims1 fname_sims1 mname_sims1 ///
			 dob_sims1 type ///
			 day_sims1 month_sims1 year_sims1
			replace type = 1 if type == .
				order type
					replace day_sims1   = day(dob_sims1)   if type == 1
					replace month_sims1 = month(dob_sims1) if type == 1
					replace year_sims1  = year(dob_sims1)  if type == 1	
		
		sort lname_sims1 fname_sims1 mname_sims1 dob_sims1
		
		drop if fname_sims1 == "" & mname_sims1 == "" & lname_sims1 == ""
		
		gen full_name = lname_sims1 + fname_sims1 + mname_sims1 
		
			* Note that there are also a lot of Students with the same name and DOB but different SASIDs 
				sort lname_sims1 fname_sims1 mname_sims1 dob_sims1
				quietly by lname_sims1 fname_sims1 mname_sims1 dob_sims1:  gen dup = cond(_N==1,0,_n)
					tab dup
					order dup
						*br if dup > 0		
						drop dup		

		duplicates drop							
		
		* http://fmwww.bc.edu/repec/scon2018/columbus18_Kranker.pdf
		dtalink full_name    7 -3  ///
				lname_sims1  7 -3  ///
		        fname_sims1  5 -3  ///
				mname_sims1  3 -1  ///
				dob_sims1    5  0 dob_sims1  3  0 7 dob_sims1 2 -6 30 ///
				month_sims1  3  0 year_sims1 2 -6 ///
				, source(type)
				
		tab _score
		
/*
Probabilist |
ic matching |
      score |      Freq.     Percent        Cum.
------------+-----------------------------------
       0.00 | 33,956,110       44.26       44.26
       1.00 | 36,300,416       47.32       91.58
       2.00 |     87,530        0.11       91.70
       3.00 |     82,714        0.11       91.81
       4.00 |    157,498        0.21       92.01
       5.00 |  2,913,096        3.80       95.81
       6.00 |  3,033,666        3.95       99.76
       7.00 |     27,224        0.04       99.80
       8.00 |     63,898        0.08       99.88
       9.00 |     38,714        0.05       99.93
      10.00 |     16,658        0.02       99.95
      11.00 |     13,742        0.02       99.97
      12.00 |        146        0.00       99.97
      13.00 |      6,156        0.01       99.98
      14.00 |      5,402        0.01       99.99
      15.00 |      3,956        0.01       99.99
      16.00 |      4,152        0.01      100.00
      17.00 |         50        0.00      100.00
      18.00 |        482        0.00      100.00
      19.00 |        396        0.00      100.00
      21.00 |         10        0.00      100.00
      23.00 |         18        0.00      100.00
      26.00 |         68        0.00      100.00
      29.00 |         92        0.00      100.00
      32.00 |         10        0.00      100.00
------------+-----------------------------------
      Total | 76,712,204      100.00
*/	

		save  "${temp}\merge_to_sims_V2_dtaweights_full.dta", replace

	restore	
	} // End
		use  "${temp}\merge_to_sims_V2_dtaweights_full.dta", replace
		
		do "${ppi_programs}\manual_edits_V2_Fuzzy_dtaweight.do"
	
		save  "${temp}\merge_to_sims_V2_dtaweights_small.dta", replace

	// temp for debugging	
	
	use "${matching}\full_student_level_dataset_new.dta", replace	

	* Remove instances that are already matched.
	merge 1:m setren_id1 using "${temp}\merge_to_sims_V1.dta"
		tab _merge			
		keep if _merge == 1			
			drop _merge sasid1-dob_sims2			

	* Match when DOB is not missing
	drop if dob1 == .
	drop if fname1 == "" & mname1 == "" & lname1 == ""		
	
	replace fname1 = subinstr(fname1, `"""',  "", .)
	merge 1:m lname1 fname1 mname1 dob1 using "${temp}\merge_to_sims_V2_dtaweights_small.dta" 
	preserve
	keep if _merge == 3
	tempfile merge_1
	save `merge_1'
	restore
		keep if _merge == 2
		drop _merge
		keep fname1 mname1 lname1 dob1 lname_sims1 fname_sims1 mname_sims1 dob_sims1
			preserve
			use "${matching}\full_student_level_dataset_new.dta", clear
			ren lname1 lnametemp
			ren fname1 fnametemp
			ren mname1 mnametemp
			ren lname2 lname1
			ren fname2 fname1
			ren mname2 mname1
			ren lnametemp lname2
			ren fnametemp fname2
			ren mnametemp mname2
			tempfile dtaweights_for_merge2
			save `dtaweights_for_merge2'
			restore
		merge 1:m lname1 fname1 mname1 dob1 using `dtaweights_for_merge2'	
		
		keep if _merge == 3
		order setren_id* lname1 fname1 mname1 lname2 fname2 mname2 lname3 fname3 mname3 lname4 fname4 mname4 lname5 fname5 mname5 lname6 fname6 mname6 lname7 fname7 mname7 lname8 fname8 mname8 lname9 fname9 mname9 dob1
		append using `merge_1'
		drop _merge _matchID _score
save "${temp}\merge_to_sims_V2_dtaweights_small_with_setrenid.dta", replace
use "${temp}\merge_to_sims_V2_dtaweights_small_with_setrenid.dta", clear
		* new code 8/13/2022
		* the vars that make it non-unique are lname_sims1 fmname_sims1, mname_sims1 
		* at a glance, many of these are the same kids, but different ordering of the names
		* I'm not sure how to capture/fix this except manually inspecting and having PII code to edit  - at another glance, there are some that are not obviously identical - I am concerned about one match i saw - how did david santiago dob sims 22aug1986 get matched to david lee adams? Is it just a First name DOB match??
		gen full_name1_sims = fname_sims1 + mname_sims1 + lname_sims1
		gen full_name1 = fname1 + mname1 + lname1
		isid full_name1 dob1
		duplicates tag full_name1_sims dob_sims1, gen (flag)
/*
       flag |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |      4,617       97.63       97.63
          1 |        112        2.37      100.00
------------+-----------------------------------
      Total |      4,729      100.00
*/
		browse if flag == 1
		* Sara after fixing - this concerning match is no longer there when I check for duplicates on full_name1_sims (fname_sims1 + mname_sims1 + lname_sims1) dob_sims1 level.
		* Then I do manual edits to fix duplicates
		preserve
		keep if flag == 1
		do "${ppi_programs}\manual_edits_fix_1tom_merge.do"
		tempfile manual_edit
		save `manual_edit'
		restore
		drop if flag == 1
		append using `manual_edit'
		//isid lname1 fname1 mname1 dob1 // this dosesn't work bc of missing mname
		isid full_name1_sims dob_sims1

	* Merge back on the SIMS data
	* ## this used to be m:m
	merge 1:m lname_sims1 fname_sims1 mname_sims1 dob_sims1 using "${merge_sims}\simsbig_${simsdate}_for_merge_fuzzy.dta"
		assert _merge != 1
		keep if _merge == 3
		drop _merge	flag	
	
	* Change back missing DOBs and Names to missing
		foreach var in dob_sims1 dob_sims2 dob_sims3 dob_sims4 {
			replace `var' = . if `var' == -10000
		}
			assert dob_sims4 == .
				drop dob_sims4
		forval i = 2/6 {
			gen flag = 1 if fname_sims`i' == "." & mname_sims`i' == "." & lname_sims`i' == "."
			replace fname_sims`i' = "" if fname_sims`i' == "." & flag == 1
			replace mname_sims`i' = "" if mname_sims`i' == "." & flag == 1
			replace mname_sims`i' = "" if mname_sims`i' == "-"
			replace lname_sims`i' = "" if lname_sims`i' == "." & flag == 1	
			replace name_full_sims`i' = "" if name_full_sims`i' == "..." & flag == 1
				drop flag
		}
		
		drop first_middle_sims*
		drop name_full_sims*
		
		gen male = 0
			replace male = 1 if gender_sims == 1
			replace male = . if gender_sims == .
		gen female = 0
			replace female = 1 if gender_sims == 0
			replace female = . if gender_sims == .
			drop gender_sims
			
		rename sasid_sims sasid1
		
		drop order full_name1_sims full_name1 keep
			
save "${temp}\merge_to_sims_V2_dtaweights.dta", replace						
					
	} // End merge_to_sims_V2
	
	if `merge_to_sims_Vs' ==1 {	

	use "${temp}\merge_to_sims_V1.dta", replace	
		gen match_source = 1		
			append using "${temp}\merge_to_sims_V2_dtaweights.dta"
				replace match_source = 2 if match_source == .
 
	sort sasid1 setren_id1	
	
	duplicates drop

* Manual edits:
	do "${ppi_programs}\manual_edits_6_merge_to_sims_Vs.do"
	
****************************************************************************	
* Check where duplicate SASIDS 
****************************************************************************
sort sasid1
quietly by sasid1:  gen dup = cond(_N==1,0,_n)
	tab dup
	order dup
		*br if dup > 0
		drop dup
		
			* Sasid
			gen double temp = sasid1
			preserve
				keep temp sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(temp id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort temp sasid
							quietly by temp :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(temp)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 temp using `fix_sasid'
				assert _merge != 2
				drop _merge temp				
				duplicates drop			
		
			* Setren ID
			preserve
				keep sasid1 setren_id*
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort sasid1 setren_id
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(sasid1)  j(dup)
									
								tempfile fix_setren
									save `fix_setren'				
			restore	
			drop setren_id*
			merge m:1 sasid1 using `fix_setren'
				assert _merge != 2
				drop _merge				
				duplicates drop						

			* Fix Name (keeping different versions)
			preserve
				keep sasid1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid1 lname fname -mname
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep sasid1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid1 dob
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep sasid1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort sasid1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort sasid1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														sasid1 == sasid1[_n-1]
									* Fix Street Name
										gsort sasid1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort sasid1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort sasid1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort sasid1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort sasid1 address_file_date
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(sasid1)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 sasid1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep sasid1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort sasid1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort sasid1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort sasid1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort sasid1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort sasid1 refer_date refer_dist
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(sasid1)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 sasid1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep sasid1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort sasid1 status_file_date status_order
					quietly by sasid1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by sasid1: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if sasid1 == sasid1[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort sasid1 status_file_date
							quietly by sasid1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort sasid1 status_file_date status_order
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(sasid1)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 sasid1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep sasid1  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid1 id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort sasid1 `var'
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(sasid1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep sasid1  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid1 id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort sasid1 `var'
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(sasid1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				*br if male ==1 & female == 1
				
				replace male = 1   if sasid1 == 1050556218 | sasid1 == 1097570609
				replace female = 0 if sasid1 == 1050556218 | sasid1 == 1097570609
				
				foreach var in `numeric_vars' {
					bysort sasid1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort sasid1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep sasid1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort sasid1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort sasid1 sib_dob 
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(sasid1)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 sasid1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop				
				
				
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
			
			* Fix DOB
			preserve
				keep setren_id1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
* Fix Match Source
		duplicates drop
			sort sasid1
			quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup	
				replace match_source = 3 if dup > 0
				drop dup
				duplicates drop				
				
		sort sasid1
		//duplicates tag sasid1, gen (flag)
		//drop if full_name1_sims == "" & full_name1 == "" & flag == 1
		//drop flag
		quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup

*****************************************************************************************			
* Check where duplicate Setren_IDs
*****************************************************************************************

			* Setren ID
			gen double temp = setren_id1
			preserve
				keep temp setren_id*
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(temp id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort temp setren_id
							quietly by temp :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(temp)  j(dup)
									
								tempfile fix_setren_id
									save `fix_setren_id'				
			restore	
			drop setren_id*
			merge m:1 temp using `fix_setren_id'
				assert _merge != 2
				drop _merge temp				
				duplicates drop			
		
			* Sasid
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 sasid
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge				
				duplicates drop						

			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep setren_id1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep setren_id1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort setren_id1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort setren_id1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														setren_id1 == setren_id1[_n-1]
									* Fix Street Name
										gsort setren_id1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort setren_id1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort setren_id1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort setren_id1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort setren_id1 address_file_date
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(setren_id1)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 setren_id1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep setren_id1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade*
					drop refer_date_sims*
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort setren_id1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort setren_id1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort setren_id1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort setren_id1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort setren_id1 refer_date refer_dist
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(setren_id1)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp1
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 setren_id1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp1 refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep setren_id1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort setren_id1 status_file_date status_order
					quietly by setren_id1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by setren_id1: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if setren_id1 == setren_id1[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort setren_id1 status_file_date
							quietly by setren_id1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort setren_id1 status_file_date status_order
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(setren_id1)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 setren_id1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep setren_id1  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep setren_id1  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				foreach var in `numeric_vars' {
					bysort setren_id1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort setren_id1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep setren_id1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort setren_id1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort setren_id1 sib_dob 
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(setren_id1)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 setren_id1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop				
				
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
			* Fix DOB
			preserve
				keep setren_id1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop
				
			* Setren ID
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 sasid
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
			
* Fix Match Source
		duplicates drop
			sort setren_id1
			quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
			tab dup	
				replace match_source = 3 if dup > 0
				drop dup
				duplicates drop				
				
		sort setren_id1
		//duplicates tag setren_id1, gen (flag)
		//drop if full_name1_sims == "" & full_name1 == "" & flag == 1
		//drop flag
		quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup
		sort sasid1
		quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup
						
	* Check at the student level
		isid sasid1 setren_id1
		
	save "${temp}\merge_to_sims.dta", replace	
	} // End merge_to_sims_Vs	

	* Find the Metco Students that are only in SIMS (not in Applicant Dataset)
	if `sims_only_metco' == 1  {
	use "${temp}\merge_to_sims.dta", replace
	keep sasid*
	duplicates drop
	
	gen expand = .
		order expand
			replace expand = 3 if sasid3 != . & expand == .
			replace expand = 2 if sasid2 != . & expand == .
			replace expand = 1 if sasid1 != . & expand == .
			
			expand expand

			sort sasid1			
			quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
				tab dup	
					order dup
						replace dup = 1 if dup == 0	

							replace sasid1 = sasid2 if dup == 2
							replace sasid1 = sasid3 if dup == 3
			rename sasid1 sasid			
			drop sasid2 sasid3 dup expand
			
			duplicates drop
			
	tempfile matched
	save `matched'
	
	use "${merge_sims}\all_metco_sims.dta", replace
	assert sasid4 == .
		drop sasid4
	order sasid1 sasid2 sasid3

	rename sasid1 sasid
	merge 1:1 sasid using `matched'
	order _merge
		keep if _merge == 1
			drop _merge
	rename sasid sasid1

	preserve	
		rename sasid2 sasid
		keep if sasid !=.
		merge 1:1 sasid using `matched'
		order _merge
			keep if _merge == 3
				drop _merge
		rename sasid sasid2
		
		tempfile sasid_2
		save `sasid_2'
	restore
	
		merge 1:1 sasid1 sasid2 sasid3 using `sasid_2'
			tab _merge
				keep if _merge == 1
					drop _merge
					
	preserve	
		rename sasid3 sasid
		keep if sasid !=.
		merge 1:1 sasid using `matched'
		order _merge
			keep if _merge == 3
				drop _merge
		rename sasid sasid3
		
		tempfile sasid_3
		save `sasid_3'
	restore
	
		merge 1:1 sasid1 sasid2 sasid3 using `sasid_3'
			tab _merge
				keep if _merge == 1
					drop _merge						
		
	forval i = 1/4 {
		foreach var in fname mname lname {
			rename `var'_sims_`i' `var'_sims`i'
			gen `var'`i' = `var'_sims`i'
		}
	}
	
	forval i = 1/3 {
		foreach var in dob {
			rename `var'_sims_`i' `var'_sims`i'
			gen `var'`i' = `var'_sims`i'
		}
	}			
	
	save "${temp}\sims_only_metco.dta", replace
	} // End sims_only_metco

	* Check for duplicates of students that did not Merge to SIMS 
	* Then combine Merged to SIMS, SIMS only and did not match to SIMS
	if `combine_with_without_sims' == 1  {
	use "${matching}\full_student_level_dataset_new.dta", replace	
	
	preserve
		use "${temp}\merge_to_sims.dta", replace	

		gen expand = .
			order expand
				replace expand = 4 if setren_id4 != . & expand == .
				replace expand = 3 if setren_id3 != . & expand == .
				replace expand = 2 if setren_id2 != . & expand == .
				replace expand = 1 if setren_id1 != . & expand == .
				
			expand expand
			drop expand

				sort setren_id1
				gen setren_id = .
					quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
						tab dup		
							order dup setren_id
								replace dup = 1 if dup == 0	

									replace setren_id = setren_id1 if dup == 1
									replace setren_id = setren_id2 if dup == 2
									replace setren_id = setren_id3 if dup == 3
									replace setren_id = setren_id4 if dup == 4		
	
	drop setren_id1 setren_id2 setren_id3 setren_id4
	drop dup
	
	sort setren_id
	quietly by setren_id : gen dup = cond(_N==1,0,_n)				
		tab dup
		order dup
		*br if dup > 0		
			assert dup == 0
				drop dup 

	tempfile merge_to_sims_temp
	save `merge_to_sims_temp'
	
	restore
	
	forval full_student = 1/4 {
		rename setren_id`full_student' setren_id
		merge m:1 setren_id using `merge_to_sims_temp'
			tab _merge
			keep if _merge == 1	
				drop _merge
		rename setren_id setren_id`full_student'
	} // End full_student
		sort setren_id1
		
		preserve
		
		order fname1 mname1 lname1 dob1
		format lname1 %15s
		format fname1 %15s
		format mname1 %15s
		
		drop if fname1 == "" & mname1 == "" & lname1 == ""
		
		sort fname1 mname1 lname1
		quietly by fname1 mname1 lname1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
				
				* For the most part, OK with these. No further de-duplictaion needed
		
		restore 
		

		quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup				
					
	isid setren_id1				
			
	save "${temp}\unmatched_metco_before.dta", replace
	
* Now, combine 
	use  "${temp}\merge_to_sims.dta", replace
		gen matched_to_sims = 1
		append using "${temp}\unmatched_metco_before.dta"
			replace matched_to_sims = 0 if matched_to_sims == .
		append using "${temp}\sims_only_metco.dta"
			replace matched_to_sims = 2 if matched_to_sims == .	
			format 		dob_sims1 %td	
				order dob_sims3, a(dob_sims2)
						
	* Manually Fix some cases where we have 2 sexes for a child	
		do "${ppi_programs}\manual_edits_6_merge_to_sims_sex.do"
			
	* Fix Refferals
		foreach var in withdrawn pending incomplete active declined graduated referred placement {
			tab `var', m
		}
			replace referred = 1 if matched_to_sims == 2
			replace active   = 1 if matched_to_sims == 2
		
	* Clean Source
		tab source_google_form matched_to_sims, m
			replace source_google_form = 0 if source_google_form == . 
			
		tab source_pdfs matched_to_sims, m
			replace source_pdfs = 0 if source_pdfs == . 
			
		gen source_sims = 0
			replace source_sims = 1 if matched_to_sims > 0
			
		tab source_electronic matched_to_sims, m
			replace source_electronic = 0 if source_electronic == .
			
	* Update 12/1/2021
		* We we have a date of referal and the status says not referred, changed to referred
			replace referred = 1 if referred == 0 & refer_date1 !=.			
			
	* Clean Statuses										
		replace active     = 1 if ///
				withdrawn == 1 | ///
				graduated == 1 
				
		replace referred   = 1 if /// 
				active    == 1 | ///
				declined  == 1 
				
		replace placement = 1 if ///
				referred == 1			
		
		replace pending = 1 if ///
				placement  == 1	
				
		replace pending = 1 if ///
				referred  == 1				
			
		save "${temp}\full_metco_toclean.dta", replace		
	}

	if `final_dedup' == 1 {
	use  "${temp}\full_metco_toclean.dta", replace
	
		do "${ppi_programs}\manual_edits_6_merge_to_sims_dedup.do"
		
	preserve
		keep if setren_id1 == .
		
			tempfile no_set_id
			save `no_set_id'		
	restore		
	drop if setren_id1 == .
		
			* Setren ID
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 setren_id
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge				
				duplicates drop			
		
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 sasid1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(setren_id1 sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 sasid1 lname fname -mname
							quietly by setren_id1 sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1 sasid1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 setren_id1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep setren_id1 sasid1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(setren_id1 sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 sasid1 dob
							quietly by setren_id1 sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1 sasid1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 setren_id1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep setren_id1 sasid1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(setren_id1 sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort setren_id1 sasid1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort setren_id1 sasid1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] 
									* Fix Street Name
										gsort setren_id1 sasid1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort setren_id1 sasid1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort setren_id1 sasid1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort setren_id1 sasid1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort setren_id1 sasid1 address_file_date
								quietly by setren_id1 sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip address_file_date , ///
									i(setren_id1 sasid1)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 setren_id1 sasid1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep setren_id1 sasid1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims1 refer_date_sims2
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(setren_id1 sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort setren_id1 sasid1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort setren_id1 sasid1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort setren_id1 sasid1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort setren_id1 sasid1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														sasid1 == sasid1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort setren_id1 sasid1 refer_date refer_dist
								quietly by setren_id1 sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(setren_id1 sasid1)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp1
				rename refer_date_sims2 temp2
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 setren_id1 sasid1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp1 refer_date_sims1
					rename temp2 refer_date_sims2
					
		* Clean Status by Group				
			preserve
				keep setren_id1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort setren_id1 status_file_date status_order
					quietly by setren_id1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by setren_id1: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if setren_id1 == setren_id1[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort setren_id1 status_file_date
							quietly by setren_id1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort setren_id1 status_file_date status_order
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(setren_id1)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 setren_id1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep setren_id1  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
			
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep setren_id1  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
													
				* Fix Numeric Vars
				foreach var in `numeric_vars' {
					bysort setren_id1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
			
				foreach var in year_in_first est_year_in_first {
					bysort setren_id1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep setren_id1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort setren_id1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort setren_id1 sib_dob 
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(setren_id1)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 setren_id1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
				
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
			* Fix DOB
			preserve
				keep setren_id1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
				foreach var in match_source matched_to_sims source_sims {
					bysort setren_id1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}
				duplicates drop

				
	preserve				
		sort setren_id1
		//duplicates tag setren_id1, gen (flag)
		//drop if full_name1_sims == "" & full_name1 == "" & flag == 1
		//drop flag
		quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
				assert dup == 0
	restore			
	
	* Update 1/28/2022
		* Realized that some matches still could be made! 
		* (Typically to one of the other name interations. We just do the fuzzy match on the first name, so this could be the cause).
			drop if setren_id1 == .
			
			*keep setren_id1 fname1-lname9 dob1 dob2 dob3 refer_date1 application_day*
			*	duplicates drop
			
			* Expand Name
				gen expand = .
					order expand
						replace expand = 9 if (fname9 != "" | mname9 != "" | lname9 != "" ) & expand == .
						replace expand = 8 if (fname8 != "" | mname8 != "" | lname8 != "" ) & expand == .
						replace expand = 7 if (fname7 != "" | mname7 != "" | lname7 != "" ) & expand == .
						replace expand = 6 if (fname6 != "" | mname6 != "" | lname6 != "" ) & expand == .
						replace expand = 5 if (fname5 != "" | mname5 != "" | lname5 != "" ) & expand == .
						replace expand = 4 if (fname4 != "" | mname4 != "" | lname4 != "" ) & expand == .
						replace expand = 3 if (fname3 != "" | mname3 != "" | lname3 != "" ) & expand == .
						replace expand = 2 if (fname2 != "" | mname2 != "" | lname2 != "" ) & expand == .
						replace expand = 1 if (fname1 != "" | mname1 != "" | lname1 != "" ) & expand == .
							drop if expand == .

					expand expand
						drop expand

						sort setren_id1
						gen fname = ""
						gen mname = ""
						gen lname = ""
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
									order dup
										replace dup = 1 if dup == 0	
										
										foreach var in fname lname mname {
											forval i = 1/9 {
												replace `var' = `var'`i' if dup == `i'
											}	
										}
						forval i = 1/9 {
							drop lname`i' fname`i' mname`i'
						}
						drop dup
						
			* Expand DOB
				gen expand = .
					order expand
						replace expand = 3 if dob3 !=. & expand == .
						replace expand = 2 if dob2 !=. & expand == .
						replace expand = 1 if dob1 !=. & expand == .
						replace expand = 1 if dob1 ==. & expand == .
						
					expand expand
						drop expand

						sort setren_id1 fname mname lname
						gen dob = .
							format dob %td
							quietly by setren_id1 fname mname lname:  gen dup = cond(_N==1,0,_n)
								tab dup		
									order dup
										replace dup = 1 if dup == 0	
										
										foreach var in dob {
											forval i = 1/3 {
												replace `var' = `var'`i' if dup == `i'
											}	
										}
								
						drop dob1 dob2 dob3 dup		
						
				order setren_id1 fname mname lname dob
					duplicates drop	
				
		preserve		
			keep fname mname lname dob
			duplicates drop			
			
			gen group_id = _n
			
				tempfile group_id
				save `group_id'		

		restore
		
		merge m:1 fname mname lname dob using `group_id' 
		assert _merge == 3
		drop _merge
		
			order group_id
				sort group_id
				
	* Standardize across same name and DOB
			* Setren
			preserve
				keep group_id setren_id*
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort group_id setren_id
							quietly by group_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(group_id)  j(dup)
									
								tempfile fix_setren_id
									save `fix_setren_id'				
			restore	
			drop setren_id*
			merge m:1 group_id using `fix_setren_id'
				assert _merge != 2
				drop _merge				
				duplicates drop	
				
			* Sasid
			preserve
				keep group_id sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort group_id sasid
							quietly by group_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(group_id)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 group_id using `fix_sasid'
				assert _merge != 2
				drop _merge				
				duplicates drop	
						
				* Fix Address
				preserve
					keep group_id poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort group_id  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort group_id -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														group_id == group_id[_n-1]
									* Fix Street Name
										gsort group_id -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort group_id -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort group_id  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort group_id -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														group_id == group_id[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort group_id address_file_date
								quietly by group_id :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(group_id)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 group_id using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep group_id  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims*
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort group_id refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														group_id == group_id[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort group_id refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														group_id == group_id[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort group_id refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														group_id == group_id[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort group_id refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														group_id == group_id[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort group_id refer_date refer_dist
								quietly by group_id :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(group_id)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp1
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 group_id using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp1 refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep group_id status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort group_id status_file_date status_order
					quietly by group_id status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by group_id: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if group_id == group_id[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort group_id status_file_date
							quietly by group_id status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort group_id status_file_date status_order
							quietly by group_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(group_id)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 group_id using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep group_id  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(group_id id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort group_id `var'
								quietly by group_id :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(group_id)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 group_id using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve	
					keep group_id  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(group_id id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort group_id `var'
								quietly by group_id :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(group_id)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 group_id using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				foreach var in `numeric_vars' matched_to_sims source_sims match_source {
					bysort group_id : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort group_id : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep group_id  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(group_id id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort group_id sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort group_id sib_dob 
								quietly by group_id :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(group_id)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 group_id using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				
			* Fix Name (keeping different versions)
			preserve
				keep group_id *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(group_id id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort group_id lname fname -mname
							quietly by group_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(group_id)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 group_id using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
			* Fix DOB
			preserve
				keep group_id dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(group_id id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort group_id dob
							quietly by group_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(group_id)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 group_id using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop

		sort group_id
		quietly by group_id :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup
		drop group_id
		
		preserve
			keep if sasid1 == .
			
			tempfile nosasids
				save `nosasids'
		restore
			drop if sasid1 == .
			
			* Setren
			preserve
				keep sasid1 setren_id*
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort sasid1 setren_id
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(sasid1)  j(dup)
									
								tempfile fix_setren_idsasid1
									save `fix_setren_idsasid1'				
			restore	
			drop setren_id*
			merge m:1 sasid1 using `fix_setren_idsasid1'
				assert _merge != 2
				drop _merge				
				duplicates drop	
				
			append using `nosasids'
		
**************************************************************************************************

	* Then get back to the Setren_id level.
		order setren_id*
		
		* Fix Name (keeping different versions)
			preserve
				keep setren_id1 fname mname lname
					drop if fname == "" & mname == "" & lname == "" 
					duplicates drop
					
							gsort setren_id1 -lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup					   					
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop fname mname lname
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 
				duplicates drop	

		* Fix DOB
			preserve
				keep setren_id1 dob
				drop if dob == .
				duplicates drop
			
					sort setren_id1 dob
					quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
						tab dup		
						
						replace dup = 1 if dup == 0	
							sum dup
								
						reshape wide dob, i(setren_id1)  j(dup)
							
						tempfile fix_dob
							save `fix_dob'				
			restore		
			drop dob
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 
				duplicates drop	
				
			* Setren ID
			gen double temp = setren_id1
			preserve
				keep temp setren_id*
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(temp id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort temp setren_id
							quietly by temp :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(temp)  j(dup)
									
								tempfile fix_setren_id
									save `fix_setren_id'				
			restore	
			drop setren_id*
			merge m:1 temp using `fix_setren_id'
				assert _merge != 2
				drop _merge temp				
				duplicates drop				
		
			* Sasid
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 sasid
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge				
				duplicates drop		
				
				* Fix Address
				preserve
					keep setren_id1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort setren_id1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort setren_id1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														setren_id1 == setren_id1[_n-1]
									* Fix Street Name
										gsort setren_id1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort setren_id1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort setren_id1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort setren_id1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort setren_id1 address_file_date
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(setren_id1)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 setren_id1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep setren_id1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims*
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort setren_id1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort setren_id1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort setren_id1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort setren_id1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort setren_id1 refer_date refer_dist
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(setren_id1)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp1
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 setren_id1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp1 refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep setren_id1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort setren_id1 status_file_date status_order
					quietly by setren_id1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by setren_id1: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if setren_id1 == setren_id1[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort setren_id1 status_file_date
							quietly by setren_id1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort setren_id1 status_file_date status_order
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(setren_id1)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 setren_id1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep setren_id1  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep setren_id1  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(setren_id1 id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort setren_id1 `var'
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(setren_id1)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 setren_id1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				foreach var in `numeric_vars' matched_to_sims source_sims match_source {
					bysort setren_id1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort setren_id1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
			
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
			* Fix DOB
			preserve
				keep setren_id1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop
				
				* Fix Siblings
				preserve
					keep setren_id1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort setren_id1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort setren_id1 sib_dob 
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(setren_id1)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 setren_id1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				
		sort setren_id1
		quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup
						
	preserve
		drop if sasid1 == .
		sort sasid1
		quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup
			order dup
				*br if dup > 0
					assert dup == 0	
						drop dup	
						
	restore

	append using `no_set_id'
	
	preserve
		keep if sasid1 == .
		
			tempfile no_sasid1
			save `no_sasid1'		
	restore	
		drop if sasid1 == .

			* Fix Name (keeping different versions)
			preserve
				keep sasid1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid1 lname fname -mname
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}
			
			* Fix Name (keeping different versions)
			preserve
				keep sasid1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid1 lname fname -mname
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop			
	
			* Fix DOB
			preserve
				keep sasid1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid1 dob
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}
			
			* Fix DOB
			preserve
				keep sasid1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid1 dob
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop		
	
	foreach var in `numeric_vars' {
		bysort sasid1 : egen max_`var' = max(`var')
			drop  `var' 
				rename max_`var' `var'
	}	

	foreach var in year_in_first est_year_in_first refer_date_sims1 {
		bysort sasid1 : egen min_`var' = min(`var')
			replace  `var' = min_`var'
				drop min_`var'
	}				
	duplicates drop		
	
	append using `no_sasid1'
	
	preserve
		keep if sasid1 != .
		sort sasid1		
			quietly by sasid1 : gen dup = cond(_N==1,0,_n)				
				tab dup
				order dup
				*br if dup > 0 
				assert dup == 0
	restore
	
	preserve
		keep if setren_id1 != .
		sort setren_id1		
			quietly by setren_id1 : gen dup = cond(_N==1,0,_n)				
				tab dup
				order dup
				*br if dup > 0 
				assert dup == 0
	restore
	
* Fix Formatting
	forval i = 1/9 {
		format lname`i' %15s
		format fname`i' %15s
		format mname`i' %18s		
	}
	forval i = 1/7 {
		format lname_sims`i' %15s
		format fname_sims`i' %15s
		format mname_sims`i' %18s		
	}	
	forval i = 1/11 {
		format gf_refer_date`i' %td
	}	
		format ed_refer_date1 %td
		format withdraw_date %td
		
		drop refer_date_sims2
		
	* Fix Twin/Sibling
		tab twin sibling,m
			replace sibling = 1 if twin == 1

	preserve
	* Update 12/21/2021
		* Generate a Full METCO List for Vital Stats Merge
			keep setren_id* sasid* fname* mname* lname* dob* sex*

		save "${data_for_analysis}\full_metco_for_vital_stats.dta", replace	
	restore
	
	save "${temp}\full_metco_handmatch.dta", replace		
	
	} // final_dedup
	
	if `manual_matches' == 1 {
	use "${temp}\full_metco_handmatch.dta", replace
	
	* Output unmatched Applicants for further matches!
		keep if sasid1 == .
		
		* Update 3/17/2022
			 * Remove extra Setren_IDs that were created for students who didn't initially match.		
			
			 *br if setren_id5 > 9000000 & setren_id5 != .
				//replace setren_id5 = . if setren_id5 > 9000000 & setren_id5 != .
			*br if setren_id4 > 9000000 & setren_id4 != .
				replace setren_id4 = . if setren_id4 > 9000000 & setren_id4 != .
			 *br if setren_id3 > 9000000 & setren_id3 != .
				replace setren_id3 = . if setren_id3 > 9000000 & setren_id3 != .
			 *br if setren_id2 > 9000000 & setren_id2 != .
				replace setren_id2 = . if setren_id2 > 9000000 & setren_id2 != .	
			
		save "${temp}\unmatched_metco.dta", replace
		
		if `fuzzymatch_to_sims' == 1 {
			* Clean up METCO data *
				use "${temp}\unmatched_metco.dta", replace

				* Generate full_name variable for fuzzy match
					gen full_name = fname1 + mname1 + lname1

				* Generate new dob variable for fuzzy match
					gen dob = dob1
					
				* Check data at the student level
					gsort fname1 mname1 lname1 dob1		
						quietly by fname1 mname1 lname1 dob1 : gen dup = cond(_N==1,0,_n)				
							tab dup
							order dup
							*br if dup > 0 
								assert dup == 0
									drop dup					
					
				* Keep important vars
					keep full_name dob fname1 mname1 lname1 dob1 setren_id1
					
				* Create by-year datasets
					gen year = year(dob)
						tab year
						
						* No SIMS DOB below 1977
						drop if year < 1977
						
						sum year
						local min_year = `r(min)'
						local max_year = `r(max)'
						
				forval i = `min_year'/`max_year' {	
				preserve
					keep if year == `i'
					drop year 
				
				* Save data in a new file
					save "${temp}\unmatched_metco_for_fuzzymatch_`i'.dta", replace
				restore
				}
		
			*Clean SIMS data *
				clear
				use "${merge_sims}\simsbig_${simsdate}_for_merge.dta"

				* Generate full_name variable for fuzzy match so that we use the same variable name in fuzzymatch 
					gen full_name = name_full_sims1

				* Generate dob variable for fuzzy match
					gen dob = dob_sims1

				* Sort data by sasid *
					sort sasid_sims
					
				* Check data at the sasid level
					isid sasid_sims
					
				* Keep important vars
					keep full_name sasid_sims fname_sims1 mname_sims1 lname_sims1 name_full_sims1 dob_sims1 dob
					
				* Create by-year datasets
					gen year = year(dob)
						
				forval y = `min_year'/`max_year' {
				preserve
					keep if year == `y'
					drop year 
				
				* Save data in a new file
					save "${temp}\unmatched_sims_for_fuzzymatch_`y'.dta", replace
				restore
				}				

		*** Fuzzy match between METCO and SIMS ***
			* Load SIMS data (by year) from above and fuzzy merge
				clear
				forval y = `min_year'/`max_year' {
					use "${temp}\unmatched_sims_for_fuzzymatch_`y'.dta"

					* Use reclink to perform a fuzzy merge with the SIMS data from above, merging on full_name and dob
						reclink2 full_name dob using "${temp}\unmatched_metco_for_fuzzymatch_`y'.dta", gen(matchscore) idm(sasid_sims) idu(setren_id1)
						
						drop if matchscore == . 
						drop _merge
						
						save "${temp}\reclink_full_matches_`y'.dta", replace
				}		
				
				clear
				use "${temp}\reclink_full_matches_1977.dta"
				forval y = 1978/2018 {
					append using "${temp}\reclink_full_matches_`y'.dta"
				}		
				
				order matchscore fname_sims1 mname_sims1 lname_sims1 dob_sims1 fname1 mname1 lname1 dob1 
				
				* Sort by the matching distance score
					gsort -matchscore

				* Generate approve or disapprove match variable, where 0 is disapprove and 1 is, approved by hand
					gen approve = 0	
					
				* Hand Match to approve:
				do "${ppi_programs}/manual_edits_6_merge_to_sims_handmatch.do"
				
				keep if approve == 1
					save "${temp}\fuzzymatch_sims_metco_full_v1.dta", replace
					
		} // End fuzzymatch_to_sims

		if `cleaning_manual_matches' == 1 {
			use "${temp}\fuzzymatch_sims_metco_full_v1.dta", clear
			gen full_name1 = fname1 + mname1 + lname1
			bys full_name1 dob1: egen maxscore = max(matchscore)
			keep if matchscore == maxscore
			duplicates drop full_name1 dob1, force
			drop full_name1 maxscore
			save "${temp}\fuzzymatch_sims_metco_full_v2.dta", replace
			use "${temp}\unmatched_metco.dta", replace
	
				drop sasid* *sims* partic year_in_first est_year_in_first
			// this used to be m:m
			merge m:1 lname1 fname1 mname1 dob1 using "${temp}\fuzzymatch_sims_metco_full_v2.dta" 	
				assert _merge !=2
				
				preserve
					keep if _merge == 1
					
					drop matchscore sasid_sims name_full_sims1 full_name Ufull_name dob Udob _merge
					tempfile still_didnot_match
						save `still_didnot_match'
				restore
				
				keep if _merge == 3
				drop matchscore sasid_sims name_full_sims1 full_name Ufull_name dob Udob _merge

			* Merge back on the SIMS data	
			* this used to be m:m merge
			merge 1:m lname_sims1 fname_sims1 mname_sims1 dob_sims1 using "${merge_sims}\simsbig_${simsdate}_for_merge.dta" 
				assert _merge != 1
				keep if _merge == 3
				drop _merge		
			
			* Change back missing DOBs and Names to missing
				foreach var in dob_sims1 dob_sims2 dob_sims3 dob_sims4 {
					replace `var' = . if `var' == -10000
				}
					assert dob_sims3 == .
						drop dob_sims3
					assert dob_sims4 == .
						drop dob_sims4
				forval i = 2/6 {
					gen flag = 1 if fname_sims`i' == "." & mname_sims`i' == "." & lname_sims`i' == "."
					replace fname_sims`i' = "" if fname_sims`i' == "." & flag == 1
					replace mname_sims`i' = "" if mname_sims`i' == "." & flag == 1
					replace mname_sims`i' = "" if mname_sims`i' == "-"
					replace lname_sims`i' = "" if lname_sims`i' == "." & flag == 1	
					replace name_full_sims`i' = "" if name_full_sims`i' == "..." & flag == 1
						drop flag
				}
				
				drop first_middle_sims*
				drop name_full_sims*
				
					replace male = 1 if gender_sims == 1
					replace female = 1 if gender_sims == 0
					drop gender_sims
					
				rename sasid_sims sasid1	
								
		* Get Data to the Student Level:
		{
			* Sasid
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 sasid
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge				
				duplicates drop						

			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/6 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/6 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep setren_id1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/2 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/2 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep setren_id1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort setren_id1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort setren_id1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														setren_id1 == setren_id1[_n-1]
									* Fix Street Name
										gsort setren_id1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort setren_id1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort setren_id1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort setren_id1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort setren_id1 address_file_date
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(setren_id1)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 setren_id1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep setren_id1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade*
					drop refer_date_sims*
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort setren_id1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort setren_id1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort setren_id1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort setren_id1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														setren_id1 == setren_id1[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort setren_id1 refer_date refer_dist
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(setren_id1)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp1
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 setren_id1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp1 refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep setren_id1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort setren_id1 status_file_date status_order
					quietly by setren_id1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by setren_id1: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if setren_id1 == setren_id1[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort setren_id1 status_file_date
							quietly by setren_id1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort setren_id1 status_file_date status_order
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(setren_id1)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 setren_id1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop			
														
				* Fix Numeric Vars
				foreach var in `numeric_vars' {
					bysort setren_id1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort setren_id1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep setren_id1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort setren_id1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort setren_id1 sib_dob 
								quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(setren_id1)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 setren_id1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop				
				
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort setren_id1 lname fname -mname
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
				
			* Fix DOB
			preserve
				keep setren_id1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(setren_id1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort setren_id1 dob
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(setren_id1)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 setren_id1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop
				
			* Setren ID
			preserve
				keep setren_id1 sasid*
					duplicates drop
					gen id = _n
		 
					reshape long sasid, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if sasid == .
							duplicates drop					
						 
							gsort setren_id1 sasid
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide sasid, i(setren_id1)  j(dup)
									
								tempfile fix_sasid
									save `fix_sasid'				
			restore	
			drop sasid*
			merge m:1 setren_id1 using `fix_sasid'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
				foreach var in year_in_first est_year_in_first refer_date_sims1 {
					bysort sasid1 : egen min_`var' = min(`var')
						replace  `var' = min_`var'
							drop min_`var'
				}				
				duplicates drop					
		}				
				
			isid sasid1 setren_id1		
			
			gen matched_to_sims = 1 
			gen source_sims	= 1
			
			* Merge back on those that did not match
			append using `still_didnot_match'
			
			replace matched_to_sims = 0 if matched_to_sims == .
			replace source_sims	= 0 if source_sims == .			
			
			tempfile after_handmatch
				save `after_handmatch'
			
	* Add back to Full applicant dataset
	use "${temp}\full_metco_handmatch.dta", replace
		keep if sasid1 != .				
		
			append using  `after_handmatch'
			
		* Get Data to the Student Level:	
		preserve
			keep if sasid1 == .
			
			tempfile still_unmatched
				save `still_unmatched'
			
		restore
			
			keep if sasid1 != .

	gen expand = .
		order expand
			replace expand = 4 if sasid4 != . & expand == .
			replace expand = 3 if sasid3 != . & expand == .
			replace expand = 2 if sasid2 != . & expand == .
			replace expand = 1 if sasid1 != . & expand == .
			
			expand expand

			sort sasid1	setren_id1
			gen long sasid = .
				order sasid, b(sasid1)
			quietly by sasid1 setren_id1:  gen dup = cond(_N==1,0,_n)
				tab dup	
					order dup
						replace dup = 1 if dup == 0	
						
							replace sasid = sasid1 if dup == 1
							replace sasid = sasid2 if dup == 2
							replace sasid = sasid3 if dup == 3
							replace sasid = sasid4 if dup == 4	
			sort sasid
	
			drop dup expand 
			
			duplicates drop
			
			{		
			* Setren ID
			preserve
				keep sasid setren_id*
					drop if setren_id1 == .
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort sasid setren_id
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(sasid)  j(dup)
									
								tempfile fix_setren
									save `fix_setren'				
			restore	
			drop setren_id*
			merge m:1 sasid using `fix_setren'
				assert _merge != 2
				drop _merge				
				duplicates drop						

			* Fix Name (keeping different versions)
			preserve
				keep sasid fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid lname fname -mname
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 sasid using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep sasid dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(sasid id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid dob
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 sasid using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep sasid poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort sasid  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort sasid -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														sasid == sasid[_n-1]
									* Fix Street Name
										gsort sasid -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort sasid -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort sasid  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort sasid -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														sasid == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort sasid address_file_date
								quietly by sasid :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(sasid)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 sasid using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep sasid  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort sasid refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														sasid == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort sasid refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														sasid == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort sasid refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														sasid == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort sasid refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														sasid == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort sasid refer_date refer_dist
								quietly by sasid :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(sasid)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 sasid using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep sasid status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort sasid status_file_date status_order
					quietly by sasid status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by sasid: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if sasid == sasid[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort sasid status_file_date
							quietly by sasid status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort sasid status_file_date status_order
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(sasid)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 sasid using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep sasid  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort sasid `var'
								quietly by sasid :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(sasid)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep sasid  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort sasid `var'
								quietly by sasid :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(sasid)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				*br if male ==1 & female == 1
				foreach var in `numeric_vars' {
					bysort sasid : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort sasid : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep sasid  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(sasid id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort sasid sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort sasid sib_dob 
								quietly by sasid :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(sasid)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 sasid using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop		
		
			* Fix Name (keeping different versions)
			preserve
				keep sasid *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(sasid id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid lname fname -mname
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 sasid using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
			
			* Fix DOB
			preserve
				keep sasid dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(sasid id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid dob
							quietly by sasid :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 sasid using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
		drop approve			
					
		gsort sasid -matched_to_sims
			bysort sasid : carryforward matched_to_sims, replace	
		gsort sasid -source_sims
			bysort sasid : carryforward source_sims, replace
		gsort sasid -match_source
			bysort sasid : carryforward match_source, replace			
			duplicates drop	
			order matched_to_sims source_sims match_source, a(dob_sims3)
				
	* Fix SASID
		gsort sasid1 -sasid2 -sasid3 -sasid4
			bysort sasid1 : carryforward sasid2, replace	
			bysort sasid1 : carryforward sasid3, replace
			bysort sasid1 : carryforward sasid4, replace	
				duplicates drop
				
	sort sasid
		quietly by sasid :  gen dup = cond(_N==1,0,_n)
			tab dup					
		replace matched_to_sims = 1 if dup > 0
			drop dup
			duplicates drop
				
			}

	sort sasid
		quietly by sasid :  gen dup = cond(_N==1,0,_n)
			tab dup	
				assert dup == 0
					drop dup
								
	drop sasid
		duplicates drop
		
			{		
			* Setren ID
			preserve
				keep sasid1 setren_id*
					drop if setren_id1 == .
					duplicates drop
					gen id = _n
		 
					reshape long setren_id, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if setren_id == .
							duplicates drop					
						 
							gsort sasid1 setren_id
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide setren_id, i(sasid1)  j(dup)
									
								tempfile fix_setren
									save `fix_setren'				
			restore	
			drop setren_id*
			merge m:1 sasid1 using `fix_setren'
				assert _merge != 2
				drop _merge				
				duplicates drop						

			* Fix Name (keeping different versions)
			preserve
				keep sasid1 fname* mname* lname*
				drop *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname mname lname, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid1 lname fname -mname
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			forval i = 1/7 {
				rename fname_sims`i' tempf`i'
				rename mname_sims`i' tempm`i'
				rename lname_sims`i' templ`i'
			}
			drop fname* mname* lname*
			merge m:1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				
			forval i = 1/7 {
				rename tempf`i' fname_sims`i'
				rename tempm`i' mname_sims`i'
				rename templ`i' lname_sims`i'
			}				
			
			* Fix DOB
			preserve
				keep sasid1 dob*
				drop dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob , i(sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid1 dob
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore	
			forval i = 1/3 {
				rename dob_sims`i' temp`i'
			}			
			drop dob*
			merge m:1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
			forval i = 1/3 {
				rename temp`i' dob_sims`i'
			}				
		
				* Fix Address
				preserve
					keep sasid1 poboxyn* street_nu* address* apt* city* state* zip* address_file_date* 
					drop if poboxyn1 == "" & street_nu1 == "" & address1 == "" & apt1 == "" & city1 == "" & state1 == "" & zip1 == "" & address_file_date1 == .
					gen id = _n
				 
					reshape long poboxyn street_nu address apt city state zip address_file_date, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if poboxyn == "" & street_nu == "" & address == "" & apt == "" & city == "" & state == "" & zip == "" & address_file_date == .
							duplicates drop	
					
									* Fix Zipcode
										gsort sasid1  -city -zip 
										replace zip = zip[_n-1] if zip == "" & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1]
									* Fix City
										gsort sasid1 -zip -city 											
										replace city = city[_n-1] if city == "" & ///
														zip == zip[_n-1] & ///
														sasid1 == sasid[_n-1]
									* Fix Street Name
										gsort sasid1 -city -street_nu -address 
										replace address = address[_n-1] if address == "" & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1]
														
									* Fix Street Number
										gsort sasid1 -city -address -street_nu
										replace street_nu = street_nu[_n-1] if street_nu == "" & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1]
									* Fix Apartment number
										replace apt = apt[_n-1] if apt == "" & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]	
									* Fix POBOX
										gsort sasid1  -city -address -street_nu -poboxyn
										replace poboxyn = poboxyn[_n-1] if poboxyn == "" & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
									* Fix Date
										gsort sasid1 -city -address -street_nu -zip -address_file_date
										replace address_file_date = address_file_date[_n-1] if address_file_date == . & ///
														sasid1 == sasid[_n-1] & ///
														city == city[_n-1] & ///
														address == address[_n-1] & ///
														street_nu == street_nu[_n-1]														
					duplicates drop
					
								sort sasid1 address_file_date
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0	
									sum dup						
								
									reshape wide poboxyn  street_nu  address  apt  city  state  zip   address_file_date , i(sasid)  j(dup)
										
										
									tempfile fix_add
										save `fix_add'				
				restore		
				
				drop poboxyn* street_nu* address* apt* city* state* zip* address_file_date*
				merge m:1 sasid1 using `fix_add'
					assert _merge != 2
					drop _merge 				
					duplicates drop							
					
				* Fix Referrals
				preserve
					keep sasid1  ///
						 refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
					drop refer_date_sims
					drop if refer_dist1 == "" & refer_date1 == . & refer_decline1 == "" & refer_decline_rez1 == "" & refer_grade1 == "" 
					gen id = _n
				 
					reshape long refer_dist refer_date refer_decline refer_decline_rez refer_grade , i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if refer_dist == "" & refer_date == . & refer_decline == "" & refer_decline_rez == "" & refer_grade == "" 
							duplicates drop
							
									* Fix refer date
										gsort sasid1 refer_dist refer_decline -refer_date 
										replace refer_date = refer_date[_n-1] if refer_date == . & ///
														sasid1 == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_decline == refer_decline[_n-1] 
									* Fix refer decline
										gsort sasid1 refer_dist -refer_date -refer_decline 
										replace refer_decline = refer_decline[_n-1] if refer_decline == "" & ///
														sasid1 == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 	
									* Fix refer decline reason
										gsort sasid1 refer_dist -refer_date -refer_decline_rez 
										replace refer_decline_rez = refer_decline_rez[_n-1] if refer_decline_rez == "" & ///
														sasid1 == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1] 			
									* Fix refer grade
										gsort sasid1 refer_dist -refer_date -refer_grade 
										replace refer_grade = refer_grade[_n-1] if refer_grade == "" & ///
														sasid1 == sasid[_n-1] & ///
														refer_dist == refer_dist[_n-1] & ///					
														refer_date == refer_date[_n-1]	
					duplicates drop
					
								sort sasid1 refer_date refer_dist
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide refer_dist refer_date refer_decline refer_decline_rez refer_grade ///
									 , i(sasid)  j(dup)
										
									tempfile fix_ref_date
										save `fix_ref_date'				
				restore		
				rename refer_date_sims1 temp
				drop refer_dist* refer_date* refer_decline* refer_decline_rez* refer_grade* 
				merge m:1 sasid1 using `fix_ref_date'
					assert _merge != 2
					drop _merge 				
					duplicates drop	
					rename temp refer_date_sims1
					
		* Clean Status by Group				
			preserve
				keep sasid1 status* status_file_date*
					drop if status1 == "" & status_file_date1 == .
					gen id = _n
				 
					reshape long status status_file_date , i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if status == "" & status_file_date == .
							duplicates drop	
					
					gen status_order = 0
						replace status_order = 1 if status == "PENDING"
						replace status_order = 2 if status == "INTERVIEW"
						replace status_order = 3 if status == "DROPMAIL"
						replace status_order = 4 if status == "NEW"
						replace status_order = 5 if status == "TRANSFER"
						replace status_order = 6 if status == "ACTIVE"
						replace status_order = 7 if status == "CONTINUE"
						replace status_order = 8 if status == "PEN766"
						replace status_order = 9 if status == "DROPPED"
						replace status_order = 10 if status == "DROPPED/PL"					
					
					* Some PDF's Contain multiple entires for a student (Ex: 136 has 
					* 3 entries for the same student blank, NEW, and ACTIVE for the same student)
					sort sasid1 status_file_date status_order
					quietly by sasid1 status_file_date:  gen dup = cond(_N==1,0,_n)
						tab dup
						order dup
							*br if dup > 0	
							* ### I am deciding to meep the "later" status for a given file_date
								drop if dup == 1
									drop dup
					
					* Keep the first by file date	
						by sasid: generate n1 = _n		
						gen keep_flag = 1 if n1 == 1
							replace keep_flag = 1 if sasid1 == sasid[_n-1] & status != status[_n-1]
							
							keep if keep_flag == 1
							
							drop n1 keep_flag
							
							sort sasid1 status_file_date
							quietly by sasid1 status_file_date :  gen dup2 = cond(_N==1,0,_n)
								tab dup2
										
							sort sasid1 status_file_date status_order
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								drop dup2 status_order
								
								replace dup = 1 if dup == 0
								
								reshape wide status status_file_date, i(sasid)  j(dup)	
								
								tempfile fix_status
									save `fix_status'	
			restore

					drop status* status_file_date*
					merge m:1 sasid1 using `fix_status'				
					assert _merge != 2
					drop _merge 				
					duplicates drop
					
			* Fix Other variables (string) (keeping multiple)
				foreach var in `clean_vars_s' {
				di in red "`var'"
				preserve
					keep sasid1  `var'* 
					drop if `var'1 == "" 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid1 id) j(refer_num)	
						drop if `var' == ""	
							drop refer_num id	
								duplicates drop						
					
								sort sasid1 `var'
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide `var', i(sasid)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}		
				
			* Fix Other variables (numeric) (keeping multiple)
				foreach var in `clean_vars_n' {
				di in red "`var'"
				preserve			
					keep sasid1  `var'* 
					drop if `var'1 == . 	
					duplicates drop
					
						gen id = _n
						reshape long `var', i(sasid1 id) j(refer_num)	
						drop if `var' == .	
							drop refer_num id	
								duplicates drop						
				
								sort sasid1 `var'
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
					
									reshape wide `var', i(sasid)  j(dup)
										
									tempfile fix_`var'
										save `fix_`var''				
				restore		
				
				drop `var'*
				merge m:1 sasid1 using `fix_`var''
					assert _merge != 2
					drop _merge 				
					duplicates drop					
				}				
														
				* Fix Numeric Vars
				*br if male ==1 & female == 1
				foreach var in `numeric_vars' {
					bysort sasid1 : egen max_`var' = max(`var')
						drop  `var' 
							rename max_`var' `var'
				}	

				duplicates drop
				
				foreach var in year_in_first est_year_in_first {
					bysort sasid1 : egen min_`var' = max(`var')
						drop  `var' 
							rename min_`var' `var'
				}	

				duplicates drop	
				
				* Fix Siblings
				preserve
					keep sasid1  ///
						 sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
					drop if sib_fname1 == "" & sib_lname1 == "" & sib_dob1 == . & ///
					        sib_metco_dist1 == "" & sib_metco_dist_other1 == "" & /// 
							sib_fname2 == "" & sib_lname2 == "" & sib_dob2 == . & ///
					        sib_metco_dist2 == "" & sib_metco_dist_other2 == "" 
					gen id = _n
				 
					reshape long sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						
						drop if sib_fname == "" & sib_lname == "" & sib_dob == . & sib_metco_dist == "" & sib_metco_dist_other == "" 
							duplicates drop
								format sib_dob %td
								
								bysort sasid1 sib_fname sib_lname sib_dob : egen max_sib_metco = max(sib_metco)
									drop sib_metco
									rename max_sib_metco sib_metco
									duplicates drop
							
								gsort sasid1 sib_dob 
								quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
									tab dup		
									
									replace dup = 1 if dup == 0				
								
									reshape wide sib_fname sib_lname sib_dob sib_metco sib_metco_dist sib_metco_dist_other  ///
									        , i(sasid)  j(dup)
										
									tempfile fix_sibling
										save `fix_sibling'				
				restore		
				drop sib_fname* sib_lname* sib_dob* sib_metco* sib_metco_dist* sib_metco_dist_other*
				merge m:1 sasid1 using `fix_sibling'
					assert _merge != 2
					drop _merge 				
					duplicates drop		
		
			* Fix Name (keeping different versions)
			preserve
				keep sasid1 *name_sims*
					duplicates drop
					gen id = _n
		 
					reshape long fname_sims mname_sims lname_sims, i(sasid1 id) j(refer_num) 	
						drop refer_num id
						drop if fname == "" & mname == "" & lname == "" 
							duplicates drop					
						 
							gsort sasid1 lname fname -mname
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide fname mname lname, i(sasid)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop *name_sims*
			merge m:1 sasid1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop					
			
			* Fix DOB
			preserve
				keep sasid1 dob_sims*
				duplicates drop
				gen id = _n
			 
				reshape long dob_sims , i(sasid1 id) j(refer_num) 					
					drop refer_num id	
						drop if dob == .
						duplicates drop
							sort sasid1 dob
							quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
								sum dup

								reshape wide dob, i(sasid)  j(dup)
									
								tempfile fix_dob
									save `fix_dob'				
			restore		
			drop dob_sims*
			merge m:1 sasid1 using `fix_dob'
				assert _merge != 2
				drop _merge 				
				duplicates drop		
					
		gsort sasid1 -matched_to_sims
			bysort sasid1 : carryforward matched_to_sims, replace	
		gsort sasid1 -source_sims
			bysort sasid1 : carryforward source_sims, replace
		gsort sasid1 -match_source
			bysort sasid1 : carryforward match_source, replace			
			duplicates drop	
			order matched_to_sims source_sims match_source, a(dob_sims3)
				
			}		
		
	sort sasid1
		quietly by sasid1 :  gen dup = cond(_N==1,0,_n)
			tab dup	
				assert dup == 0
					drop dup	
					
			append using  `still_unmatched'
			save "${temp}\full_metco_tovars.dta", replace

	} // End cleaning_manual_matches
	
	} // End manual_matches
	
	if `create_variables' == 1 {
	use "${temp}\full_metco_tovars.dta", replace	
	
* Update 3/17/2022
	 * Remove extra Setren_IDs that were created for students who didn't initially match.
	 
	 *br if setren_id4 > 9000000 & setren_id4 != .
		replace setren_id4 = . if setren_id4 > 9000000 & setren_id4 != .
	 *br if setren_id3 > 9000000 & setren_id3 != .
		replace setren_id3 = . if setren_id3 > 9000000 & setren_id3 != .
	 *br if setren_id2 > 9000000 & setren_id2 != .
		replace setren_id2 = . if setren_id2 > 9000000 & setren_id2 != .
		
* Generate a Single DOB variable 
* (some sudents have multiple DOBs from the different data sources)
		replace dob_sims1 = 13666 if sasid1 == 1088159311
		replace dob_sims2 = . if sasid1 == 1088159311
		/*
		* Just one DOB
			br if dob2 ==.  & dob1 != . // 58,141/61,492
		* Two DOBs
			br if dob2 != . & dob3 == . // 2,233/61,492
		* Three DOBs
			br if dob3 != . // 313/61,492
		* Just one DOB
			br if dob_sims2 == . & dob_sims1 != . // 36,919/61,492
		* Two DOBs
			br if dob_sims2 != . & dob_sims3 == . // 76/61,492
		* Three DOBs
			br if dob_sims3 != . // 2/61,492	
		*/	
		
		gen dob = .
		format dob %td
			* First, pick the single DOBs from SIMS
			replace dob = dob_sims1 if dob_sims2 == . & dob_sims1 != .
			* If no DOB from SIMS, and Single DOB from METCO, pick this
			replace dob = dob1 if dob == . & dob_sims1 == . & dob2 ==.  & dob1 != .
			* If 2 DOBs from SIMS (most are within a year/2 year, just keep the earlier one!)
				gen test = dob_sims2 - dob_sims1 if dob == .
				tab test
				drop test
			replace dob = dob_sims1 if dob == . & dob_sims1 != . & dob_sims2 != . & dob_sims3 == .
			* If 3 DOBs from SIMS (most are within a year/2 year, just keep the earlier one!)
				gen test = dob_sims3 - dob_sims1 if dob == .
				tab test
				drop test
			replace dob = dob_sims1 if dob == . & dob_sims3 != .
			* If 2 DOBs from METCO 
				* This group may have some errors from the PDF Scans. 
				* From the tabulation below, many are within 1-2 years. 
				* But some are Must more. If it is more than 1201 ### (maybe will want to reevaluate?)
				* I ick the second date
				gen test = dob2 - dob1 if dob == . & dob3 == .
				tab test
			replace dob = dob1 if dob == . & dob1 != . & dob2 != . & dob3 == .	& test < 1201
			replace dob = dob2 if dob == . & dob1 != . & dob2 != . & dob3 == .	& test >= 1201
				drop test
			* If 3 DOBs from METCO 
				* Two will be closer. Pick the earlier of the closer DOBs. 
				gen diff1 = dob2 - dob1 if dob == . 
				gen diff2 = dob3 - dob2 if dob == . 
				gen diff3 = dob3 - dob1 if dob == . 
					egen diff_min = rowmin(diff1 diff2 diff3)
					order diff*
				replace dob = dob1 if dob == . & diff_min == diff1	
				replace dob = dob2 if dob == . & diff_min == diff2	
					drop diff*		
					
* Pick Application Day
	gen diff1 = application_day1 - dob
	gen diff2 = application_day2 - dob
	gen diff3 = application_day3 - dob
	gen diff4 = application_day4 - dob
	gen diff5 = application_day5 - dob
	gen diff6 = application_day6 - dob
	
	egen diffmin = rowmin(diff*)
	egen diffmax = rowmax(diff*)
	
	egen datemin = rowmin(application_day1 application_day2 application_day3 application_day4 application_day5 application_day6)
		format datemin %td
	egen datemax = rowmax(application_day1 application_day2 application_day3 application_day4 application_day5 application_day6)
		format datemax %td

	gen application_day_clean = .
	format application_day_clean %td
		
	* (1) If application on DOB pick this one
	forval i = 1/6 {
		replace application_day_clean = application_day`i' if diff`i' == 0
	}
	
	* (2) If all are before DOB, pick the latest 
		replace application_day_clean = datemax if application_day_clean == . & diffmax < 0
		
	* (3) If all are after DOB, pick the earliest 
		replace application_day_clean = datemin if application_day_clean == . & diffmin > 0	& diffmin !=.	
	
	* (4) If some are before and some are after DOB, use absolute value to pick the first after the DOB.
	forval i = 1/6 {
		replace diff`i' = . if diff`i' <0
		replace diff`i' = . if diff`i' <0
	}
	drop diffmin datemin
	egen diffmin = rowmin(diff*)
	forval i = 1/6 {
		replace application_day_clean = application_day`i' if diff`i' == diffmin & application_day_clean == .
	}
	
	* (5) If DOB missing, use first application date
		replace application_day_clean = application_day1 if application_day_clean == . & dob == .
		
	drop diff* diffmax datemax diffmin  
		
		order dob dob1 dob2 dob3 application_day_clean application_day1 application_day2 application_day3 application_day4 application_day5 application_day6
		gen diff = application_day_clean - dob
			order diff
		
	sort dob
	gen birth_year = year(dob)
		tab birth_year

		gen birth_cohort = .
			forval year = 1959/2018 {
				local i = `year' - 1
				replace birth_cohort = `year' if dob >= mdy(9, 1, `i') & dob <= mdy(8, 31, `year')
			}
			
		tab birth_cohort, m
			label var birth_cohort "DOB between 9/1/birthyear-1 and 8/31/birthyear"
			
		gen grade_cohort = birth_cohort + 7
			label var grade_cohort "Estimated Year Starting the First Grade"

		drop diff
		
* Referred before 1st Grade	
	* First, check that imputed SIMS refer date is correct (refer_date_sims1)
	format year_in_first %9.0g
	format est_year_in_first %9.0g
	
	tab birth_cohort year_in_first
	tab grade_cohort year_in_first
	
	*br setren_id* fname1 mname1 lname1 dob1 dob2 dob3 refer_date1 refer_date2 refer_date3 refer_date4 refer_date5 refer_date_sims1
	sort refer_date1
	replace refer_date1 = mdy(3,10,2015) if refer_date1 == mdy(3,10,205)
	replace refer_date1 = mdy(12,2,2015) if refer_date1 == mdy(12,2,1015)
	replace refer_date1 = mdy(8,31,2015) if refer_date1 == mdy(8,31,3015)
	
		* Exploration for how imputed referred date compares to METCO given referred date
		gen refer_date1_y = year(refer_date1)
		gen refer_date_sims1_y = year(refer_date_sims1)
		tab refer_date1_y refer_date_sims1_y
				tab refer_date1_y refer_date_sims1_y
					drop refer_date1_y refer_date_sims1_y
		
		* Generate combined referral indicator
			generate referred_all = referred
				replace referred_all = 1 if partic == 1 & referred == 0
				
				* Update other Status Variables
				replace placement = 1 if ///
						referred_all == 1			
				
				replace pending = 1 if ///
						placement  == 1
						
				replace pending = 1 if ///
						referred_all  == 1					
				
		* Generate combined referral date
			generate refer_date_all = .
				replace refer_date_all = refer_date1
	
				*replace refer_date_sims1 = . if refer_date_sims1 == 15127 // Check if others can be fixed?
				replace refer_date_all = refer_date_sims1 if refer_date1 == .
					format refer_date_all %td
						
		* Generate Referred Before Grade Flag
			* Referred Before K
				gen date_start_K = mdy(9, 1, grade_cohort - 2)
					format date_start_K %td
						gen referred_b_K = 0
							replace referred_b_K = 1 if refer_date_all <= date_start_K 
							replace referred_b_K = . if refer_date_all == .	
			* Referred within year Before K
				gen referred_within_K = 0
					replace referred_within_K = 1 if (refer_date_all <= date_start_K ) & (refer_date_all >= date_start_K -365)
					replace referred_within_K = . if refer_date_all == .								
					
			* Referred Before 1st
				gen date_start_1 = mdy(9, 1, grade_cohort - 1)
					format date_start_1 %td
						gen referred_b_1 = 0
							replace referred_b_1 = 1 if refer_date_all <= date_start_1 
							replace referred_b_1 = . if refer_date_all == .	
			* Referred within year Before 1st
				gen referred_within_1 = 0
					replace referred_within_1 = 1 if (refer_date_all <= date_start_1 ) & (refer_date_all >= date_start_1 -365)
					replace referred_within_1 = . if refer_date_all == .							
					
			* Referred Before 9th
				gen date_start_9 = mdy(9, 1, grade_cohort + 7)
					format date_start_9 %td		
						gen referred_b_9 = 0
							replace referred_b_9 = 1 if refer_date_all <= date_start_9 
							replace referred_b_9 = . if refer_date_all == .
			* Referred within year Before 9th	
				gen referred_within_9 = 0
					replace referred_within_9 = 1 if (refer_date_all <= date_start_9 ) & (refer_date_all >= date_start_9 -365)
					replace referred_within_9 = . if refer_date_all == .

		* Generate Predicted First day in school based on Grade Cohort (which is based on day of birth)
			* Applied Before K
				gen applied_b_K = 0
					replace applied_b_K = 1 if application_day_clean <= date_start_K 
					replace applied_b_K = . if application_day_clean == .	
			* Applied within year Before K
				gen applied_within_K = 0
					replace applied_within_K = 1 if (application_day_clean <= date_start_K ) & (application_day_clean >= date_start_K -365)
					replace applied_within_K = . if application_day_clean == .								
					
			* Applied Before 1st
				gen applied_b_1 = 0
					replace applied_b_1 = 1 if application_day_clean <= date_start_1 
					replace applied_b_1 = . if application_day_clean == .	
			* Applied within year Before 1st
				gen applied_within_1 = 0
					replace applied_within_1 = 1 if (application_day_clean <= date_start_1 ) & (application_day_clean >= date_start_1 -365)
					replace applied_within_1 = . if application_day_clean == .							
					
			* Applied Before 9th	
				gen applied_b_9 = 0
					replace applied_b_9 = 1 if application_day_clean <= date_start_9 
					replace applied_b_9 = . if application_day_clean == .
			* Applied within year Before 9th	
				gen applied_within_9 = 0
					replace applied_within_9 = 1 if (application_day_clean <= date_start_9 ) & (application_day_clean >= date_start_9 -365)
					replace applied_within_9 = . if application_day_clean == .							
							
		* Age at first application
		gen age_app = (application_day_clean - dob)/ 365
			*gen rawmonths_age_app = age_app * 12
			*gen months_age_app = floor(age_app * 12)
			*gen age_app_month_bins = months_age_app/12
			gen negative_app_age = 0
				replace negative_app_age = 1 if age_app <0
			*replace age_app = -1 if age_app < 0
			
		* Age at first referral
		gen age_ref = (refer_date_all - dob)/ 365		
			replace age_ref = 0 if age_ref < 0	
			
	* Gen Sex based on SIMS if matched to SIMS, 
	* and Google Forms/PDFs if they didn't match	
		tab sex_f female, m
		tab sex_m male, m
		tab sex_f sex_m, m
		tab female male, m

		gen sex = ""
			replace sex = "male"   if male == 1 
			replace sex = "female" if female == 1 
				tab sex, m
				tab sex_f sex_m if sex == "", m
			replace sex = "male"   if sex_m == 1 & sex == ""
			replace sex = "female" if sex_f == 1 & sex == ""			
				tab sex, m
			drop female male sex_m sex_f sex_na
			
				foreach var in male female {
					gen `var' = 0
						replace `var' = 1 if sex == "`var'"
						replace `var' = . if sex == ""
				}
		* Sex missing if they didn't match to SASID or not in Electronic Database					
	
* Clean Race	
	* First, for Waitlist analysis, we want just a single race category for a student.			
	* Gen Race based on SIMS DOB if matched to SIMS, and Google Forms/PDFs if they didn't match		
		egen sumrace = rowtotal(asian black hispanic nat_american other white)
		egen sumrace_sims = rowtotal(hisp_sims black_sims white_sims asian_sims otherrace_sims)
		
		gen race_single = ""
		rename hispanic hisp
		rename other otherrace
		
		* Fill in Race from SIMS
		* Update 2/1/2022 please note that the order here is very important! Sometimes, Sims has more than one race for a student. 
		* Because of the way the waitlists are made, we need that each student have 1 race.
		* So, the order should be white -> otherrace -> Asian -> hisp -> black
		foreach x in white otherrace asian hisp black {
			replace race_single = "`x'" if `x'_sims == 1 & matched_to_sims >= 1
		}
		
		* If not in SIMS, use METCO data
		* Not the same issue here, as these students only have 1 race (sumrace == 1)
		foreach x in asian black hisp otherrace white {
			replace race_single = "`x'" if `x'      == 1 & matched_to_sims == 0 & sumrace == 1
		}	
		
		* Fill in Race from METCO
			replace race_single = "otherrace" if nat_american == 1 & matched_to_sims == 0 & sumrace == 1
			* ### Not sure if this is OK, but if they are black and hisp or black and other, I classify them as black
			replace race_single = "black" if black == 1 & hisp      == 1 & matched_to_sims == 0 & sumrace == 2
			replace race_single = "black" if black == 1 & otherrace == 1 & matched_to_sims == 0 & sumrace == 2
			replace race_single = "black" if black == 1 & otherrace == 1 & hisp      == 1 & matched_to_sims == 0 & sumrace == 3
			* ### Not sure if this is OK, but if they are hisp and other, I classify them as hisp
			replace race_single = "hisp"  if hisp  == 1 & otherrace == 1 & matched_to_sims == 0 & sumrace == 2	
			* ### Not sure if this is OK, but if they are asian and other, I classify them as asian
			replace race_single = "asian" if asian == 1 & otherrace == 1 & matched_to_sims == 0 & sumrace == 2					
				* 148 missing race

				foreach var in asian black hisp otherrace white {
					gen `var'_single = 0
						replace `var'_single = 1 if race_single == "`var'"
						replace `var'_single = . if race_single == ""
				}	
				drop sumrace sumrace_sims
				
		* Update 12/16/2021: Change race to just Black/Hisp/Other
		tab race_single
			gen RACE_single = race_single
				replace RACE_single = "otherrace" if race_single == "asian"
				replace RACE_single = "otherrace" if race_single == "white"
					tab RACE_single
		gen BLACK_single = black_single
		gen HISP_single = hisp_single
		gen OTHERRACE_single = otherrace_single
			replace OTHERRACE_single = 1 if white_single == 1
			replace OTHERRACE_single = 1 if asian_single == 1	
	
	* Now that these single vars are created, create a combined race variable from METCO and SIMS:
	replace otherrace = 1 if nat_american == 1
		drop nat_american
		
		* the overlap with race definitions is a bit weird across datasets. For now, use SIMS 
		* and if didn't match to SIMS, use METCO.
		
		foreach x in white otherrace asian hisp black {
			replace `x' = 0 if `x' == . 
			replace `x' = . if source_sims == 1 & source_google_form == 0 & source_electronic == 0 & source_pdfs== 0
		}	
		
		tab asian asian_sims, m
		tab black black_sims, m
		tab white white_sims, m
		tab hisp hisp_sims, m
		tab otherrace otherrace_sims, m
		
	* How to classify race?
		*(1) "EVER" approach
			foreach x in white otherrace asian hisp black {
				gen `x'_temp = 0
					replace `x'_temp = 1 if `x'_sims == 1 | `x' == 1
			}		
		
		*(2) Use SIMS, and where SIMS missing, replace with METCO
			*foreach x in white otherrace asian hisp black {
			*	gen `x'_temp = `x'_sims
			*	replace `x'_temp = `x' if `x'_sims == .
			*}	
			*
			*foreach x in white otherrace asian hisp black {
			*	tab `x'_temp 
			*}
			*
			*drop asian asian_sims black black_sims white white_sims hisp hisp_sims otherrace otherrace_sims
			*
			*foreach x in white otherrace asian hisp black {
			*	rename `x'_temp `x'
			*}	
			
***************************************************************************************************************************	
if `race_explore' == 1 {	
	* Summary Table on Race
		preserve
			mat results = J(400,400,.)
				local row=1
				local col=1
				
		foreach x in asian black hisp white otherrace {
			count if `x' == 1 
				matrix results[`row'  ,`col']=`r(N)'
				
			count if `x' == 1 & asian == 1
				matrix results[`row'+3,`col']=`r(N)'	
			count if `x' == 1 & black == 1
				matrix results[`row'+4,`col']=`r(N)'	
			count if `x' == 1 & hisp == 1
				matrix results[`row'+5,`col']=`r(N)'				
			count if `x' == 1 & white == 1
				matrix results[`row'+6,`col']=`r(N)'
			count if `x' == 1 & otherrace == 1
				matrix results[`row'+7,`col']=`r(N)'
				
			count if `x' == 1 & asian_sims == 1
				matrix results[`row'+10,`col']=`r(N)'	
			count if `x' == 1 & black_sims == 1
				matrix results[`row'+11,`col']=`r(N)'	
			count if `x' == 1 & hisp_sims == 1
				matrix results[`row'+12,`col']=`r(N)'				
			count if `x' == 1 & white_sims == 1
				matrix results[`row'+13,`col']=`r(N)'
			count if `x' == 1 & otherrace_sims == 1
				matrix results[`row'+14,`col']=`r(N)'	
				
			count if `x' == 1 & `x'_sims == 0 & asian_sims == 1
				matrix results[`row'+17,`col']=`r(N)'	
			count if `x' == 1 & `x'_sims == 0 & black_sims == 1
				matrix results[`row'+18,`col']=`r(N)'	
			count if `x' == 1 & `x'_sims == 0 & hisp_sims == 1
				matrix results[`row'+19,`col']=`r(N)'				
			count if `x' == 1 & `x'_sims == 0 & white_sims == 1
				matrix results[`row'+20,`col']=`r(N)'
			count if `x' == 1 & `x'_sims == 0 & otherrace_sims == 1
				matrix results[`row'+21,`col']=`r(N)'					
				
		local col = `col' + 1
		}				
			
		* Export
			clear
			svmat results
			export excel using "${tables_rq1}\RQ1_${rq1_output}.xlsx", sheet("race_exploration1") sheetreplace cell(C4)	
		restore	
			
		preserve	
			mat results = J(400,400,.)
				local row=1
				local col=1
				
			foreach dataset in "" "_sims" "_temp" "_single" {
			
			* 1
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'  ,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+1,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+2,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+3,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 1
					matrix results[`row'+4,`col']=`r(N)'	
					
			* 2		
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+6,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+7,`col']=`r(N)'					
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+8,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+9,`col']=`r(N)'
					
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+10,`col']=`r(N)'	
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+11,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+12,`col']=`r(N)'
					
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+13,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+14,`col']=`r(N)'
					
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+15,`col']=`r(N)'					
			
			* 3
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+17,`col']=`r(N)'			
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+18,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+19,`col']=`r(N)'					
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+20,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+21,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+22,`col']=`r(N)'					
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+23,`col']=`r(N)'					
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 1
					matrix results[`row'+24,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 1
					matrix results[`row'+25,`col']=`r(N)'					
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 1
					matrix results[`row'+26,`col']=`r(N)'
					
			* 4
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 0 
					matrix results[`row'+28,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 0 & otherrace`dataset' == 1 
					matrix results[`row'+29,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 0 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+30,`col']=`r(N)'
				count if asian`dataset' == 1 & black`dataset' == 0 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+31,`col']=`r(N)'
				count if asian`dataset' == 0 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+32,`col']=`r(N)'					
			* 5
				count if asian`dataset' == 1 & black`dataset' == 1 & hisp`dataset' == 1 & white`dataset' == 1 & otherrace`dataset' == 1 
					matrix results[`row'+34,`col']=`r(N)'
					
			* 0
				count if asian`dataset' == 0 & black`dataset' == 0 & hisp`dataset' == 0 & white`dataset' == 0 & otherrace`dataset' == 0 
					matrix results[`row'+36,`col']=`r(N)'
					
			* .
				count if asian`dataset' == . & black`dataset' == . & hisp`dataset' == . & white`dataset' == . & otherrace`dataset' == . 
					matrix results[`row'+38,`col']=`r(N)'
					
			local col = `col' + 2		
			}
			
			* Export
			clear
			svmat results
			export excel using "${tables_rq1}\RQ1_${rq1_output}.xlsx", sheet("race_exploration2") sheetreplace cell(C4)	
			
			restore
}		
***************************************************************************************************************************				
	
			drop asian asian_sims black black_sims white white_sims hisp hisp_sims otherrace otherrace_sims
			
			foreach x in white otherrace asian hisp black {
				rename `x'_temp `x'
			}
			
	* Update 7/11/2022: Adding in Registrant information
		preserve
			keep if setren_id1 == . | setren_id1 >= 9000000
			
			tempfile no_registrant
			save `no_registrant'
		
		restore

	drop if setren_id1 == . 
	drop if setren_id1 >= 9000000
	
	* First, merge on Registrant Names
		gen expand = .
		order expand
			replace expand = 4 if setren_id4 != . & expand == .
			replace expand = 3 if setren_id3 != . & expand == .
			replace expand = 2 if setren_id2 != . & expand == .
			replace expand = 1 if setren_id1 != . & expand == .
			
		expand expand

			sort setren_id1 sasid1
			gen setren_id = .			
				quietly by setren_id1 sasid1 :  gen dup = cond(_N==1,0,_n)
					tab dup		
						order dup setren_id
							replace dup = 1 if dup == 0	
							
							foreach var in setren_id {
								replace `var' = `var'1 if dup == 1
								replace `var' = `var'2 if dup == 2
								replace `var' = `var'3 if dup == 3
								replace `var' = `var'4 if dup == 4
							}
							drop dup expand 
							
	merge 1:1 setren_id using "${electronic_data}/registrant_names.dta"	
		tab _merge
			drop if _merge == 2
				drop _merge	
				
		* Get back to the student level
			drop setren_id
			duplicates drop
			
			* Fix Name (keeping different versions)
			preserve
				keep setren_id1 registrant_lname* registrant_fname*
					duplicates drop
					gen id = _n
		 
					reshape long registrant_fname registrant_lname, i(setren_id1 id) j(refer_num) 	
						drop refer_num id
						drop if registrant_fname == "" & registrant_lname == ""  
							duplicates drop					
						 
							gsort setren_id1 registrant_lname registrant_fname 
							quietly by setren_id1 :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0	
									sum dup						
							
								reshape wide registrant_fname registrant_lname, i(setren_id1)  j(dup)
									
								tempfile fix_name
									save `fix_name'				
			restore	
			drop registrant_lname* registrant_fname*
			merge m:1 setren_id1 using `fix_name'
				assert _merge != 2
				drop _merge 				
				duplicates drop	
				isid setren_id1			
	
	append using `no_registrant'
		
	save "${merge_sims}\full_metco.dta", replace
	
	} // End create_variables

} // End merge_to_sims

/*
use "${merge_sims}\full_metco.dta", replace

sort lname1 fname1	
order	application_day1 source* referred dob1 *name*			
local name "crissu"	
local type "fname"
br  if strpos(`type'1, "`name'")>0 | strpos(`type'2, "`name'")>0 | ///
strpos(`type'3, "`name'")>0 | strpos(`type'4, "`name'")>0 | ///
strpos(`type'5, "`name'")>0 | strpos(`type'6, "`name'")>0 | ///
strpos(`type'7, "`name'")>0 | strpos(`type'8, "`name'")>0 | ///
strpos(`type'9, "`name'")>0 
br if lname1 == "williams" & (fname1 == "tray" | fname1 ==  "lray" | fname1 ==  "lzray")
*/

