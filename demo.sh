# NOTE : This script is just a guidelined usage there may be errors that can happen based on your environment.

#!/bin/bash
set -e


#---------------------------------Setup base url values-------------------------
region[1]="https://us-south.apprapp.cloud.ibm.com/apprapp/feature/v1/instances"
region[2]="https://eu-gb.apprapp.cloud.ibm.com/apprapp/feature/v1/instances"
region[3]="https://au-syd.apprapp.cloud.ibm.com/apprapp/feature/v1/instances"
urlSeparator="/"
environmentName=""
environmentId=""
environments="environments"
collections="collections"
features="features"
properties="properties"
segments="segments"

generateEnvId(){
	environmentId="$(tr [A-Z] [a-z] <<< "$1")"
}
#---------------------------------Get inputs for the script to run------------------------
printf "\nEnter the region where your App configuration service is created\n1. us-south (Dallas)\n2. eu-gb (London)\n3. au-syd (Sydney)\n\n"

read -p "Enter region number> "  regionIn
printf "\nChoose action\n"
printf "1. Setup - Create pre-defined features flags & properties, which are organized into collections and targeted to segments in your instance\n"
printf "2. Cleanup - Delete all the existing entires of collection, feature flags, properties and segments from your instance\n\n"
read -p "Enter action number> "  actionIn
if [[ $actionIn == 1 ]]
then
	printf "\nPerform setup using default environment?\n1. Yes\n2. No. Create a new environment\n\n"
	read -p "Enter action number(1 or 2)> " envActionIn
	if [[ $envActionIn == 1 ]]
	then
		environmentName="Dev"
		environmentId="dev"
	elif [[ $envActionIn == 2 ]]
	then
		printf "\n"
		read -r -p "Enter an environment name> " environmentName
		generateEnvId $environmentName
	else
		printf "\nProvide a valid input number"
		exit 1
	fi
fi
printf "\n"
read -p "Enter apikey: (Obtained from Service credentials tab of your instance): "  apikey
printf "\n"
read -p "Enter guid: (Obtained from Service credentials tab of your instance): "  guid

#---------------------------------Setup input params-------------------------
baseURL=${region[${regionIn}]}
baseURL="$baseURL$urlSeparator$guid"

#---------------------------------Setup input params-------------------------
environmentURL="$baseURL$urlSeparator$environments"
segmentURL="$baseURL$urlSeparator$segments"
collectionURL="$baseURL$urlSeparator$collections"
featureURL="$baseURL$urlSeparator$environments$urlSeparator$environmentId$urlSeparator$features"
propertyURL="$baseURL$urlSeparator$environments$urlSeparator$environmentId$urlSeparator$properties"
segmentIdArray=()


cleanup()
{
	#---------------------------------segments Cleanup-------------------------
	printf "%b\n**************************Cleanup is called**************************\n"
	cleanupSegmentURL="$segmentURL"
	curl -sb -H "Accept: application/json" -H "Authorization: $apikey" $cleanupSegmentURL > auto.json
	if [ -s auto.json ] && grep -q "segments" auto.json
	then
		segmentIds=($((<auto.json jq -r '.segments' | jq . | jq -r '.[].segment_id | @sh') | tr -d \'\"))

		for i in "${segmentIds[@]}"
		do
			printf "%b\n deleting segment with id $i\n"
			segmentDelURL=$segmentURL$urlSeparator$i
			segmentDelResponse=$(curl -s --write-out 'HTTPSTATUS:%{http_code}' -H "Accept: application/json" -H "Authorization: $apikey" -X DELETE  $segmentDelURL)
			HTTP_STATUS=$(echo $segmentDelResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
			if [ $HTTP_STATUS != 204 ]
			then
				printf "%b\n \e[31m Failure : Segment delete failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
			fi
		done
	else
		exit 1
	fi

	#---------------------------------collections Cleanup-------------------------
	cleanupCollectionURL="$collectionURL"
	curl -sb -H "Accept: application/json" -H "Authorization: $apikey" $cleanupCollectionURL > auto.json
	if [ -s auto.json ] && grep -q "collection" auto.json
	then
		collectionIds=($((<auto.json jq -r '.collections' | jq . | jq -r '.[].collection_id | @sh') | tr -d \'\"))

		for i in "${collectionIds[@]}"
		do
			printf "%b\n deleting collection with id $i\n"
			collectionDelURL=$collectionURL$urlSeparator$i
			collectionDelResponse=$(curl -s --write-out 'HTTPSTATUS:%{http_code}' -H "Accept: application/json" -H "Authorization: $apikey" -X DELETE  $collectionDelURL)
			HTTP_STATUS=$(echo $collectionDelResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
			if [ $HTTP_STATUS != 204 ]
			then
				printf "%b\n \e[31m Failure : Collection delete failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
			fi
		done
	else 
		exit 1
	fi

	#---------------------------------environments Cleanup-------------------------
	cleanupEnvironmentURL="$environmentURL"
	curl -sb -H "Accept: application/json" -H "Authorization: $apikey" $cleanupEnvironmentURL > auto.json
	if [ -s auto.json ] && grep -q "environment" auto.json
	then
		environmentIds=($((<auto.json jq -r '.environments' | jq . | jq -r '.[].environment_id | @sh') | tr -d \'\"))

		for ((i=0; i<${#environmentIds[@]}-1; i++))
		do
			printf "%b\n deleting environment with id ${environmentIds[i]}\n"
			environmentDelURL=$environmentURL$urlSeparator${environmentIds[i]}
			environmentDelResponse=$(curl -s --write-out 'HTTPSTATUS:%{http_code}' -H "Accept: application/json" -H "Authorization: $apikey" -X DELETE  $environmentDelURL)
			HTTP_STATUS=$(echo $environmentDelResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
			if [ $HTTP_STATUS != 204 ]
			then
				printf "%b\n \e[31m Failure : Environment delete failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
			fi
		done
		environmentId=${environmentIds[i]}
	else
		exit 1
	fi

	#---------------------------------feature Cleanup-------------------------
	cleanupFeatureURL="$baseURL$urlSeparator$environments$urlSeparator$environmentId$urlSeparator$features"
	curl -sb -H "Accept: application/json" -H "Authorization: $apikey" $cleanupFeatureURL > auto.json
	if [ -s auto.json ] && grep -q "features" auto.json
	then
		featureIds=($((<auto.json jq -r '.features' | jq . | jq -r '.[].feature_id | @sh') | tr -d \'\"))

		for i in "${featureIds[@]}"
		do
			printf "%b\n deleting feature with id $i\n"
			featureDelURL=$cleanupFeatureURL$urlSeparator$i
			featureDelResponse=$(curl -s --write-out 'HTTPSTATUS:%{http_code}' -H "Accept: application/json" -H "Authorization: $apikey" -X DELETE  $featureDelURL)
			HTTP_STATUS=$(echo $featureDelResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
			if [ $HTTP_STATUS != 204 ]
			then
				printf "%b\n \e[31m Failure : Feature delete failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
			fi
		done
	else 
		exit 1
	fi

	#---------------------------------property Cleanup-------------------------
	cleanupPropertyURL="$baseURL$urlSeparator$environments$urlSeparator$environmentId$urlSeparator$properties"
	curl -sb -H "Accept: application/json" -H "Authorization: $apikey" $cleanupPropertyURL > auto.json
	if [ -s auto.json ] && grep -q "properties" auto.json
	then
		propertyIds=($((<auto.json jq -r '.properties' | jq . | jq -r '.[].property_id | @sh') | tr -d \'\"))

		for i in "${propertyIds[@]}"
		do
			printf "%b\n deleting property with id $i\n"
			propertyDelURL=$cleanupPropertyURL$urlSeparator$i
			propertyDelResponse=$(curl -s --write-out 'HTTPSTATUS:%{http_code}' -H "Accept: application/json" -H "Authorization: $apikey" -X DELETE  $propertyDelURL)
			HTTP_STATUS=$(echo $propertyDelResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
			if [ $HTTP_STATUS != 204 ]
			then
				printf "%b\n \e[31m Failure : Property delete failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
			fi
		done
	else 
		exit 1
	fi
	printf "%b\n\n \e[32mSuccess : Cleanup completed successfully. Re-run the setup. \e[39m \n"
}

set -e
addSegments()
{
	segmentUpdateURL=$segmentURL
	days=$(($(date +'%s * 1000 + %-N / 1000000')))
	segmentId="segment_${days}"
	segmentStatus=$(curl -s --write-out 'HTTPSTATUS:%{http_code}'  -X POST $segmentUpdateURL -H "Authorization: $apikey" -H "Content-Type: application/json" --data '{"segment_id": "'"${segmentId}"'", "name": "Bluetooth earphones segment","description": "Segment to evaluate that bluetooth earphones are visible only during 10am to 12pm local time period","tags": "sale","rules" :  [{"values":["10"],"operator":"greaterThanEquals","attribute_name":"time"},{"values":["12"],"operator":"lesserThan","attribute_name":"time"}]}' )
	HTTP_BODY=$(echo $segmentStatus | sed -e 's/HTTPSTATUS\:.*//g' | jq .)
	HTTP_STATUS=$(echo $segmentStatus | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
 	printf "%b\nHTTP_STATUS is $HTTP_STATUS"
	if [ $HTTP_STATUS != 201 ]
	then
		printf "%b\n \e[31m Failure : Segment update failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
		cleanup
	else 
		segmentIdResponse=$(echo $HTTP_BODY | jq -rc '.segment_id')
		printf "%b\nSuccess:  Segment updated with id $segmentIdResponse\n"
	fi
	bluetoothEarphonesSegmentId=$segmentIdResponse
	printf "ibmer SegmentId is $bluetoothEarphonesSegmentId\n"

}

addCollection() 
{
	collectionStatus=$(curl -s --write-out 'HTTPSTATUS:%{http_code}'  -X POST $collectionURL -H "Authorization: $apikey" -H "Content-Type: application/json" --data '{"name" : "Shopping Website","collection_id": "shopping-website","description": "E-commerce site for shopping regular households","tags": "e-commerce"}' )
	HTTP_BODY=$(echo $collectionStatus | sed -e 's/HTTPSTATUS\:.*//g' | jq .)
	HTTP_STATUS=$(echo $collectionStatus | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
	printf "%b\nHTTP_STATUS is $HTTP_STATUS"
	if [ $HTTP_STATUS != 201 ]
	then
		printf "%b\n \e[31m Failure : Collection creation failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
		cleanup
	else 
		collectionId=$(echo $HTTP_BODY | jq -rc '.collection_id')
		printf "%b\nSuccess:  Collection created with id $collectionId\n"
	fi
}

addFeature()
{
	featureUpdateURL=$featureURL
	featureStatus=$(curl -s --write-out 'HTTPSTATUS:%{http_code}'  -X POST $featureUpdateURL -H "Authorization: $apikey" -H "Content-Type: application/json" --data '{"name": "Flash sale banner","feature_id": "flash-sale-banner","description": "A Boolean feature flag to display the announcement of flash sale via a banner","enabled_value": true,"type": "BOOLEAN","disabled_value": false,"tags": "banner","collections": [{"collection_id": "shopping-website"}],"segment_rules":[],"enabled": true}' )
	HTTP_BODY=$(echo $featureStatus | sed -e 's/HTTPSTATUS\:.*//g' | jq .)
	HTTP_STATUS=$(echo $featureStatus | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
	printf "%b\nHTTP_STATUS is $HTTP_STATUS\n"
	if [ $HTTP_STATUS != 201 ]
	then
		printf "%b\n \e[31m Failure : Feature update failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
		cleanup
	else 
		featureId=$(echo $HTTP_BODY | jq -rc '.feature_id')
		printf "%bSuccess:  Feature updated with id $featureId\n"
	fi

	featureStatus=$(curl -s --write-out 'HTTPSTATUS:%{http_code}'  -X POST $featureUpdateURL -H "Authorization: $apikey" -H "Content-Type: application/json" --data '{"name": "Bluetooth earphones","feature_id": "bluetooth-earphones","description": "Feature flag to show or disable all the bluetooth earphones in the products list. When targeting is enabled, the earphones are shown only to that segment","enabled_value": false,"type": "BOOLEAN","disabled_value": false,"tags": "earphones","segment_rules": [{"rules": [{"segments": ["'"${bluetoothEarphonesSegmentId}"'"]}],"value": true,"order": "1"}],"collections": [{"collection_id": "shopping-website"}],"enabled": true}' )
	HTTP_BODY=$(echo $featureStatus | sed -e 's/HTTPSTATUS\:.*//g' | jq .)
	HTTP_STATUS=$(echo $featureStatus | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
	if [ $HTTP_STATUS != 201 ]
	then
		printf "%b\n \e[31m Failure : Feature update failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
		cleanup
	else 
		featureId=$(echo $HTTP_BODY | jq -rc '.feature_id')
		printf "%bSuccess:  Feature updated with id $featureId\n"
	fi

}

addProperty()
{
	propertyUpdateURL=$propertyURL
	propertyStatus=$(curl -s --write-out 'HTTPSTATUS:%{http_code}'  -X POST $propertyUpdateURL -H "Authorization: $apikey" -H "Content-Type: application/json" --data '{"name": "Flash sale date","property_id": "flash-sale-date","description": "Numeric property to alter or change the date of flash sale","value": 20,"type": "NUMERIC","tags": "date","segment_rules": [],"collections": [{"collection_id": "shopping-website"}]}' )
	HTTP_BODY=$(echo $propertyStatus | sed -e 's/HTTPSTATUS\:.*//g' | jq .)
	HTTP_STATUS=$(echo $propertyStatus | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
	if [ $HTTP_STATUS != 201 ]
	then
		printf "%b\n \e[31m Failure : Property update failed with error code $HTTP_STATUS and body $HTTP_BODY \e[39m"
		cleanup
	else 
		propertyId=$(echo $HTTP_BODY | jq -rc '.property_id')
		printf "%bSuccess:  Property updated with id $propertyId\n"
	fi

}

if [[ $actionIn == 2 ]]
then
	cleanup
	exit 1
fi


#------------------------------------Environment tests---------------------------
if [[ $envActionIn == 2 ]]
then
	printf "%b\n************************** Creating environment for demo **************************\n"
	addEnvironment
fi

#------------------------------------Segments tests---------------------------
printf "%b\n************************** Creating segments for demo **************************\n"
addSegments

#------------------------------------Collections tests---------------------------
printf "%b\n************************** Creating collections for demo **************************\n"
addCollection

#------------------------------------Feature tests---------------------------
printf "%b\n************************** Creating features for demo **************************\n"
addFeature

#------------------------------------Feature tests---------------------------
printf "%b\n************************** Creating properties for demo **************************\n"
addProperty

printf "%b\n \e[32m--------------------------Demo script complete %b--------------------------\n"
