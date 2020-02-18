#!/bin/bash
#Author: Anubhav Goel
#Script for collecting all tibco bw instance names, their running status, restart BW and Hawk services for given set of servers.
#1. Collect ALL TRAs(RUNNING+STOPPED) of specified DOMAIN.
#2. Collect RUNNING TRAs ONLY.
#3. Collect ALL TRAs (RUNNING+STOPPED) + their instance STATUS + share through mail.
#4. Start BW Instances ${BGreen}from backUp Tralist(from OPTION 2).
#5. Restart BW Instances ${BGreen} of specified DOMAIN in a single shot.
#6. Restart Hawk Agent ${BGreen}of specified domain

#ColourCode
ColorCode(){
RED='\033[0;31m'
BBlue='\033[1;34m'
BGreen='\033[1;32m'
Bold='\e[1m'
NC='\033[0m'
SingleLine=${Bold}${BBlue}"------------------------------------------------------------------------------------------------------------------------------"${NC}
}

# Assigning config and log files as per your environment and requirement.
VariableDeclarations(){
Date=`date "+%Y-%m-%d %H:%M:%S"`
InputDomain=$( echo "$configFile" | cut -d\. -f1 | cut -d\- -f2 )
LogFile=/home/tibadm1/Anubhav/Scripts/HealthCheck/logs/BWInfraServices_`date +%Y%m%d_%H%M%S`.log
TraList=/home/tibadm1/Anubhav/Scripts/HealthCheck/files/TraList.txt
HostTra=/home/tibadm1/Anubhav/Scripts/HealthCheck/files/TraList_${InputDomain}_`date +%Y%m%d_%H%M%S`.csv
HostAllTra=/home/tibadm1/Anubhav/Scripts/HealthCheck/files/HostAllTra_`date +%Y%m%d_%H%M%S`.csv
StatusCsvFile=/home/tibadm1/Anubhav/Scripts/HealthCheck/files/AppStatus_`date +%Y%m%d_%H%M%S`.csv
HTMLContent=/home/tibadm1/Anubhav/Scripts/HealthCheck/files/HTMLContent.html
ConfigPath=/home/tibadm1/Anubhav/Scripts/DomainList
}

#header
Header(){
clear
echo -e "${Bold}${BGreen}==============================================================================================================================${NC}"
echo ""
echo -e "${Bold}${RED}  \tWelcome to Tibco BW Infra Platform on `hostname`\n${NC}"
echo -e "${Bold}${BGreen}==============================================================================================================================${NC} \n"
}

#Option1 and 3
CollectAllTRAs(){
echo -e ${BGreen}"\nCollecting info about BW Instances..."${NC}
# If Host is reachable then proceed else exit
for Host in `cat $configFile`;do
MachineUser=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "whoami")
if [[ -z $MachineUser ]]; then
echo " $Host: Server not reachable "   | tee -a  $LogFile
else

# Collect All TRA files (START and STOP both)
echo -e ${BGreen}"Collecting TRA names from " $Host ${NC}
CMD="find /opt/tibco/tra/domain/${InputDomain}/application/*/ -name *.tra"
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host $CMD >> $TraList

# Adding hostname to TRAs
for i in `cat $TraList`;
do
echo -e $Host'|'$i >> $HostAllTra
done
rm $TraList
fi
done
echo -e ${BGreen}"All TRA Names are collected"${NC} '\n'$SingleLine
sort -u $HostAllTra > $HostTra
cat $HostTra >> $LogFile
rm $HostAllTra
}

#Option 2 and 5
CollectRunningTRAs(){
for Host in `cat $configFile`;do
	
# Check if host is accesible
HostUser=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "whoami")
if [[ -z $HostUser ]]; then
echo -e $Date " " $Host " not reachable!"
else
echo -e $Date " Collecting Running Instances details from " $Host | tee -a  $LogFile
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef"| grep '.tra' | grep 'bwengine'| awk -F " " '{ print $(NF-1)}' >> $TraList
for i in `cat $TraList`;
do
echo -e $Host','$i >> $HostAllTra
done
rm $TraList
fi
done
echo -e ${BGreen}"Running Instances details collected!"${NC} '\n'$SingleLine
# Only unique entries, if in case of duplicate PIDs
sort -u $HostAllTra > $HostTra
cat $HostTra >> $LogFile
rm $HostAllTra
}

#Option 3
CollectInstanceStatus(){
#Checking the status for each Instance
echo -e ${BGreen}"Starting BW Instance check ......\n"${NC}
for line in `cat $HostTra`;do
Host=`echo $line |awk -F "|" '{ print $1 }'`
Tra=`echo $line |awk -F "|" '{ print $2 }'`
    App_Name=`echo $Tra |awk -F "/" '{print $(NF-1)}' |awk -F "-" '{ print $1 }'`
Domain=`echo $Tra |awk -F "/" '{ print $6 }'`
App_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef"|grep "$Tra" | grep -v grep | awk '{print $2}')

if [[ -z $App_PID ]]; then
 echo -e ${RED}"$Date\t$App_Name\t$Domain\t$Host\tStopped" ${NC}
 echo -e "$App_Name,$Domain,$Host,Stopped" >> $StatusCsvFile 
 else
 echo -e ${BGreen}"$Date\t$App_Name\t$Domain\t$Host\tRunning" ${NC}
 echo -e "$App_Name,$Domain,$Host,Running" >> $StatusCsvFile
fi
done
cat $StatusCsvFile > $LogFile
}

#Option 4
StartBWInstancesFromBackUp(){
for line in `cat $HostTraFromOption2`;do
Host=`echo $line|awk -F "," '{ print $1}'`
Tra=`echo $line|awk -F "," '{ print $2}'`
Instance=`echo $Tra|awk -F "/" '{ print $(NF)}'|awk -F "." '{ print $1}'`
Sh_Name=${Tra/'.tra'/'.sh'}

# Starting BW process.
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "$Sh_Name  >> nohup.out 2>&1 &"
New_BW_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef"|grep $Tra | grep -v grep | awk '{print $2}')
echo -e ${BGreen} $Date $Host $Instance "New_PID: " $New_BW_PID ${NC}
echo -e $Date $Host $Instance "New_PID: " $New_BW_PID >>  $LogFile

# Stopping Ghost SH process.
Sh_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef" | grep $Sh_Name | grep -v grep | awk '{print $2}')
if [ $Sh_PID -ne 0 ]
then
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "kill -9 $Sh_PID > /dev/null 2>&1"
fi
done
echo -e $SingleLine
}

#Option 5
Refresh_RunningInstances(){
echo -e ${BGreen}"Initiating Instance refresh with 10 seconds time interval...\n"${NC}
for line in `cat $HostTra`;do
Host=`echo $line|awk -F "," '{ print $1}'`
Tra=`echo $line|awk -F "," '{ print $2}'`
Instance=`echo $Tra|awk -F "/" '{ print $(NF)}'|awk -F "." '{ print $1}'`

#1. Extracting Old BW process PID`s from remote servers.
Old_BW_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef"|grep $Tra | grep -v grep | awk '{print $2}')

#2. Killing Old BW process PID`s from remote servers.
if [ -z $Old_BW_PID ]
then
echo -e ${RED}$Date $Host $Instance " BW NOT Running "  ${NC}
echo -e $Date $Host $Instance " BW NOT Running "   >> $LogFile
else
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "kill -9 $Old_BW_PID > /dev/null 2>&1"
sleep 10

#3. Starting BW instance.
Sh_Name=${Tra/'.tra'/'.sh'}
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "$Sh_Name  >> nohup.out 2>&1 &"
New_BW_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef"|grep $Tra | grep -v grep | awk '{print $2}')

echo -e ${BGreen}$Date $Host $Instance "New_PID: " $New_BW_PID ${NC}
echo -e $Date $Host $Instance "New_PID: " $New_BW_PID >>  $LogFile

#4. Stopping Ghost SH process.
Sh_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "ps -ef" | grep $Sh_Name | grep -v grep | awk '{print $2}')
if [ $Sh_PID -ne 0 ]
then
ssh -o BatchMode=yes -qo ConnectTimeout=5 $Host "kill -9 $Sh_PID > /dev/null 2>&1"
fi
fi
done
echo -e $SingleLine
}

#Option 6
HawkRefresh(){
#1.Executing for loop to restart hawk instances one by one using $configFile file as an input
for host in `cat $configFile`;do
    RSName=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "uname -a" | grep -v grep | awk '{ print $2 }')

#2.Extracting HAWK & HMA process PID`s from remote servers
    RSDomain=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "cd /opt/tibco/tra/domain; ls -l |grep "HUB"" | awk '{print $9}')

    if [[ -z $RSDomain ]]; then
    echo -e $Date $host " not reachable!"     | tee -a  $ErrorLogFile
    fi
    RSDomain_V=`echo $RSDomain |awk '{print $1,$2}'`
    ARR_RSDomain=($RSDomain_V)
    for Domain in "${ARR_RSDomain[@]}";do
        RSPATH=/opt/tibco/tra/domain/$Domain
        HAWK_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "ps -ef"|grep -w [^]]hawkagent_$Domain | grep -v grep |awk '{print $2}')
        HMA_PID=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "ps -ef"|grep [^]]tibhawkhma | grep -v grep | awk '{print $2}')

#3.Starting HAWK instance if it is in stopped state after killing HMA process ID
        if [[ -z $HAWK_PID ]]; then
        ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "kill -9 $HAWK_PID $HMA_PID" > /dev/null 2>&1
        ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "cd $RSPATH ; nohup ./hawkagent_$Domain >> nohup.out 2>&1 &"
        NewHAWK_PID1=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "ps -ef"|grep -w [^]]hawkagent_$Domain | grep -v grep | awk '{print $2}')
        echo -e ${RED}$Date $RSName ": Hawk was NOT running, STARTED! New_PID : " $NewHAWK_PID1 ${NC}
 echo -e $Date $RSName ": Hawk was NOT running, STARTED! New_PID : " $NewHAWK_PID1 >> $LogFile
        else

#4.Restarting HAWK instance if it is already in running state after killing Hawk & HMA process ID`s
        ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "kill -9 $HAWK_PID $HMA_PID" > /dev/null 2>&1
        ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "cd $RSPATH ; nohup ./hawkagent_$Domain >> nohup.out 2>&1 &"
        NewHAWK_PID2=$(ssh -o BatchMode=yes -qo ConnectTimeout=5 $host "ps -ef"|grep -w [^]]hawkagent_$Domain | grep -v grep | awk '{print $2}')
        echo -e $Date $RSName ": Hawk was running and RE-STARTED! New_PID : " $NewHAWK_PID2 "Old_PID : " $HAWK_PID >>  $LogFile
        echo -e ${BGreen}$Date $RSName ": Hawk was running and RE-STARTED! New_PID : " $NewHAWK_PID2 "Old_PID : " $HAWK_PID ${NC}
 fi
    done
done < $configFile
}

DisplayStatistics(){
if [ $action == 1 ] 
then
echo -e "Total  Instances in " $InputDomain "     : " `cat $HostTra|wc -l` | tee -a  $LogFile
echo -e "File Name containing ALL TRAs        : " $HostTra | tee -a  $LogFile
echo -e 'For More details see logs            : ' $LogFile '\n'${SingleLine} 

elif [ $action == 2 ]
then 
echo -e "Running  Instances in " $InputDomain "   : " `cat $HostTra|wc -l` | tee -a  $LogFile
echo -e "File Name containing Running TRAs    : " $HostTra | tee -a  $LogFile
echo -e 'For More details see logs            : ' $LogFile '\n'${SingleLine} 

elif [ $action == 3 ]
then 
echo -e "Running  Instances in " $InputDomain "   : " `grep Running $StatusCsvFile|wc -l` | tee -a  $LogFile
echo -e "Mail Sent to                         : " $TO | tee -a $LogFile
echo -e "File Name containing TRAs            : " $HostTra | tee -a  $LogFile
echo -e 'For More details see logs            : ' $LogFile '\n'${SingleLine} 

elif [ $action == 4 ]
then 
echo -e "File Name containing TRAs            : " $HostTraFromOption2 | tee -a  $LogFile
echo -e 'For More details see logs            : ' $LogFile '\n'${SingleLine} 

elif [ $action == 5 ]
then 
echo -e "File Name containing Refreshed TRAs  : " $HostTra | tee -a  $LogFile
echo -e 'For More details see logs            : ' $LogFile '\n'${SingleLine} 

elif [ $action == 6 ]
then 
echo -e ${SingleLine} ${BGreen}'\nHawk Refresh completed succesfully !!\nFor More details see logs   : '$LogFile $ErrorLogFile ${NC} '\n'${SingleLine} 
fi
}

#Option 3 
Mail(){
#MakingMailContent
SUBJECT="Health Check Status Report for BW Instances in $InputDomain Env on $Date "
awk 'BEGIN{
FS=","
msg1="<font face="Calibri" color="blue">Hi Team<br/>Please find below the BW Instances Health Check Status Report :<br/><br/><font/>"
msg2="<br/><br/><b>Thanks & Regards,</b><br/> Tibco Team<br/><br/>"
printf "%s", msg1
print  "<HTML>""<TABLE border="2"><TH>APPLICATION</TH><TH>DOMAIN</TH><TH>MACHINE</TH><TH>STATUS</TH>" 
}
{
printf "<TR>"
for(i=1;i<=NF;i++)
printf "<TD>%s</TD>", $i
print "</TR>"
 }
END{
print "</TABLE></BODY></HTML>"
printf "%s", msg2
 }
' $StatusCsvFile > $HTMLContent
sed -i "s/Running/<font color="green">Running<\/font>/g;s/Stopped/<font color="red">Stopped<\/font>/g;s/APPLICATION/<font color="purple">APPLICATION<\/font>/g;s/DOMAIN/<font color="purple">DOMAIN<\/font>/g;s/MACHINE/<font color="purple">MACHINE<\/font>/g;s/STATUS/<font color="purple">STATUS<\/font>/g" $HTMLContent

#MailCmd
echo -e $SingleLine
for User in "${TO[@]}";do
mailx -s "$(echo -e "$SUBJECT \nContent-Type: text/html")" $User -- -r AnubhavGoel@org.com <  $HTMLContent
done
rm -r $HTMLContent
}

Scripted_inputs_options(){
clear
Header
echo -e "${BBlue}Please select the option from below:\n\n ${BGreen}\t1. Collect ALL TRAs(RUNNING+STOPPED) of specified DOMAIN.\n\t2. Collect RUNNING TRAs ONLY.\n\t3. Collect ALL TRAs (RUNNING+STOPPED) + their instance STATUS + share through mail.\n\t4. ${RED}Start BW Instances ${BGreen}from backUp Tralist(from OPTION 2).\n\t5. ${RED}Restart BW Instances ${BGreen} of specified DOMAIN in a single shot.\n\t6. ${RED}Restart Hawk Agent ${BGreen}of specified domain.\n${RED}NOTE     : Please keep the server list handy.${NC}"
echo -e $SingleLine ${BGreen}"\nPlease enter your choice: "${NC}
read action

if [[ ($action > 0) && ($action < 7) ]]
then 
UserInput
else 
Scripted_inputs_options
fi
}
MailIdInput() {
echo -e $SingleLine ${BGreen}"\nPlease enter org Mail Id (OR multiple Ids seprated by semi colon) :"${NC}
read TO 
if [[ $TO != *"@org.com"* ]]; then
# validating mail with domain  @org.com only
echo -e ${RED}'Invalid E-mail Id. Please enter valid org Mail Id only!!' ${NC}
MailIdInput
fi
}
TralistInput()    {
echo -e $SingleLine ${BGreen}"\nPlease enter Tralist for Instance Refresh :"${NC}
read HostTraFromOption2 
if [[ (! -f $HostTraFromOption2) || (! -n  $HostTraFromOption2) ]]; then
echo -e ${RED}'Invalid Path or File Name. Please enter correct details !!' ${NC}
TralistInput
fi
}
configFileInput()  {
ConfigPath=/home/tibadm1/Anubhav/Scripts/DomainList
echo -e $SingleLine ${BGreen}"\nPlease enter serverlist from " $ConfigPath " :"${NC}
ls $ConfigPath
echo -e $SingleLine
read ServerList 
configFile="$ConfigPath"/"$ServerList"
echo -e $configFile
if [[ (! -f "$configFile") || (! -n  "$configFile") ]]; then
echo -e ${RED}' Invalid Path or File Name. Please enter correct details !!' ${NC}
configFileInput
fi 
}
UserInput(){
if [ $action -eq 1 ] 
then 
configFileInput

elif [ $action -eq 2 ] 
then 
configFileInput

elif [ $action -eq 3 ] 
then 
MailIdInput
configFileInput

elif [ $action -eq 4 ]
then 
TralistInput

elif [ $action -eq 5 ] 
then 
configFileInput

elif [ $action -eq 6 ] 
then 
echo -e ${BGreen}"Please enter Hostname for 1 specific machine else press enter for serverlist :"${NC}
read HostForHawk
if [ -z $HostForHawk ]
then
configFileInput
else
configFile=TempConfig_`date +%Y%m%d_%H%M%S`.cfg
echo "$HostForHawk" > $configFile
fi
fi
}

clearVariables(){
unset StatusCsvFile TraList HostAllTra
if [ -f $HostTra ]
then 
unset HostTra
fi
}

Scripted_Actions_Main(){
if [ $action == 1 ]
then
    echo -e "${BGreen}Proceeding for COLLECTING ALL TRAs of all Instances${NC}"
VariableDeclarations
echo -e $configFile
    CollectAllTRAs
DisplayStatistics
 
elif [ $action == 2 ]
then
    echo -e "${BGreen}Proceeding for COLLECTING RUNNING TRAs of all Instances${NC}"
VariableDeclarations
    CollectRunningTRAs
DisplayStatistics

elif [ $action == 3 ]
then
    echo -e "${BGreen}Proceeding for SAVING the backUp of all Instances${NC}"
VariableDeclarations
    CollectAllTRAs
CollectInstanceStatus
Mail
DisplayStatistics

elif [ $action == 4 ]
then
    echo -e "${BGreen}Proceeding for STARTING the BW Instances from BackUp TraList...${NC}"
VariableDeclarations
StartBWInstancesFromBackUp
DisplayStatistics
        
elif [ $action == 5 ]
then
    echo -e "${BGreen}Proceeding for STOPPING and STARTING the BW Instances from BackUp list${NC}"
VariableDeclarations
CollectRunningTRAs
Refresh_RunningInstances
DisplayStatistics

elif [ $action == 6 ]
then
    echo -e "${BGreen}Proceeding for STOPPING and STARTING the Hawk Agents for $InputDomain${NC}"
VariableDeclarations
HawkRefresh
DisplayStatistics

else
echo -e "${RED}Invalid Choice. Please enter valid mailId and select Menu in numbers!!${NC}"
fi

echo -e "\n${BGreen}Do you wish to continue(yes/no) ?${NC}"
read ans
clear
}

Show_Main() {
ColorCode
ans=yes
while [[ ($ans == "yes") || ($ans == "Y") || ($ans == "y")  ]]
do
Scripted_inputs_options
Header
Scripted_Actions_Main
clearVariables
done
}
##### calling the main function#################
Show_Main

