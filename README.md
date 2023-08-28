# Amazon Cognito 기반 Amazon API Gateway 인증
Amazon Cognito 사용자 풀을 통해서 Amazo API Gateway를 통해서 생성한 REST API 매서드 인증 데모

## AWS 데모 환경 생성 

1. 테라폼 코드가 있는 디렉토리로 이동
    ```
    cd terraform
    ```

2. 테라폼 코드 실행
    ```
    terraform apply
    ```

3. 테라폼 코드 실행 후 출력되는 변수 확인
    ```
    aws_cognito_user_pool_client_id=xxxxxxx
    api_invoke_url=xxxxxxx
    ```

## 테스트

1. 데모 애플리케이션 코드가 있는 디렉토리로 이동
    ```
    cd source
    ```

2. 애플리케이션 실행에 필요한 라이브러리 설치
    ```
    pip install -r requirements.txt
    ```

3. 애플리케이션 소스 코드 수정 - cognito.py
    ```
    CLIENT_ID=테라폼 출력에서 확인한 aws_cognito_user_pool_client_id 값
    API_URL=테라폼 출력에서 확인한 api_invoke_url 값
    ```

4. 애플리케이션 실행
    ```
    python cognito.py
    ```
