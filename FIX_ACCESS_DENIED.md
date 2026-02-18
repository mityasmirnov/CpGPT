# Fixing "Access Denied" Error

You're getting "Access Denied" because your IAM user needs explicit permissions for requester-pays S3 buckets. Here's how to fix it:

## Solution: Update IAM Permissions

### Option 1: Attach AmazonS3ReadOnlyAccess Policy (Recommended - Easiest)

1. **Go to AWS Console → IAM**
   - Navigate to https://console.aws.amazon.com/iam/
   - Click "Users" in the left sidebar

2. **Select Your User**
   - Click on `cpgpt-downloader` (or your user name)

3. **Add Permissions**
   - Click "Add permissions" button
   - Select "Attach policies directly"
   - Search for `AmazonS3ReadOnlyAccess`
   - ✅ Check the box next to it
   - Click "Next" → "Add permissions"

4. **Wait a Few Seconds**
   - AWS permissions can take 10-30 seconds to propagate

5. **Test Again**
   ```bash
   aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester
   ```

### Option 2: Create Custom Policy (If Option 1 Doesn't Work)

If `AmazonS3ReadOnlyAccess` doesn't work, create a custom policy:

1. **Go to IAM → Policies**
   - Click "Policies" in the left sidebar
   - Click "Create policy"

2. **Use JSON Editor**
   - Click the "JSON" tab
   - Paste this policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::cpgpt-lucascamillo-public",
                "arn:aws:s3:::cpgpt-lucascamillo-public/*"
            ],
            "Condition": {
                "StringEquals": {
                    "s3:RequestPayer": "requester"
                }
            }
        }
    ]
}
```

3. **Name the Policy**
   - Policy name: `CpGPT-S3-RequesterPays-ReadOnly`
   - Description: "Allow read access to CpGPT requester-pays bucket"
   - Click "Create policy"

4. **Attach to Your User**
   - Go back to IAM → Users
   - Click on `cpgpt-downloader`
   - Click "Add permissions" → "Attach policies directly"
   - Search for `CpGPT-S3-RequesterPays-ReadOnly`
   - ✅ Check the box
   - Click "Next" → "Add permissions"

5. **Test**
   ```bash
   aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester
   ```

### Option 3: Verify Current Permissions

Check what policies are currently attached:

1. **In AWS Console**
   - Go to IAM → Users → `cpgpt-downloader`
   - Click "Permissions" tab
   - Look under "Permissions policies"
   - You should see `AmazonS3ReadOnlyAccess` or a custom policy

2. **If No Policies Are Attached**
   - Follow Option 1 above to attach `AmazonS3ReadOnlyAccess`

## Common Issues

### "Policy Already Attached"
- If you see `AmazonS3ReadOnlyAccess` is already attached, wait 30 seconds and try again
- AWS permissions can take time to propagate

### "Still Getting Access Denied"
- Make sure you're using `--request-payer requester` flag
- Try logging out and back into AWS Console
- Verify you're using the correct AWS account

### "Can't See Policies"
- Make sure you're logged into the AWS account that created the IAM user
- Check you have permission to view IAM (you should if you created the account)

## Quick Test After Fixing

Once permissions are updated, test with:

```bash
# Test 1: List bucket
aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester

# Test 2: List models folder
aws s3 ls s3://cpgpt-lucascamillo-public/models/ --request-payer requester

# Test 3: Download a small file (if tests pass)
aws s3 cp s3://cpgpt-lucascamillo-public/models/small/ ./checkpoints/small --request-payer requester --recursive
```

## Expected Output

After fixing permissions, you should see:

```
                           PRE data/
                           PRE dependencies/
                           PRE models/
```

If you see this, you're ready to download! Run:
```bash
./download_models.sh
```
