#!/usr/bin/env bash

# ENV 
TYPE=$1
SLACK_WEBHOOK=$2
TOKEN=$3
COLOR=$4
TITLE=$5
ENVIRONMENT=$6


if [ -z $COLOR ]; then
    COLOR=\#2EB886
elif [ $COLOR == "success" ]; then
    COLOR=\#2EB886
elif [ $COLOR == "failure" ]; then
    COLOR=\#CC0000
elif [ $COLOR == "cancelled" ]; then
    COLOR=\#A0A0A0
fi


echo [INFO] EVENT $GITHUB_EVENT_PATH
EVENT_RESULT=$(<$GITHUB_EVENT_PATH)


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
    jq ".blocks += [$REVIEW_FIELD_PAYLOAD]" payload.json > tmp.json
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
    jq ".blocks += [$REVIEWR_PAYLOAD]" payload.json > tmp.json
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
    jq ".blocks += [$MERGED_FIELD_PAYLOAD]" payload.json > tmp.json
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



add_commit_field_func() {
    COMMIT_MESSAGE=$1
    COMMIT_URL=$2
    COMMITTER=$3

cat << EOF > commit_field.json
{
    "type": "context",
    "elements": [
        {
            "type": "mrkdwn",
            "text": "*${COMMIT_MESSAGE}*\n<${COMMIT_URL}|${COMMITTER}>"
        }
    ]
}
EOF
    COMMIT_FIELD_PAYLOAD=$(<commit_field.json)
    jq ".blocks += [$COMMIT_FIELD_PAYLOAD]" payload.json > tmp.json
    mv tmp.json payload.json

}





if [ $TYPE == "pr" ]; then

    REPO_NAME=${GITHUB_REPOSITORY}
    PR_NUMBER=$(echo $EVENT_RESULT | jq .number)
    PR_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER
    PR_REVIEW_API=https://api.github.com/repos/$REPO_NAME/pulls/$PR_NUMBER/reviews
    PR_RESULT=$(curl -s $PR_API \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Authorization: Bearer $TOKEN")
    PR_REVIEW_RESULT=$(curl -s $PR_REVIEW_API \
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
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": ":github: :merged: $TITLE",
                "emoji": true
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*\`$BASE\`*   :arrow-l:   *\`$HEAD\`*"
            }
        },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "$PR_TITLE\n<$PR_URL|확인>"
                    }
                ]
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
EOF

    add_reviewer_func
    create_mergedBy_field_func $MERGED_BY $MERGED_BY_AVATAR


elif [ $TYPE == "push" ]; then
    echo [INFO] TYPE $TYPE
    

    echo [INFO] BRANCH_NAME $GITHUB_REF_NAME
    echo [INFO] SERVICE_NAME $GITHUB_REPOSITORY
    TITLE=$GITHUB_REPOSITORY
    BRANCH_NAME=$GITHUB_REF_NAME


cat << EOF > payload.json
    {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": ":github: :git-push: $TITLE",
                    "emoji": true
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
                        "text": " "
                    },
                    {
                        "type": "mrkdwn",
                        "text": "\`$BRANCH_NAME\`"
                    },
                    {
                        "type": "mrkdwn",
                        "text": " "
                    }
                ]
            }
        ]
    }
EOF

    echo $EVENT_RESULT | jq .
    BEFORE_COMMIT=$(echo $EVENT_RESULT | jq -r .before)

    for COMMIT in $(git rev-list ${BEFORE_COMMIT}..${GITHUB_SHA}); do
        echo [INFO] COMMIT $COMMIT
        
        COMMITTER=$(git show -s --format=%an $COMMIT)
        COMMIT_MESSAGE=$(git show -s --format=%B $COMMIT)
        COMMIT_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/$COMMIT
        
        add_commit_field_func "$COMMIT_MESSAGE" "$COMMIT_URL" "$COMMITTER"
    done

    




elif [ "$TYPE" == "build" ]; then
    REPO_NAME=${GITHUB_REPOSITORY}
    SERVICE_NAME=$(basename $REPO_NAME)
    BRANCH_NAME=${GITHUB_REF##*heads/}
    ACTION_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
    GITHUB_WORKFLOW=${GITHUB_WORKFLOW}

    
    COMMIT_URL=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}
    COMMIT_API=https://api.github.com/repos/$REPO_NAME/commits/${GITHUB_SHA}
    COMMIT_RESULT=$(curl -s $COMMIT_API \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN")
    COMMIT_MESSAGE=$(echo $COMMIT_RESULT | jq -r .commit.message)
    
       


    if [ -z $TITLE ]; then
        TITLE=$SERVICE_NAME 빌드
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
    COMMIT_RESULT=$(curl -s $COMMIT_API \
                         -H "Accept: application/vnd.github.v3+json" \
                         -H "Authorization: Bearer $TOKEN")
    COMMIT_MESSAGE=$(echo $COMMIT_RESULT | jq -r .commit.message)

    if [ -z $TITLE ]; then
        TITLE=${SERVICE_NAME} 배포
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
                            "text": ":argo: :kubernetes: $TITLE",
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
