#!/bin/sh -l

SLACK_WEBHOOK=$1
TYPE=$2

echo "SLACK_WEBHOOK" $SLACK_WEBHOOK
echo "TYPE" $TYPE
echo "PR_NUMBER" $PR_NUMBER




# pr
if [ $TYPE == "pr" ]; then
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
						"text": "test-service"
					}
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*`develop`*  :arrow_left:  *`api/*`*"
					}
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "<https://google.com|*PR 메시지*>"
					}
				},
				{
					"type": "divider"
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*PR 생성자*"
					}
				},
				{
					"type": "context",
					"elements": [
						{
							"type": "plain_text",
							"text": "성준혁"
						}
					]
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*PR 승인자*"
					}
				},
				{
					"type": "context",
					"elements": [
						{
							"type": "plain_text",
							"text": "성준혁"
						},
						{
							"type": "plain_text",
							"text": "성준혁"
						},
						{
							"type": "plain_text",
							"text": "성준혁"
						}
					]
				}
			]
		}
	]
}
EOF

else if [ $TYPE == "build" ]; then



else if [ $TYPE == "helm" ]; then


fi
