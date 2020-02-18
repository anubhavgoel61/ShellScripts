#!/bin/bash
# Author: Anubhav Goel
#To deploy the BW 6.4 (can be any 6.x) services with the help of a configuration file named config.prop in below format. 
#DOMAIN|APPSPACE|APPLICATION1_1.2.3.ear
#DOMAIN1|APPSPACE1|APPLICATION1_1.2.3.ear
#DOMAIN1|APPSPACE1|APPLICATION2_1.2.3.ear

####UserDefinedVariables#
project='TESTING'
BW6_HOME=/opt/tibco6/bw/6.4
earLocation=/home/tibcoadmin/
configFile=config.prop

#########DontChangeAnythingFromHere####
BBlue='\033[1;34m'
BGreen='\033[1;32m'
Bold='\e[1m'
NC='\033[0m'
Header="${Bold}${BGreen}============================================================================\n\n\tWelcome to ${project} BW6 Deployment Services on `hostname`\n\n============================================================================${NC}\n\n"
SingleLine=${BBlue}'------------------------------------------'${NC}


Show_Domain()
{
clear
echo -e $Header'\n\n\n'${BBlue}'Select DOMAIN from below : \n'$SingleLine ${NC}
cat $configFile | cut -d '|' -f1 | sort -u 
echo -e $SingleLine ${BGreen}'\nPlease enter your choice:'${NC}
read domain_name
Show_Appspace
}

Show_Appspace()
{
clear
echo -e $Header'\n\n\n'${BBlue}'Select APPSPACE from below : \n'$SingleLine ${NC}
grep $domain_name $configFile | cut -d '|' -f2 | sort -u  
echo -e $SingleLine ${BGreen}'\nPlease enter your choice:'${NC}
read appspace_name
Show_ApplicationList
}

Show_ApplicationList()
{
clear
echo -e $Header'\n\n\n'${BBlue}'Select Application from below : \n'$SingleLine ${NC}
grep $appspace_name $configFile | cut -d '|' -f3 | sort -u 
echo -e "\n"
echo -e $SingleLine ${BGreen}"\nPlease enter your choice:"${NC}
read app_name


ear_name=$app_name 
app_name=`echo $app_name | cut -d '_' -f1`
app_version=`echo $ear_name | cut -d '_' -f2 | cut -c1-5`
app_maj_min_version=`echo $ear_name | cut -d '_' -f2 | cut -c1-3`


clear
echo -e $Header
echo -e ${Bold}${BBlue}'+++++++ INPUTs GIVEN ++++++++++++++++++++++++++++++++++++++++++++++++\n'${NC}
echo -e 'DOMAIN\t\t\t\t: '$domain_name
echo -e 'APPSPACE\t\t\t: '$appspace_name
echo -e 'EARNAME\t\t\t\t: '$ear_name
echo -e 'APPLICATION\t\t\t: '$app_name
echo -e 'VERSION\t\t\t\t: '$app_version
echo -e 'Major_Minor_version\t\t: '$app_maj_min_version
echo -e ${Bold}${BBlue}'+++++++ INPUTs END ++++++++++++++++++++++++++++++++++++++++++++++++++\n\n\n'${NC}
echo -e ${BGreen}'Do you want to REVISE Inputs(yes/no)'${NC}
read ans
}

Scripted_inputs_options()
{
clear

echo -e $Header 
echo -e "${BBlue}Please select the option from below:\n${NC}"$SingleLine 
echo -e "${BBlue}\n\t1. Deploy and Start Application\n\t2. Deploy and Stop Application\n\t3. Start an Existing Application\n\t4. Stopping an Existing Application\n\t5. Undeploy Application\n\t6. Export Application PROFILE.\n\t7. View ALL Application Details.${NC}"
echo -e $SingleLine ${BGreen}"\nPlease enter your choice:"${NC}
read action
}
Scripted_Deploy_Main()
{ 
cd $BW6_HOME/bin

if [ $action = 1 ]
then
    echo -e "${BGreen}Deploying $applicationName Service on $domain${NC}"
Deploy_Start
fi
if [ $action = 2 ]
then
    echo -e "${BGreen}Deploying $applicationName Service on $domain${NC}"
Deploy_Stop
fi
if [ $action = 3 ]
then
    echo -e "${BGreen}Starting $applicationName Service on $domain${NC}"
Start_Application
fi
if [ $action = 4 ]
then
echo -e "${BGreen}Stopping $applicationName Service on $domain${NC}"
Stop_Application
fi
if [ $action = 5 ]
then
echo -e "${BGreen}Undeploying $applicationName Service on $domain${NC}"
Undeploy_Application
fi
if [ $action = 6 ]
then
Export_Application
fi
if [ $action = 7 ]
then
View_Application
fi
echo -e "${BGreen}........Do you want to continue(yes/no) .................${NC}"
read reply
}

Deploy_Start()
{

cd $BW6_HOME/bin

FOUND=`./bwadmin exists -d ${domain_name} -a ${appspace_name} application ${app_name}`

EXIT_STATUS=$?
echo "EXIT_STATUS": $EXIT_STATUS
#if application already present in domain then it will return 0 or not found 
#then return 1 else 100(incase of execution failed)
if [ $EXIT_STATUS = "0" ]; then
#applicatoin already exists

./bwadmin stop -d $domain_name -a $appspace_name application $app_name $app_version; ./bwadmin undeploy -d $domain_name -a $appspace_name application $app_name $app_version; ./bwadmin upload -d $domain_name -replace $earLocation/$ear_name; ./bwadmin deploy -d $domain_name -a $appspace_name  -p $environment_name -startondeploy  $ear_name;

else
#applicatoin not  exists
./bwadmin upload -d $domain_name $earLocation/$ear_name; ./bwadmin deploy -d $domain_name  -a $appspace_name  -p $environment_name -startondeploy $ear_name;
fi
}

Deploy_Stop()
{
cd $BW6_HOME/bin;
./bwadmin stop -d $domain_name -a $appspace_name application $app_name $app_version; ./bwadmin undeploy -d $domain_name -a $appspace_name application $app_name $app_version; 
}

Start_Application()
{
echo -e $Header'\n\n\n'${BBlue}'Enter APPNODE Name from below : \n'$SingleLine ${NC}
grep $appspace_name $ConfigFile|grep $domain_name|grep $appspace_name|grep $appNode| cut -d ',' -f6|sort -u
echo -e $SingleLine ${BBlue}'\nInput :'${NC}
read appNode
cd $BW6_HOME/bin; $startCommand;./bwadmin start -d $domain_name -a $appspace_name -n $appNode application $app_name $app_version;
}
Stop_Application()
{
cd $BW6_HOME/bin;
./bwadmin stop -d $domain_name -a $appspace_name application $app_name $app_maj_min_version;
}

Undeploy_Application()
{
cd $BW6_HOME/bin;
./bwadmin undeploy -d $domain_name -a $appspace_name application $app_name $app_maj_min_version;
}

Edit_Application()
{
cd $BW6_HOME/bin; 
./bwadmin config -d $domain_name -a $appspace_name -n $appNode -p $environment_name application $ear_name;
}

Export_Application()
{
cd $BW6_HOME/bin;
./bwadmin export -d $domain_name -a $appspace_name application $app_name $app_maj_min_version;
echo 'PROFILE backed up on path : '$BW6_HOME'/bin' 
}

View_Application()
{
cd $BW6_HOME/bin; 
./bwadmin show -domain $domain_name -appspace $appspace_name applications;
#connect remote server 
}

Show_Main(){
ans=yes
while [ $ans == "yes" ]
do
Show_Domain
done

Scripted_inputs_options
Scripted_Deploy_Main

}
##### call the main function#################
Show_Main





