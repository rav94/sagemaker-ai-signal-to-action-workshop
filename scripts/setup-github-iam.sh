#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

subject_pattern='^repo:([A-Za-z0-9-]+/[A-Za-z0-9_.-]+|[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+):ref:refs/heads/main$'
if [[ "$#" != 1 || ! "$1" =~ $subject_pattern ]]; then
  echo "Usage: bash scripts/setup-github-iam.sh GITHUB_OIDC_SUBJECT_FOR_MAIN" >&2
  exit 2
fi
: "${AWS_PROFILE:?Set AWS_PROFILE to the teaching sandbox profile}"
: "${AWS_REGION:?Set AWS_REGION to the teaching sandbox Region}"
: "${WORKSHOP_ACCOUNT_ID:?Set WORKSHOP_ACCOUNT_ID to the approved teaching account ID}"
export AWS_PAGER=""

stack="${WORKSHOP_STACK:-sagemaker-ai-signal-insight-action-workshop}"
if [[ ! "$stack" =~ ^[A-Za-z][A-Za-z0-9-]{0,53}$ ]]; then
  echo "Choose a CloudFormation base stack name of at most 54 characters." >&2
  exit 2
fi

caller=$(aws sts get-caller-identity --query '[Account,Arn]' --output text)
IFS=$'\t' read -r account caller_arn <<< "$caller"
if [[ "$account" != "$WORKSHOP_ACCOUNT_ID" || "$caller_arn" != arn:* ]]; then
  echo "AWS caller account does not match the approved teaching account." >&2
  exit 2
fi

assets=$(aws cloudformation describe-stacks --stack-name "${stack}-assets" \
  --query "Stacks[0].[Outputs[?OutputKey=='ArtifactBucket'].OutputValue | [0], Outputs[?OutputKey=='ImageRepositoryUri'].OutputValue | [0]]" \
  --output text)
IFS=$'\t' read -r artifact_bucket repository_uri <<< "$assets"
if [[ -z "$artifact_bucket" || "$artifact_bucket" == None || "$repository_uri" != */?* ]]; then
  echo "Workshop assets outputs are missing. Run the workshop launcher first." >&2
  exit 2
fi

partition="${caller_arn#arn:}"
provider_host=token.actions.githubusercontent.com
provider_arn="arn:${partition%%:*}:iam::$account:oidc-provider/$provider_host"
audience=sts.amazonaws.com

provider=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?Arn=='$provider_arn'].Arn | [0]" --output text)
if [[ "$provider" != "$provider_arn" ]]; then
  if created=$(aws iam create-open-id-connect-provider --url "https://$provider_host" \
      --client-id-list "$audience" --query OpenIDConnectProviderArn --output text 2>&1); then
    printf 'Created account OIDC provider %s\n' "$provider_arn"
  elif [[ "$created" != *EntityAlreadyExists* ]]; then
    printf '%s\n' "$created" >&2
    exit 1
  fi
fi

# IAM can take a moment to make a newly created provider visible.
for attempt in 1 2 3 4 5; do
  if has_audience=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" \
      --query "contains(ClientIDList || \`[]\`, '$audience')" --output text 2>&1); then
    break
  fi
  if [[ "$has_audience" != *NoSuchEntity* || "$attempt" == 5 ]]; then
    printf '%s\n' "$has_audience" >&2
    exit 1
  fi
  sleep 2
done
case "$has_audience" in
  True) ;;
  False)
    aws iam add-client-id-to-open-id-connect-provider \
      --open-id-connect-provider-arn "$provider_arn" --client-id "$audience"
    ;;
  *)
    echo "Could not verify the GitHub OIDC provider audience." >&2
    exit 1
    ;;
esac
printf 'Using account OIDC provider %s with audience %s\n' "$provider_arn" "$audience"

aws cloudformation deploy --template-file github-deploy-iam.yaml \
  --stack-name "${stack}-github-iam" --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides "GitHubOidcSubject=$1" "WorkshopStack=$stack" \
  "ArtifactBucket=$artifact_bucket" "ImageRepositoryName=${repository_uri#*/}"
aws cloudformation describe-stacks --stack-name "${stack}-github-iam" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
