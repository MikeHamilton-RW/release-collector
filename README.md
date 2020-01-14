# Release Collector Action
Pull releases from other repos to assist in creating a release collection. This action is for those working on several different repos, wanting to completely automate their workflow, and they have the need to create release collections from numnerous repos. This action will create a PR from development branch changes into the release branch, merge those changes once the status checks pass, create a release from the release branch, and then import that release and the release notes into your repo.  

If you have 30 repos, utilize this action 30 times in your yaml script, zip up the files, and create a custom release collection consisting of all of your other releases. This is helpful if you work with any sort of hardware-in-the-loop or in the embedded space.


## Action Inputs
- **GITHUB_TOKEN**: Required. Typically this will be `${{ secrets.GITHUB_TOKEN }}`.
- **REPOSITORY**: Required. User and name of the repository to pull the release. Currently, you must have permissions to create and merge PRs in that repository. Future updates will include a flag to allow pulling from any public repository.
- **RELEASE_BRANCH**: Required. Set to the release branch of the repository you are pulling from, i.e., 'master'.
- **DEVELOPMENT_BRANCH**: Required. Set to the development branch of the repository you are pulling from, i.e., 'develop' or 'integration'.


## Action Outputs
- **ARTIFACT_NAME**: The name of the binary file saved from the other repo's release.
- **RELEASE_NOTES**: String consisting of all release notes. Markdown format is encouraged.


## Example
This example will create a release when a repository dispatch event with the event type "create_release_collection" is sent:

```yml
name: Release Collection Creator

on:
  repository_dispatch:
    types: [create_release_collection]

jobs:

  build:
  
    runs-on: ubuntu-latest
    
    steps:
    
    - name: Run the actions/checkout
      uses: actions/checkout@722adc6
      
    - name: Download asset using release-collection action
      id: download_stuff
      uses: MikeHamilton-RW/release-collector@v1.0
      env:
        GITHUB_TOKEN: ${{ secrets.TOKEN }}
        REPOSITORY: my-user-name-or-organization/my-repo
        RELEASE_BRANCH: master
        DEVELOPMENT_BRANCH: develop

    - name: Print release notes to markdown file
      run: |
        printf "# "${{ steps.download_stuff.outputs.ARTIFACT_NAME }}"\n\n" >> ReleaseNotes.md
        printf ${{ steps.download_stuff.outputs.RELEASE_NOTES }}"\n\n\n" >> ReleaseNotes.md
    
    # Then create your own release with something like ncipollo/release-action
```

## Notes
- You must have full permissions to the repo you are requesting the release from. Future updates will include the ability to skip this and pull from public repos that are not your own.


## Trigger via repo dispatch
- You probably don't want to create an entire release collection each time you push this yaml script, so I highly reccomend only run on repository_dispatch:
```
curl -H "Accept: application/vnd.github.everest-preview+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --request POST \
    --data '{"event_type": "create_release_collection"}' \
    https://api.github.com/repos/:owner/:repo/dispatches
```  
