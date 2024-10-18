import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import os

def lambda_handler(event, context):
    # Extract the message from the SNS event
    message = json.loads(event['Records'][0]['Sns']['Message'])
    print(json.dumps(message))
        
    # Get details from the message
    alarm_name = message['AlarmName']
    new_state = message['NewStateValue']
    reason = message['NewStateReason']
    
    # Format the message to be sent to Slack
    slack_message = {
        'text' : f':fire: {alarm_name} state is now {new_state} :fire:\n{reason}\n'
                 f'```\n{json.dumps(message, indent=2)}```'
    }
    
    # Get the Slack webhook URL from the environment variables
    webhook_url = os.environ.get('SLACK_WEBHOOK')
    
    # Prepare the request to the Slack API
    req = Request(webhook_url, json.dumps(slack_message).encode('utf-8'))
    
    try:
        # Send the request to the Slack API
        response = urlopen(req)
        response.read()
        print("Message posted to Slack")
    except HTTPError as e:
        # Handle HTTP errors from the request
        print(f'Request failed: {e.code} {e.reason}')
    except URLError as e:
        # Handle URL errors, such as connection issues
        print(f'Server connection failed: {e.reason}')
