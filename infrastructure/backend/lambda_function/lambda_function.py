import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('crc-fbrpinto-dynamodb-tf')

def lambda_handler(event, context):
    try:
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

        # Update DynamoDB table
        response = table.update_item(
            Key={'id': '0'},
            UpdateExpression='SET visitors = :nv',
            ExpressionAttributeValues={':nv': num_visitors + 1}
        )
        return {
            'statusCode': 200,
            'body': json.dumps('DynamoDB updated successfully')
        }
    except Exception as e:
        print('Error updating DynamoDB:', e)
        return {
            'statusCode': 500,
            'body': json.dumps('Error updating DynamoDB')
        }
