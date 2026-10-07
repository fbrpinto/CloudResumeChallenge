
import json
import boto3

DYNAMODB_TABLE_NAME = 'crc-fbrpinto-dynamodb-tf'

# Created once per Lambda instance and reused across invocations
_dynamodb = None


def get_table(table_name):
    global _dynamodb
    if _dynamodb is None:
        _dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
    return _dynamodb.Table(table_name)


def get_visitors(table):
    # Try to get the number of visitors
    response = table.get_item(
        Key={'id': '0'}
    )
    item = response.get('Item')

    # If 'visitors' attribute is not defined yet
    if not item or 'visitors' not in item:
        num_visitors = 0
    else:
        num_visitors = item['visitors']

    # Return current number of visitors
    return num_visitors


def update_visitors(table):
    # Atomically increment the number of visitors (ADD starts from 0 if not defined yet),
    # so simultaneous visits are never lost
    response = table.update_item(
        Key = {'id': '0'},
        UpdateExpression = 'ADD visitors :one',
        ExpressionAttributeValues = {':one': 1},
        ReturnValues = 'UPDATED_NEW'
    )

    return response['Attributes']['visitors']


def lambda_handler(event, context, table_name=DYNAMODB_TABLE_NAME):
    try:
        # Select DynamoDB table
        table = get_table(table_name)

        # Increment the number of visitors in DynamoDB
        new_num_visitors = update_visitors(table)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'visitors': int(new_num_visitors)}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Invalid Request',
                                'message': str(e)}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }
    