# get-tfc-applies
PowerShell script to get all Terraform Cloud Workspace applies within a given timeframe
## Details
This .ps1 script will return the successful applies for a Terraform organization within a specific timeframe. Default timeframe is start of the current month.

This script can be useful for matching applies (changes over time) to specific workspaces and projects for chargeback/showback purposes. It can optionally be sent to CSV file with the `-file` parameter.

## TO-DO
Currently the Org token is saved in plaintext to facilitate Bearer token headers. Ideally this should be cleared from meory and the org token rotated following script completion.