// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import kafkaHub.config;
import kafkaHub.persistence as persist;
import kafkaHub.util;

import ballerina/http;
import ballerina/mime;
import ballerina/websubhub;
import ballerina/uuid;
import wso2/mi;

@mi:Operation
public isolated function onRegisterTopic(json request) returns json {
    do {
        websubhub:TopicRegistration topicRegistration = check request.fromJsonWithType();
        websubhub:TopicDeregistrationSuccess response = check registerTopic(topicRegistration);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:TopicRegistrationError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing topic registration: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function registerTopic(websubhub:TopicRegistration message)
    returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {

    string topicName = util:sanitizeTopicName(message.topic);
    lock {
        if registeredTopicsCache.hasKey(topicName) {
            return error websubhub:TopicRegistrationError(
                "Topic has already registered with the Hub", statusCode = http:STATUS_CONFLICT);
        }
    }
    error? persistingResult = persist:addRegsiteredTopic(message.cloneReadOnly());
    if persistingResult is error {
        string errMsg = string `Error occurred while persisting the topic-registration: ${persistingResult.message()}`;
        return error websubhub:TopicRegistrationError(errMsg, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
    }
    return websubhub:TOPIC_REGISTRATION_SUCCESS;
}

@mi:Operation
public isolated function onDeregisterTopic(json request) returns json {
    do {
        websubhub:TopicDeregistration topicDeregistration = check request.fromJsonWithType();
        websubhub:TopicDeregistrationSuccess response = check deregisterTopic(topicDeregistration);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:TopicDeregistrationError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing topic deregistration: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function deregisterTopic(websubhub:TopicDeregistration message)
    returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {

    string topicName = util:sanitizeTopicName(message.topic);
    lock {
        if !registeredTopicsCache.hasKey(topicName) {
            return error websubhub:TopicDeregistrationError(
                "Topic has not been registered in the Hub", statusCode = http:STATUS_NOT_FOUND);
        }
    }
    error? persistingResult = persist:removeRegsiteredTopic(message.cloneReadOnly());
    if persistingResult is error {
        string errMsg = string `Error occurred while persisting the topic-deregistration: ${persistingResult.message()}`;
        return error websubhub:TopicDeregistrationError(errMsg, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
    }
    return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
}

@mi:Operation
public isolated function onUpdateMessage(json request) returns json {
    do {
        websubhub:UpdateMessage updateMsg = check request.fromJsonWithType();
        websubhub:Acknowledgement response = check updateMessage(updateMsg);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:UpdateMessageError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing content update message: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function updateMessage(websubhub:UpdateMessage message)
    returns websubhub:Acknowledgement|websubhub:UpdateMessageError {

    string topicName = util:sanitizeTopicName(message.hubTopic);
    boolean topicAvailable = false;
    lock {
        topicAvailable = registeredTopicsCache.hasKey(topicName);
    }
    if topicAvailable {
        error? errorResponse = persist:addUpdateMessage(topicName, message);
        if errorResponse is websubhub:UpdateMessageError {
            return errorResponse;
        } else if errorResponse is error {
            string errMsg = string `Error occurred while publishing the content: ${errorResponse.message()}`;
            return error websubhub:UpdateMessageError(errMsg, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
    } else {
        return error websubhub:UpdateMessageError(
            string `Topic [${message.hubTopic}] is not registered with the Hub`, statusCode = http:STATUS_NOT_FOUND);
    }
    return websubhub:ACKNOWLEDGEMENT;
}

@mi:Operation
public isolated function onSubscription(json request) returns json {
    _ = start verifyAndValidateSubscription(request.cloneReadOnly());
    return {
        statusCode: http:STATUS_ACCEPTED,
        mediaType: mime:APPLICATION_FORM_URLENCODED,
        body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
    };
}

isolated function verifyAndValidateSubscription(json request) {
    record {| 
        int statusCode; 
        string mediaType; 
        string body;
    |}|error validateResponse = onSubscriptionValidation(request).fromJsonWithType();
    if validateResponse is error {
        return;
    }
    if validateResponse.statusCode !is http:STATUS_ACCEPTED {
        return;
    }

    onSubscriptionVerification(request);
}

public isolated function onSubscriptionValidation(json request) returns json {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        websubhub:SubscriptionDeniedError? subscriptionDenied = check validateSubscription(subscription);
        if subscriptionDenied is () {
            return {
                statusCode: http:STATUS_ACCEPTED,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
            };
        }

        map<string> params = {
            "hub.mode": "denied",
            "hub.topic": subscription.hubTopic,
            "hub.reason": subscriptionDenied.message()
        };
        _ = check util:sendNotification(subscription.hubCallback, params);
        websubhub:CommonResponse response = subscriptionDenied.detail();
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": subscriptionDenied.message()})
        };
    } on fail error e {
        util:logError("Unexpected error occurred while validating the subscription", e);
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
        };
    }
}

isolated function validateSubscription(websubhub:Subscription message) returns websubhub:SubscriptionDeniedError? {
    string topicName = util:sanitizeTopicName(message.hubTopic);
    boolean topicAvailable = false;
    lock {
        topicAvailable = registeredTopicsCache.hasKey(topicName);
    }
    if !topicAvailable {
        return error websubhub:SubscriptionDeniedError(
                string `Topic [${message.hubTopic}] is not registered with the Hub`, statusCode = http:STATUS_NOT_ACCEPTABLE);
    } else {
        string subscriberId = util:generateSubscriberId(message.hubTopic, message.hubCallback);
        websubhub:VerifiedSubscription? subscription = getSubscription(subscriberId);
        if subscription is () {
            return;
        }
        if subscription.hasKey(STATUS) && subscription.get(STATUS) is STALE_STATE {
            return;
        }
        return error websubhub:SubscriptionDeniedError(
            "Subscriber has already registered with the Hub", statusCode = http:STATUS_NOT_ACCEPTABLE);
    }
}

public isolated function onSubscriptionVerification(json request) {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        map<string?> params = {
            "hub.mode": "subscribe",
            "hub.topic": subscription.hubTopic,
            "hub.challenge": uuid:createType4AsString(),
            "hub.lease_seconds": subscription.hubLeaseSeconds
        }; 
        _ = check util:sendNotification(subscription.hubCallback, params);
        websubhub:VerifiedSubscription verifiedSubscription = {
            ...subscription
        };
        onSubscriptionIntentVerified(verifiedSubscription);
    } on fail error e {
        util:logError("Error occurred while processing subscription verification", e);
    }
}

isolated function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) {
    websubhub:VerifiedSubscription subscription = prepareSubscriptionToBePersisted(message);
    error? persistingResult = persist:addSubscription(subscription.cloneReadOnly());
    if persistingResult is error {
        util:logError("Error occurred while persisting the subscription", persistingResult);
    }
}

isolated function prepareSubscriptionToBePersisted(websubhub:VerifiedSubscription message) returns websubhub:VerifiedSubscription {
    string subscriberId = util:generateSubscriberId(message.hubTopic, message.hubCallback);
    websubhub:VerifiedSubscription? subscription = getSubscription(subscriberId);
    // if we have a stale subscription, remove the `status` flag from the subscription and persist it again
    if subscription is websubhub:Subscription {
        _ = subscription.removeIfHasKey(STATUS);
        return subscription;
    }
    if !message.hasKey(CONSUMER_GROUP) {
        string consumerGroup = util:generateGroupName(message.hubTopic, message.hubCallback);
        message[CONSUMER_GROUP] = consumerGroup;
    }
    message[SERVER_ID] = config:SERVER_ID;
    return message;
}

@mi:Operation
public isolated function onUnsubscription(json request) returns json {
    _ = start verifyAndValidateUnsubscription(request.cloneReadOnly());
    return {
        statusCode: http:STATUS_ACCEPTED,
        mediaType: mime:APPLICATION_FORM_URLENCODED,
        body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
    };
}

isolated function verifyAndValidateUnsubscription(json request) {
    record {| 
        int statusCode; 
        string mediaType; 
        string body;
    |}|error validateResponse = onUnsubscriptionValidation(request).fromJsonWithType();
    if validateResponse is error {
        return;
    }
    if validateResponse.statusCode !is http:STATUS_ACCEPTED {
        return;
    }

    onUnsubscriptionVerification(request);
}

public isolated function onUnsubscriptionValidation(json request) returns json {
    do {
        websubhub:Unsubscription unsubscription = check request.fromJsonWithType();
        websubhub:UnsubscriptionDeniedError? unsubscriptionDenied = validateUnsubscription(unsubscription);
        if unsubscriptionDenied is () {
            return {
                statusCode: http:STATUS_ACCEPTED,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: util:getFormUrlEncodedPayload({"hub.mode": "accepted"})
            };
        }

        map<string> params = {
            "hub.mode": "denied",
            "hub.topic": unsubscription.hubTopic,
            "hub.reason": unsubscriptionDenied.message()
        };
        _ = check util:sendNotification(unsubscription.hubCallback, params);
        websubhub:CommonResponse response = unsubscriptionDenied.detail();
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": unsubscriptionDenied.message()})
        };        
    } on fail error e {
        util:logError("Unexpected error occurred while validating the unsubscription", e);
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: util:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
        };
    }
}

isolated function validateUnsubscription(websubhub:Unsubscription message) returns websubhub:UnsubscriptionDeniedError? {
    string topicName = util:sanitizeTopicName(message.hubTopic);
    boolean topicAvailable = false;
    lock {
        topicAvailable = registeredTopicsCache.hasKey(topicName);
    }
    if !topicAvailable {
        return error websubhub:UnsubscriptionDeniedError(
            string `Topic [${message.hubTopic}] is not registered with the Hub`, statusCode = http:STATUS_NOT_ACCEPTABLE);
    } else {
        string subscriberId = util:generateSubscriberId(message.hubTopic, message.hubCallback);
        if !isValidSubscription(subscriberId) {
            return error websubhub:UnsubscriptionDeniedError(
                string `Could not find a valid subscriber for Topic [${message.hubTopic}] and Callback [${message.hubCallback}]`, 
                statusCode = http:STATUS_NOT_ACCEPTABLE);
        }
    }
}

public isolated function onUnsubscriptionVerification(json request) {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        map<string?> params = {
            "hub.mode": "unsubscribe",
            "hub.topic": subscription.hubTopic,
            "hub.challenge": uuid:createType4AsString(),
            "hub.lease_seconds": subscription.hubLeaseSeconds
        }; 
        _ = check util:sendNotification(subscription.hubCallback, params);
        websubhub:VerifiedUnsubscription verifiedUnsubscription = {
            ...subscription
        };
        onUnsubscriptionIntentVerified(verifiedUnsubscription);
    } on fail error e {
        util:logError("Error occurred while processing unsubscription verification", e);
    }
}

isolated function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
    error? persistingResult = persist:removeSubscription(message.cloneReadOnly());
    if persistingResult is error {
        util:logError("Error occurred while persisting the unsubscription ", persistingResult);
    }
}
