#!/usr/bin/env bash

if [ ! -f .jenkins.env ]; then
    echo "Please create a .jenkins.env file to run the script, you could take the .jenkins.env.example as an reference :))"
    exit 1
else
    source .jenkins.env
    sudo apt-get update
    sudo apt-get -y install zip unzip wget
fi

if ! command -v frep &> /dev/null; then
    sudo curl -fSL https://github.com/subchen/frep/releases/download/v1.3.12/frep-1.3.12-linux-amd64 -o /usr/local/bin/frep
    sudo chmod +x /usr/local/bin/frep
fi
frep --overwrite tomcat@jenkins.service.tmpl
frep --overwrite jenkins_nginx.conf.tmpl

if ! command -v java &> /dev/null; then
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install java 11.0.12-open
fi

# 1. Remove the systemd file if it exists already
if [ -f $JENKINS_SERV_PATH_AND_NAME ]; then
    sudo systemctl disable $JENKINS_SERV_NAME
    sudo rm $JENKINS_SERV_PATH_AND_NAME
fi

# 2. Install tomcat to the predefined path (/opt/apache-tomcat-$TOMCAT_VERSION)
if [ ! -d $TOMCAT_PATH$TOMCAT_FOLDER ]; then
    wget $TOMCAT_SRC
    sudo mkdir $TOMCAT_PATH
    sudo unzip apache-tomcat-9.0.54.zip -d $TOMCAT_PATH
    sudo rm -rf $TOMCAT_PATH$TOMCAT_FOLDER/webapps/*
    rm *.zip
fi

# 3. Download the Jenkins war file and install it to tomcat
if [ ! -f $TOMCAT_PATH$TOMCAT_FOLDER/webapps/ROOT.war ]; then
    wget $JENKINS_SRC
    sudo mv jenkins.war $TOMCAT_PATH$TOMCAT_FOLDER/webapps/ROOT.war
fi

# 4. Create the tomcat user for the systemd job
if id "tomcat" &>/dev/null; then
    echo "User tomcat already exists"
else
    sudo groupadd tomcat
    sudo useradd -M -s /sbin/nologin -g tomcat -d $TOMCAT_PATH tomcat
    sudo chgrp -R tomcat $TOMCAT_PATH$TOMCAT_FOLDER
    sudo chmod +x $TOMCAT_PATH$TOMCAT_FOLDER/bin/catalina.sh $TOMCAT_PATH$TOMCAT_FOLDER/bin/startup.sh $TOMCAT_PATH$TOMCAT_FOLDER/bin/shutdown.sh
    sudo chmod -R g+r $TOMCAT_PATH$TOMCAT_FOLDER/conf
    sudo chmod g+x $TOMCAT_PATH$TOMCAT_FOLDER/conf
    sudo chown -R tomcat $TOMCAT_PATH$TOMCAT_FOLDER/webapps/ $TOMCAT_PATH$TOMCAT_FOLDER/work/ $TOMCAT_PATH$TOMCAT_FOLDER/temp/ $TOMCAT_PATH$TOMCAT_FOLDER/logs/
fi

# 5. Create the systemd files
sudo cp $JENKINS_SERV_NAME $JENKINS_SERV_PATH_AND_NAME
sudo systemctl enable $JENKINS_SERV_NAME
sudo systemctl start $JENKINS_SERV_NAME
