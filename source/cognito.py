# 애플리케이션 구동에 필요한 라이브러리 불러오기
import boto3
import requests

# 애플리케이션 구동에 필요한 환경 변수 지정
CLIENT_ID = ''
API_URL = ''

# Cognito 클라이언트 시동
cognito = boto3.client('cognito-idp')

# Cognito 로그인(토큰 발급)
response = cognito.initiate_auth(
    AuthFlow='USER_PASSWORD_AUTH',
    AuthParameters={
        'USERNAME': 'test-user',
        'PASSWORD': 'Asdf!234'
    },
    ClientId=CLIENT_ID
)

# 토큰 확인
id_token = response['AuthenticationResult']['IdToken']

# 토큰 없이 API 호출
print("토큰 없이 API 호출..")
req_without_cognito = requests.get(API_URL)
print(req_without_cognito.text)

print("")

# 토큰을 포함해서 API 호출
print("토큰을 포함해서 API 호출..")
req_with_cognito = requests.get(API_URL, headers={'Authorization': id_token})
print(req_with_cognito.text)
