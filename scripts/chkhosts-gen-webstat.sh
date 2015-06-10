#!/bin/bash
#
# Script to generate host status php web page and
# the description & comment update form pages.
#
# usage: chkhosts-gen-webstat.sh  chkhosts_directory

OUR_CONFIG_FILE=chkhosts-gen-webstat.conf

# Announce ourselves.
echo "Chkhosts-gen-webstat.sh MY_VERSION_STRING"

# Check for required parameter and grab our working directory
if [[ "$#" -ne "1" ]]; then
        echo ""
        echo "ERROR:  Must specify chkhost's working directory."
        echo ""
        exit 1
else
        WORKDIR=$1
fi

# source OUR_CONFIG_FILENAME to set user-configurable variables
if [[ -e "$WORKDIR/conf/$OUR_CONFIG_FILE" ]]; then
	echo "Sourcing $WORKDIR/conf/$OUR_CONFIG_FILE..."
	source $WORKDIR/conf/$OUR_CONFIG_FILE
else
        echo ""
        echo "ERROR:  Cannot access $WORKDIR/conf/$OUR_CONFIG_FILE.  Aborting."
        echo ""
        exit 2
fi

# Now set our variables relative to the working directory
HOSTLISTFILE=$WORKDIR/conf/hostlist.txt
EMAIL_LIST=$WORKDIR/conf/notify-email.txt
SMS_LIST=$WORKDIR/conf/notify-sms.txt
UPHOSTSTATUSDIR=$WORKDIR/status-up
DOWNHOSTSTATUSDIR=$WORKDIR/status-down
CHKHOSTLOGDIR=$WORKDIR/log
CHKHOSTLOG=$CHKHOSTLOGDIR/chkhosts.log
WEBSTATDIR=$WORKDIR/webstat
WEBDESCRIPTIONDIR=$WEBSTATDIR/system-description
WEBCOMMENTDIR=$WEBSTATDIR/system-comment
WEBPAGE=$WEBSTATDIR/status.php
COMMENTFORM=$WEBSTATDIR/update-comment.php
DESCFORM=$WEBSTATDIR/update-description.php

# Calculate the number of hosts we're monitoring
NUMSYSTEMS=$(grep -v -e '^#' $HOSTLISTFILE | wc -l)


#
# Create the Comment Form page first
####################################

echo "Generating $COMMENTFORM..."
echo '<!DOCTYPE html>' >$COMMENTFORM
echo '<html>'  >>$COMMENTFORM
echo '<head>'  >>$COMMENTFORM
echo '	<meta charset="UTF-8">' >>$COMMENTFORM
echo '	<meta name="generator" content="gen-webstat.sh MY_VERSION_STRING">' \
	>>$COMMENTFORM
echo '	<link rel="stylesheet" type="text/css" href="style.css">' >>$COMMENTFORM
echo "	<title>${_CHKHOSTS_COMMENTFORM_TITLE_}</title>"   >>$COMMENTFORM
echo '</head>' >>$COMMENTFORM
echo ' ' >>$COMMENTFORM

echo '<body>' >>$COMMENTFORM

# insert the php POST function and showstatus functions
cat >>$COMMENTFORM << "SUBMIT_FUNCTION_SECTION"
<?php
	session_start();
	if (isset($_SESSION['comment_session'])) {
		/* Don't do anything - already processed the submit... */
	}
	else {
        	if (isset($_POST['submit'])) {
               		$action_hostname = $_POST['CommentHostName'];
                	$action_comment = $_POST['CommentText'];
                	file_put_contents("system-comment/$action_hostname.txt",
				$action_comment);
                	$log_entry = strftime("%F %T: ") . 
				"$action_hostname, $action_comment\n";
                	file_put_contents("comment.log",$log_entry, 
				FILE_APPEND);
			header('Location: status.php');
			exit();
		}
        }
?>
SUBMIT_FUNCTION_SECTION

# insert the comment section 
cat >>$COMMENTFORM << "COMMENT_SECTION_1"
<h3>_CHKHOSTS_COMMENTFORM_TITLE_</h3>
<p>
This form allows you to update the <b>comment</b> line of 
the selected host. &nbsp;
</p>
<form action="<?php echo $_SERVER['PHP_SELF']; ?>" method="post">
<table align="center" style="border-spacing: 1px;border-style: solid;
              border-color: #000000;border-width: 3px 3px 3px 3px">
        <tr><td><b>Host:</b> &nbsp;
                <select name="CommentHostName">
                        <option selected value="unknown">&lt;select host&gt;
COMMENT_SECTION_1

# ensure system-comment directory and comment.log exist
mkdir -p $WEBCOMMENTDIR
touch $WEBSTATDIR/comment.log

# add the hosts to the drop-down list
for i in $( grep -v -e '^#' $HOSTLISTFILE ); do

	# create short host name...
        IPADDR="`echo $i | grep -e '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'`"
        if [[ "$IPADDR" == "" ]]; then
                SHORTNAME="`echo $i | awk -F . '{ print $1}'`"
        else
                SHORTNAME="$IPADDR"
	fi

	# add to list in web page
	echo "		<option value=\"$SHORTNAME\">$SHORTNAME" \
		>>$COMMENTFORM

	# add initial comment to comment file for host
	echo "no comment" >$WEBCOMMENTDIR/$SHORTNAME.txt
done

# set permissions to ensure web server can write the files
chmod ugo+w $WEBCOMMENTDIR/* $WEBSTATDIR/comment.log

cat >>$COMMENTFORM << "COMMENT_SECTION_2"
                </select>
                </td></tr>
        <tr><td><b>Comment:</b> &nbsp;
                <input type="text" name="CommentText" size=40 maxlength=512 /></td></tr>
        <tr><td align="center"><input type="submit" name="submit" value="Update Comment"></td></tr>
</table>
</form>

<p>&nbsp;</p>
<div class="footer"> 
      <hr width="55%">
      <p align="center">This page generated by 
	<a href="https://github.com/k6ekb/chkhosts">
	gen-webstat.sh MY_VERSION_STRING</a><br>
	This page last edited on 
	<?php echo  strftime("%a, %d %b %Y at %H:%M %Z.", 
		filemtime("update-comment.php")); ?><br>
        You're logged in as '<?php print getenv("REMOTE_USER");?>' 
	from <?php print getenv("REMOTE_ADDR"); ?><br>
</div>
COMMENT_SECTION_2

#
# Close out COMMENTFORM document 
#############################

echo '</body>' >>$COMMENTFORM
echo '</html>' >>$COMMENTFORM

# now customize the Comment Form page...
sed -i "s/_CHKHOSTS_COMMENTFORM_TITLE_/${_CHKHOSTS_COMMENTFORM_TITLE_}/g" $COMMENTFORM
sed -i "s/_CHKHOSTS_HOSTNAME_/${_CHKHOSTS_HOSTNAME_}/g" $COMMENTFORM
sed -i "s/_CHKHOSTS_POLL_INTERVAL_/${_CHKHOSTS_POLL_INTERVAL_}/g" $COMMENTFORM
sed -i "s/_CHKHOSTS_CONTACTNAME_/${_CHKHOSTS_CONTACTNAME_}/g" $COMMENTFORM
sed -i "s/_CHKHOSTS_CONTACTEMAIL_/${_CHKHOSTS_CONTACTEMAIL_}/g" $COMMENTFORM


#
# Create the Description Form page next
#######################################

echo "Generating $DESCFORM..."
echo '<!DOCTYPE html>' >$DESCFORM
echo '<html>'  >>$DESCFORM
echo '<head>'  >>$DESCFORM
echo '	<meta charset="UTF-8">' >>$DESCFORM
echo '	<meta name="generator" content="gen-webstat.sh MY_VERSION_STRING">' \
	>>$DESCFORM
echo '	<link rel="stylesheet" type="text/css" href="style.css">' >>$DESCFORM
echo "	<title>${_CHKHOSTS_DESCFORM_TITLE_}</title>"   >>$DESCFORM
echo '</head>' >>$DESCFORM
echo ' ' >>$DESCFORM

echo '<body>' >>$DESCFORM

# insert the php POST function and showstatus functions
cat >>$DESCFORM << "SUBMIT_FUNCTION_SECTION"
<?php
	session_start();
	if (isset($_SESSION['description_session'])) {
		/* Don't do anything - already processed the submit... */
	}
	else {
        	if (isset($_POST['submit'])) {
               		$action_hostname = $_POST['DescriptionHostName'];
                	$action_description = $_POST['DescriptionText'];
                	file_put_contents(
				"system-description/$action_hostname.txt",
				$action_description);
                	$log_entry = strftime("%F %T: ") . 
				"$action_hostname, $action_description\n";
                	file_put_contents("description.log",$log_entry, 
				FILE_APPEND);
			header('Location: status.php');
			exit();
		}
        }
?>
SUBMIT_FUNCTION_SECTION

# insert the description section part 1
cat >>$DESCFORM << "DESCRIPTION_SECTION_1"
<h3>_CHKHOSTS_DESCFORM_TITLE_</h3>
<p>
This form allows you to update the <b>description</b> line of 
the selected host. &nbsp;
</p>
<form action="<?php echo $_SERVER['PHP_SELF']; ?>" method="post">
<table align="center" style="border-spacing: 1px;border-style: solid;
              border-color: #000000;border-width: 3px 3px 3px 3px">
        <tr><td><b>Host:</b> &nbsp;
                <select name="DescriptionHostName">
                        <option selected value="unknown">&lt;select host&gt;
DESCRIPTION_SECTION_1

# make sure the system-description directory, log file exist
mkdir -p $WEBDESCRIPTIONDIR
touch $WEBSTATDIR/description.log

# create the host list for drop down menu
for i in $( grep -v -e '^#' $HOSTLISTFILE ); do

	# create short host name...
        IPADDR="`echo $i | grep -e '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'`"
        if [[ "$IPADDR" == "" ]]; then
                SHORTNAME="`echo $i | awk -F . '{ print $1}'`"
        else
                SHORTNAME="$IPADDR"
	fi

	# add to list in web page
	echo "		<option value=\"$SHORTNAME\">$SHORTNAME" >>$DESCFORM

	# add initial description to description file for host
	echo "description" >$WEBDESCRIPTIONDIR/$SHORTNAME.txt
done

# set permissions to ensure web server can write the files
chmod ugo+w $WEBDESCRIPTIONDIR/* $WEBSTATDIR/description.log

cat >>$DESCFORM << "DESCRIPTION_SECTION_2"
                </select>
                </td></tr>
        <tr><td><b>Description:</b> &nbsp;
                <input type="text" name="DescriptionText" size=40 maxlength=512 /></td></tr>
        <tr><td align="center"><input type="submit" name="submit" value="Update Description"></td></tr>
</table>
</form>

<p>&nbsp;</p>
<div class="footer"> 
      <hr width="55%">
      <p align="center">This page generated by 
	<a href="https://github.com/k6ekb/chkhosts">
	gen-webstat.sh MY_VERSION_STRING</a><br>
	This page last edited on 
	<?php echo  strftime("%a, %d %b %Y at %H:%M %Z.", 
		filemtime("update-description.php")); ?><br>
        You're logged in as '<?php print getenv("REMOTE_USER");?>' 
	from <?php print getenv("REMOTE_ADDR"); ?><br>
</div>
DESCRIPTION_SECTION_2

#
# Close out DESCFORM document 
#############################

echo '</body>' >>$DESCFORM
echo '</html>' >>$DESCFORM

# now customize the Description Form page...
sed -i "s/_CHKHOSTS_DESCFORM_TITLE_/${_CHKHOSTS_DESCFORM_TITLE_}/g" $DESCFORM
sed -i "s/_CHKHOSTS_HOSTNAME_/${_CHKHOSTS_HOSTNAME_}/g" $DESCFORM
sed -i "s/_CHKHOSTS_POLL_INTERVAL_/${_CHKHOSTS_POLL_INTERVAL_}/g" $DESCFORM
sed -i "s/_CHKHOSTS_CONTACTNAME_/${_CHKHOSTS_CONTACTNAME_}/g" $DESCFORM
sed -i "s/_CHKHOSTS_CONTACTEMAIL_/${_CHKHOSTS_CONTACTEMAIL_}/g" $DESCFORM


#
# Generate the HTML header for status page
#############################################

echo "Generating $WEBPAGE..."
echo '<!DOCTYPE html>' >$WEBPAGE
echo '<html>'  >>$WEBPAGE
echo '<head>'  >>$WEBPAGE
echo '	<meta charset="UTF-8">' >>$WEBPAGE
echo '	<meta http-equiv="refresh" content="300">' >>$WEBPAGE
echo '	<meta name="generator" content="gen-webstat.sh MY_VERSION_STRING">' \
	>>$WEBPAGE
echo '	<link rel="stylesheet" type="text/css" href="style.css">' >>$WEBPAGE
echo "	<title>${_CHKHOSTS_TITLE_}</title>"   >>$WEBPAGE
echo '</head>' >>$WEBPAGE
echo ' ' >>$WEBPAGE

#
# Generate the HTML body
########################

echo '<body>' >>$WEBPAGE

# insert the php POST function and showstatus functions
cat >>$WEBPAGE << "PHP_FUNCTIONS_SECTION"
<?php
        date_default_timezone_set('America/Los_Angeles');
        function showstatus($pingname,$hostname)
        {
                if (file_exists("../status-up/$pingname")) {
                        echo '<td style="background-color:green; \
				border-color: #000000; \
				border-width: 1px 1px 1px 1px">';
                        echo "<b><a href=\"https://$pingname\">$hostname
				</a></b><br>";
                        if (file_exists("system-description/$hostname.txt")) {
                                $description=rtrim(file_get_contents(
					"system-description/$hostname.txt"));
                                echo $description;
                                echo "<br>";
                        }
                        if (file_exists("system-comment/$hostname.txt")) {
                                $comment=rtrim(file_get_contents(
					"system-comment/$hostname.txt"));
                                echo $comment;
                                echo "<br>";
                        }
                        echo strftime("%Y-%m-%d at %H:%M %Z",
                                filemtime("../status-up/$pingname"));
                        echo '</td>';
                } else {
                        echo '<td style="background-color:red; \
				border-color: #000000; \
				border-width: 1px 1px 1px 1px">';
                        echo "<b><a href=\"ssh://$pingname\">$hostname
				</a></b><br>";
                        if (file_exists("system-description/$hostname.txt")) {
                                $description=rtrim(file_get_contents(
					"system-description/$hostname.txt"));
                                echo $description;
                                echo "<br>";
                        }
                        if (file_exists("system-comment/$hostname.txt")) {
                                $comment=rtrim(file_get_contents(
					"system-comment/$hostname.txt"));
                                echo $comment;
                                echo "<br>";
                        }
                        if (file_exists("../status-down/$pingname")) {
                                echo strftime("%Y-%m-%d at %H:%M %Z",
                                        filemtime("../status-down/$pingname"));
                        } else {
                                echo "pinging halted";
                        }
                        echo '</td>';
                }
        }
?>

PHP_FUNCTIONS_SECTION

# insert the header and intro section template
cat >>$WEBPAGE  << "HEADER_INTRO_SECTION"

<div class="body">

<h1 class="title">_CHKHOSTS_TITLE_</h1>
<p align=center><b><?php echo "Last refreshed: ";
                        echo strftime('%c'); ?></b></p>

<p>
The date and time in the bottom of each cell in the tables below is the
time the host <b>last</b> responded to a network ping. &nbsp;
The ping script runs on _CHKHOSTS_HOSTNAME_ 
<b>at a _CHKHOSTS_POLL_INTERVAL_ interval</b> 
and sends text/SMS and e-mail notifications when systems first 
go down or come back up. &nbsp;
Contact <a href="mailto:_CHKHOSTS_CONTACTEMAIL_">_CHKHOSTS_CONTACTNAME_</a>
if you'd like to be added to the SMS or e-mail
notification lists.
</p>

HEADER_INTRO_SECTION

# insert the status table
echo "<h3>System Status Table ($NUMSYSTEMS systems)</h3>" >>$WEBPAGE
echo '<p><table>' >>$WEBPAGE

HOSTCOUNTER=0
for i in $( grep -v -e '^#' $HOSTLISTFILE ); do

	# create short host name...
        IPADDR="`echo $i | grep -e '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'`"
        if [[ "$IPADDR" == "" ]]; then
                SHORTNAME="`echo $i | awk -F . '{ print $1}'`"
        else
                SHORTNAME="$IPADDR"
        fi

	# start a new table row 	
	if [[ "$((HOSTCOUNTER % $_CHKHOSTS_TABLE_COLS_))" == "0" ]]; then
		echo '<tr>' >>$WEBPAGE
	fi
	echo "<?php showstatus(\"$i\",\"$SHORTNAME\"); ?>" >>$WEBPAGE

	let "HOSTCOUNTER += 1"
done
echo '</table></p>' >>$WEBPAGE


# insert the Log links section 
cat >>$WEBPAGE << "LOG_SECTION"
<p>
The description (line 2) and comment (line 3) for each host in
the system status table above can be updated via the web. &nbsp;
All changes are logged with the date and time the change was 
made. &nbsp;
Use these links to make updates or to review changes:
<ul>
	<li><a href="update-description.php">
		<b>Update Description (line 2)</b></a> 
		&nbsp;&nbsp;(<a href="description.log">
		Review Description Change Log</a>)</li>
	<li><a href="update-comment.php">
		<b>Update Comment (line 3)</b></a> 
		&nbsp;&nbsp;(<a href="comment.log">
		Review Comment Change Log</a>)</li>
</ul>
</p>
<p>
Use this link to review host status changes (up/down):
<ul>
	<li><a href="../log/chkhosts.log"><b>Host Status Change Log</b></a></li>
</ul>
</p>
<p>
Windows users:  The log file links above render best in Google 
Chrome or Firefox; 
Internet Explorer reportedly garbles or doesn't display the 
log file at all.
</p>
LOG_SECTION


# insert the footer
cat >>$WEBPAGE << "FOOTER_SECTION"
</div>

<div class="footer"> 
      <hr width="55%">
      <p align="center">This page generated by 
	<a href="https://github.com/k6ekb/chkhosts">
	gen-webstat.sh MY_VERSION_STRING</a><br>
	This page last edited on 
	<?php echo  strftime("%a, %d %b %Y at %H:%M %Z.", 
		filemtime("status.php")); ?><br>
        You're logged in as '<?php print getenv("REMOTE_USER");?>' 
	from <?php print getenv("REMOTE_ADDR"); ?><br>
</div>
FOOTER_SECTION

#
# Close out document 
####################

echo '</body>' >>$WEBPAGE
echo '</html>' >>$WEBPAGE


# now customize it...
sed -i "s/_CHKHOSTS_TITLE_/${_CHKHOSTS_TITLE_}/g" $WEBPAGE
sed -i "s/_CHKHOSTS_HOSTNAME_/${_CHKHOSTS_HOSTNAME_}/g" $WEBPAGE
sed -i "s/_CHKHOSTS_POLL_INTERVAL_/${_CHKHOSTS_POLL_INTERVAL_}/g" $WEBPAGE
sed -i "s/_CHKHOSTS_CONTACTNAME_/${_CHKHOSTS_CONTACTNAME_}/g" $WEBPAGE
sed -i "s/_CHKHOSTS_CONTACTEMAIL_/${_CHKHOSTS_CONTACTEMAIL_}/g" $WEBPAGE

# ensure an empty status change log exists (for new installation)
mkdir -p $CHKHOSTLOGDIR
touch $CHKHOSTLOG

# all done!
echo "All done."
exit 0
