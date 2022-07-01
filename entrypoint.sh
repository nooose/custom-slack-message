#!/usr/bin/env bash

# ENV 
TYPE=$1
SLACK_WEBHOOK=$2
TOKEN=$3
COLOR=$4
TITLE=$5

function create_build_payload() {
    REPO_NAME=${GITHUB_REPOSITORY}
    SERVICE_NAME=`basename $REPO_NAME`
    BRANCH_NAME=${GITHUB_REF##*heads/}
    ACTION_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
    GITHUB_WORKFLOW=${GITHUB_WORKFLOW}
    COMMIT_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}
    COMMIT_API=https://api.github.com/repos/$REPO_NAME/commits/${GITHUB_SHA}
    COMMIT_RESULT=`curl -s $COMMIT_API \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN"`
    COMMIT_MESSAGE=`echo $COMMIT_RESULT | jq -r .commit.message`
    GTIHUB_EVENT_JSON=`cat $GITHUB_EVENT_PATH`
    SENDER_AVATAR_URL=`echo $GTIHUB_EVENT_JSON | jq -r .sender.avatar_url`
    SENDER_HTML_URL=`echo $GTIHUB_EVENT_JSON | jq -r .sender.html_url`
    SENDER_API_URL=`echo $GTIHUB_EVENT_JSON | jq -r .sender.url`
    SENDER_NAME=`curl -s $SENDER_API_URL \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN" \
                         | jq -r .name`

    if [ -z $TITLE ]; then
        TITLE="$SERVICE_NAME 빌드"
    fi

    sed -i -bak "s/<TITLE>/$TITLE/g" //build_payload.json
    sed -i -bak "s/<COMMIT_MESSAGE>/$COMMIT_MESSAGE/g" /build_payload.json
    sed -i -bak "s/<COMMIT_URL>/$COMMIT_URL/g" /build_payload.json
    sed -i -bak "s/<SENDER_AVATAR_URL>/$SENDER_AVATAR_URL/g" /build_payload.json
    sed -i -bak "s/<SENDER_HTML_URL>/$SENDER_HTML_URL/g" /build_payload.json
    sed -i -bak "s/<SENDER_NAME>/$SENDER_NAME/g" /build_payload.json
    sed -i -bak "s/<TAG>/$TAG/g" /build_payload.json
    sed -i -bak "s/<BRANCH_NAME>/$BRANCH_NAME/g" /build_payload.json
    sed -i -bak "s/<ACTION_URL>/$ACTION_URL/g" /build_payload.json
    sed -i -bak "s/<GITHUB_WORKFLOW>/$GITHUB_WORKFLOW/g" /build_payload.json

    mv /build_payload.json payload.json
}    
        

# === main ===
echo [INFO] EVENT $GITHUB_EVENT_PATH
echo `cat $GITHUB_EVENT_PATH` | jq .


if [ "$COLOR" == "success" ]; then
    COLOR=\#2EB886
elif [ "$COLOR" == "failure" ]; then
    COLOR=\#CC0000
elif [ "$COLOR" == "cancelled" ]; then
    COLOR=\#A0A0A0
else
    COLOR=\#2EB886
fi

if [ "$TYPE" == "build" ]; then
    create_build_payload
else
    return 1;
fi

# send message to slack channel
curl -s $SLACK_WEBHOOK \
     -d @payload.json
