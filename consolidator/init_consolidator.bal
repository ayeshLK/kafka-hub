// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import consolidatorService.config;
import ballerinax/kafka;
import consolidatorService.util;
import consolidatorService.types;

function init() returns error? {
    // Initialize consolidator-service state
    error? stateSyncResult = syncSystemState();
    if stateSyncResult is error {
        util:logError("Error while syncing system state during startup", stateSyncResult, "FATAL");
        return;
    }

    // start the consolidator-service
    _ = @strand { thread: "any" } start consolidateSystemState();    
}

isolated function syncSystemState() returns error? {
    kafka:ConsumerConfiguration websubEventsSnapshotConfig = {
        groupId: string `websub-events-snapshot-group-${config:CONSTRUCTED_CONSUMER_ID}`,
        offsetReset: "earliest",
        topics: [config:WEBSUB_EVENTS_SNAPSHOT_TOPIC]
    };
    kafka:Consumer websubEventsSnapshotConsumer = check new (config:KAFKA_BOOTSTRAP_NODE, websubEventsSnapshotConfig);
    do {
        types:SystemStateSnapshot[] events = check websubEventsSnapshotConsumer->pollPayload(config:POLLING_INTERVAL);
        if events.length() > 0 {
            types:SystemStateSnapshot lastStateSnapshot = events.pop();
            refreshTopicCache(lastStateSnapshot.topics);
            refreshSubscribersCache(lastStateSnapshot.subscriptions);
        }
    } on fail error kafkaError {
        util:logError("Error occurred while syncing system-state", kafkaError, "FATAL");
        error? result = check websubEventsSnapshotConsumer->close();
        if result is error {
            util:logError("Error occurred while gracefully closing asb:MessageReceiver", result);
        }
        return kafkaError;
    }
    check websubEventsSnapshotConsumer->close();
}
