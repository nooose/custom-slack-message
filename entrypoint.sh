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
    GTIHUB_EVENT_JSON=`cat $GITHUB_EVENT_PATH`

    COMMIT_MESSAGE=`echo $GTIHUB_EVENT_JSON | jq -r .head_commit.message`
    COMMIT_MESSAGE=${COMMIT_MESSAGE//\\/\\\\}
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

    sed -i -e "s@COLOR@$COLOR@g" /build_payload.json
    sed -i -e "s@TITLE@$TITLE@g" /build_payload.json
    sed -i -e "s@COMMIT_MESSAGE@$COMMIT_MESSAGE@g" /build_payload.json
    sed -i -e "s@COMMIT_URL@$COMMIT_URL@g" /build_payload.json
    sed -i -e "s@SENDER_AVATAR_URL@$SENDER_AVATAR_URL@g" /build_payload.json
    sed -i -e "s@SENDER_HTML_URL@$SENDER_HTML_URL@g" /build_payload.json
    sed -i -e "s@SENDER_NAME@$SENDER_NAME@g" /build_payload.json
    sed -i -e "s@TAG@$TAG@g" /build_payload.json
    sed -i -e "s@BRANCH_NAME@$BRANCH_NAME@g" /build_payload.json
    sed -i -e "s@ACTION_URL@$ACTION_URL@g" /build_payload.json
    sed -i -e "s@GITHUB_WORKFLOW@$GITHUB_WORKFLOW@g" /build_payload.json

    mv /build_payload.json ./payload.json
}

# === main ===
echo "[INFO] EVENT $GITHUB_EVENT_PATH"
echo `cat $GITHUB_EVENT_PATH` | jq .


if [ "$COLOR" == "success" ]; then
    COLOR=\#2EB886
elif [ "$COLOR" == "failure" ]; then
    COLOR=\#CC0000
elif [ "$COLOR" == "cancelled" ]; then
    COLOR=\#A0A0A0
else
    COLOR=\#A0A0A0
fi

if [ "$TYPE" == "build" ]; then
    create_build_payload
else
    echo "[ERROR] $TYPE type is not supported."
    exit 1;
fi

# echo payload
echo "[INFO] slack payload"
echo `cat payload.json` | jq .

# send message to slack channel
curl -s $SLACK_WEBHOOK \
     -d @payload.json
