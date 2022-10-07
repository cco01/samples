/*
*Title: 
*Created by: Savannah Kochinke
*Created on: 12/3/2021
*Last modified on: 
*Last modified by: 
*Purpose: 

*/

* First, clean the date_referred variable

	replace metco_district = "westwood" if date_referred == "6/2/11- Westwood"
	replace date_referred = "02jun2011" if date_referred == "6/2/11- Westwood"	
	
	replace metco_district = "weston" if date_referred == "3/14/13-Weston"
	replace date_referred = "14mar2013" if date_referred == "3/14/13-Weston"
	
	replace date_referred = "03apr2012" if date_referred == "4/3/12- ARLINGTON"
	replace date_referred = "03feb2015" if date_referred == "02/03/15 Wayland"
	
	replace date_referred = lower(date_referred)
	replace date_referred = "10sep2016" if date_referred == "9/0/2016 & 9/19/2016"	
	replace date_referred = subinstr(date_referred, "3-20-13;referred to arlington picked up by mt. enter into database by ac", "3-20-13", .)
	replace date_referred = "20mar2013" if date_referred == "3-20-13"
	replace date_referred = subinstr(date_referred, " referred to newton brought to the mda for lr and sg enter into data by ac, lw", "", .)
	replace date_referred = "12dec2012" if date_referred == "12/12/12"
	replace date_referred = subinstr(date_referred, " ready for referral (ac)", "", .)
	replace date_referred = "21dec2012" if date_referred == "12-21-12"
	replace date_referred = "01mar2016" if date_referred == "2016-2017"
	replace date_referred = subinstr(date_referred, "- ready for referral", "", .)
	replace date_referred = "09nov2012" if date_referred == "11/9/12"	
	replace date_referred = "" if date_referred == "/" | date_referred == "yes" | date_referred == "y"
	replace date_referred = subinstr(date_referred, " referred to wayland. 3-14-13 referred to weston", "", .)
	replace date_referred = "25feb2013" if date_referred == "2-25-13"	
	replace date_referred = "06dec2012" if date_referred == "12/06/12 & 11/25/13"
	replace date_referred = "10sep2013" if date_referred == "9/10/13- referred to natick"
	replace date_referred = "21sep2016" if date_referred == "9/216/16"
	
	* If we just have the referred year, set March 1, Year as the referral date
	forval i = 1970/2019 {
		replace date_referred = "01mar`i'"   if date_referred == "`i'"					
	}	
	 
	format date_referred %15s
	
	*Clean file to only contain observations with no referrral date *

* Now clean from the Status Notes
	* First, focus on when we are missing ref district and date, but we have a status:
		* If missing both METCO District and REF date, add both
		* First, update earliest METCO District
		* Then update date referred in the format "DDMMMYYY"
	replace metco_district = "reading" if statusnotes1 == "refer to reading on 5/04/07 by adfsc"
		replace date_referred = "04may2007" if statusnotes1 == "refer to reading on 5/04/07 by adfsc"
	replace metco_district = "lexington" if statusnotes1 == "melrose , parent declined,reason: already  registered and paying tuition at another school would lose payment. hold for 2 grade. enter by bf/7/20/05.  ref to melrose.  fldr in plcmnt 2/4/05hy ref to lex 2/4/05hy del, no show 3-23-05hy"
		replace date_referred = "04feb2005" if statusnotes1 == "melrose , parent declined,reason: already  registered and paying tuition at another school would lose payment. hold for 2 grade. enter by bf/7/20/05.  ref to melrose.  fldr in plcmnt 2/4/05hy ref to lex 2/4/05hy del, no show 3-23-05hy"
	replace metco_district = "bedford" if statusnotes1 == "mother came to the office to learn about whsat it's necessary to update folder in placement from last year 2009 did recommended that she bring end of last year and also this year report card, threeo proofs of the most recent's bills for proof of residency the most recent should be at less up to two months old, and the phisical and immunizations enter by adfsc on 6/23/10 father called to check the status enter by adfsc on 8/31/09 declined no reason given and back page was missing took it from bf she had since 2/09/2009 enter by adfsc on 04/03/09 refer to bedford enter on 1/27/09 call to reqst the most recent reprt card  recvd folder needs the current report card erecvd and enter by adfsc on 12/01/08"
		replace date_referred = "03apr2009" if statusnotes1 == "mother came to the office to learn about whsat it's necessary to update folder in placement from last year 2009 did recommended that she bring end of last year and also this year report card, threeo proofs of the most recent's bills for proof of residency the most recent should be at less up to two months old, and the phisical and immunizations enter by adfsc on 6/23/10 father called to check the status enter by adfsc on 8/31/09 declined no reason given and back page was missing took it from bf she had since 2/09/2009 enter by adfsc on 04/03/09 refer to bedford enter on 1/27/09 call to reqst the most recent reprt card  recvd folder needs the current report card erecvd and enter by adfsc on 12/01/08"
	replace metco_district = "concord" if statusnotes1 == "i, anthonia umeh would like to withdraw my daughter kenchukwu abajue-umeh for metco waiting list. she will be attending the boston latin school in sept. 2006. entered by bf/4/3/06 reentered again in 5/10/06.  file has been returned to metco, reason: concord  public school district is not placing 7th grader at time time. entered by bf.4.18/06.  ref to concord entered by bf/2/14/06."
		replace date_referred = "14feb2006" if statusnotes1 == "i, anthonia umeh would like to withdraw my daughter kenchukwu abajue-umeh for metco waiting list. she will be attending the boston latin school in sept. 2006. entered by bf/4/3/06 reentered again in 5/10/06.  file has been returned to metco, reason: concord  public school district is not placing 7th grader at time time. entered by bf.4.18/06.  ref to concord entered by bf/2/14/06."
	replace metco_district = "reading" if statusnotes1 == "declined from reading 10/26/06 by adfsc refer to reading 7/21/06 by adfsc"
		replace date_referred = "21jul2006" if statusnotes1 == "declined from reading 10/26/06 by adfsc refer to reading 7/21/06 by adfsc"
	replace metco_district = "brookline" if statusnotes1 == "7-20-12 file is being referred to brookline. ds 6-13-12 file is complete and ready for referral. ds"
		replace date_referred = "20jul2012" if statusnotes1 == "7-20-12 file is being referred to brookline. ds 6-13-12 file is complete and ready for referral. ds"
	replace metco_district = "melrose" if statusnotes1 == "bedford accepted christopher emtered by bf 10/30/06 confirmed by mrs mcmanus donnette. declined by parent on 7/06/06 recvd & enter by adfsc refer to melrose on 6/23/06  fldr updated 3-24-05hy"
		replace date_referred = "23jun2006" if statusnotes1 == "bedford accepted christopher emtered by bf 10/30/06 confirmed by mrs mcmanus donnette. declined by parent on 7/06/06 recvd & enter by adfsc refer to melrose on 6/23/06  fldr updated 3-24-05hy"
	replace metco_district = "walpole" if statusnotes1 == "referred to walpole 11/05/03 ac."
		replace date_referred = "05nov2003" if statusnotes1 == "referred to walpole 11/05/03 ac."
	replace metco_district = "belmont" if statusnotes1 == "compl.folder12/3/02hy ref to belmont 9-14-03hy decl, space 9-29-03hy letter sent out for update 11/03..did not update…folder will be disposed with accor. 7-04hy"
		replace date_referred = "03dec2002" if statusnotes1 == "compl.folder12/3/02hy ref to belmont 9-14-03hy decl, space 9-29-03hy letter sent out for update 11/03..did not update…folder will be disposed with accor. 7-04hy"
	replace metco_district = "hingham" if statusnotes1 == "4-13-10 declined by 3rd grade principal. ds 3-12-10 file is being referred to bedford. ds 3-5-10 file is complete and ready for referral. a new folder was brouth in by parent but there is already a folder here and i will combine the information. ds folder in plct.entered by bf/2/9/09 ref to hingham. entered by bf/5/13/09. declined by hingham 9/2/09 enter by c. givan on 9/10/09"
		replace date_referred = "09feb2009" if statusnotes1 == "4-13-10 declined by 3rd grade principal. ds 3-12-10 file is being referred to bedford. ds 3-5-10 file is complete and ready for referral. a new folder was brouth in by parent but there is already a folder here and i will combine the information. ds folder in plct.entered by bf/2/9/09 ref to hingham. entered by bf/5/13/09. declined by hingham 9/2/09 enter by c. givan on 9/10/09"
	replace metco_district = "newton" if statusnotes1 == "compl.folder11/26/02hy..referring to newton1/17/03hy declined, not age approp. 1-27-03hy update lttr sent 11-03..did not responf, folder will disposed with accor…7-04hy"
		replace date_referred = "17jan2003" if statusnotes1 == "compl.folder11/26/02hy..referring to newton1/17/03hy declined, not age approp. 1-27-03hy update lttr sent 11-03..did not responf, folder will disposed with accor…7-04hy"
	replace metco_district = "concord" if statusnotes1 == "updte per mother recvd & enter by adfsc on 10/28/05 chg adress and ph nm (old adrs 73 draper st apatr# 1 dorchester ma 02122 also ph nm 617-265-7346) compl.folder11/13/02hy..refered to con/car 2/11/03hy accepted to c/c..k2 03/04hy"
		replace date_referred = "11feb2003" if statusnotes1 == "updte per mother recvd & enter by adfsc on 10/28/05 chg adress and ph nm (old adrs 73 draper st apatr# 1 dorchester ma 02122 also ph nm 617-265-7346) compl.folder11/13/02hy..refered to con/car 2/11/03hy accepted to c/c..k2 03/04hy"
	replace metco_district = "westwood" if statusnotes2 == "declined by reading' on 8/28/06 returned recvd & enter by adfsc on 1/10/06 re-refer to reading on 8/2006 by adfsc refer to westwood on 6/22/06 by adfsc recvd &enter by adfsc also chg adress or updte per folder recvd 2005 info session lttr returned, bad address…11-15-05hy"
		replace date_referred = "22jun2006" if statusnotes2 == "declined by reading' on 8/28/06 returned recvd & enter by adfsc on 1/10/06 re-refer to reading on 8/2006 by adfsc refer to westwood on 6/22/06 by adfsc recvd &enter by adfsc also chg adress or updte per folder recvd 2005 info session lttr returned, bad address…11-15-05hy"
	replace metco_district = "weston" if statusnotes1 == "fldr in plcmnt/will be referred to weston for 2003 1stgr placemnt 11/2003hy refer to weston 2/13/03 by ac/ decline by weston on 5/21/04 by ac"
		replace date_referred = "01nov2003" if statusnotes1 == "fldr in plcmnt/will be referred to weston for 2003 1stgr placemnt 11/2003hy refer to weston 2/13/03 by ac/ decline by weston on 5/21/04 by ac"
	replace metco_district = "bedford" if statusnotes1 == "4-4-12 file is complete and ready for referral. ds 4-13-10 declined by bedford's principal. ds 2-1-10 file is completed and is being referred to bedford. ds"
		replace date_referred = "02jan2010" if statusnotes1 == "4-4-12 file is complete and ready for referral. ds 4-13-10 declined by bedford's principal. ds 2-1-10 file is completed and is being referred to bedford. ds"
	replace metco_district =  "arlington" if statusnotes1 == "declined per lack of space enter by adfsc on 9/12/09 referred to arlington pick up by sp on 3/23/09 by adfsc mother came to register for the second time she had original and because we do have a high request for kii i took the initiative of given her a folder to complete and she also have to complete the information session enter by adfsc on 10/08/08"
		replace date_referred = "09dec2009" if statusnotes1 == "declined per lack of space enter by adfsc on 9/12/09 referred to arlington pick up by sp on 3/23/09 by adfsc mother came to register for the second time she had original and because we do have a high request for kii i took the initiative of given her a folder to complete and she also have to complete the information session enter by adfsc on 10/08/08"
	replace metco_district =  "bedford" if statusnotes2 == "9-8-11 declined by bedford for lack of space. ds 6-23-11 file is being referred to bedford. ds brought folder complete and copied enter by adfsc on 11/08/10 took folder to be complete came before to a information tall her because is been so long she will have to came again enter by adfsc on 10/07/10 change status mother came to check on and adress was updted and enter by adfsc on 10/07/10 2005 info session lttr returned..bad address…11-17-04hy"
		replace date_referred = "23jun2011" if statusnotes2 == "9-8-11 declined by bedford for lack of space. ds 6-23-11 file is being referred to bedford. ds brought folder complete and copied enter by adfsc on 11/08/10 took folder to be complete came before to a information tall her because is been so long she will have to came again enter by adfsc on 10/07/10 change status mother came to check on and adress was updted and enter by adfsc on 10/07/10 2005 info session lttr returned..bad address…11-17-04hy"
	replace metco_district = "reading" if statusnotes1 == "9-8-11 declined by bedford for lack of space. ds 7-12-11 file was referred to bedford. ds 3-10-11 file was referred on 1/13/11 to reading and declined because parent did not return calls for orientation. ds 12-13-10 file is complete and ready for referral. ds received fax with cumus enter by adfsc on 11/04/10 folder received and enter also need to be complete by just bringing the cumulative school recd enter adfsc on 10/19/10"
		replace date_referred = "13jan2011" if statusnotes1 == "9-8-11 declined by bedford for lack of space. ds 7-12-11 file was referred to bedford. ds 3-10-11 file was referred on 1/13/11 to reading and declined because parent did not return calls for orientation. ds 12-13-10 file is complete and ready for referral. ds received fax with cumus enter by adfsc on 11/04/10 folder received and enter also need to be complete by just bringing the cumulative school recd enter adfsc on 10/19/10"
	replace metco_district =  "scituate" if statusnotes1 == "referred to scituate 1-16-03 by ac kids were accpted to scit…however, after a a couple of dys in school, parent withdrew them b/c he said it was hard to get them to bus stop…he wants belmont /brookline…some place close.9-9-03hy  see above note..update lttr, no response 7-04hy"
		replace date_referred = "16jan2003" if statusnotes1 == "referred to scituate 1-16-03 by ac kids were accpted to scit…however, after a a couple of dys in school, parent withdrew them b/c he said it was hard to get them to bus stop…he wants belmont /brookline…some place close.9-9-03hy  see above note..update lttr, no response 7-04hy"
	replace metco_district =  "scituate" if statusnotes1 == "referred to scituate 1-16-03 by ac look under jose for more info..9-5-03hy see above note…update lttr 11-03..7-04hy"
		replace date_referred = "16jan2003" if statusnotes1 == "referred to scituate 1-16-03 by ac look under jose for more info..9-5-03hy see above note…update lttr 11-03..7-04hy"
	replace metco_district =  "swampscott" if statusnotes1 == "to be refer to swampscott on 4/05/07 by adfsc recvd folder and updte status per new one recvd on 4/05/07 by adfsc"
		replace date_referred = "04apr2007" if statusnotes1 == "to be refer to swampscott on 4/05/07 by adfsc recvd folder and updte status per new one recvd on 4/05/07 by adfsc"
	replace metco_district =  "reading" if statusnotes1 == "6-2-11 declined by reading due to parent not showing up to orientation for placement. ds 3-14-11 file is being referred to reading. ds 3-11-11 file is complete and ready for referral. ds"
		replace date_referred = "14mar2011" if statusnotes1 == "6-2-11 declined by reading due to parent not showing up to orientation for placement. ds 3-14-11 file is being referred to reading. ds 3-11-11 file is complete and ready for referral. ds"
	replace metco_district =  "needham" if statusnotes1 == "sharon returned the folder. enter  by bf/7/14/05.   refer to needham on 3/16/05 by ac  received folder on 3/03/05 spoke with mother on 3/11/05 comfirm receiving package from fedex very nice parent on 3/11/05 enter by ac"
		replace date_referred = "16mar2005" if statusnotes1 == "sharon returned the folder. enter  by bf/7/14/05.   refer to needham on 3/16/05 by ac  received folder on 3/03/05 spoke with mother on 3/11/05 comfirm receiving package from fedex very nice parent on 3/11/05 enter by ac"
	replace metco_district =  "brookline" if statusnotes1 == "6-24-10 accepted in lynnfield. ds 4-6-10 file is being referred to lynnfield. ds 3-17-10 file was returned and replaced by siblings. ds 1-29-10 file is being referred to brookline. ds 1-28-10 file is completed and ready for referral. ds"
		replace date_referred = "29jan2010" if statusnotes1 == "6-24-10 accepted in lynnfield. ds 4-6-10 file is being referred to lynnfield. ds 3-17-10 file was returned and replaced by siblings. ds 1-29-10 file is being referred to brookline. ds 1-28-10 file is completed and ready for referral. ds"
	replace metco_district =  "newton" if statusnotes1 == "active in newton acpted at underwood elementary school enter by adfsc on 10/10/08 refer to newton on 12/08/08 by adfsc enter on 3/20/08 updte per folder recvd too young for 2007/08 next year enter by adfsc active as 2008"
		replace date_referred = "08dec2008" if statusnotes1 == "active in newton acpted at underwood elementary school enter by adfsc on 10/10/08 refer to newton on 12/08/08 by adfsc enter on 3/20/08 updte per folder recvd too young for 2007/08 next year enter by adfsc active as 2008"
	replace metco_district =  "lincoln/sudbury" if statusnotes1 == "4/16/ 14 left message physical, 2 proof of address; 3/18/14 & 3/21/14spoke to mom 5th, 8th - 10th grade report cards 9-26-12 declined by lincoln/sudbury per going to a charter school. ds  4-12-12 file is being referred to lincoln/sudbury. i left a message for the mother for physical, 2 proof of address, 5th,6th,7th, 8th and 9th grade report cards. ds enter on 2/11/09 by c. givan."
		replace date_referred = "12apr2012" if statusnotes1 == "4/16/ 14 left message physical, 2 proof of address; 3/18/14 & 3/21/14spoke to mom 5th, 8th - 10th grade report cards 9-26-12 declined by lincoln/sudbury per going to a charter school. ds  4-12-12 file is being referred to lincoln/sudbury. i left a message for the mother for physical, 2 proof of address, 5th,6th,7th, 8th and 9th grade report cards. ds enter on 2/11/09 by c. givan."
	replace metco_district =  "melrose" if statusnotes1 == "ref to melrose 9-9-04hy no kg space 9-04hy parent wrote an accusatory lttr of bias, and requested that her son be taken off the list 11-2-04hy"
		replace date_referred = "09sept2004" if statusnotes1 == "ref to melrose 9-9-04hy no kg space 9-04hy parent wrote an accusatory lttr of bias, and requested that her son be taken off the list 11-2-04hy"
	replace metco_district =  "brookline" if statusnotes1 == "again try another town not acpted by lack of space arlington on 9/01/06 by adfsc re-refer to arlington on 9/01/06 via fax by adfsc deferred for next year melrose on 9/07/06 enter by adfsc  re-refer to melrose on 8/03/2006 folder was ref to brookline on1/10/06.returned on5/25/05. tiana wants her daughter to stay in the dame school. entered by bf/5/25/06. reentered bybf/9/5/06."
		replace date_referred = "10jan2006" if statusnotes1 == "again try another town not acpted by lack of space arlington on 9/01/06 by adfsc re-refer to arlington on 9/01/06 via fax by adfsc deferred for next year melrose on 9/07/06 enter by adfsc  re-refer to melrose on 8/03/2006 folder was ref to brookline on1/10/06.returned on5/25/05. tiana wants her daughter to stay in the dame school. entered by bf/5/25/06. reentered bybf/9/5/06."
	replace metco_district =  "natick" if statusnotes1 == "declined per lack of sapce on 9/23/08 enter by adfsc on 9/24/08 refer to natick on 9/19/08 by adfsc i do believe it was declnd by bedford because it may had been referred there enter by adfsc on 9/24/08"
		replace date_referred = "19sept2008" if statusnotes1 == "declined per lack of sapce on 9/23/08 enter by adfsc on 9/24/08 refer to natick on 9/19/08 by adfsc i do believe it was declnd by bedford because it may had been referred there enter by adfsc on 9/24/08"
		replace metco_district =  "belmont" if statusnotes1 == "4-4-12 declined by belmont no longer taking 7th graders. ds 3-20-12 file is being referred to belmont. ds 2-13-12 file is complete and ready for referral. ds"
		replace date_referred = "20mar2012" if statusnotes1 == "4-4-12 declined by belmont no longer taking 7th graders. ds 3-20-12 file is being referred to belmont. ds 2-13-12 file is complete and ready for referral. ds"
		
	
	* If missing Ref date, but have district, add date:
		replace date_referred = "05may2000" if statusnotes2 == "1/18/00 file complete. hb 5/5/00 file referred out to arl. hb10-01-01 bad address; orientation letter returned pac"
	replace date_referred = "06apr2004" if statusnotes2 == "updted per new roster received on 10/25/07 enter by adfsc refer to sudbury on 4/06/04 by ac accepted by the town of sudbury on 6/23/04 enter by ac"
	replace date_referred = "07jan2011" if statusnotes1 == "8-15-11 active in reading. ds 1-7-11 file is complete and is being referred to reading. ds"
	replace date_referred = "03feb2004" if statusnotes1 == "parent will bring in info for ref. folder to lexington 1/27/04hy fldr in plcmnt 2/2/04hy ref to lex 2/3/04hy"
	replace date_referred = "09may2001" if statusnotes1 == "5--09-01 file complete pac referred to wel pac accepted to wel pac"
	replace date_referred = "08jun2011" if statusnotes1 == "6-8-11 file was referred to wayland as a sibling and is now active. ds"
	replace date_referred = "03feb2006" if statusnotes1 == "active acpted in wayland on 10/03/06 by adfsc re-refer to wayland on 9/07/06 by adfsc declined per lack of space on 8/24/06 by adfsc refer to needham on 2/03/2006 by adfsc"
	replace date_referred = "29jan2010" if statusnotes1 == "active in wayland on 2010 by adfsc referrer to wayland on 1/29/10 review on 2/01/10 by adfsc 1-26-10 father is picking up an application for victor who is a sibling of a wayland student. ds"
	replace date_referred = "24jan2000" if statusnotes1 == "12/23/99 file complete.rj 1/24/00 referred to wellesley.rj 5/1/00!!! wellesley declined; no available space. rj 6/9/00 file referred out to fra. hb"
	replace date_referred = "31may2001" if statusnotes1 == "4-10-01 file complete pac 5/31/01 file referred out to con. hb 6/22/01 parent declined closest bus stop is too far. hb. 9/21/01 file referred out to bro. hb 9/01 student accepted in bro. hb"
	replace date_referred = "03mar2003" if statusnotes1 == "compl.folder11/7/02hy..referred to arlington 3/3/03hy accepted to arlington 03/04hy 1st grade"
	replace date_referred = "22mar2005" if statusnotes1 == "phone changed to 6174424343 andcell 6179661023 . entered by bf/10/18/06. the address changed also. belmont accepted the child : entered by bf/5/09.05    mom would prefer he goes to belmont… fldr in plcmnt 11-8-04hy ref to belmont 3-22-05hy"
	replace date_referred = "30jan2002" if statusnotes1 == "file complete 1/30/02 kae. file refered out to concord 1/30/02 kae. con/car hs 02/03hy"
	replace date_referred = "06jan2011" if statusnotes1 == "5-27-11 active in bedford. ds 1-6-11 file is being referred to bedford. ds 12-21-10 file is complete and ready for referral. ds"
	replace date_referred = "10jan2003" if statusnotes1 == "compl.folder1/2/02hy referring, priority for 2003/4school yearhy..referred folder to lexington1/10/03hy accepted to lexington for 1st gr 03/04hy"
	replace date_referred = "30jan2002" if statusnotes1 == "file complete 1/27/02. file refered out to concord 1/30/02. kae. con/car middle school 02/03 atending hy"
	replace date_referred = "13sep2010" if statusnotes1 == "9-29-10 active in reading. ds 9-13-10 file was referred to reading. ds"
	replace date_referred = "08apr2002" if statusnotes1 == "fldr in plcmnt 1/2004hy set aside (both) for brookline 3/22/04hy ref olan to brook 4-8-04hy decl…mom wanted siblings to go together…dr. morris could not take both…621-04hy"
	replace date_referred = "15dec2011" if statusnotes1 == "7-3-12 active in concord. ds 1-10-12 mother called to check status bring physical and immunization enter by adfsc 12-15-11 file is complete and is being referred to concord. ds"
	replace date_referred = "12mar2009" if statusnotes1 == "to be refer to sudbury next week enter by adfsc on 3/12/09  i did locate folder and called mothering request to updte assessment (because the last one is about an year old) new report card and physical and immunization enter by adfsc on 3/12/09 around 718pm mother call to check status on 3/12/09 by adfsc  after review call parent second time to updte and did updte per new folder recvd enter by adfsc on 9/23/08 around 550pm call and reminded parents to updte on 8/21/08 by adfsc left detail msge declined by melrose on 8/21/08 by adfsc re-refer to melrose on 5/2008 by adfsc declined per lack of space from cohasett on 5/2008 by aadfsc refer to cohasasett pick up by mrs carolina walround on the morning of 3/27/08 sent by adfsc on 3/26/08"
	replace date_referred = "25apr2000" if statusnotes1 == "4/3/00 file complete. hb 4/25/00 file referred out to bra. hb 5/30/00 child accepted in bra. hb"
	replace date_referred = "07jun2006" if statusnotes1 == "address of the by bf/10/16/07. ref to brookline and accepted 6/7/06. entered by bf/7/5/06. mom took a folder. entered by bf/1/9/06."
	replace date_referred = "29aug2001" if statusnotes1 == "8-22-01 file complete pac 8-29-01 referred to fra. pac 9-04-01 fra declined because of no space pac 9-228--01 referred to mar. pac"
	replace date_referred = "02aug2007" if statusnotes1 == "9-21-11 updte per new folder received father adress under male guardian box and grade enter by adfsc active acpted at marblehead high school enter by adfsc on 7/13/09 re-refer again with more updtes via fax by adfsc on 4/06/09 referrer to marblehead enteron 3/26/09 to be pick up by ck on 3/27/09 by adfsc  father called to updted i asked of him for all of the updte doc physical and immunization and current report card enter by adfsc 3/24/09 declined by melrose unable to place due to increased enrollment notes from dw on 8/2007 enter by adfsc on 10/02/07 refer to melrose on 8/02/07 by adfsc"
	replace date_referred = "04aug2000" if statusnotes1 == "updated 04/03/2000 s.y. 2/2/00 - orientation letter returned; bad address. rj 5/19/00 file complte. hb 5/23/00 file referred out to lex. hb 8/4/00 - mom called and said she cant reach cheryl. the machine at the office isn't working or is full and the home # cheryl gave her is the wrong #. mom could not make the meeting at rcc but will be there on aug. 31st for the open house. rj 6-05-01 lex accepted pac"
	replace date_referred = "08sep2004" if statusnotes1 == "active in arlington enter by ac on 7/2004 ref to arlington 9-8-04hy"
	replace date_referred = "05may2000" if statusnotes1 == "3/27/00 file complete. hb hb 5/5/00 file referred out to arl. hb 9/19/00 child accepted in arl. hb new address as of 8-8-01. ea"
	replace date_referred = "04apr2000" if statusnotes1 == "2/18/00 file complete. hb 4/4/00 file referred out to lex. hb"
	replace date_referred = "01feb2010" if statusnotes1 == "6-17-10 accepted in bedford. ds 2-1-10 file is being referred to bedford as a sibling. ds 1-15-10 file is completed and ready for referral. ds"
	replace date_referred = "28apr2008" if statusnotes1 == "refer to belmont will be pick up by diane wilshire on 4/28/08 enter by adfsc on 4/17/08 accepted to bedford. entered by bf/8/28/08."
	replace date_referred = "06apr2004" if statusnotes1 == "accepted town sudbury on 6/23/04 ac refer to sudbury on 4/06/04 by ac"
	replace date_referred = "28jun2006" if statusnotes1 == "acpted by melrose at winthrop school on 7/03/06  refer to melrose by adfsc on 6/28/06  declined from lexington. entered by bf/6/15/06."
	replace date_referred = "26jun2008" if statusnotes1 == "re-refer to melrose on 6/26/08 by adfsc lexington declined. timika called to check the status. entered by bf/6/2/08. folder in plct. received and entered by bf/1/9/08. lexg.or bro"
	replace date_referred = "08jun2010" if statusnotes1 == "8-31-10 active in braintree. ds 8-6-10 file is being referred to braintree. ds please only referrer to walpole, hingham, braintree or arlington,if any qyestion ask antoinette c. on 4/29/10 mother called to check status enter by adfsc on 3/31/10 if possible referrer to wellesley by adfsc llollp  3-9-10 file is complete and ready for referral. ds 3-3-10 mother called us about coming to an info session. ds"
	replace date_referred = "02apr2011" if statusnotes1 == "6-20-11 active in sudbury. ds 2-4-11 file is being referred to sudbury. ds 11-22-10 file is complete and ready for referral. ds"
	replace date_referred = "19jul2007" if statusnotes1 == "enjoyo was referred to bedford and declined . ref to concord on 7/19/07 by bf. accepted to concord. entered by bf/8/22/07."
	replace date_referred = "21jun2011" if statusnotes1 == "7-15-11 active in lincoln. ds 6-21-11 file is being referred to lincoln. ds 2-17-11 file is complete and is ready for referral. ds"
	replace date_referred = "11jun2012" if statusnotes1 == "6-26-12 active in belmont. ds 6-11-12 file is being referred to belmont. ds 10-17-11 declined by brookline per lack of space. ds 8-26-11 file is being referred to brookline. ds 6-21-11 declined by belmont for lack of space. ds 2-14-11 file is complete and being referred to belmont. ds"
	replace date_referred = "16mar2012" if statusnotes1 == "3-16-12 referrer to marblehead piched up by f.f.-a. enter by adfsc 3-08-12 to be referrer to marblehead enter by adfsc 3-08-12 mother came around 1238pm to updte enter by adfsc miss taylor, germaine grandaugther.enter by adfsc 3-07-12 mother called to let me know she will be here tomorrow to updte folder enter by adfsc 2-28-12mother call to check status was advised to updte folder as soon is possible enter by adfsc 7-26-11 file is complete and ready for referral. ds mother called to check on the status alkso was advised to updte next/current end of the year report card, and beginning of next year for physical & immunization, proofs of adress at less 3 months and new report card enter by adfsc on 5/26/10 3-9-10 file is complete and ready for referral. ds lataria took a plct form and she also filled a change form of address . entered by bf/9/29/08"
	replace date_referred = "11may2001" if statusnotes1 == "4-24-01 file complete pac 5-11-01 referred to con. pac attends boston university hy"
	replace date_referred = "22may2001" if statusnotes1 == "4-26-01 file complete pac 5-22-01 referred to con. pac"
	replace date_referred = "14mar2008" if statusnotes1 == "acepted active at lincon/sudbury regional high school recvd letter of aceptance on 6/26/08 enter by adfsc  declined by reading on 6/2008 enter by adfsc  referrer reading on 3/14/2008 by adfsc complete folder recvd by adfsc on 3/2008"
	replace date_referred = "07apr2006" if statusnotes1 == "acpted by reading on 8/15/06 by adfsc refer reading on 4/07/06 by adfsc"
	replace date_referred = "01jul2008" if statusnotes1 == "acpted by melrose on 7/21/08 enter by adfsc on 8/21/08  re-refer to melrose on 7/01/08 by adfsc declined by weston. entered by bf/6/26/08. ref to melrose.  folder in plct. ref to weston by fax .entered by bf/6/11/08."
	replace date_referred = "22dec2010" if statusnotes1 == "7-20-11 active in concord. ds 12-22-10 file is complete and is being referred to concord. ds"
	replace date_referred = "16mar2001" if statusnotes1 == "12-06-00 file complete pac 3/16/01 file referred out to con. hb"
	replace date_referred = "16jan2007" if statusnotes1 == "albino is accepted to lexington. entered by bf/6/20/07. ref to lexington on 1/16/07. by bf.recvd folder updte per folder recvd & enter by adfsc on 12/12/06"
	replace date_referred = "18jan2012" if statusnotes1 == "1-18-12 file is complete and being referred to brookline. ds"
	replace date_referred = "25jul2001" if statusnotes1 == "4/16/99. parent declined placement in lex. never respond to any messages. hb 2/10/01 file complete. hb 3/26/01 file referred out to way. pac 6-04--01 way declined because parent miss meetings. pac 7-25-01 referred to sha pac"
	replace date_referred = "20mar2001" if statusnotes1 == "12-06-00 file complete pac 3/20/01 file referred out to lex. hb 6-05-01 lex accepted pac"
	replace date_referred = "18may2001" if statusnotes1 == "2-27-01 file complete pac 5-18-01 referred to arl. pac update letter sent oct 2002, no response. folder will be disposed with accord. 8-14-03hy"
	replace date_referred = "06dec2010" if statusnotes1 == "6-20-11 active in newton at lincon-elliot enter by adfsc referrer to newton on 12/06/10 by adfsc pick up by s.g. ready to be referrer also updted per new folder received enter by adfsc on 11/17/10 (cousins in newton)"
	replace date_referred = "07dec2008" if statusnotes1 == "active in newton acpted at angier elemntary school enter by adfsc on 10/10/08 re-refer to newton on 12/07/08 by adfsc declined by lack of space arlington enter by adfsc on 9/27/07 refer to arlington on 2/2007 by adfsc  data base updte per folder recvd & enter by adfsc on 3/08/07"
	replace date_referred = "06dec2011" if statusnotes1 == "6-14-12active in newton at underwood elementary school enter by adfsc 12-6-11 file is complete and being referred to newton. ds"
	replace date_referred = "06dec2011" if statusnotes1 == "6-14-12active in newton at underwood elementary school enter by adfsc 12-6-11 file is complete and being referred to newton as a sibling. ds"
	replace date_referred = "27aug2001" if statusnotes1 == "5/14/99 mother wants 1st. grade plcmnt. hb. 1/18/00 - file updated. rj referred out to lex 1/27/00 hb. 03/29/00 parent declined distance. hb.12-16-00 file complete pac 8-27-01 referred to con. pac  update letter sent oct 2002, no response. folder will be disposed with accor 9-10-03hy"
	replace date_referred = "25oct2000" if statusnotes1 == "12/22/99 file complete hb. referred out to lex 1/27/00 hb. 2/2/00 parent dec wants children together. hb 10/25/00 file referred out to wak. hb 11/1/00 parent declined wants k child to attend same community can't place k age children. hb"
	replace date_referred = "29aug2001" if statusnotes1 == "4/4/01 file complete. hb 8-29-01 referred to nee.pac 9-05-01 accepted to lin. pac"
	replace date_referred = "29aug2001" if statusnotes1 == "4/04/01 file complete hb 8-29-0-1 referred to nee. pac 9-05-01 accepted to nee. pac"
	replace date_referred = "12jan2000" if statusnotes1 == "12/23/99 - file complete. rj 1/12/00 - referred to newton. rj 5/29/00 - accepted to newton. rj"
	replace date_referred = "15sept2000" if statusnotes1 == "12/20/99 file complerte hb. 1/24/00 - referred to wellesley. rj 2/8/00 - wellesley declined. student's age and academic readiness raise great concerns. rj 9/15/00 file referred out to fox. hb"
	replace date_referred = "09nov2000" if statusnotes1 == "10/23/00 file complete. hb 11/9/00 file referred out to bra. hb"
	replace date_referred = "21jun2000" if statusnotes1 == "12/3/99 file complete. hb. referred out to lex 1/27/00 hb. 4/3/00 parent declined did not keep appointment. hb 6/6/00 - referred to belmont. rj 6/16/00 community declined space. hb 6/21/00 referred out to hin. hb 7/7/00 child accepted in hin. hb."
	replace date_referred = "13jan2000" if statusnotes1 == "wayland community declined lack of funding. 9/21/99 - referred out to melrose. 9/23/99 - melrose declined; doreen made numerous attempts to contact parent with no success.  parent did not update file. 1/10/00 - mom would like to go to melrose again rj 1/13/00 - referred to newton. rj 5/29/00 - accepted to newton. rj"
	replace metco_district = "newton" if statusnotes1 == "09/17/18 active in newton -was referrer on 01/03/18"