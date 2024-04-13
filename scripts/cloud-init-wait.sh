#!/bin/bash
set -Ee -o pipefail
export AWS_DEFAULT_REGION=${aws_region}
command_id=$(aws ssm send-command --document-name ${ssm_document_arn} --instance-ids ${instance_id} --output text --query "Command.CommandId")
if ! aws ssm wait command-executed --command-id $command_id --instance-id ${instance_id}; then
  echo "Failed to start services on instance ${instance_id}!";
  echo "stdout:";
  aws ssm get-command-invocation --command-id $command_id --instance-id ${instance_id} --query StandardOutputContent;
  echo "stderr:";
  aws ssm get-command-invocation --command-id $command_id --instance-id ${instance_id} --query StandardErrorContent;
  exit 1;
fi;
echo "Services started successfully on the new instance with id ${instance_id}!"
