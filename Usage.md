## Using Functional API based Websubhub

Websubhub functional API offers 5 APIs to invoke hub operations. Following are there usage and relevant request response formats.

| Function Name                  | Argument Type | Argument Structure                                                                                                            | Return Type | Return Type Structure                                     |
|-------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------|-------------|------------------------------------------------------------|
| onRegisterTopic               | json          | { topic: string, hubMode: string }                                                                                            | json        | { statusCode: int, mediaType: string, body: string }       |
| onDeregisterTopic             | json          | { topic: string, hubMode: string }                                                                                            | json        | { statusCode: int, mediaType: string, body: string }       |
| onUpdateMessage               | json          | { msgType: string, hubTopic: string, contentType: string, content: json }                                                     | json        | { statusCode: int, mediaType: string, body: string }       |
| onSubscription                | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |                                                          |
| onUnsubscription              | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |                                                          |

### Mapping HTTP request to the `hub` API

#### `registerTopic` API

- HTTP Request

    ```sh
    POST /hub 
    Host: localhost:9000
    Content-Type: application/x-www-form-urlencoded

    hub.mode=register&hub.topic=topic1
    ```

- Mapped JSON payload for the method invocation

    ```json
    {
        "hubMode": "register",
        "topic": "topic1"
    }
    ```

#### `registerTopic` API

- HTTP Request

    ```sh
    POST /hub 
    Host: localhost:9000
    Content-Type: application/x-www-form-urlencoded

    hub.mode=deregister&hub.topic=topic1
    ```

- Mapped JSON payload for the method invocation

    ```json
    {
        "hubMode": "deregister",
        "topic": "topic1"
    }
    ```

#### `onUpdateMessage` API

- HTTP Request

    ```sh
    POST /hub?hub.mode=publish&hub.topic=topic1 
    Host: localhost:9000
    Content-Type: application/json
    x-ballerina-publisher: publish

    {
        "message": "This is a sample message"
    }
    ```

- Mapped JSON payload for the method invocation

    ```json
    {
        "msgType": "PUBLISH",
        "hubTopic": "topic1",
        "contentType": "application/json",
        "content": {
            "message": "This is a sample message"
        }
    }
    ```

#### `onSubscription` API

- HTTP Request

    ```sh
    POST /hub
    Host: localhost:9000
    Content-Type: application/x-www-form-urlencoded
    
    hub.mode=subscribe&hub.topic=topic1&hub.callback=https://callback.com&hub.lease_seconds=72000&hub.secret=secret1
    ```

- Mapped JSON payload for the method invocation

    ```json
    {
        "hub": "https://localhost:9000/hub",
        "hubMode": "subscribe",
        "hubTopic": "topic1",
        "hubCallback": "https://callback.com",
        "hubLeaseSeconds": "72000",
        "hubSecret": "secret1"
    }
    ```

**Note: In the subscription request `hub.lease_seconds` and `hub.secret` are optional parameters**

#### `onUnsubscription` API

- HTTP Request

    ```sh
    POST /hub
    Host: localhost:9000
    Content-Type: application/x-www-form-urlencoded
    
    hub.mode=unsubscribe&hub.topic=topic1&hub.callback=https://callback.com&hub.lease_seconds=72000&hub.secret=secret1
    ```

- Mapped JSON payload for the method invocation

    ```json
    {
        "hub": "https://localhost:9000/hub",
        "hubMode": "unsubscribe",
        "hubTopic": "topic1",
        "hubCallback": "https://callback.com",
        "hubLeaseSeconds": "72000",
        "hubSecret": "secret1"
    }
    ```

**Note: In the unsubscription request `hub.lease_seconds` and `hub.secret` are optional parameters**
