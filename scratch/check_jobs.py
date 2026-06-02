import urllib.request
import json
import ssl
import sys

def check_run_jobs(run_id):
    url = f"https://api.github.com/repos/mataeg/ansible/actions/runs/{run_id}/jobs"
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(url, headers=headers)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode("utf-8"))
            jobs = data.get("jobs", [])
            for job in jobs:
                print(f"Job Name: {job.get('name')}")
                print(f"Status: {job.get('status')}")
                print(f"Conclusion: {job.get('conclusion')}")
                steps = job.get("steps", [])
                print("Steps:")
                for step in steps:
                    print(f"  - {step.get('name')}: {step.get('status')} ({step.get('conclusion')})")
    except Exception as e:
        print(f"Error fetching jobs: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        check_run_jobs(sys.argv[1])
    else:
        print("Please provide a run ID.")
