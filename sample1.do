/*
*Title: 1_research_metco_applicant_database
*Created by: Clive Myrie Co
*Created on: 04/20/2021
*Last modified on: 05/11/2022
*Edited by: Sara Ji

*Purpose: Imports the Research_METCO_Applicant_Database.xlsx (source of Setren IDs)
From Folder: E:\METCO\data\raw_data\boston_metco\Research database - DO NOT USE FOR WAITLIST

### I believe that Research_METCO_Applicant_Database.xlsx is originally made in 0_metco_database_clean, setren IDs added later
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

/***************************************************************************
Switches
***************************************************************************/
local import  = 1

/***************************************************************************
Locals
***************************************************************************/
local status_types active graduated pending place referred withdrawn tooold registered notpending notinterested

/***************************************************************************
Import
***************************************************************************/
if `import' == 1 {
clear

import excel "${raw_database}\Research_METCO_Applicant_Database.xlsx", firstrow case(lower)

* Rename Variables
rename e child_middle_name	
rename aq notes
drop ar /*Duplicate of AQ*/ as at 

format child_first_name %15s

* Drop empty rows
#delimit ;
gen flag = 0 ;
replace flag = 1 if
		setren_id 	                 == "" &
		family_id 	                 == "" &
		child_id 	                 == "" &
		child_first_name 	         == "" &
		child_middle_name 	         == "" &
		child_last_name 	         == "" &
		dob 	                     == "" &
		date_of_1st_app 	         == "" &
		sibling 	                 == "" &
		to_delete_duplicate 	     == "" &
		checked_entry 	             == "" &
		changed_entry 	             == "" &
		registered 	                 == "" &
		pending 	                 == "" &
		place 	                     == "" &
		referred 	                 == "" &
		date_referred 	             == "" &
		active 	                     == "" &
		withdrawn 	                 == "" &
		metco_district 	             == "" &
		parent_declined 	         == "" &
		district_declined 	         == "" &
		district_declined_iep        == "" &
		district_declined_no_space 	 == "" &
		notesondeclined 	         == "" &
		new_entry 	                 == "" &
		race_black 	                 == "" &
		race_asian 	                 == "" &
		race_hisp 	                 == "" &
		race_nativeamer 	         == "" &
		race_other 	                 == "" &
		race_white 	                 == "" &
		male 	                     == "" &
		female 	                     == "" &
		statusnotes1 	             == "" &
		statusnotes2 	             == "" &
		statusnotes3 	             == "" &
		box_cataloging_notes 	     == "" &
		notes	                     == "" ;
		
#delimit cr

tab flag		
drop if flag == 1
drop flag

drop cousin cousin_notes address zip_code /*No Observations*/

* Clean Entries for Merge:
	replace child_id = family_id if setren_id == "20"
	* Some strange entries
	replace notes = child_first_name if strpos(child_first_name,"6/25/99 - FILE IS INCOMPLETE! Need grades!!")>0
		replace child_first_name = "SAMBRIANA (TWIN)" if strpos(child_first_name,"6/25/99 - FILE IS INCOMPLETE! Need grades!!")>0
	replace notes = "First name was originally 24may1997" if child_first_name == "24may1997"
		replace child_first_name = "" if child_first_name == "24may1997"			
		replace child_first_name = "" if child_first_name == "unknown"
	replace child_first_name = "TRUE" if child_first_name == "1"
	replace child_first_name = "JIMMY twins" if child_first_name == "Nelson twins"
	replace child_first_name = "Imani" if setren_id == "22807"	
	replace family_id = child_id if family_id == "yes" | family_id == "WAS" | family_id == "N" | family_id == "ye" | family_id == "0"
	replace family_id = child_id if setren_id == "12077" | setren_id == "30791"
	replace child_id = family_id if child_id == "SHR1020CEL" & family_id == "STE1014CYN"
	replace child_id = family_id if child_id == "RJAM1010ELV" & family_id == "JAM1010KAR"
	replace child_id = family_id if child_id == "Fr" & family_id == "BUT060616121349"
	replace child_id = family_id if child_id == "," & family_id == "MUN1010RAS"
	replace child_id = family_id if setren_id == "37628"
	replace child_id = family_id if child_id == "DUR1010ROS" & family_id == "UZO1010PET"	

* Setren ID blank
	* We have a blank setren ID between the 4050 & 4052
		replace setren_id = "4051" if setren_id == " " & family_id == "IMA1014MIC"
		replace setren_id = "35078" if setren_id == "" & family_id == "SAN1012CAR"
		replace setren_id = "36741" if setren_id == "  " & family_id == "MEN1012APR"
		
		destring setren_id, replace	
	
* Clean Dates
	replace child_middle_name = dob if dob == "c"
	replace dob = "20apr2004" if dob == "c"
	replace date_of_1st_app = "07apr1992" if date_of_1st_app == "  6588229"
	replace date_of_1st_app = "25sep2003" if date_of_1st_app == "25Sept2003"
		foreach date in dob date_of_1st_app {		
			rename `date' `date'_str
			gen `date' = date(`date'_str, "DMY")
			format `date' %td			
			order `date', a(`date'_str)
		}			
		
	* Update 1/2/2022 
		* Some Setren id get dropped for some reason. Add these back in
		append using "${raw_metco}/dropped_setren_ids.dta"		
			sort setren_id
			isid setren_id
			
			drop box_cataloging_notes box_processing_notes *_orig2
			drop address1 city1 zip1 poboxyn1 address2 city2 zip2 poboxyn2 ///
                 address3 city3 zip3 poboxyn3 address4 city4 zip4 poboxyn4 address5 city5 zip5 poboxyn5
			
			order graduated tooold, a(referred)

		* For some reason, Zip codes and statuses get dropped. Add these back in. 
		* Also noticed that some application days got messed up!!
		merge 1:1 setren_id using "${raw_metco}/applicant_database_for_metco_boxes_wSetren_ID_new.dta"	
			tab _merge
			drop _merge			
			
			* Just check that setren_ids were created correctly
				foreach var	in child_first_name child_middle_name child_last_name ///
							   child_first_name_ElecData child_last_name_ElecData ///
							   child_last_name_orig2 child_first_name_orig2	child_mi_ElecData ///
							   child_mi_orig2 {
							   replace `var' = lower(`var')
							   }
				gen flag = 1 if  child_last_name != child_last_name_ElecData & child_first_name != child_first_name_ElecData				
				order setren_id child_first_name child_middle_name child_last_name child_first_name_ElecData child_mi_ElecData ///
				child_last_name_ElecData  child_first_name_orig2	 child_mi_orig2 child_last_name_orig2 dob child_dob
				*br if  flag == 1	
			* 37 differences by name, but all are ok!
			
				* Replace names when missing
					replace child_last_name = child_last_name_orig2 if child_last_name == ""
					replace child_first_name = child_first_name_orig2 if child_first_name == ""
					
					drop *_orig2 child_first_name_ElecData child_mi_ElecData child_last_name_ElecData flag		
				
				* Note that there are 117 where dob from the raw data does not match the dob from the 
				* Google Sheet version of the data.
				* I will assume that these changes were made intentionally
				*br if dob != child_dob 
					drop child_dob

			* Replace Addresses
				replace city = city_ElecData
				replace zip = zip_ElecData
				replace metco_district = metco_district_ElecData	
					
			* Replace with updated Application day (previous used a diffeerent method of creating application day)
			drop date_of_1st_app_str
				rename date_of_1st_app application_day_7
				rename application_day_1_ElecData application_day_8 
				rename application_day_2_ElecData application_day_9
				rename application_day_3_ElecData application_day_10 
				rename application_day_4_ElecData application_day_11
				rename application_day_5_ElecData application_day_12
				rename application_day_6_ElecData application_day_13
				
			preserve
				keep setren_id application_day_*
					duplicates drop
					gen id = _n
		 
					reshape long application_day_, i(setren_id id) j(refer_num) 	
						drop refer_num id
						drop if application_day_ == . 
							duplicates drop					
						 
							sort setren_id application_day_
							quietly by setren_id :  gen dup = cond(_N==1,0,_n)
								tab dup		
								
								replace dup = 1 if dup == 0
									sum dup
									local max = r(max)
									di in red "`max'"															
							
								reshape wide application_day_, i(setren_id)  j(dup)
									
								tempfile fix_app
									save `fix_app'				
			restore	
			drop application_day_*
			merge m:1 setren_id using `fix_app'
			drop _merge 				

* Clean Y/N entries	
	foreach var in sibling to_delete_duplicate checked_entry changed_entry `status_types' ///
	               new_entry race_black race_asian race_hisp race_nativeamer race_other   ///
				   race_white male female notpending_ElecData notinterested_ElecData ///
				   registered_ElecData pending_ElecData place_ElecData referred_ElecData ///
				   active_ElecData withdrawn_ElecData metco_district_ElecData graduated_ElecData tooold_ElecData {
		replace `var' = lower(`var')
		replace `var' = "" if `var' == " "
		replace `var' = subinstr(`var', " ", "", .)
		replace `var' = subinstr(`var', char(10), "", .)
		replace `var' = subinstr(`var', "/", "", .)
		replace `var' = subinstr(`var', ".", "", .)
		format `var' %10s
	}
	replace to_delete_duplicate = "yes" if to_delete_duplicate == "duplicate"
			
* Destring 
gen flag = 1 if referred == "27jun2000"
replace date_referred = referred if flag == 1
replace referred = "yes" if flag == 1
	drop flag
	foreach var in race_black race_asian race_hisp race_nativeamer race_other race_white male female `status_types' ///
				   registered_ElecData pending_ElecData place_ElecData referred_ElecData notpending_ElecData notinterested_ElecData ///
				   active_ElecData withdrawn_ElecData metco_district_ElecData graduated_ElecData tooold_ElecData {
	tab `var'
		replace `var' = "1" if `var' == "yes"
		replace `var' = "0" if `var' == "no"
			destring `var', replace			
	}
	
		foreach var in `status_types' {
			di in red "`var'"
			replace `var' = `var'_ElecData if `var' == .
			replace `var' = `var'_ElecData if `var'_ElecData == 1 & `var' == 0
			*replace `var'_ElecData = `var' if `var'_ElecData == 0 & `var' == 1
		}

		drop *_ElecData	
		
* Clean Names
	gen fname = child_first_name  
	gen mname = child_middle_name 
	gen lname = child_last_name    
	
	order lname fname mname, a(child_id)
	
	foreach var in lname fname mname child_first_name child_middle_name child_last_name {
		replace `var' = lower(`var')
	}

	* Clean Last Name

		* Remove JR.
			replace lname = subinstr(lname, "-jr.", "", .)
			replace lname = subinstr(lname, "-jr", "", .)
			replace lname = subinstr(lname, ", jr.", "", .)
			replace lname = subinstr(lname, " jr.", "", .)	
			
			replace lname = subinstr(lname, ", jr", "", .)
			replace lname = subinstr(lname, ",jr", "", .)
			replace lname = subinstr(lname, " jr", "", .)
			replace lname = subinstr(lname, "jr.", "", .)
			
		* Remove Twins
			gen twin = 0
				replace twin = 1 if strpos(lname,"twin")>0
				order twin, a(sibling)
				
				replace sibling = "1" if sibling == "yes"
				replace sibling = "1" if sibling == "sibling"
				replace sibling = "1" if sibling == "weston"
				replace sibling = "1" if sibling == "yes-foster"
				replace sibling = "1" if sibling == "cousin"
				replace sibling = "0" if sibling == "no"
				replace twin    = 1   if sibling == "yes(twin)"
				replace sibling = "1" if sibling == "yes(twin)"
					destring sibling, replace				

			replace lname = subinstr(lname, "-twins", "", .)
			replace lname = subinstr(lname, "-twin", "", .)
			replace lname = subinstr(lname, "/twins", "", .)
			replace lname = subinstr(lname, "/twin", "", .)
			replace lname = subinstr(lname, "\twins", "", .)
			replace lname = subinstr(lname, "\twin", "", .)
			replace lname = subinstr(lname, "(twins)", "", .)
			replace lname = subinstr(lname, "(twin)", "", .)
			replace lname = subinstr(lname, " twins", "", .)
			replace lname = subinstr(lname, " twin", "", .)

		* Remove II, III, IV
			replace lname = subinstr(lname, "-4th", "", .)
			replace lname = subinstr(lname, " iv", "", .)
			replace lname = subinstr(lname, " iii", "", .)
			replace lname = subinstr(lname, " 111", "", .)			
			replace lname = subinstr(lname, ",iii", "", .)
			replace lname = subinstr(lname, " lll", "", .)
			replace lname = subinstr(lname, " l l l", "", .)
			replace lname = subinstr(lname, "-3rd", "", .)
			replace lname = subinstr(lname, "3rd", "", .)
			replace lname = subinstr(lname, " ii", "", .)
			replace lname = subinstr(lname, " ll", "", .)
			replace lname = subinstr(lname, ",ii", "", .)
			replace lname = subinstr(lname, "-2nd", "", .)
			replace lname = subinstr(lname, " 111", "", .)
			replace lname = subinstr(lname, " 11", "", .)
			
		* Move Middle Name
			*br lname mname if strpos(lname,".") == strlen(lname) & strpos(lname,".")>0			
			gen temp_lname = lname if strpos(lname,".") == strlen(lname) & strpos(lname,".")>0
				replace temp_lname = subinstr(temp_lname, "  ", " ", .)
				split temp_lname, p(" ")
				replace temp_lname2 = subinstr(temp_lname2, ".", "", .)
		
			replace lname = temp_lname1 if strlen(temp_lname2) == 1
			replace mname = mname + temp_lname2 if strlen(temp_lname2) == 1
			
			replace lname = subinstr(lname, ".", "", .) if strpos(lname,".") == strlen(lname)
				drop temp_l*
			
		* Fix characters and spaces
			* One name is a date. Not clear why.
			replace notes = "Last name was originally 01apr2005" if lname == "01apr2005"
				replace lname = "" if lname == "01apr2005"				
				replace lname = "" if lname == "summer school 2002"
		
			* Clean Random Characters
			foreach x in "." "-" "/" "\" "]" " " {
				replace lname = subinstr(lname, "`x'", "", .)
			}
			
		format lname %26s
		
	* Clean First Name
		* Remove JR.
			replace fname = subinstr(fname, "-jr.", "", .)
			replace fname = subinstr(fname, "-jrae", "jroe", .)
			replace fname = subinstr(fname, " jroe", "jroe", .)
			replace fname = subinstr(fname, "-jr", "", .)
			replace fname = subinstr(fname, ", jr.", "", .)
			replace fname = subinstr(fname, " jr.", "", .)	
			replace fname = subinstr(fname, ",jr", "", .)
			replace fname = subinstr(fname, " jr,", "", .)	
			replace fname = subinstr(fname, " jr", "", .)
			replace fname = subinstr(fname, ".jr.", "", .)
			replace fname = subinstr(fname, "jr.", "", .)
			replace fname = subinstr(fname, "jr", "", .) if strpos(fname,"jr") == strlen(fname)-1
		
		* Remove Twins
			replace twin = 1 if strpos(fname,"twin")>0

			replace fname = subinstr(fname, "-twins", "", .)
			replace fname = subinstr(fname, "-twin", "", .)
			replace fname = subinstr(fname, "/twins", "", .)
			replace fname = subinstr(fname, "/twin", "", .)	
			replace fname = subinstr(fname, "\twins", "", .)
			replace fname = subinstr(fname, "\twin", "", .)	
			replace fname = subinstr(fname, "(twins", "", .)
			replace fname = subinstr(fname, "(twin", "", .)	
			replace fname = subinstr(fname, " twins", "", .)
			replace fname = subinstr(fname, " twin", "", .)
			replace fname = subinstr(fname, ".twins", ".", .)
			replace fname = subinstr(fname, ".twin", ".", .)

		* Remove II, III, IV
			replace fname = subinstr(fname, " iv", "", .) if strpos(fname," iv") == strlen(fname)-2
			replace fname = subinstr(fname, " iii", "", .)
			replace fname = subinstr(fname, " 111", "", .)	
			replace fname = subinstr(fname, " lll", "", .)
			replace fname = subinstr(fname, "-3rd", "", .)
			replace fname = subinstr(fname, "3rd", "", .)	
			replace fname = subinstr(fname, " ii.", "", .)
			replace fname = subinstr(fname, " ii", "", .)
			replace fname = subinstr(fname, " 11", "", .)
			replace fname = subinstr(fname, " ll.", "", .)
			replace fname = subinstr(fname, " ll", "", .)
			replace fname = subinstr(fname, "-2nd", "", .)			
			
			* Clean Random Characters				
				* Remove Characters
				foreach x in "#" "(" ")" "?" "/" "]" "1" "2" "5" "," {
					replace fname = subinstr(fname, "`x'", "", .)
				}
				replace fname = subinstr(fname, "0", "o", .)
				
				replace fname = trim(fname)		
				replace fname = subinstr(fname, "        ", " ", .)
				replace fname = subinstr(fname, "       ", " ", .)
				replace fname = subinstr(fname, "      ", " ", .)
				replace fname = subinstr(fname, "     ", " ", .)
				replace fname = subinstr(fname, "    ", " ", .)
				replace fname = subinstr(fname, "   ", " ", .)
				replace fname = subinstr(fname, "   ", " ", .)
				replace fname = subinstr(fname, "  ", " ", .)
				
		* Move Middle Name
			*(A)
			replace fname = subinstr(fname, "..", ".", .)
			*br lname fname mname if strpos(fname,".") == strlen(fname) & strpos(fname,".")>0
			
			gen temp_fname = fname if strpos(fname,".") == strlen(fname) & strpos(fname,".") == strlen(fname)
				replace temp_fname = subinstr(temp_fname, ".", "", .)
				split temp_fname, p(" ")
				
				* If 2 first names
					replace fname = temp_fname1 + " " + temp_fname2 if temp_fname3 != "" 
						replace mname = temp_fname3 if temp_fname3 != ""  
						
				* if 1 first name
					replace fname = temp_fname1 if temp_fname3 == "" & temp_fname1 != "" & temp_fname2 != ""
						replace mname = mname + temp_fname2 if temp_fname3 == "" & temp_fname1 != "" & temp_fname2 != ""
			
				drop temp_f*
				replace fname = subinstr(fname, ".", "", .) if strpos(fname,".") == strlen(fname) & strpos(fname,".")>0
		
			*(B)
			*br lname fname mname if strpos(fname,".") == strlen(fname)-1 & strpos(fname,".")>0				
			gen temp_fname = fname if strpos(fname,".") == strlen(fname)-1 & strpos(fname,".")>0
				replace temp_fname = subinstr(temp_fname, ".", "", .)
				replace temp_fname = subinstr(temp_fname, "-", " ", .)
				split temp_fname, p(" ")	
				
					replace fname = temp_fname1 if temp_fname1 != "" & temp_fname2 != ""
						replace mname = mname + temp_fname2 if temp_fname1 != "" & temp_fname2 != ""
			
				drop temp_f*
				
			*(C)
			*br lname fname mname if strpos(fname,".") == strlen(fname)-2 & strpos(fname,".")>0
			gen temp_fname = fname if strpos(fname,".") == strlen(fname)-2 & strpos(fname,".")>0
				replace temp_fname = subinstr(temp_fname, ".", "", .)
				split temp_fname, p(" ")	
				
					replace fname = temp_fname1 if temp_fname1 != "" & temp_fname2 != ""
						replace mname = mname + temp_fname2 + temp_fname3 if temp_fname1 != "" & temp_fname2 != ""
			
				drop temp_f*
				
			*(D)
			*br lname fname mname  if strpos(fname," ") == strlen(fname)-1 & strpos(fname," ")>0
			gen temp_fname = fname if strpos(fname," ") == strlen(fname)-1 & strpos(fname," ")>0
				replace temp_fname = subinstr(temp_fname, ".", "", .)
				split temp_fname, p(" ")	
				
					replace fname = temp_fname1 if temp_fname1 != "" & temp_fname2 != ""
						replace mname = child_mi + temp_fname2  if temp_fname1 != "" & temp_fname2 != ""
			
				drop temp_f*				
				
			* ### Could maybe do more cleaning, but will hold off for now.				
			
			format fname %26s	
			
	foreach var in lname fname mname {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', "-", "", .)
		replace `var' = subinstr(`var', " ", "", .)
		replace `var' = subinstr(`var', "'", "", .)
		replace `var' = subinstr(`var', ".", "", .)
		replace `var' = subinstr(`var', "0", "o", .)
		replace `var' = subinstr(`var', "1", "", .)
		replace `var' = subinstr(`var', "8", "", .)
	}
	
		format lname %26s		
		format fname %26s	
		
	* Fix statuses
		format statusnotes1 %15s
		format statusnotes2 %15s
		format statusnotes3 %15s
		format notes %15s
		format parent_declined % 15s
		format district_declined % 15s
		format district_declined_iep % 15s
		format district_declined_no_space % 15s	
			 
		replace statusnotes1 = lower(statusnotes1)
		replace statusnotes2 = lower(statusnotes2)
		replace statusnotes3 = lower(statusnotes3)
		replace statusnotes1 = subinstr(statusnotes1, char(10), "", .) 
		replace statusnotes2 = subinstr(statusnotes2, char(10), "", .) 
		replace statusnotes3 = subinstr(statusnotes3, char(10), "", .) 
		replace statusnotes1 = subinstr(statusnotes1, `"""', "", .) 
		replace statusnotes2 = subinstr(statusnotes2, `"""', "", .) 
		replace statusnotes3 = subinstr(statusnotes3, `"""', "", .)	
		replace statusnotes1 = subinstr(statusnotes1, "*", "", .) 
		replace statusnotes2 = subinstr(statusnotes2, "*", "", .) 
		replace statusnotes3 = subinstr(statusnotes3, "*", "", .)	
		replace statusnotes1 = subinstr(statusnotes1, "{", "", .) 
		replace statusnotes2 = subinstr(statusnotes2, "{", "", .) 
		replace statusnotes3 = subinstr(statusnotes3, "{", "", .)
		replace statusnotes1 = subinstr(statusnotes1, "}", "", .) 
		replace statusnotes2 = subinstr(statusnotes2, "}", "", .) 
		replace statusnotes3 = subinstr(statusnotes3, "}", "", .)		
		replace notes = subinstr(notes, char(10), "", .) 		
		
* Clean District & Date 
	replace metco_district = trim(metco_district)
	replace metco_district = lower(metco_district)
	
	tab date_referred
	
	replace date_referred = "03mar2013" if metco_district == "weston-referred 3/15/13"
	replace metco_district = "weston" if metco_district == "weston-referred 3/15/13"
	
	replace date_referred = "20mar2012" if metco_district == "3/20/12-westwood"
	replace metco_district = "westwood" if metco_district == "3/20/12-westwood"		
	
	replace metco_district = "bedford/swampscott" if metco_district == "swampscott/bedford"
	replace metco_district = "bedford/lincoln" if metco_district == "lincoln/bedford"
	replace metco_district = "brookline/sudbury" if metco_district == "sudbury/brookline"
	replace metco_district = "cohasset" if metco_district == "cohasett"
	replace metco_district = "dover/sherborn" if metco_district == "dover sherborne"
	replace metco_district = "dover/sherborn" if metco_district == "dover/sherborne"
	replace metco_district = "foxborough" if metco_district == "foxboro"
	replace metco_district = "foxborough" if metco_district == "foxborouth"
	replace metco_district = "foxborough" if metco_district == "foxbourogh"
	replace metco_district = "foxborough/swampscott" if metco_district == "swampscott/foxborough"
	replace metco_district = "hingham" if metco_district == "higham"
	replace metco_district = "lexington/walpole" if metco_district == "walpole/lexington"
	replace metco_district = "lincoln" if metco_district == "lincon"
	replace metco_district = "lincoln/melrose" if metco_district == "melrose/lincoln"
	replace metco_district = "lincoln/sudbury" if metco_district == "sulbury/lincoln"
	replace metco_district = "lynnfield" if metco_district == "lynfied"
	replace metco_district = "natick/westwood" if metco_district == "westwood/natick"
	replace metco_district = "swampscott" if metco_district == "swampcott"
	replace metco_district = "sudbury" if metco_district == "subbury"
	replace metco_district = "sudbury" if metco_district == "sud"	
	replace metco_district = "sudbury" if metco_district == "sudury"
	replace metco_district = "sudbury/weston" if metco_district == "weston/sudbury"
	replace metco_district = "walpole" if metco_district == "walpolehigh"
	replace metco_district = "wellesley" if metco_district == "wellsley"	
		
		* Find Referral Dates from the Status Notes				
			* Fix Referral Dates	
				do "${programs}\1_research_metco_applicant_database_refdates.do"
									
		foreach date in date_referred {		
			rename `date' `date'_str
			gen `date' = date(`date'_str, "DMY")
			format `date' %td			
			order `date', a(`date'_str)
		}	
		
		

	* ### Questions
		* What does it mean if date refered is not empty and district is?
		* What does it mean if they are refered twice?
		* What does it mean if refered to a district and distirct is noted in date, but not the same as METCO district?
		* br date_referred metco_district notes if date_referred != "" 
		

		
		* Clean Declined and Notes	
		format parent_declined            %-30s
		format district_declined          %-30s
		format district_declined_iep      %-30s
		format district_declined_no_space %-30s
		format notesondeclined            %-30s
		
		foreach var in 	parent_declined district_declined district_declined_iep district_declined_no_space notesondeclined {
			replace `var' = subinstr(`var', char(10), "", .)
			replace `var' = lower(`var')
			replace `var' = trim(`var')
		}
	 
		gen test = strlen(parent_declined)
			replace notesondeclined = "parent_declined:" + parent_declined + " || " + notesondeclined if test > 3
			replace parent_declined = "yes" if test > 3
				drop test
		gen test = strlen(district_declined)
			replace notesondeclined = "district_declined:" + district_declined + " || " + notesondeclined if test > 3
			replace district_declined = "yes" if test > 3
				drop test	
		gen test = strlen(district_declined_iep)
			replace notesondeclined = "parent_declined:" + district_declined_iep + " || " + notesondeclined if test > 3
			replace district_declined_iep = "yes" if test > 3
			rename district_declined_iep dist_dcld_iep
				drop test
		gen test = strlen(district_declined_no_space)
			replace notesondeclined = "district_declined_iep:" + district_declined_no_space + " || " + notesondeclined if test > 3
			replace district_declined_no_space = "yes" if test > 3
			rename district_declined_no_space dist_dcld_no_space
				drop test			
			
		* ### Questions
			* What does it mean if both the district and the parents declined?
			* What does it mean if there is no metco_district, but the district declined?
		
* Create variables for merges:
	gen name = lname + fname + mname	
	gen orig_name = child_last_name + child_first_name + child_middle_name
	gen day   = day(dob)
	gen month = month(dob)
	gen year  = year(dob)	
		
* Rename Vars	
	foreach var of varlist _all {
		rename `var' `var'_app_database
	}
	format child_first_name_app_database %15s	
	
save "${electronic_data}\electronic_database.dta", replace

}
