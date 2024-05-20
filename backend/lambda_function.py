import json
import boto3

DYNAMODB_TABLE_NAME = 'crc-fbrpinto-dynamodb-tf'

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


def update_visitors(table, num_visitors):
    #Update number of visitors
    num_visitors += 1

    # Update DynamoDB table
    response = table.update_item(
        Key = {'id': '0'},
        UpdateExpression = 'SET visitors = :nv',
        ExpressionAttributeValues = {':nv': num_visitors}
    )
    
    return num_visitors


def lambda_handler(event, context, table_name=DYNAMODB_TABLE_NAME):
    try:
        # Select DynamoDB table
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(table_name)

        # Get current number of visitors from DynamoDB
        num_visitors = get_visitors(table)

        # Update the current number of visitors in DynamoDB
        new_num_visitors = update_visitors(table, num_visitors)
        
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
    