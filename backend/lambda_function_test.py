import unittest
from moto import mock_aws
import boto3
from lambda_function import get_visitors, update_visitors, lambda_handler, DYNAMODB_TABLE_NAME

class BackendUnitTesting(unittest.TestCase):

    def setUp(self):
        self.mock_aws = mock_aws()  # Start AWS mocking
        self.mock_aws.start()

        # Create a DynamoDB client for testing
        dynamodb = boto3.client('dynamodb', region_name='eu-west-1')

        table_name = DYNAMODB_TABLE_NAME
        key_schema = [
            {'AttributeName': 'id', 'KeyType': 'HASH'},  # Define the partition key
        ]

        attribute_definitions = [{'AttributeName': 'id', 'AttributeType': 'S'}]  # Define attribute types

        # Define the table schema for DynamoDB
        table_schema = {
            'TableName': table_name,
            'KeySchema': key_schema,
            'AttributeDefinitions': attribute_definitions,
            'BillingMode': 'PAY_PER_REQUEST'  # Set billing mode
        }

        # Create the DynamoDB table
        dynamodb.create_table(**table_schema)

    def tearDown(self):
        self.mock_aws.stop()  # Stop AWS mocking after tests

    def test_get_visitors_empty_table(self):
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        # Assert that the number of visitors is 0 when the table is empty
        self.assertEqual(get_visitors(table), 0)

    def test_get_visitors_with_value(self):
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        # Update the item in the table to set visitors to 100
        table.update_item(
            Key={'id': '0'},
            UpdateExpression='SET visitors = :nv',
            ExpressionAttributeValues={':nv': 100}
        )

        # Assert that the number of visitors is 100
        self.assertEqual(get_visitors(table), 100)

    def test_update_visitors(self):
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        # Call update_visitors and assert that it increments the visitor count correctly
        new_num_visitors = update_visitors(table, 100)

        read_num_visitors = table.get_item(
            Key={'id': '0'}
        ).get('Item')['visitors']  # Retrieve the updated number of visitors

        self.assertEqual(new_num_visitors, 101)  # Check if updated visitors count is correct
        self.assertEqual(new_num_visitors, read_num_visitors)  # Check if retrieved count matches updated count

    def test_lambda_handler_valid(self):
        # Test the lambda handler for valid responses
        response1 = lambda_handler(None, None)
        response2 = lambda_handler(None, None, DYNAMODB_TABLE_NAME)

        # Assert that the responses have correct status and body for both calls
        self.assertEqual(response1['statusCode'], 200)
        self.assertEqual(response1['body'], '{"visitors": 1}')
        self.assertEqual(response1['headers']['Content-Type'], 'application/json')

        self.assertEqual(response2['statusCode'], 200)
        self.assertEqual(response2['body'], '{"visitors": 2}')
        self.assertEqual(response2['headers']['Content-Type'], 'application/json')

    def test_lambda_handler_error(self):
        # Test the lambda handler for error handling with a non-existing table
        response = lambda_handler(None, None, 'NON_EXISTING_TABLE')

        # Assert that the response indicates an error
        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(response['body'], '{"error": "Invalid Request", "message": "An error occurred (ResourceNotFoundException) when calling the GetItem operation: Requested resource not found"}')
        self.assertEqual(response['headers']['Content-Type'], 'application/json')

if __name__ == '__main__':
    unittest.main()  # Run the unit tests
