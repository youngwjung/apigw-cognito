import boto3
import requests


CLIENT_ID = ''
API_URL = ''

cognito = boto3.client('cognito-idp')

response = cognito.initiate_auth(
    AuthFlow='USER_PASSWORD_AUTH',
    AuthParameters={
        'USERNAME': 'test-user',
        'PASSWORD': 'Asdf!234'
    },
    ClientId=CLIENT_ID
)

id_token = response['AuthenticationResult']['IdToken']

req_without_cognito = requests.get(API_URL)
req_with_cognito = requests.get(API_URL, headers={'Authorization': id_token})

print(req_without_cognito.text)
print(req_with_cognito.text)
