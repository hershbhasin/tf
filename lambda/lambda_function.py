import json
import boto3
import uuid



def get_account(message):
    if 'MessageAttributes' not in message:
        return ''

    if 'account' not in message['MessageAttributes']:
        return ''
    

    if message['MessageAttributes']['account']['Type'] == 'String':
       return message['MessageAttributes']['account']['Value']

    return ''
 
def process_message(message):
    
    item_id = str(uuid.uuid4())
    body = json.loads(message['body'])
    account = get_account(body)
    
    
    
    TABLE_NAME =""
    
    if (account == "1"):
        TABLE_NAME = 'fap-account1'
    
    elif (account == "2"):
    
        TABLE_NAME = 'fap-account2'
    else:
        TABLE_NAME = 'fap-accountall'
       

    print ("posting to table: " + TABLE_NAME)
    
    item = {
        'Id': {
            'S': item_id
        },
        'Account': {
            'S': account
        },
        'Contents': {
            'S': body['Message']
        }
    }

    dynamodb = boto3.client('dynamodb')
    response = dynamodb.put_item(TableName=TABLE_NAME, Item=item)
    status = response['ResponseMetadata']['HTTPStatusCode']

def lambda_handler(event, context):
    # print(event)

    for record in event['Records']:
       process_message(record)
