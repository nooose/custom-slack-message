#!/usr/bin/env bash

# ENV 
TYPE=$1
SLACK_WEBHOOK=$2
TOKEN=$3
PR_NUMBER=$4
COLOR=$5
TITLE=$6
ENVIRONMENT=$7


if [ -z $COLOR ]; then
    COLOR=\#2EB886
elif [ $COLOR == "success" ]; then
    COLOR=\#2EB886
elif [ $COLOR == "failure" ]; then
    COLOR=\#CC0000
elif [ $COLOR == "cancelled" ]; then
    COLOR=\#A0A0A0
fi


create_review_field_func() {
cat << EOF > review_field.json
    {
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "*리뷰어*"
        }
    }
EOF
    REVIEW_FIELD_PAYLOAD=$(<review_field.json)
    jq ".attachments[].blocks += [$REVIEW_FIELD_PAYLOAD]" payload.json > tmp.json
    mv tmp.json payload.json
}

create_reviewer_func() {
    USER=$1
    AVATAR=$2

cat << EOF > reviewer.json
    {
    "type": "context",
    "elements": 
        [
            {
                "type": "image",
                "image_url": $AVATAR,
                "alt_text": ""
            },
            {
                "type": "plain_text",
                "text": $USER
            }
        ]
    }
EOF
    REVIEWR_PAYLOAD=$(<reviewer.json)
    jq ".attachments[].blocks += [$REVIEWR_PAYLOAD]" payload.json > tmp.json
    mv tmp.json payload.json
}

create_mergedBy_field_func() {
    MERGED_BY=$1
    MERGED_BY_AVATAR=$2

cat << EOF > merged_field.json
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
EOF
    MERGED_FIELD_PAYLOAD=$(<merged_field.json)
    jq ".attachments[].blocks += [$MERGED_FIELD_PAYLOAD]" payload.json > tmp.json
    mv tmp.json payload.json
}

add_reviewer_func() {
    # 리뷰어 리스트
    APPROVED_REVIEWS=$(echo $PR_REVIEW_RESULT | \
                        jq '.[] | select(.state == "APPROVED") | [.user.login, .user.avatar_url]' | \
                        jq -c | uniq)
    
    REVIEWS_SIZE=0
    for REVIEW in $APPROVED_REVIEWS
    do
        REVIEWS_SIZE=$(( REVIEWS_SIZE + 1 ))
    done

    if [ $REVIEWS_SIZE -gt 0 ]; then
        create_review_field_func
    fi


    for REVIEW in $APPROVED_REVIEWS
    do    
        REVIEW=$(echo $REVIEW | tr '[' ' ' | tr ']' ' ')
        USER=$(echo $REVIEW | cut -d ',' -f1)
        AVATAR=$(echo $REVIEW | cut -d ',' -f2)
        
        echo $USER $AVATAR
        create_reviewer_func $USER $AVATAR
    done
}



if [ $TYPE == "pr" ]; then

    REPO_NAME=${GITHUB_REPOSITORY}
    PR_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER
    PR_REVIEW_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER/reviews
    PR_RESULT=$(curl $PR_API \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Authorization: Bearer $TOKEN")
    PR_REVIEW_RESULT=$(curl $PR_REVIEW_API \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Authorization: Bearer $TOKEN")                

    PR_URL=$(echo $PR_RESULT | jq -r .html_url)
    SERVICE_NAME=$(echo $PR_RESULT | jq -r .head.repo.name)
    BASE=$(echo $PR_RESULT | jq -r .base.ref)
    HEAD=$(echo $PR_RESULT | jq -r .head.ref)
    PR_CREATOR=$(echo $PR_RESULT | jq .user.login)
    PR_CREATOR_AVATAR=$(echo $PR_RESULT | jq .user.avatar_url)
    PR_TITLE=$(echo $PR_RESULT | jq -r .title)
    MERGED_BY=$(echo $PR_RESULT | jq .merged_by.login)
    MERGED_BY_AVATAR=$(echo $PR_RESULT | jq .merged_by.avatar_url)

    if [ -z $TITLE ]; then
        TITLE=$SERVICE_NAME
    fi

    # COLOR=\#A0A0A0

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
                        "text": "$TITLE"
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
                }
            ]
        }
    ]
}
EOF

    add_reviewer_func
    create_mergedBy_field_func $MERGED_BY $MERGED_BY_AVATAR

elif [ "$TYPE" == "build" ]; then
    echo [INFO] 테스트 $IMAGE_NAME

    REPO_NAME=${GITHUB_REPOSITORY}
    SERVICE_NAME=$(basename $REPO_NAME)
    BRANCH_NAME=${GITHUB_REF##*heads/}
    ACTION_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
    GITHUB_WORKFLOW=${GITHUB_WORKFLOW}

    
    COMMIT_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}
    COMMIT_API=https://api.github.com/repos/$REPO_NAME/commits/${GITHUB_SHA}
    COMMIT_RESULT=$(curl $API \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN")
    COMMIT_MESSAGE=$(echo $COMMIT_RESULT | jq .commit.message)   


    if [ -z $TITLE ]; then
        TITLE=$SERVICE_NAME-빌드
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
                            "text": "$TITLE" 
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": "<$COMMIT_URL|$COMMIT_MESSAGE>"
                        }
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
                                "text": "\`$BRANCH_NAME\`"
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
    

elif [ $TYPE == "deploy" ]; then

    REPO_NAME=${GITHUB_REPOSITORY}
    ACTION_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
    GITHUB_WORKFLOW=${GITHUB_WORKFLOW}

    COMMIT_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}
    COMMIT_API=https://api.github.com/repos/$REPO_NAME/commits/${GITHUB_SHA}
    COMMIT_RESULT=$(curl $API \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN")
    COMMIT_MESSAGE=$(echo $COMMIT_RESULT | jq .commit.message)

    if [ -z $TITLE ]; then
        TITLE=${SERVICE_NAME}-배포
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
                            "text": "$TITLE" 
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": "<$COMMIT_URL|$COMMIT_MESSAGE>"
                        }
				    },
                    {
                        "type": "section",
                        "fields": [
                            {
                                "type": "mrkdwn",
                                "text": "*환경*"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "*Action URL*"
                            },
                            {
                                "type": "mrkdwn",
                                "text": "\`$ENVIRONMENT\`"
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

else
    return 1;
fi

curl -s $SLACK_WEBHOOK \
     -d @payload.json
