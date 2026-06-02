import urllib.request
import json
import ssl

def inspect_jobs_json():
    run_id = "26831309681"
    url = f"https://api.github.com/repos/mataeg/ansible/actions/runs/{run_id}/jobs"
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(url, headers=headers)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode("utf-8"))
            # Print a readable, indented version of the first job to inspect fields
            jobs = data.get("jobs", [])
            if not jobs:
                print("No jobs found.")
                return
            
            job = jobs[0]
            print(json.dumps(job, indent=2))
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_jobs_json()
