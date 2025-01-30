#!/bin/bash

# this script monitors the active queue and the deferred queue and alerts when those queues go over a preset threshold
#
# a cron job should be setup that runs every minute : /etc/cron.d/mailqueue__notifcation
# 	*/1 * * * * root nice -n 19 bash /usr/local/sbin/mailqueue_notification.sh >/dev/null 2>&1
#
# healthchecks.io to monitor it's execution, pushover.net and email to notify

EMAIL_TO="<email@example.com>"
EMAIL_FROM="<servername>"
SERVER_NAME="<servername.example.com>"

# anything greater than the threshold (not equal to)
#QUEUE_ALERT_THRESHOLD=200 #100
DEFERRED_QUEUE_ALERT_THRESHOLD=0 #>0 anything deferred get notified if single deferral
ACTIVE_QUEUE_ALERT_THRESHOLD=10

## pushover.net auth
PO_APP_TOKEN="<app_token>"
PO_USER_KEY="<user_key>"

# healthchecks.io url
HEALTHCHECKS_URL="<https://hc-ping.com/guid>"

# *** setup alert interval tracking ***
PO_ALERT_INTERVAL=300	# Minimum time between alerts in seconds (5 minutes)
PO_LAST_ACTIVE_ALERT_FILE="/tmp/postfix_pushover_active_queue_alert_time" # File to store the timestamp of the last alert
PO_LAST_DEFERRED_ALERT_FILE="/tmp/postfix_pushover_deferred_queue_alert_time" # File to store the timestamp of the last alert

EMAIL_ALERT_INTERVAL=600              # Minimum time between alerts in seconds (10 minutes)
EMAIL_LAST_ACTIVE_ALERT_FILE="/tmp/postfix_email_active_queue_alert_time" # File to store the timestamp of the last alert
EMAIL_LAST_DEFERRED_ALERT_FILE="/tmp/postfix_email_deferred_queue_alert_time" # File to store the timestamp of the last alert

source .env

CURRENT_TIME=$(date +%s)
#HUMAN_TIME=$(date "+%a %b %d %I:%M:%S %p %:::z %Y")
HUMAN_TIME=$(date)

# Read the last alert timestamp if it exists
## ACTIVE QUEUE
if [[ -f $PO_LAST_ACTIVE_ALERT_FILE ]]; then
  PO_LAST_ACTIVE_ALERT_TIME=$(cat $PO_LAST_ACTIVE_ALERT_FILE)
else
  PO_LAST_ACTIVE_ALERT_TIME=0
fi
if [[ -f $EMAIL_LAST_ACTIVE_ALERT_FILE ]]; then
  EMAIL_LAST_ACTIVE_ALERT_TIME=$(cat $EMAIL_LAST_ACTIVE_ALERT_FILE)
else
  EMAIL_LAST_ACTIVE_ALERT_TIME=0
fi
## DEFERRED
if [[ -f $PO_LAST_DEFERRED_ALERT_FILE ]]; then
  PO_LAST_DEFERRED_ALERT_TIME=$(cat $PO_LAST_DEFERRED_ALERT_FILE)
else
  PO_LAST_DEFERRED_ALERT_TIME=0
fi
if [[ -f $EMAIL_LAST_DEFERRED_ALERT_FILE ]]; then
  EMAIL_LAST_DEFERRED_ALERT_TIME=$(cat $EMAIL_LAST_DEFERRED_ALERT_FILE)
else
  EMAIL_LAST_DEFERRED_ALERT_TIME=0
fi
# *** end setup alert interval tracking ***




# get queue counts
# mailq_count="$(/usr/bin/mailq | /usr/bin/tail -n1 | /usr/bin/gawk '{print $5}')"
active_count="$(postqueue -j | jq -s 'reduce .[].queue_name as $q ({}; . + { ($q): (1 + .[$q]) })' | jq '.active // empty')"
deferred_count="$(postqueue -j | jq -s 'reduce .[].queue_name as $q ({}; . + { ($q): (1 + .[$q]) })' | jq '.deferred // empty')"

#echo $(($CURRENT_TIME - $LAST_ALERT_TIME))
#echo $(($CURRENT_TIME - $LAST_DEFERRED_ALERT_TIME))

# If variable is empty, then the queue is empty -> set it to zero
if [ -z "$active_count" ]; then
  active_count=0
fi
if [ -z "$deferred_count" ]; then
  deferred_count=0
fi

echo $HUMAN_TIME
echo "ACTIVE QUEUE: $active_count / $ACTIVE_QUEUE_ALERT_THRESHOLD"
echo "DEFERRED QUEUED: $deferred_count / $DEFERRED_QUEUE_ALERT_THRESHOLD"
echo "Email to: $EMAIL_TO"

# ACTIVE QUEUE

if [ "$active_count" -gt $ACTIVE_QUEUE_ALERT_THRESHOLD ]; then

  if [ $(($CURRENT_TIME - $EMAIL_LAST_ACTIVE_ALERT_TIME)) -ge $EMAIL_ALERT_INTERVAL ]; then
    #send email
    echo "ACTIVE mail count on ${SERVER_NAME} is ${active_count} ${HUMAN_TIME}" | /usr/bin/mail -s "${SERVER_NAME} ACTIVE queue size: ${active_count} ${HUMAN_TIME}" $EMAIL_TO -a "From: ${EMAIL_FROM}" <<< "${SERVER_NAME} ACTIVE queue size: ${active_count} / threshold: ${ACTIVE_QUEUE_ALERT_THRESHOLD} happened at ${HUMAN_TIME}"
    # Update the last alert timestamp
    echo $CURRENT_TIME >| $EMAIL_LAST_ACTIVE_ALERT_FILE

    echo "EMAIL ALERT SENT for ACTIVE"
  fi

  if [ $(($CURRENT_TIME - $PO_LAST_ACTIVE_ALERT_TIME)) -ge $PO_ALERT_INTERVAL ]; then
    # pushover.net
    curl -s \
      --form-string "token=${PO_APP_TOKEN}" \
      --form-string "user=${PO_USER_KEY}" \
      --form-string "message=${SERVER_NAME} ACTIVE queue size is ${active_count} / threshold: ${ACTIVE_QUEUE_ALERT_THRESHOLD} happened at ${HUMAN_TIME}" \
      https://api.pushover.net/1/messages.json

    # Update the last alert timestamp
    echo $CURRENT_TIME >| $PO_LAST_ACTIVE_ALERT_FILE

    echo "PUSHOVER ALERT SENT for ACTIVE"
  fi

fi


# DEFERRED QUEUE

if [ "$deferred_count" -gt $DEFERRED_QUEUE_ALERT_THRESHOLD ]; then

  if [ $(($CURRENT_TIME - $EMAIL_LAST_DEFERRED_ALERT_TIME)) -ge $EMAIL_ALERT_INTERVAL ]; then
    #send email
    echo "DEFERRED mail count on ${SERVER_NAME} is ${deferred_count} ${HUMAN_TIME}" | /usr/bin/mail -s "${SERVER_NAME} DEFERRED queue size: ${deferred_count} ${HUMAN_TIME}" $EMAIL_TO -a "From: ${EMAIL_FROM}" <<< "${SERVER_NAME} DEFERRED queue size: ${deferred_count} / threshold: ${DEFERRED_QUEUE_ALERT_THRESHOLD} happened at ${HUMAN_TIME}"
    # Update the last alert timestamp
    echo $CURRENT_TIME >| $EMAIL_LAST_DEFERRED_ALERT_FILE

    echo "EMAIL ALERT SENT for DEFERRED"
  fi

  if [ $(($CURRENT_TIME - $PO_LAST_DEFERRED_ALERT_TIME)) -ge $PO_ALERT_INTERVAL ]; then
    # pushover.net
    curl -s \
      --form-string "token=${PO_APP_TOKEN}" \
      --form-string "user=${PO_USER_KEY}" \
      --form-string "message=${SERVER_NAME} DEFERRED queue size is ${deferred_count} / threshold: ${DEFERRED_QUEUE_ALERT_THRESHOLD} happened at ${HUMAN_TIME}" \
      https://api.pushover.net/1/messages.json

    # Update the last alert timestamp
    echo $CURRENT_TIME >| $PO_LAST_DEFERRED_ALERT_FILE

    echo "PUSHOVER ALERT SENT for DEFERRED"
  fi

fi


## update heathchecks.io
## using curl (10 second timeout, retry up to 5 times):
curl -m 10 --retry 5 $HEALTHCHECKS_URL
