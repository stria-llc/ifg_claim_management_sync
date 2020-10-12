# IFG Claim Management Sync automation

## Overview

This script retrieves all submissions for the Claim Management form in
ProntoForms and adds or updates the data in a Smartsheet table as
appropriate. The automation runs in an ECS task in the CaaS cluster
on a schedule. The AWS resources related to this project have names in the
form of `IfgClaimManagementSync*`, e.g. `IfgClaimManagementFormSyncUser`.

## Environment variables

| Name | Description |
|------|-------------|
| PRONTOFORMS_API_KEY_ID | ProntoForms API key ID |
| PRONTOFORMS_API_KEY_SECRET | ProntoForms API secret key |
| PRONTOFORMS_FORM_ID | The form ID of the claim management form |
| SMARTSHEET_API_TOKEN | Smartsheet API access token |
| SMARTSHEET_SHEET_ID | ID of the Smartsheet to add claim management data to. |

## Development

Ensure you have IAM credentials under the `ifg_claim_mgmt_sync_user`
profile that provide ECR write access to the ECR repository for this project:
`cid01554/jid01495/ifg_claim_mgmt_sync`. You can use a different profile name
with the `:profile` rake task argument. See Rakefile for usage.

You can create a `.env` file that contains the various environment variable
values used to execute the task, or provide them when executing the task,
e.g.:

```
$ SMARTSHEET_SHEET_ID=... SMARTSHEET_API_TOKEN=... <etc> ruby main.rb
```

## Deploy

After code changes & testing, build and push updated image to AWS ECR. Future
task executions will use this updated image.

1. `rake build`
2. `rake login`
3. `rake push`
