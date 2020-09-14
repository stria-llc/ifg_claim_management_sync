# IFG Claim Management Sync automation

## Development

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
