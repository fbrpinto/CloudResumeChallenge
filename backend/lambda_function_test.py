import unittest
from moto import mock_aws
import boto3
from lambda_function import get_visitors, update_visitors, lambda_handler, DYNAMODB_TABLE_NAME


class BackendUnitTesting(unittest.TestCase):

    def setUp(self):
        self.mock_aws = mock_aws()
        self.mock_aws.start()

        # Create a DynamoDB client
        dynamodb = boto3.client('dynamodb', region_name='eu-west-1')

        table_name = DYNAMODB_TABLE_NAME
        key_schema = [
            {'AttributeName': 'id', 'KeyType': 'HASH'},  # Partition key
        ]

        attribute_definitions = [{'AttributeName': 'id', 'AttributeType': 'S'}]
    
    
        # Define the table schema
        table_schema = {
            'TableName': table_name,
            'KeySchema': key_schema,
            'AttributeDefinitions': attribute_definitions,
            'BillingMode': 'PAY_PER_REQUEST'
        }
    
        # Create the table
        dynamodb.create_table(**table_schema)

    def tearDown(self):
        self.mock_aws.stop()

    def test_get_visitors_empty_table(self):
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        self.assertEqual(get_visitors(table), 0)
    
    def test_get_visitors_with_value(self):
        dynamodb = boto3.resource('dynamodb',region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        table.update_item(
            Key = {'id': '0'},
            UpdateExpression = 'SET visitors = :nv',
            ExpressionAttributeValues = {':nv': 100}
        )

        self.assertEqual(get_visitors(table), 100)

    def test_update_visitors(self):
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        new_num_visitors = update_visitors(table, 100)

        read_num_visitors = table.get_item(
            Key={'id': '0'}
        ).get('Item')['visitors']

        self.assertEqual(new_num_visitors, 101)
        self.assertEqual(new_num_visitors, read_num_visitors)
    

    def test_lambda_handler_valid(self):

        response1 = lambda_handler(None,None)
        response2 = lambda_handler(None,None, DYNAMODB_TABLE_NAME)

        self.assertEqual(response1['statusCode'], 200)
        self.assertEqual(response1['body'], '{"visitors": 1}')
        self.assertEqual(response1['headers']['Content-Type'], 'application/json')

        self.assertEqual(response2['statusCode'], 200)
        self.assertEqual(response2['body'], '{"visitors": 2}')
        self.assertEqual(response2['headers']['Content-Type'], 'application/json')


    def test_lambda_handler_error(self):
        response = lambda_handler(None,None, 'NON_EXISTING_TABLE')

        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(response['body'], '{"error": "Invalid Request", "message": "An error occurred (ResourceNotFoundException) when calling the GetItem operation: Requested resource not found"}')
        self.assertEqual(response['headers']['Content-Type'], 'application/json')

    

if __name__ == '__main__':
    unittest.main()