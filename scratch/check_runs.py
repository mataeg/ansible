import urllib.request
import json
import ssl

def check_github_actions():
    url = "https://api.github.com/repos/mataeg/ansible/actions/runs"
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(url, headers=headers)
    
    # Bypass SSL verification if there are container certificate issues
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode("utf-8"))
            runs = data.get("workflow_runs", [])
            if not runs:
                print("No runs found.")
                return
            
            latest = runs[0]
            print(f"Latest Run ID: {latest.get('id')}")
            print(f"Commit Message: {latest.get('head_commit', {}).get('message')}")
            print(f"Status: {latest.get('status')}")
            print(f"Conclusion: {latest.get('conclusion')}")
            print(f"HTML URL: {latest.get('html_url')}")
            print(f"Created At: {latest.get('created_at')}")
            print(f"Updated At: {latest.get('updated_at')}")
    except Exception as e:
        print(f"Error fetching runs: {e}")

if __name__ == "__main__":
    check_github_actions()
