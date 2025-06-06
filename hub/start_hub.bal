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

import kafkaHub.types;
import kafkaHub.util;

import ballerina/log;

import wso2/mi;

function init() returns error? {
    check initializeHubState();
    log:printInfo("Websubhub service started successfully");
}

@mi:Operation
public function initHubState(json initialState) {
    do {
        types:SystemStateSnapshot systemStateSnapshot = check initialState.fromJsonWithType();
        check processWebsubTopicsSnapshotState(systemStateSnapshot.topics);
        check processWebsubSubscriptionsSnapshotState(systemStateSnapshot.subscriptions);
        // Start hub-state update worker
        _ = @strand {thread: "any"} start updateHubState();
    } on fail error err {
        util:logError("Error occurred while initializing the hub-state using the latest state-snapshot", err, severity = "FATAL");
    }
}
