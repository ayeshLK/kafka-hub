## Using Functional API based Websubhub

Websubhub functional API offers 9 APIs to invoke hub operations. Following are there usage and relevant request response formats.

| Function Name                  | Argument Type | Argument Structure                                                                                                            | Return Type | Return Type Structure                                     |
|-------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------|-------------|------------------------------------------------------------|
| onRegisterTopic               | json          | { topic: string, hubMode: string }                                                                                            | json        | { statusCode: int, mediaType: string, body: string }       |
| onDeregisterTopic             | json          | { topic: string, hubMode: string }                                                                                            | json        | { statusCode: int, mediaType: string, body: string }       |
| onUpdateMessage               | json          | { msgType: string, hubTopic: string, contentType: string, content: json }                                                     | json        | { statusCode: int, mediaType: string, body: string }       |
| onSubscription                | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |
| onSubscriptionValidation      | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |
| onSubscriptionVerification    | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | nil         |                                                            |
| onUnsubscription              | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |
| onUnsubscriptionValidation    | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | json        | { statusCode: int, mediaType: string, body: string }       |
| onUnsubscriptionVerification  | json          | { hub: string, hubMode: string, hubCallback: string, hubTopic: string, hubLeaseSeconds: string?, hubSecret: string? }         | nil         |                                                            |
