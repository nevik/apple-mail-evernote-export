(*
◸ Veritrope.com
Apple Mail to Evernote
VERSION 2.07
March 14, 2014

// TERMS OF USE:
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

// LIKE THIS SCRIPT?
If this AppleScript is helpful to you, please show your support here:
http://veritrope.com/support

// IMPORTANT LINKS:
-- Project Page: http://veritrope.com/code/apple-mail-to-evernote

// REQUIREMENTS:
THIS SCRIPT REQUIRES LION OR GREATER (OS X 10.7+) TO RUN WITHOUT MODIFICATION

THE APP STORE VERSION OF GROWL IS REQUIRED FOR THIS SCRIPT TO WORK!
(If you do not have it installed, you'll get an error when you try to save this script.)
    -- GROWL IS AVAILABLE FOR DOWNLOAD HERE:
    -- http://bit.ly/GrowlApp

// INSTALLATION:  
-- You can save this script to /Library/Scripts/Mail Scripts and launch it using the system-wide script menu from the Mac OS X menu bar. (The script menu can be activated using the AppleScript Utility application).
-- To use, highlight the email messages you want to archive into Evernote and run this script file;
-- The "User Switches" below allow you to customize the way this script works.
-- You can save this script as a service and trigger it with a keyboard shortcut.

    (Optional but recommended)
    Easier Keyboard Shortcut with FastScripts
    -- Download and Install FastScripts here:
    -- http://bit.ly/FastScripts

// CHANGELOG:

Version 2.07: CHANGE TO UTF DECODING (THANKS EDUARDO!). CC RECIPIENTS ADDED TO NOTEHEADER

    * 2.06
    SWITCH FOR PLAINTEXT OPERATION (FOR NON-ENGLISH ENCODING), FIX FOR MISSING RECIPIENT NAME

    * 2.05
    FIX FOR LEADING SPACES IN TAG LIST
   
    * 2.04
    CHANGE TO DISPLAY MULTIPLE TO: RECIPIENTS, GROWL TWEAKS
   
    * 2.03
    FIXES AND ADJUSTMENTS FOR TAGS, ATTACHMENT OPERATIONS
   
    * 2.02
    CHANGED SOME VARIABLES TO WORK BETTER WITH "OPEN IN SCRIPT EDITOR" BUTTON
   
    * 2.01
    CONSOLIDATED SOME BASE64 CODE INTO A HANDLER, FIXED BUGS WITH ENCODING

    * 2.00 FINAL
    ELIMINATED MAILTAGS SUPPORT, GROWL REQUIREMENT, REWORKED HTML EMAIL TRANSFER FOR 10.7+ SYSTEMS

    * 2.00 b2
    BUG FIXES (USER SWITCH FOR NOTEBOOK, BETTER BASE 64 DETECTION, ATTACHMENT FIX)

    * 2.00 b1
    HTML MESSAGES, APPEND ATTACHMENTS, MAILTAGS, QUIET TEMP FILE REMOVAL

    * 1.30 (June 5, 2010)  
    ATTACHMENT CREATION. LAYING TRACK FOR HTML NOTES.
   
    * 1.20 (July 25, 2009)
    STREAMLINED MENU FOR NOTE EXPORT
   
    * 1.10 (May 6, 2009)  
    ACTIVATED MESSAGE LINKING/ADDED EVERNOTE ICON TO DIALOG BOX/MISC. CLEAN-UP!
   
    * 1.01 (April 23, 2009)
    FIXED TYPOGRAPHICAL ERROR
   
    * 1.00 (April 20, 2009)
    INITIAL RELEASE OF SCRIPT
*)

(*
======================================
// USER SWITCHES
======================================
*)

-- SET THIS TO "OFF" IF YOU WANT TO SKIP THE TAGGING/NOTEBOOK DIALOG
-- AND SEND ITEMS DIRECTLY INTO YOUR DEFAULT NOTEBOOK
property tagging_Switch : "ON"

-- IF YOU'VE DISABLED THE TAGGING/NOTEBOOK DIALOG,
-- TYPE THE NAME OF THE NOTEBOOK YOU WANT TO SEND ITEM TO
-- BETWEEN THE QUOTES IF IT ISN'T YOUR DEFAULT NOTEBOOK.
-- (EMPTY SENDS TO DEFAULT)
property EVnotebook : ""

-- IF TAGGING IS ON AND YOU'D LIKE TO CHANGE THE DEFAULT TAG,
-- TYPE IT BETWEEN THE QUOTES ("Email Message" IS DEFAULT)
property defaultTag : "Email Message"

-- SET THIS TO "OFF" IF YOU WANT TO PROCESS EMAILS
-- AS PLAINTEXT (USEFUL FOR NON-ENGLISH ENCODED EMAILS)
property HTML_Switch : "ON"


(*
======================================
// OTHER PROPERTIES
======================================
*)
property successCount : 0
property growl_Running : "false"
property myTitle : "Mail Item"
property theMessages : {}
property thisMessage : ""
property itemNum : "0"
property attNum : "0"
property errNum : "0"
property userTag : ""
property EVTag : {}
property multiHTML : ""
property theSourceItems : {}
property mySource : ""
property decode_Success : ""
property finalHTML : ""
property myHeaders : ""
property mysource_Paragraphs : {}
property base64_Raw : ""
property baseHTML : ""
property paraSource : ""
property cutSourceItems : ""
property allCC : ""

(*
======================================
// MAIN PROGRAM
======================================
*)

--RESET ITEMS
set successCount to "0"
set errNum to "0"
set AppleScript's text item delimiters to ""

try
    --CHECK FOR GROWL
    my Growl_Check()
   
    --SET UP ACTIVITIES
    my item_Check()
   
    --MESSAGES SELECTED?
    if theMessages is not {} then
       
        --GET FILE COUNT
        my item_Count(theMessages)
       
        --ANNOUNCE THE EXPORT OF ITEMS 
        my process_Items(itemNum, attNum)
       
        --PROCESS MAIL ITEMS FOR EXPORT
        my mail_Process(theMessages)
       
    else
        --NO MESSAGES SELECTED
        set successCount to -1
    end if
   
    --GROWL RESULTS
    my growl_Growler(growl_Running, successCount, errNum)
   
    --ERROR HANDLING
on error errText number errNum
    if growl_Running is true then
       
        --GROWL FAILURE FOR CANCEL
        if errNum is -128 then
            tell application "Growl"
                notify with name ¬
                    "Failure Notification" title ¬
                    "User Cancelled" description ¬
                    "Failed to export!" application name "Apple Mail to Evernote" icon of application "Mail"
               
            end tell
        else
           
            --GROWL FAILURE FOR ERROR
            tell application "Growl"
                notify with name ¬
                    "Failure Notification" title ¬
                    "Import Failure" description "Failed to export " & return & myTitle & ¬
                    "\"  due to the following error: " & return & errText ¬
                    application name "Apple Mail to Evernote" icon of application "Mail"
               
            end tell
        end if
       
        --NON-GROWL ERROR MSG. FOR ERROR
    else if growl_Running is false then
        display dialog "Item Failed to Import: " & errNum & return & errText with icon 0
    end if
end try

(*
======================================
// PREPARATORY SUBROUTINES
=======================================
*)

--APP DETECT
on appIsRunning(appName)
    tell application "System Events" to (name of processes) contains appName
end appIsRunning

--SET UP ACTIVITIES
on item_Check()
    set myPath to (path to home folder)
    tell application "Mail"
        try
            set theMessages to selection
        end try
    end tell
end item_Check

--GET COUNT OF ITEMS AND ATTACHMENTS
on item_Count(theMessages)
    tell application "Mail"
        set itemNum to count of theMessages
        set attNum to 0
        repeat with theMessage in theMessages
            set attNum to attNum + (count of mail attachment of theMessage)
        end repeat
    end tell
end item_Count

(*
======================================
// TAGGING AND NOTEBOOK SUBROUTINES
=======================================
*)

--TAGGING AND NOTEBOOK SELECTION DIALOG
on tagging_Dialog()
    try
        display dialog "" & ¬
            "Please Enter Your Tags Below:
(Multiple Tags Separated By Commas)" with title "Veritrope.com | Apple Mail to Evernote Export" default answer defaultTag buttons {"Create in Default Notebook", "Select Notebook from List", "Cancel"} default button "Create in Default Notebook" cancel button ¬
            "Cancel" with icon path to resource "Evernote.icns" in bundle (path to application "Evernote")
        set dialogresult to the result
        set userInput to text returned of dialogresult
        set ButtonSel to button returned of dialogresult
        set theDelims to {","}
    on error number -128
        set errNum to -128
    end try
   
    --ASSEMBLE LIST OF TAGS
    set theTags to my Tag_List(userInput, theDelims)
   
    --RESET, FINAL CHECK, AND FORMATTING OF TAGS
    set EVTag to {}
    set EVTag to my Tag_Check(theTags)
   
    --SELECT NOTEBOOK
    if ButtonSel is "Select Notebook from List" then set EVnotebook to my Notebook_List()
end tagging_Dialog

--GET EVERNOTE'S DEFAULT NOTEBOOK
on default_Notebook()
    tell application "Evernote"
        set get_defaultNotebook to every notebook whose default is true
        if EVnotebook is "" then
            set EVnotebook to name of (item 1 of get_defaultNotebook) as text
        end if
    end tell
end default_Notebook

--TAG SELECTION SUBROUTINE
on Tag_List(userInput, theDelims)
    set oldDelims to AppleScript's text item delimiters
    set theList to {userInput}
    repeat with aDelim in theDelims
        set AppleScript's text item delimiters to aDelim
        set newList to {}
        repeat with anItem in theList
            set newList to newList & text items of anItem
        end repeat
        set theList to newList
    end repeat
    set AppleScript's text item delimiters to oldDelims
    return theList
end Tag_List

--CREATES TAGS IF THEY DON'T EXIST
on Tag_Check(theTags)
    tell application "Evernote"
        set finalTags to {}
        repeat with theTag in theTags
           
            -- TRIM LEADING SPACE, IF ANY
            if (the character 1 of theTag is " ") then set theTag to text 2 thru end of theTag as text
           
            if (not (tag named theTag exists)) then
                try
                    set makeTag to make tag with properties {name:theTag}
                    set end of finalTags to makeTag
                end try
            else
                set end of finalTags to tag theTag
            end if
        end repeat
    end tell
    return finalTags
end Tag_Check

--EVERNOTE NOTEBOOK SELECTION SUBROUTINE
on Notebook_List()
    tell application "Evernote"
        activate
        set listOfNotebooks to {} (*PREPARE TO GET EVERNOTE'S LIST OF NOTEBOOKS *)
        set EVNotebooks to every notebook (*GET THE NOTEBOOK LIST *)
        repeat with currentNotebook in EVNotebooks
            set currentNotebookName to (the name of currentNotebook)
            copy currentNotebookName to the end of listOfNotebooks
        end repeat
        set Folders_sorted to my simple_sort(listOfNotebooks) (*SORT THE LIST *)
        set SelNotebook to choose from list of Folders_sorted with title "Select Evernote Notebook" with prompt ¬
            "Current Evernote Notebooks" OK button name "OK" cancel button name "New Notebook" (*USER SELECTION FROM NOTEBOOK LIST *)
        if (SelNotebook is false) then (*CREATE NEW NOTEBOOK OPTION *)
            set userInput to ¬
                text returned of (display dialog "Enter New Notebook Name:" default answer "")
            set EVnotebook to userInput
        else
            set EVnotebook to item 1 of SelNotebook
        end if
    end tell
end Notebook_List

(*
======================================
// UTILITY SUBROUTINES
=======================================
*)

-- EXTRACTION SUBROUTINE
on extractBetween(SearchText, startText, endText)
    set tid to AppleScript's text item delimiters
    set AppleScript's text item delimiters to startText
    set endItems to text of text item -1 of SearchText
    set AppleScript's text item delimiters to endText
    set beginningToEnd to text of text item 1 of endItems
    set AppleScript's text item delimiters to tid
    return beginningToEnd
end extractBetween

--SORT SUBROUTINE
on simple_sort(my_list)
    set the index_list to {}
    set the sorted_list to {}
    repeat (the number of items in my_list) times
        set the low_item to ""
        repeat with i from 1 to (number of items in my_list)
            if i is not in the index_list then
                set this_item to item i of my_list as text
                if the low_item is "" then
                    set the low_item to this_item
                    set the low_item_index to i
                else if this_item comes before the low_item then
                    set the low_item to this_item
                    set the low_item_index to i
                end if
            end if
        end repeat
        set the end of sorted_list to the low_item
        set the end of the index_list to the low_item_index
    end repeat
    return the sorted_list
end simple_sort

--REMOVE EMBEDDED IMAGE REFERENCES
on stripCID(imgstpHTML)
    set theCommandString to "echo " & quoted form of imgstpHTML & " | sed 's/\"cid:.*\"/\"\"/'"
    set theResult to do shell script theCommandString
    return theResult
end stripCID

on trimStart(str)
    -- Thanks to HAS (http://applemods.sourceforge.net/mods/Data/String.php)
    local str, whiteSpace
    try
        set str to str as string
        set whiteSpace to {character id 10, return, space, tab}
        try
            repeat while str's first character is in whiteSpace
                set str to str's text 2 thru -1
            end repeat
            return str
        on error number -1728
            return ""
        end try
    on error eMsg number eNum
        error "Can't trimStart: " & eMsg number eNum
    end try
end trimStart


(*
======================================
// PROCESS MAIL ITEMS SUBROUTINE
=======================================
*)

on mail_Process(theMessages)
    --CHECK DEFAULT NOTEBOOK
    my default_Notebook()
    tell application "Mail"
        try
            if tagging_Switch is "ON" then my tagging_Dialog()
           
            repeat with thisMessage in theMessages
                try
                    --GET MESSAGE INFO
                    set myTitle to the subject of thisMessage
                    set myContent to the content of thisMessage
                    set mySource to the source of thisMessage
                    set ReplyAddr to the reply to of thisMessage
                    set EmailDate to the date received of thisMessage
                    set allRecipients to (every to recipient of item 1 of thisMessage)
                   
                    --TEST FOR CC RECIPIENTS
                    set allCCs to (every cc recipient of item 1 of thisMessage)
                   
                    --ASSEMBLE ALL TO: RECIPENTS FOR HEADER
                    set toRecipients to ""
                    repeat with allRecipient in allRecipients
                        set toName to ""
                        set toName to (name of allRecipient)
                        if toName is missing value then set toName to ""
                        set toEmail to (address of allRecipient)
                        set toCombined to toName & space & "(" & toEmail & ")<br/>"
                        set toRecipients to (toRecipients & toCombined as string)
                    end repeat
                   
                    --ASSEMBLE ALL CC: RECIPENTS FOR HEADER
                    set ccRecipients to ""
                   
                    if allCCs is not {} then
                        repeat with allCC in allCCs
                            set ccName to ""
                            set ccName to (name of allCC)
                            if ccName is missing value then set toName to ""
                            set ccEmail to (address of allCC)
                            set ccCombined to ccName & space & "(" & ccEmail & ")<br/>"
                            set ccRecipients to (ccRecipients & ccCombined as string)
                        end repeat
                    end if
                    --CREATE MAIL MESSAGE URL
                    set theRecipient to ""
                    set ex to ""
                    set MsgLink to ""
                    try
                        set theRecipient to ""
                        set theRecipient to the address of to recipient 1 of thisMessage
                        set MsgLink to "message://%3c" & thisMessage's message id & "%3e"
                        if theRecipient is not "" then set ex to my extractBetween(ReplyAddr, "<", ">") -- extract the Address
                    end try
                   
                    --HTML EMAIL FUNCTIONS
                    set theBoundary to my extractBetween(mySource, "boundary=\"", "\"" & linefeed)
                    set theMessageStart to (return & "--" & theBoundary)
                    set theMessageEnd to ("--" & theBoundary & return & "Content-Type:")
                    set paraSource to paragraphs of mySource
                    set myHeaderlines to paragraphs of (all headers of thisMessage as rich text)
                   
                   
                    --GET CONTENT TYPE
                    repeat with myHeaderline in myHeaderlines
                        if myHeaderline starts with "Content-Type: " then
                            set myHeaders to my extractBetween(myHeaderline, "Content-Type: ", ";")
                        end if
                    end repeat
                    set cutSource to my stripHeader(paraSource, myHeaderlines)
                    set evHTML to cutSource
                end try
               
                --MAKE HEADER TEMPLATE
                set the_Template to "
<table border=\"1\" width=\"100%\" cellspacing=\"0\" cellpadding=\"2\">
<tbody>

<tr BGCOLOR=\"#ffffff\">
<td valign=\"top\"><font color=\"#797979\"><strong>From: </strong>  </td>
<td valign=\"top\" ><a href=\"mailto:" & ex & "\">" & ex & "</a></td>
</tr>

<tr BGCOLOR=\"#ffffff\">
<td valign=\"top\"><font color=\"#797979\"><strong>Subject: </strong>  </td>
<td valign=\"top\" ><strong>" & myTitle & "</strong></td>
</tr>

<tr BGCOLOR=\"#ffffff\">
<td valign=\"top\"><font color=\"#797979\"><strong>Date / Time:  </strong></td>
<td valign=\"top\">" & EmailDate & "</td>
</tr>

<tr BGCOLOR=\"#ffffff\">
<td valign=\"top\"><font color=\"#797979\"><strong>To:</strong></td>
<td valign=\"top\">" & toRecipients & "</td>
</tr>

<tr BGCOLOR=\"#ffffff\">
<td valign=\"top\"><font color=\"#797979\"><strong>CC:</strong></td>
<td valign=\"top\">" & ccRecipients & "</td>
</tr>
</tbody>
</table>
<hr />"
               
                --SEND ITEM TO EVERNOTE SUBROUTINE
                my make_Evernote(myTitle, EVTag, EmailDate, MsgLink, myContent, mySource, theBoundary, theMessageStart, theMessageEnd, myHeaders, thisMessage, evHTML, EVnotebook, the_Template)
               
            end repeat
        end try
    end tell
end mail_Process


(*
======================================
// MAKE ITEM IN EVERNOTE SUBROUTINE
=======================================
*)

on make_Evernote(myTitle, EVTag, EmailDate, MsgLink, myContent, mySource, theBoundary, theMessageStart, theMessageEnd, myHeaders, thisMessage, evHTML, EVnotebook, the_Template)
   
    tell application "Evernote"
        try
           
           
           
            --IS IT A TEXT EMAIL?  
            if myHeaders contains "text/plain" then
                set n to create note with html the_Template title myTitle notebook EVnotebook
                if EVTag is not {} then assign EVTag to n
                tell n to append text myContent
                set creation date of n to EmailDate
                set source URL of n to MsgLink
               
                -- IF HTML PROCESSING IS TURNED TO "OFF", PROCESS
                -- AS PLAINTEXT (USEFUL FOR NON-ENGLISH ENCODED EMAILS)
            else if HTML_Switch is "OFF" then
                set n to create note with html the_Template title myTitle notebook EVnotebook
                if EVTag is not {} then assign EVTag to n
                tell n to append text myContent
                set creation date of n to EmailDate
                set source URL of n to MsgLink
                --IS IT MULTIPART ALTERNATIVE?
            else if myHeaders contains "multipart/alternative" then
               
                --CHECK FOR BASE64
                set base64Detect to my base64_Check(mySource)
               
                --IF MESSAGE IS BASE64 ENCODED...
                if base64Detect is true then
                    set multiHTML to my extractBetween(mySource, "Content-Transfer-Encoding: base64", "--" & theBoundary)
                   
                    --STRIP OUT CONTENT-DISPOSITION, IF NECESSARY
                    if multiHTML contains "Content-Disposition: inline" then set multiHTML to my extractBetween(multiHTML, "Content-Disposition: inline", theBoundary)
                    if multiHTML contains "Content-Transfer-Encoding: 7bit" then set multiHTML to my extractBetween(multiHTML, "Content-Transfer-Encoding: 7bit", theBoundary)
                   
                    --TRIM LEADING LINEFEEDS
                    set baseHTML to my trimStart(multiHTML)
                   
                    --DECODE BASE64
                    set baseHTML to do shell script "echo " & (quoted form of baseHTML) & "| base64 -D"
                   
                    --MAKE NOTE IN EVERNOTE
                    set n to create note with html the_Template title myTitle notebook EVnotebook
                    if EVTag is not {} then assign EVTag to n
                    tell n to append html baseHTML
                    set creation date of n to EmailDate
                    set source URL of n to MsgLink
                else
                   
                    --IF MESSAGE IS NOT BASE64 ENCODED...
                    set finalHTML to my htmlFix(mySource, theBoundary, myContent)
                    if decode_Success is true then
                       
                        --MAKE NOTE IN EVERNOTE
                        set n to create note with html the_Template title myTitle notebook EVnotebook
                        if EVTag is not {} then assign EVTag to n
                        tell n to append html finalHTML
                        set creation date of n to EmailDate
                        set source URL of n to MsgLink
                    else
                       
                        --MAKE NOTE IN EVERNOTE
                        set n to create note with html the_Template title myTitle notebook EVnotebook
                        if EVTag is not {} then assign EVTag to n
                        tell n to append text myContent
                        set creation date of n to EmailDate
                        set source URL of n to MsgLink
                    end if
                end if
               
                --IS IT MULTIPART MIXED?
            else if myHeaders contains "multipart" then
                if mySource contains "Content-Type: text/html" then
                   
                    --CHECK FOR BASE64
                    set base64Detect to my base64_Check(mySource)
                   
                    --IF MESSAGE IS BASE64 ENCODED...
                    if base64Detect is true then
                        set baseHTML to my base64_Decode(mySource)
                       
                        --MAKE NOTE IN EVERNOTE
                        set n to create note with html the_Template title myTitle notebook EVnotebook
                        if EVTag is not {} then assign EVTag to n
                        tell n to append html baseHTML
                        set creation date of n to EmailDate
                        set source URL of n to MsgLink
                       
                        --IF MESSAGE IS NOT BASE64 ENCODED...
                    else if base64Detect is false then
                        set finalHTML to my htmlFix(mySource, theBoundary, myContent)
                        if decode_Success is true then
                           
                            --MAKE NOTE IN EVERNOTE
                            set n to create note with html the_Template title myTitle notebook EVnotebook
                            if EVTag is not {} then assign EVTag to n
                            tell n to append html finalHTML
                            set creation date of n to EmailDate
                            set source URL of n to MsgLink
                        else
                           
                            --MAKE NOTE IN EVERNOTE
                            set n to create note with html the_Template title myTitle notebook EVnotebook
                            if EVTag is not {} then assign EVTag to n
                            tell n to append text myContent
                            set creation date of n to EmailDate
                            set source URL of n to MsgLink
                        end if
                    end if
                   
                else if mySource contains "text/plain" then
                   
                    --MAKE NOTE IN EVERNOTE
                    set n to create note with html the_Template title myTitle notebook EVnotebook
                    if EVTag is not {} then assign EVTag to n
                    tell n to append text myContent
                    set creation date of n to EmailDate
                    set source URL of n to MsgLink
                   
                end if -- MULTIPART MIXED
               
                --OTHER TYPES OF HTML-ENCODING 
            else
               
                --CHECK FOR BASE64
                set base64Detect to my base64_Check(mySource)
               
                --IF MESSAGE IS BASE64 ENCODED...
                if base64Detect is true then
                    set finalHTML to my base64_Decode(mySource)
                else
                    set multiHTML to my extractBetween(evHTML, "</head>", "</html>")
                    set finalHTML to my htmlFix(multiHTML, theBoundary, myContent) as text
                end if
               
                --MAKE NOTE IN EVERNOTE
                set n to create note with html the_Template title myTitle notebook EVnotebook
                if EVTag is not {} then assign EVTag to n
                tell n to append html finalHTML
                set creation date of n to EmailDate
                set source URL of n to MsgLink
               
                --END OF MESSAGE PROCESSING
            end if
           
            --START OF ATTACHMENT PROCESSING
            tell application "Mail"
                --IF ATTACHMENTS PRESENT, RUN ATTACHMENT SUBROUTINE
                if thisMessage's mail attachments is not {} then my attachment_process(thisMessage, n)
            end tell
            --ITEM HAS FINISHED! COUNT IT AS A SUCCESS!
            set successCount to successCount + 1
        end try
    end tell
    log "successCount: " & successCount
end make_Evernote



(*
======================================
// ATTACHMENT SUBROUTINES
=======================================
*)

--FOLDER EXISTS?
on f_exists(ExportFolder)
    try
        set myPath to (path to home folder)
        get ExportFolder as alias
        set SaveLoc to ExportFolder
    on error
        tell application "Finder" to make new folder with properties {name:"Temp Export From Mail"}
    end try
end f_exists

--ATTACHMENT PROCESSING
on attachment_process(thisMessage, n)
    tell application "Mail"
       
        --MAKE SURE TEXT ITEM DELIMITERS ARE DEFAULT
        set AppleScript's text item delimiters to ""
       
        --TEMP FILES PROCESSED ON THE DESKTOP
        set ExportFolder to ((path to desktop folder) & "Temp Export From Mail:") as string
        set SaveLoc to my f_exists(ExportFolder)
       
        --PROCESS THE ATTACHMENTS
        set theAttachments to thisMessage's mail attachments
        set attCount to 0
        repeat with theAttachment in theAttachments
            set theFileName to ExportFolder & theAttachment's name
            try
                save theAttachment in file theFileName
            end try
            tell application "Evernote"
                tell n to append attachment file theFileName
            end tell
           
            --SILENT DELETE OF TEMP FILE
            set trash_Folder to path to trash folder from user domain
            do shell script "mv " & quoted form of POSIX path of theFileName & space & quoted form of POSIX path of trash_Folder
           
        end repeat
       
        --SILENT DELETE OF TEMP FOLDER
        set success to my trashfolder(SaveLoc)
       
    end tell
end attachment_process

--SILENT DELETE OF TEMP FOLDER (THANKS MARTIN MICHEL!)
on trashfolder(SaveLoc)
    try
        set trashfolderpath to ((path to trash) as Unicode text)
        set srcfolderinfo to info for (SaveLoc as alias)
        set srcfoldername to name of srcfolderinfo
        set SaveLoc to quoted form of POSIX path of SaveLoc
        set counter to 0
        repeat
            if counter is equal to 0 then
                set destfolderpath to trashfolderpath & srcfoldername & ":"
            else
                set destfolderpath to trashfolderpath & srcfoldername & " " & counter & ":"
            end if
            try
                set destfolderalias to destfolderpath as alias
            on error
                exit repeat
            end try
            set counter to counter + 1
        end repeat
        set destfolderpath to quoted form of POSIX path of destfolderpath
        set command to "ditto " & SaveLoc & space & destfolderpath
        do shell script command
        -- this won't be executed if the ditto command errors
        set command to "rm -r " & SaveLoc
        do shell script command
        return true
    on error
        return false
    end try
end trashfolder

(*
======================================
// HTML CLEANUP SUBROUTINES
=======================================
*)

--HEADER STRIP (THANKS DOMINIK!)
on stripHeader(paraSource, myHeaderlines)
   
    -- FIND THE LAST NON-EMPTY HEADER LINE
    set lastheaderline to ""
    set n to count (myHeaderlines)
    repeat while (lastheaderline = "")
        set lastheaderline to item n of myHeaderlines
        set n to n - 1
    end repeat
   
    -- COMPARE HEADER TO SOURCE
    set sourcelength to (count paraSource)
    repeat with n from 1 to sourcelength
        if (item n of paraSource is equal to "") then exit repeat
    end repeat
   
    -- STRIP OUT THE HEADERS
    set cutSourceItems to (items (n + 1) thru sourcelength of paraSource)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to return
    set cutSource to (cutSourceItems as text)
    set AppleScript's text item delimiters to oldDelims
   
    return cutSource
   
end stripHeader

--BASE64 CHECK
on base64_Check(mySource)
    set base64Detect to false
    set base64MsgStr to "Content-Transfer-Encoding: base64"
    set base64ContentType to "Content-Type: text"
    set base64MsgOffset to offset of base64MsgStr in mySource
    set base64ContentOffset to offset of base64ContentType in mySource
    set base64Offset to base64MsgOffset - base64ContentOffset as real
    set theOffset to base64Offset as number
    if theOffset is not greater than or equal to 50 then
        if theOffset is greater than -50 then set base64Detect to true
    end if
    return base64Detect
end base64_Check

--BASE64 DECODE
on base64_Decode(mySource)
    --USE TID TO QUICKLY ISOLATE BASE64 DATA
    set oldDelim to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "Content-Type: text/html"
    set base64_Raw to second text item of mySource
    set AppleScript's text item delimiters to linefeed & linefeed
    set base64_Raw to second text item of base64_Raw
    set AppleScript's text item delimiters to "-----"
    set multiHTML to first text item of base64_Raw
    set AppleScript's text item delimiters to oldDelim
   
    --DECODE BASE64
    set baseHTML to do shell script "echo " & (quoted form of multiHTML) & "| base64 -D"
   
    return baseHTML
end base64_Decode


--HTML FIX
on htmlFix(multiHTML, theBoundary, myContent)
   
    set oldDelims to AppleScript's text item delimiters
    --set multiHTML to evHTML as string
   
    --TEST FOR / STRIP OUT HEADER
    set paraSource to paragraphs of multiHTML
    if item 1 of paraSource contains "Received:" then
        set myHeaderlines to (item 1 of paraSource)
        set multiHTML to my stripHeader(paraSource, myHeaderlines)
    end if
   
    --TRIM ENDING
    if multiHTML contains "</html>" then
        set multiHTML to my extractBetween(multiHTML, "Content-Type: text/html", "</html>")
    else
        set multiHTML to my extractBetween(multiHTML, "Content-Type: text/html", "--" & theBoundary)
    end if
    set paraSource to paragraphs of multiHTML
   
    --TEST FOR / STRIP OUT LEADING SEMI-COLON
    if item 1 of paraSource contains ";" then
        set myHeaderlines to (item 1 of paraSource)
        set multiHTML to my stripHeader(paraSource, myHeaderlines)
        set paraSource to paragraphs of multiHTML
    end if
   
    --TEST FOR EMPTY LINE / CLEAN SUBSEQUENT ENCODING INFO, IF NECESSARY
    if item 1 of paraSource is "" then
        --TEST FOR / STRIP OUT CONTENT-TRANSFER-ENCODING
        if item 2 of paraSource contains "Content-Transfer-Encoding" then
            set myHeaderlines to (item 2 of paraSource)
            set multiHTML to my stripHeader(paraSource, myHeaderlines)
            set paraSource to paragraphs of multiHTML
        end if
        --TEST FOR / STRIP OUT CHARSET
        if item 2 of paraSource contains "charset" then
            set myHeaderlines to (item 2 of paraSource)
            set multiHTML to my stripHeader(paraSource, myHeaderlines)
            set paraSource to paragraphs of multiHTML
        end if
    end if
   
    --TEST FOR / STRIP OUT CONTENT-TRANSFER-ENCODING
    if item 1 of paraSource contains "Content-Transfer-Encoding" then
        set myHeaderlines to (item 1 of paraSource)
        set multiHTML to my stripHeader(paraSource, myHeaderlines)
        set paraSource to paragraphs of multiHTML
    end if
   
    --TEST FOR / STRIP OUT CHARSET
    if item 1 of paraSource contains "charset" then
        set myHeaderlines to (item 1 of paraSource)
        set multiHTML to my stripHeader(paraSource, myHeaderlines)
        set paraSource to paragraphs of multiHTML
    end if
   
    --CLEAN CONTENT
    set AppleScript's text item delimiters to theBoundary
    set theSourceItems to text items of multiHTML
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "&#" & "37;" as string
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "="
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "%"
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%\""
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "=\""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%" & (ASCII character 13)
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%%"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "%"
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%" & (ASCII character 10)
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%0A"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%09"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%C2%A0"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "&nbsp;"
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "%20"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to " "
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to (ASCII character 10)
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to ""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "="
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "&#" & "61;" as string
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "$"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "&#" & "36;" as string
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "'"
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "&apos;"
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to "\""
    set theSourceItems to text items of theEncoded
    set AppleScript's text item delimiters to "\\\""
    set theEncoded to theSourceItems as text
   
    set AppleScript's text item delimiters to oldDelims
   
    set trimHTML to my extractBetween(theEncoded, "</head>", "</html>")
   
    set theHTML to myContent
   
    try
        set decode_Success to false
       
        --UTF-8 CONV
        set NewEncodedText to do shell script "echo " & quoted form of trimHTML & " | iconv -t UTF-8 "
        set the_UTF8Text to quoted form of NewEncodedText
       
        --URL DECODE CONVERSION
        set theDecodeScript to "php -r \"echo utf8_encode(urldecode(utf8_decode(" & the_UTF8Text & ")));\"" as text
        set theDecoded to do shell script theDecodeScript
       
        --FIX FOR APOSTROPHE / PERCENT / EQUALS ISSUES
        set AppleScript's text item delimiters to "&apos;"
        set theSourceItems to text items of theDecoded
        set AppleScript's text item delimiters to "'"
        set theDecoded to theSourceItems as text
       
        set AppleScript's text item delimiters to "&#" & "37;" as string
        set theSourceItems to text items of theDecoded
        set AppleScript's text item delimiters to "%"
        set theDecoded to theSourceItems as text
       
        set AppleScript's text item delimiters to "&#" & "61;" as string
        set theSourceItems to text items of theDecoded
        set AppleScript's text item delimiters to "="
        set theDecoded to theSourceItems as text
       
        --RETURN THE VALUE
        set finalHTML to theDecoded
        set decode_Success to true
        return finalHTML
    end try
   
end htmlFix

(*
======================================
// GROWL SUBROUTINES
=======================================
*)

--CHECK FOR GROWL
on Growl_Check()
    if appIsRunning("Growl") then
        set growl_Running to true
        tell application "Growl"
            set allNotificationsFiles to {"Import To Evernote", "Success Notification", "Failure Notification"}
            set enabledNotificationsFiles to {"Import To Evernote", "Success Notification", "Failure Notification"}
            register as application ¬
                "Apple Mail to Evernote" all notifications allNotificationsFiles ¬
                default notifications enabledNotificationsFiles ¬
                icon of application "Mail"
        end tell
    end if
end Growl_Check

--ANNOUNCE THE COUNT OF TOTAL ITEMS TO EXPORT
on process_Items(itemNum, attNum)
    set attPlural to ""
    if attNum = 0 then
        set attNum to "No"
    else if attNum > 1 then
        set attPlural to "s"
    end if
    tell application "Finder"
        if growl_Running is true then
            set Plural_Test to (itemNum) as number
            if Plural_Test is greater than 1 then
                tell application "Growl"
                    notify with name ¬
                        "Import To Evernote" title ¬
                        "Import To Evernote Started" description "Now Processing " & itemNum & " Items with " & attNum & ¬
                        " attachment" & attPlural & "." application name ¬
                        "Apple Mail to Evernote" icon of application "Mail"
                end tell
            else
                tell application "Growl"
                    notify with name ¬
                        "Import To Evernote" title ¬
                        "Import To Evernote Started" description "Now Processing " & itemNum & " Item With " & attNum & ¬
                        " Attachment" & attPlural & "." application name ¬
                        "Apple Mail to Evernote" icon of application "Mail"
                   
                end tell
            end if
        end if
    end tell --FINDER
end process_Items

--GROWL RESULTS
on growl_Growler(growl_Running, successCount, errNum)
    if growl_Running is true then
        tell application "Growl"
            -- GROWL FAILURE FOR CANCEL
            if errNum is -128 then tell application "Growl" to notify with name ¬
                "Failure Notification" title ¬
                "User Cancelled" description ¬
                "Failed to export!" application name "Apple Mail to Evernote" icon of application "Mail"
           
           
            -- GROWL FAILURE
            set Plural_Test to (successCount) as number
            if Plural_Test is -1 then
                notify with name ¬
                    "Failure Notification" title ¬
                    "Import Failure" description "No Items Selected In Apple Mail!" application name "Apple Mail to Evernote" icon of application "Mail"
            else if Plural_Test is 0 then
                notify with name ¬
                    "Failure Notification" title ¬
                    "Import Failure" description "No Items Exported From Mail!" application name "Apple Mail to Evernote" icon of application "Mail"
               
               
                -- GROWL SUCCESS
            else if Plural_Test is equal to 1 then
                notify with name ¬
                    "Success Notification" title ¬
                    "Import Success" description "Successfully Exported " & itemNum & ¬
                    " Item to the " & EVnotebook & " Notebook in Evernote" application name "Apple Mail to Evernote" icon of application "Mail"
               
               
                -- GROWL SUCCESS
            else if Plural_Test is greater than 1 then
                notify with name ¬
                    "Success Notification" title ¬
                    "Import Success" description "Successfully Exported " & itemNum & ¬
                    " Items to the " & EVnotebook & " Notebook in Evernote" application name "Apple Mail to Evernote" icon of application "Mail"
               
            end if
        end tell
        set itemNum to "0"
    end if
end growl_Growler
