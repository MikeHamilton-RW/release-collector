#!/bin/bash

set -x

await_ci_completion(){
    while [ 1 ]
    do
        sleep 5
        BUILD_PASS="true"
        CI_STATUS=$(curl -s -H "${HEADER_AUTH_TOKEN}" -H "${HEADER_JSON}" "https://api.github.com/repos/${REPOSITORY}/commits/$1/check-runs")
        while read status;
        do
            read conclusion
            read name
            if [[ $status == *"completed"* ]] && [[ $conclusion == *"success"* ]]; then
                echo "PASS: Check ${name}, status: ${status}, conclusion: ${conclusion}"
            else
                echo "FAIL: Check ${name}, status: ${status}, conclusion: ${conclusion}"
                BUILD_PASS="false"
                break
            fi
        done <<<$(echo ${CI_STATUS} | jq '.check_runs | .[] | .status, .conclusion, .name')
        if [[ $BUILD_PASS == "true" ]]; then
            break
        fi
    done
}

HEADER_SHA="Accept: application/vnd.github.v3.sha"
HEADER_JSON="Accept: application/vnd.github.antiope-preview+json"
HEADER_AUTH_TOKEN="Authorization: token ${GITHUB_TOKEN}"

RELEASE_BRANCH_SHA=$(curl -s -H "${HEADER_AUTH_TOKEN}" -H "${HEADER_SHA}" "https://api.github.com/repos/${REPOSITORY}/commits/${RELEASE_BRANCH}")
DEVELOPMENT_BRANCH_SHA=$(curl -s -H "${HEADER_AUTH_TOKEN}" -H "${HEADER_SHA}" "https://api.github.com/repos/${REPOSITORY}/commits/${DEVELOPMENT_BRANCH}")
echo "${DEVELOPMENT_BRANCH} sha: ${DEVELOPMENT_BRANCH_SHA} , and ${RELEASE_BRANCH} sha: ${RELEASE_BRANCH_SHA}"

RESPONSE=$(curl -s -H "${HEADER_AUTH_TOKEN}" -d '{"title":"Autobuild from ReleaseCollections repo, Merge '${DEVELOPMENT_BRANCH}' to '${RELEASE_BRANCH}'","base":"'${RELEASE_BRANCH}'", "head":"'${DEVELOPMENT_BRANCH}'"}' "https://api.github.com/repos/${REPOSITORY}/pulls")

# If there are no commits between release branch and development branch, then check the latest release of that repo.
if [[ $(echo $RESPONSE | jq '.errors[0].message') != *"No commits"* ]]; then

    # Get latest release with curl
    LATEST_RELEASE_JSON=$(curl -s -H "${HEADER_AUTH_TOKEN}" "https://api.github.com/repos/${REPOSITORY}/releases/latest")

    # Allow time for status check to initialize after pull request creation above
    sleep 15

    # Wait until build status is successful for latest integration commit sha and latest master commit sha
    IFS=$''

    await_ci_completion ${DEVELOPMENT_BRANCH_SHA}

    # Get PR number
    PR_NUMBER=$(curl -H "${HEADER_AUTH_TOKEN}" "https://api.github.com/repos/${REPOSITORY}/pulls" | jq '.[] | .number')

    # Merge the PR
    MERGE_STATUS_JSON=$(curl -s -X PUT -H "${HEADER_AUTH_TOKEN}" "https://api.github.com/repos/${REPOSITORY}/pulls/${PR_NUMBER}/merge")

    # Check the status of the merge
    MERGE_STATUS=$(echo ${MERGE_STATUS_JSON} | jq '.merged')
    if [[ $MERGE_STATUS != *"true"* ]]; then
        # Exit upon merge failure. Would need further investigation into the offending repo.
        exit 1
    fi

    # Allow time for master push to start status checks
    sleep 15 

    await_ci_completion ${RELEASE_BRANCH}
fi

# Get latest release
LATEST_RELEASE_JSON=$(curl -s -H "${HEADER_AUTH_TOKEN}" "https://api.github.com/repos/${REPOSITORY}/releases/latest")

# Get latest release asset ID
ASSET_ID=$(echo ${LATEST_RELEASE_JSON} | jq '.assets[0].id')
ASSET_NAME=$(echo ${LATEST_RELEASE_JSON} | jq '.assets[0].name' | tr -d '"')
echo "::set-output name=ARTIFACT_NAME::${ASSET_NAME}"

# Download the assets attached to the release
wget -q --auth-no-challenge --header='Accept:application/octet-stream' https://${GITHUB_TOKEN}:@api.github.com/repos/${REPOSITORY}/releases/assets/${ASSET_ID} -O ${ASSET_NAME}

RELEASE_NOTES="$(echo "${LATEST_RELEASE_JSON}" | jq '.body')"
echo "::set-output name=RELEASE_NOTES::${RELEASE_NOTES}"

set +x
