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

cat << EOF > payload.json
    {
        "attachments": 
        [
            {
                "color": "$COLOR",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": ":docker-1: $TITLE",
                            "emoji": true
                        }
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": "$COMMIT_MESSAGE\n<$COMMIT_URL|확인>"
                            }
                        ]
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": "*Action sender*"
                            }
                        ]
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "image",
                                "image_url": "$SENDER_AVATAR_URL",
                                "alt_text": "avatar"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "\n<$SENDER_HTML_URL|$SENDER_NAME>"
                            }
                        ]
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": "*이미지 태그*\n\`$TAG\`"
                            }
                        ]
                    },
                    {
                        "type": "section",
                        "fields": [
                            {
                                "type": "mrkdwn",
                                "text": "*브랜치*"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "*Action URL*"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "*\`$BRANCH_NAME\`*"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "<$ACTION_URL|$GITHUB_WORKFLOW>"
                            }
                        ]
                    }
                ]
            }
        ]
    }
EOF
}

echo [INFO] EVENT $GITHUB_EVENT_PATH
echo `cat $GITHUB_EVENT_PATH` | jq .


# === main ===
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
