import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import os


#define the function
def lambda_handler(event, context):
    #retrieve message from event when lamda is triggered from SNS
    print(json.dumps(event))
    
    message = json.loads(event['Records'][0]['Sns']['Message'])
    print(json.dumps(message))
    
    '''
    Retrieve Json vriables from message
    AlarmName is the name of the cloudwatch alarm tht was set
    NewStateValue is the state of the alarm when lambda is triggered which means it has 
                gone from OK to Alarm
    NewStateReason is the reason for the change in state
    '''
    
    alarm_name = message['AlarmName']
    new_state = message['NewStateValue']
    reason = message['NewStateReason']
    
    #Create format for slack message
    slack_message = {
        'text' : f':fire: {alarm_name} state is now {new_state} :fire:\n{reason}\n'
                 f'```\n{json.dumps(message, indent=2)}```'
                    }
    #retrieve webhook url from parameter store
    webhook_url = os.environ.get('SLACK_WEBHOOK')
    
    #make  request to the API
    
    req = Request(webhook_url,
                    json.dumps(slack_message).encode('utf-8'))
    
    try:
        response = urlopen(req)
        response.read()
        print("Messge posted to Slack")
    except HTTPError as e:
        print(f'Request failed: {e.code} {e.reason}')
    except URLError as e:
        print(f'Server Connection failed:  {e.reason}')
