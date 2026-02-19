"""
Script to trigger Databricks job via REST API.

This script is used in AzureML pipelines to trigger Databricks job execution
as part of a hybrid ML workflow.
"""

import argparse
import requests
import time
import sys
import os


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Trigger a Databricks job via REST API"
    )
    parser.add_argument(
        "--job_id",
        type=str,
        required=True,
        help="Databricks job ID to trigger"
    )
    parser.add_argument(
        "--databricks_instance",
        type=str,
        required=False,
        help="Databricks workspace URL (e.g., adb-123456789.azuredatabricks.net)"
    )
    parser.add_argument(
        "--token",
        type=str,
        required=False,
        help="Databricks access token (prefer using environment variable)"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=3600,
        help="Maximum time to wait for job completion in seconds (default: 3600)"
    )
    parser.add_argument(
        "--poll_interval",
        type=int,
        default=30,
        help="Polling interval in seconds (default: 30)"
    )
    return parser.parse_args()


def trigger_job(databricks_instance, job_id, token):
    """
    Trigger a Databricks job.
    
    Args:
        databricks_instance: Databricks workspace URL
        job_id: Job ID to trigger
        token: Access token
        
    Returns:
        run_id: The run ID of the triggered job
    """
    url = f"https://{databricks_instance}/api/2.1/jobs/run-now"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {"job_id": job_id}
    
    print(f"🚀 Triggering Databricks job {job_id}...")
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        run_id = response.json()["run_id"]
        print(f"✅ Job triggered successfully! Run ID: {run_id}")
        return run_id
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to trigger job: {e}")
        if hasattr(e.response, 'text'):
            print(f"   Response: {e.response.text}")
        sys.exit(1)


def get_run_status(databricks_instance, run_id, token):
    """
    Get the status of a Databricks job run.
    
    Args:
        databricks_instance: Databricks workspace URL
        run_id: Run ID to check
        token: Access token
        
    Returns:
        dict: Status information
    """
    url = f"https://{databricks_instance}/api/2.1/jobs/runs/get"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    params = {"run_id": run_id}
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=30)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"⚠️  Failed to get run status: {e}")
        return None


def wait_for_completion(databricks_instance, run_id, token, timeout, poll_interval):
    """
    Wait for Databricks job to complete.
    
    Args:
        databricks_instance: Databricks workspace URL
        run_id: Run ID to monitor
        token: Access token
        timeout: Maximum wait time in seconds
        poll_interval: Polling interval in seconds
        
    Returns:
        bool: True if job completed successfully, False otherwise
    """
    print(f"⏳ Waiting for job completion (timeout: {timeout}s)...")
    
    start_time = time.time()
    
    while True:
        elapsed_time = time.time() - start_time
        
        if elapsed_time > timeout:
            print(f"❌ Job execution timed out after {timeout} seconds")
            return False
        
        status_info = get_run_status(databricks_instance, run_id, token)
        
        if status_info is None:
            print("⚠️  Could not retrieve status, retrying...")
            time.sleep(poll_interval)
            continue
        
        state = status_info.get("state", {})
        life_cycle_state = state.get("life_cycle_state", "UNKNOWN")
        state_message = state.get("state_message", "")
        
        print(f"   Status: {life_cycle_state} | Elapsed: {int(elapsed_time)}s")
        
        if state_message:
            print(f"   Message: {state_message}")
        
        # Check if job has completed
        if life_cycle_state in ["TERMINATED", "SKIPPED", "INTERNAL_ERROR"]:
            result_state = state.get("result_state", "UNKNOWN")
            
            if result_state == "SUCCESS":
                print(f"✅ Job completed successfully!")
                return True
            else:
                print(f"❌ Job failed with result: {result_state}")
                error_message = state.get("state_message", "No error message available")
                print(f"   Error: {error_message}")
                return False
        
        # Wait before next poll
        time.sleep(poll_interval)


def main():
    """Main execution workflow."""
    args = parse_args()
    
    # Get Databricks instance from args or environment
    databricks_instance = args.databricks_instance or os.getenv("DATABRICKS_INSTANCE")
    if not databricks_instance:
        print("❌ Databricks instance not provided. Use --databricks_instance or DATABRICKS_INSTANCE env var")
        sys.exit(1)
    
    # Get token from args or environment
    token = args.token or os.getenv("DATABRICKS_TOKEN")
    if not token:
        print("❌ Databricks token not provided. Use --token or DATABRICKS_TOKEN env var")
        sys.exit(1)
    
    # Remove https:// prefix if present
    databricks_instance = databricks_instance.replace("https://", "")
    
    print(f"🔧 Configuration:")
    print(f"   Instance: {databricks_instance}")
    print(f"   Job ID: {args.job_id}")
    print(f"   Timeout: {args.timeout}s")
    print(f"   Poll Interval: {args.poll_interval}s")
    print()
    
    # Trigger the job
    run_id = trigger_job(databricks_instance, args.job_id, token)
    
    # Wait for completion
    success = wait_for_completion(
        databricks_instance,
        run_id,
        token,
        args.timeout,
        args.poll_interval
    )
    
    if success:
        print("\n🎉 Databricks job execution completed successfully!")
        sys.exit(0)
    else:
        print("\n💥 Databricks job execution failed!")
        sys.exit(1)


if __name__ == "__main__":
    main()
