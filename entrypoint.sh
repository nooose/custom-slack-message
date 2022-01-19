#!/bin/sh

# ENV 
TYPE=$1
SLACK_WEBHOOK=$2
TOKEN=$3
PR_NUMBER=$4
REPO_NAME=$5

echo [INFO] TYPE $1
echo [INFO] SLACK_WEBHOOK $2
echo [INFO] TOKEN $3
echo [INFO] PR_NUMBER $4
echo [INFO] REPO_NAME $5



if [ $TYPE == "pr" ]; then
PR_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER
PR_REVIEW_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER/reviews
PR_RESULT=$(curl $PR_API \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Authorization: Bearer $TOKEN")
PR_REVIEW_RESULT=$(curl $PR_REVIEW_API \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Authorization: Bearer $TOKEN")                

PR_URL=$(echo $PR_RESULT | jq -r .html_url)
SERVICE=$(echo $PR_RESULT | jq .head.repo.name)
BASE=$(echo $PR_RESULT | jq -r .base.ref)
HEAD=$(echo $PR_RESULT | jq -r .head.ref)
PR_CREATOR=$(echo $PR_RESULT | jq .user.login)
PR_CREATOR_AVATAR=$(echo $PR_RESULT | jq .user.avatar_url)
PR_TITLE=$(echo $PR_RESULT | jq -r .title)
MERGED_BY=$(echo $PR_RESULT | jq .merged_by.login)
MERGED_BY_AVATAR=$(echo $PR_RESULT | jq .merged_by.avatar_url)


COLOR=\#A0A0A0
cat << EOF > payload.json
{
    "attachments": [
        {
            "color": "${COLOR}",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": $SERVICE
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*\`$BASE\`*   :arrow_left:   *\`$HEAD\`*"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "<$PR_URL|*$PR_TITLE*>"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*PR 생성*"
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "image",
                            "image_url": $PR_CREATOR_AVATAR,
                            "alt_text": ""
                        },
                        {
                            "type": "plain_text",
                            "text": $PR_CREATOR
                        }
                    ]
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*Merged by*"
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "image",
                            "image_url": $MERGED_BY_AVATAR,
                            "alt_text": ""
                        },
                        {
                            "type": "plain_text",
                            "text": $MERGED_BY
                        }
                    ]
                }
            ]
        }
    ]
}
EOF

# 리뷰어 추가
# Approved 상태인 리뷰 length가 0 보다 큰 경우 진행
    # APPROVED_REVIEWS=$(echo $PR_REVIEW_RESULT | jq '.[] | select(.state == "APPROVED") | [.user.login, .user.avatar_url]' | jq -c | uniq)
    # REVIEWS_SIZE=$(echo $APPROVED)
    
    # echo [INFO] APPROVED_REVIEWS $APPROVED_REVIEWS
    # if [ $APPROVED_SIZE -gt 0 ]; then
    #     # JQ 추가
    #     echo [INFO] JQ 추가
    # fi


elif [ $TYPE == "build" ]; then
    echo $TYPE 
elif [ $TYPE == "helm" ]; then
    echo $TYPE
else
    return 1;
fi

curl -s $SLACK_WEBHOOK \
     -d @payload.json
    


