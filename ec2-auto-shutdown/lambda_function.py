import boto3
import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

MAX_RUNNING_HOURS = 5
EXEMPT_TAG_KEY = "AutoShutdown"
EXEMPT_TAG_VALUE = "false"


def get_all_regions() -> list[str]:
    ec2 = boto3.client("ec2", region_name="us-east-1")
    response = ec2.describe_regions(AllRegions=False)
    return [r["RegionName"] for r in response["Regions"]]


def handler(event, context):
    cutoff = datetime.now(timezone.utc) - timedelta(hours=MAX_RUNNING_HOURS)
    regions = get_all_regions()
    stopped = []

    for region in regions:
        ec2 = boto3.client("ec2", region_name=region)
        response = ec2.describe_instances(
            Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
        )

        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                instance_id = instance["InstanceId"]
                launch_time = instance["LaunchTime"]
                tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
                name = tags.get("Name", "unnamed")

                if tags.get(EXEMPT_TAG_KEY, "").lower() == EXEMPT_TAG_VALUE:
                    logger.info("Skipping %s (%s) in %s — exempt tag set", instance_id, name, region)
                    continue

                running_hours = (datetime.now(timezone.utc) - launch_time).total_seconds() / 3600

                if launch_time < cutoff:
                    logger.info(
                        "Stopping %s (%s) in %s — running %.1fh", instance_id, name, region, running_hours
                    )
                    ec2.stop_instances(InstanceIds=[instance_id])
                    stopped.append(
                        {"region": region, "id": instance_id, "name": name, "running_hours": round(running_hours, 1)}
                    )
                else:
                    logger.info(
                        "Skipping %s (%s) in %s — only running %.1fh", instance_id, name, region, running_hours
                    )

    logger.info("Stopped %d instance(s): %s", len(stopped), stopped)
    return {"stopped_count": len(stopped), "stopped": stopped}
