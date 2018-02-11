#!/bin/bash

cd $(dirname $0)

APP_NAME=employee
BARAZA_PATH=/opt/baraza
TOMCAT_PATH=/opt/tomcat/webapps

echo 'Copying Xml...'
cp $BARAZA_PATH/projects/$APP_NAME/configs/$APP_NAME.xml $TOMCAT_PATH/$APP_NAME/WEB-INF/configs/
echo 'Copying Reports....'
cp $BARAZA_PATH/projects/$APP_NAME/reports/*.* $TOMCAT_PATH/$APP_NAME/reports

S1="y"
S2="n"

echo "Copy baraza.jar? (y/n)"
read option

if [ "$option" = $S1 ]; then
    echo 'Copying baraza.jar.......'
    cp $BARAZA_PATH/build/baraza.jar  $TOMCAT_PATH/$APP_NAME/WEB-INF/lib/

elif [ "$option" = $S2 ]; then
    echo "baraza.jar ignored"
fi

echo 'Finished'
