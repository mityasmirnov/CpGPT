# Quick Fix for Access Denied Error

## The Problem
Your IAM user `cpgpt-downloader` doesn't have S3 permissions attached.

## The Solution (Choose One)

### ✅ EASIEST: Attach AmazonS3ReadOnlyAccess Policy

1. **Open AWS Console**: https://console.aws.amazon.com/iam/
2. **Go to**: IAM → Users → `cpgpt-downloader`
3. **Click**: "Add permissions" button (top right)
4. **Select**: "Attach policies directly"
5. **Search**: `AmazonS3ReadOnlyAccess`
6. **Check**: ✅ AmazonS3ReadOnlyAccess
7. **Click**: "Next" → "Add permissions"
8. **Wait**: 30 seconds
9. **Test**: 
   ```bash
   aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester
   ```

### Alternative: Create Custom Policy (If Above Doesn't Work)

1. **Go to**: IAM → Policies → "Create policy"
2. **Click**: "JSON" tab
3. **Paste**: The contents of `cpgpt-s3-policy.json` (included in this repo)
4. **Name**: `CpGPT-S3-ReadOnly`
5. **Create**: Click "Create policy"
6. **Attach**: Go back to Users → `cpgpt-downloader` → Add permissions → Attach the new policy

## Verify It Worked

After attaching the policy, run:

```bash
aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester
```

You should see:
```
                           PRE data/
                           PRE dependencies/
                           PRE models/
```

If you see this, run:
```bash
./download_models.sh
```

## Still Not Working?

1. **Check**: Are you logged into the correct AWS account?
2. **Wait**: Permissions can take up to 1 minute to propagate
3. **Verify**: In IAM → Users → `cpgpt-downloader` → Permissions tab, you should see the policy listed
