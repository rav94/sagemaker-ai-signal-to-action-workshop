"""Emit the SageMaker Pipelines definition for one workshop release."""

import json
import sys


(
    bucket, dataset_uri, training_image, serving_image, job_role,
    package_group, version, training_type, evaluation_type, serving_type,
) = sys.argv[1:]

model_uri = {"Get": "Steps.TrainModel.ModelArtifacts.S3ModelArtifacts"}
report_prefix = {
    "Std:Join": {
        "On": "/",
        "Values": [f"s3://{bucket}/evaluation-output", {"Get": "Execution.PipelineExecutionId"}],
    }
}
report_uri = {
    "Std:Join": {
        "On": "/",
        "Values": [*report_prefix["Std:Join"]["Values"], "evaluation.json"],
    }
}

training = {
    "Name": "TrainModel",
    "Type": "Training",
    "Arguments": {
        "RoleArn": job_role,
        "AlgorithmSpecification": {"TrainingImage": training_image, "TrainingInputMode": "File"},
        "InputDataConfig": [{
            "ChannelName": "train",
            "DataSource": {"S3DataSource": {
                "S3DataType": "S3Prefix",
                "S3Uri": dataset_uri,
                "S3DataDistributionType": "FullyReplicated",
            }},
        }],
        "OutputDataConfig": {"S3OutputPath": f"s3://{bucket}/training-output"},
        "ResourceConfig": {"InstanceType": training_type, "InstanceCount": 1, "VolumeSizeInGB": 10},
        "StoppingCondition": {"MaxRuntimeInSeconds": 900},
        "Environment": {
            "WORKSHOP_MODEL_VERSION": version,
            "WORKSHOP_EVALUATE_SEPARATELY": "true",
        },
        "EnableNetworkIsolation": True,
    },
}


def processing_input(name, uri):
    return {
        "InputName": name,
        "S3Input": {
            "S3Uri": uri,
            "LocalPath": f"/opt/ml/processing/{name}",
            "S3DataType": "S3Prefix",
            "S3InputMode": "File",
            "S3DataDistributionType": "FullyReplicated",
        },
    }


evaluation = {
    "Name": "EvaluateModel",
    "Type": "Processing",
    "PropertyFiles": [{
        "PropertyFileName": "EvaluationReport",
        "OutputName": "evaluation",
        "FilePath": "evaluation.json",
    }],
    "Arguments": {
        "RoleArn": job_role,
        "AppSpecification": {
            "ImageUri": training_image,
            "ContainerEntrypoint": ["python", "/opt/program/evaluate.py"],
            "ContainerArguments": [
                "--model", "/opt/ml/processing/model/model.tar.gz",
                "--data", "/opt/ml/processing/data/complaints.csv",
                "--report", "/opt/ml/processing/evaluation/evaluation.json",
            ],
        },
        "ProcessingInputs": [processing_input("model", model_uri), processing_input("data", dataset_uri)],
        "ProcessingResources": {
            "ClusterConfig": {"InstanceCount": 1, "InstanceType": evaluation_type, "VolumeSizeInGB": 10}
        },
        "ProcessingOutputConfig": {"Outputs": [{
            "OutputName": "evaluation",
            "S3Output": {
                "S3Uri": report_prefix,
                "LocalPath": "/opt/ml/processing/evaluation",
                "S3UploadMode": "EndOfJob",
            },
        }]},
        "NetworkConfig": {"EnableNetworkIsolation": True},
        "StoppingCondition": {"MaxRuntimeInSeconds": 900},
    },
}
register = {
    "Name": "RegisterCandidate",
    "Type": "RegisterModel",
    "Arguments": {
        "ModelPackageGroupName": package_group,
        "ModelPackageDescription": f"Workshop pipeline release {version}",
        "ModelApprovalStatus": "PendingManualApproval",
        "SkipModelValidation": "All",
        "CustomerMetadataProperties": {"ReleaseVersion": version},
        "InferenceSpecification": {
            "Containers": [{"Image": serving_image, "ModelDataUrl": model_uri}],
            "SupportedContentTypes": ["application/json"],
            "SupportedResponseMIMETypes": ["application/json"],
            "SupportedRealtimeInferenceInstanceTypes": [serving_type],
        },
        "ModelMetrics": {"ModelQuality": {
            "Statistics": {"ContentType": "application/json", "S3Uri": report_uri},
        }},
    },
}
gate = {
    "Name": "CheckBillingRecall",
    "Type": "Condition",
    "Arguments": {
        "Conditions": [{
            "Type": "GreaterThanOrEqualTo",
            "LeftValue": {"Std:JsonGet": {
                "PropertyFile": {"Get": "Steps.EvaluateModel.PropertyFiles.EvaluationReport"},
                "Path": "multiclass_classification_metrics.billing_recall.value",
            }},
            "RightValue": {"Get": "Parameters.MinimumBillingRecall"},
        }],
        "IfSteps": [register],
        "ElseSteps": [{
            "Name": "RejectBelowThreshold",
            "Type": "Fail",
            "Arguments": {"ErrorMessage": "Billing recall is below the configured quality gate."},
        }],
    },
}

print(json.dumps({
    "Version": "2020-12-01",
    "Parameters": [{
        "Name": "MinimumBillingRecall",
        "Type": "Float",
        "DefaultValue": 0.50,
        "Description": "Sandbox minimum recall for the billing label.",
    }],
    "Steps": [training, evaluation, gate],
}, indent=2))
