# IFG Claim Management Sync automation

## Overview

This script retrieves all submissions for the Claim Management form in
ProntoForms and adds or updates the data in a Smartsheet table as
appropriate. The automation runs in an ECS task in the CaaS cluster
on a schedule. The AWS resources related to this project have names in the
form of `IfgClaimManagementSync*`, e.g. `IfgClaimManagementFormSyncUser`.

## Development

Ensure you have IAM credentials under the `ifg_claim_mgmt_sync_user`
profile that provide ECR write access to the ECR repository for this project:
`cid01554/jid01495/ifg_claim_mgmt_sync`. You can use a different profile name
with the `:profile` rake task argument. See Rakefile for usage.

Review `main.rb` for required environment variables. Do __not__ hard-code
them. Provide them when executing the program via the command-line e.g.

```
$ SMARTSHEET_SHEET_ID=... SMARTSHEET_API_TOKEN=... <etc> ruby main.rb
```

## Deploy

After code changes & testing, build and push updated image to AWS ECR. Future
task executions will use this updated image.

1. `rake build`
2. `rake login`
3. `rake push`
