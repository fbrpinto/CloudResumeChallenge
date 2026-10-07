import json
import os
import re
from urllib.request import Request, urlopen

# ntfy topics are public: send only the monitor, threshold and value (no names, links or IDs)
NTFY_URL = f"https://ntfy.sh/{os.environ['NTFY_TOPIC']}"


def number(value):
    # 1000.0 -> "1,000", 0.5 -> "0.5"
    return f"{float(value):,.2f}".rstrip("0").rstrip(".")


def alarm_text(message):
    label = message['AlarmDescription']
    threshold = number(message['Trigger']['Threshold'])

    if message['NewStateValue'] == 'OK':
        return f"{label} recovered. Threshold is {threshold}.", 'default'

    # The reason holds the datapoint, e.g. "... [1234.0 (07/10/26 12:00:00)] was greater than ..."
    match = re.search(r"\[([0-9.eE+-]+) \(", message['NewStateReason'])
    value = number(match.group(1)) if match else 'unknown'
    return f"{label} fired. Threshold was {threshold}. Value is {value}.", 'high'


def anomaly_text(message):
    threshold = number(os.environ['ANOMALY_THRESHOLD'])
    try:
        value = f"${float(message['impact']['totalImpact']):,.2f}"
    except (KeyError, TypeError, ValueError):
        value = 'unknown'
    return f"Cost anomaly fired. Threshold was ${threshold}. Value is {value}.", 'high'


def send(text, priority):
    print(text)
    req = Request(NTFY_URL, data=text.encode('utf-8'), headers={'Priority': priority})
    # Errors are raised so Lambda retries the delivery
    with urlopen(req, timeout=10) as response:
        response.read()


def lambda_handler(event, context):
    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])

        # CloudWatch alarm
        if 'AlarmName' in message:
            # Alarms start in INSUFFICIENT_DATA, so only announce OK after a real alarm
            if message['NewStateValue'] == 'OK' and message['OldStateValue'] != 'ALARM':
                continue
            send(*alarm_text(message))

        # Cost Anomaly Detection
        else:
            send(*anomaly_text(message))
